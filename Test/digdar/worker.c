/**
 * forked from:
 *
 * @brief Red Pitaya Oscilloscope worker module.
 *
 * @Author Jure Menart <juremenart@gmail.com>
 *         Ales Bardorfer <ales.bardorfer@redpitaya.com>
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in C programming language.
 * Please visit http://en.wikipedia.org/wiki/C_(programming_language)
 * for more details on the language used herein.
 * This module is multi-threaded and is using synchronization with mutexes
 * from POSIX thread library. For these topics please visit:
 * http://en.wikipedia.org/wiki/POSIX_Threads
 */

#include <stdio.h>
#include <pthread.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <math.h>
#include <stdlib.h>

#include "main_digdar.h"
#include "worker.h"
#include "fpga_digdar.h"

/**
 * GENERAL DESCRIPTION:
 *
 * The worker module is linking point between main digdar module and FPGA
 * module. 
 *
 * It is running continuously in separate thread and controls FPGA OSC module. If
 * the oscilloscope is running in auto or manual mode it collects results, 
 * process them and put them to main module, where they are available for the 
 * client. In the opposite direction main module is setting new parameters which 
 * are used by worker by each new iteration of the worker thread loop. If 
 * parameters change during measurement, this is aborted and worker updates new 
 * parameters and starts new measurement.
 * Third party of the data is control of the worker thread loop - main or worker
 * module can change the state of the loop. Possible states are defined in
 * rp_osc_worker_state_e enumeration.
 *
 * Signal and parameters structures between worker and main module are protected
 * with mutexes - which means only one can access them at the same time. With 
 * this the consistency of output (signal) or input (parameters) data is assured.
 * 
 * Besides interfacing main and FPGA module big task of worker module is also 
 * processing the result, this includes:
 *  - preparing time vector, based on current settings
 *  - decimating the signal length from FPGA buffer length (OSC_FPGA_SIG_LEN) to
 *    output signal length (SIGNAL_LENGTH defined in main_osc.h). 
 *  - converting signal from ADC samples to voltage in [V].
 */

/** POSIX thread handler */
pthread_t rp_osc_thread_handler;
/** Worker thread function declaration */
void *rp_osc_worker_thread(void *args);

/** pthread mutex used to protect parameters and related variables */
pthread_mutex_t       rp_osc_ctrl_mutex = PTHREAD_MUTEX_INITIALIZER;
/** Worker thread state holder */
rp_osc_worker_state_t rp_osc_ctrl;
/** Worker module copy of parameters (copied from main parameters) */
rp_osc_params_t       rp_osc_params[PARAMS_NUM];
/** Signalizer if new parameters were copied */
int                   rp_osc_params_dirty;
/** Signalizer if worker thread loop needs to update FPGA registers */
int                   rp_osc_params_fpga_update;

/** pthread mutex used to protect signal structure and related variables */
pthread_mutex_t       rp_osc_sig_mutex = PTHREAD_MUTEX_INITIALIZER;
/** Output signals holder */
float               **rp_osc_signals;
/** Output signals signalizer - it indicates to main whether new signals are 
 *  available or not */
int                   rp_osc_signals_dirty = 0;
/** Output signal index indicator - used in long acquisitions, it indicates 
 *  to main module if the returning signal is full or partial
 */
int                   rp_osc_sig_last_idx = 0;

/** Pointers to the FPGA input signal buffers for Channel A and B */
int                  *rp_fpga_cha_signal, *rp_fpga_chb_signal;

/** Pointers to the FPGA input signal buffers for Slow Channel A and B */
int                  *rp_fpga_xcha_signal, *rp_fpga_xchb_signal;

/** @brief Initializes worker module
 *
 * This function starts new worker thread, initializes internal structures 
 * (signals, state, ...) and initializes FPGA module.
 *
 * @retval -1 Failure
 * @retval 0 Success
*/
int rp_osc_worker_init(void)
{
  int ret_val;

    rp_osc_ctrl               = rp_osc_idle_state;
    rp_osc_params_dirty       = 0;
    rp_osc_params_fpga_update = 0;

    /* FPGA module initialization */
    if(osc_fpga_init() < 0) {
        return -1;
    }

    /* Initializing the pointers for the FPGA input signal buffers */
    osc_fpga_get_sig_ptr(&rp_fpga_cha_signal, &rp_fpga_chb_signal, &rp_fpga_xcha_signal, &rp_fpga_xchb_signal);

    /* Creating worker thread */
    ret_val = 
        pthread_create(&rp_osc_thread_handler, NULL, rp_osc_worker_thread, NULL);
    if(ret_val != 0) {
        osc_fpga_exit();

        fprintf(stderr, "pthread_create() failed: %s\n", 
                strerror(errno));
        return -1;
    }

    return 0;
}

/** @brief Cleans up worker module.
 *
 * This function stops the working thread (sending quit state to it) and waits
 * until it is shutdown. After that it cleans up FPGA module and internal 
 * structures.
 * After this function is called any access to worker module are forbidden.
 *
 * @retval 0 Always returns 0
*/
int rp_osc_worker_exit(void)
{
  int ret_val;

    rp_osc_worker_change_state(rp_osc_quit_state);
    ret_val = pthread_join(rp_osc_thread_handler, NULL);
    if(ret_val != 0) {
        fprintf(stderr, "pthread_join() failed: %s\n", 
                strerror(errno));
    }

    osc_fpga_exit();
    return 0;
}

/** @brief Changes the worker state
 *
 * This function is used to change the worker thread state. When new state is
 * requested, it is not effective immediately. It is changed only when thread
 * loop checks and accepts it (for example - if new state is requested during
 * signal processing - the worker thread loop will detect change in the state
 * only after it finishes the processing.
 *
 * @param [in] new_state New requested state
 *
 * @retval -1 Failure
 * @retval 0 Success
 **/
int rp_osc_worker_change_state(rp_osc_worker_state_t new_state)
{
    if(new_state >= rp_osc_nonexisting_state)
        return -1;
    pthread_mutex_lock(&rp_osc_ctrl_mutex);
    rp_osc_ctrl = new_state;
    pthread_mutex_unlock(&rp_osc_ctrl_mutex);
    return 0;
}

/** @brief Updates the worker copy of the parameters 
 *
 * This function is used to update the parameters in worker. These parameters are
 * not effective immediately. They will be used by worker thread loop after 
 * current operation is finished.
 * 
 * @param [in] params New parameters
 * @param [in] fpga_update Flag is FPGA needs to be updated.
 *
 * @retval 0 Always returns 0
 **/
int rp_osc_worker_update_params(rp_osc_params_t *params, int fpga_update)
{
    pthread_mutex_lock(&rp_osc_ctrl_mutex);
    memcpy(&rp_osc_params, params, sizeof(rp_osc_params_t)*PARAMS_NUM);
    rp_osc_params_dirty       = 1;
    rp_osc_params_fpga_update = fpga_update;
    pthread_mutex_unlock(&rp_osc_ctrl_mutex);
    return 0;
}


static uint16_t cur_pulse = 0; // index into pulses buffer

uint16_t rp_osc_get_current_pulse_index() {
  uint16_t rv;
  pthread_mutex_lock(&rp_osc_ctrl_mutex);
  rv = cur_pulse;
  pthread_mutex_unlock(&rp_osc_ctrl_mutex);
  return(rv);
};

void *rp_osc_worker_thread(void *args)
{
    rp_osc_worker_state_t state = rp_osc_idle_state;

    pthread_mutex_lock(&rp_osc_ctrl_mutex);
    state = rp_osc_ctrl;
    pthread_mutex_unlock(&rp_osc_ctrl_mutex);

    /* set number of samples to collect after triggering */
    osc_fpga_set_trigger_delay(spp);

    osc_fpga_set_decim(decim);

    static int did_first_arm = 0;

    int32_t *max_data = & rp_fpga_cha_signal[16384];

    /* Continuous thread loop (exited only with 'quit' state) */
    while(1) {
        state = rp_osc_ctrl;

        /* request to stop worker thread, we will shut down */

        if(state == rp_osc_quit_state) {
            return 0;
        }

        if(state == rp_osc_idle_state) {
            usleep(10000);
            continue;
        }

        if(state != rp_osc_start_state) {
          usleep(1000);
          continue;
        }

        if (! did_first_arm) {
          osc_fpga_arm_trigger();
          osc_fpga_set_trigger(10);
          did_first_arm = 1;
        }

        if( ! osc_fpga_triggered()) {
          usleep(10);
          sched_yield();
          continue;
        }

        // get trigger write pointer (i.e. where do data start?)
        int32_t tr_ptr;
        int32_t wr_ptr;
        osc_fpga_get_wr_ptr(&wr_ptr, &tr_ptr);

        pulse_metadata *pbm = (pulse_metadata *) (((char *) pulse_buffer) + cur_pulse * psize);
        pbm->trig_clock = g_digdar_fpga_reg_mem->saved_trig_clock_low + (((uint64_t) g_digdar_fpga_reg_mem->saved_trig_clock_high) << 32);
        pbm->num_trig = g_digdar_fpga_reg_mem->saved_trig_count;
        pbm->num_acp = g_digdar_fpga_reg_mem->saved_acp_count;
        pbm->acp_clock = g_digdar_fpga_reg_mem->saved_acp_clock_low + (((uint64_t) g_digdar_fpga_reg_mem->saved_acp_clock_high) << 32);
        pbm->num_arp = g_digdar_fpga_reg_mem->saved_arp_count;
        pbm->arp_clock = g_digdar_fpga_reg_mem->saved_arp_clock_low + (((uint64_t) g_digdar_fpga_reg_mem->saved_arp_clock_high) << 32);

        // arm to allow acquisition of next pulse while we copy data from the BRAM buffer
        // for this one.

        osc_fpga_arm_trigger();
        
        /* Start the trigger: 10 is the digdar trigger source on TRIG line; FIXME: find the .H file where this is defined */
        osc_fpga_set_trigger(10);

        uint16_t * data = & pbm->data[0];
        int32_t *src_data = & rp_fpga_cha_signal[tr_ptr];
        uint16_t n1 = max_data - src_data;
        uint16_t n2;
        if (n1 >= spp) {
          n1 = spp;
          n2 = 0;
        } else {
          n2 = spp - n1;
        }
        uint16_t i;
        for (i = 0; i < n1; ++i) {
          data[i] = src_data[i];
        }
        if (n2) {
          src_data = & rp_fpga_cha_signal[0];
          data = &data[i];
          for (i = 0; i < n2; ++i) {
            data[i] = src_data[i];
          }
        }

        pthread_mutex_lock(&rp_osc_ctrl_mutex);
        ++cur_pulse;
        if (cur_pulse == num_pulses)
          cur_pulse = 0;
        pthread_mutex_unlock(&rp_osc_ctrl_mutex);
    }
    return 0;
}


