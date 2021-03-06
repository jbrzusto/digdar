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

static int16_t reader_chunk_index = -1; // which chunk is currently being read by the export thread
static int16_t writer_chunk_index = 0;  // which chunk is currently being written by the capture thread

int rp_osc_get_chunk_for_reader(uint16_t * cur_pulse, uint16_t * num_pulses) {
  // return the index of the first pulse in a chunk, and the number of pulses in the chunk
  // It must already have been filled by writer.
  // These values are returned in the passed pointers; the function returns
  // 1 if successful, 0 otherwise (e.g. if there are no pulses to read.)
  int16_t ci;
  pthread_mutex_lock(&rp_osc_ctrl_mutex);
  // try bump up to the next chunk in the ring
  ci = (1 + reader_chunk_index) % num_chunks;
  // if it's the writer's chunk, we fail
  if (ci == writer_chunk_index)
    ci = -1;
  else
    reader_chunk_index = ci;
  // Note: it's possible the writer has passed us,
  // in which case it makes more sense to skip the
  // as-yet unwritten chunks, because otherwise we'll
  // be interleaving new and old ones.
  pthread_mutex_unlock(&rp_osc_ctrl_mutex);

  if (ci < 0)
    return 0; // fail

  *cur_pulse = ci * chunk_size;
  *num_pulses = pulses_in_chunk[reader_chunk_index];

  return 1;
};

int16_t rp_osc_get_chunk_index_for_writer() {
  // return the index of a chunk which the writer can write to.
  // Normally, it's the next chunk in the ring, except that
  // we skip over the reader's current chunk.

  int16_t rv;
  pthread_mutex_lock(&rp_osc_ctrl_mutex);
  rv = (1 + writer_chunk_index) % num_chunks;
  if (rv == reader_chunk_index)
    rv = (1 + rv) % num_chunks;
  writer_chunk_index = rv;
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
    osc_fpga_set_trigger_delay(n_samples);

    osc_fpga_set_decim(decim);

    int did_first_arm = 0;

    int32_t *max_data = & rp_fpga_cha_signal[16384];

    int16_t n = 0;  // number of pulses written to chunk
    int16_t cur_pulse = 0; // index of current pulse in ring buffer

    struct timespec rtc = {0, 0}; // realtime clock for start of pulse digitizing
    uint32_t prev_arp_clock_low = 0;   // saved arp clock (125 MHz digitizing clock); used to detect new ARP

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
        continue;
      }

      // get trigger write pointer (i.e. where do data start?)
      int32_t tr_ptr;
      int32_t wr_ptr;
      osc_fpga_get_wr_ptr(&wr_ptr, &tr_ptr);


      // read ARP registers

      uint32_t trig_count = g_digdar_fpga_reg_mem->saved_trig_count - g_digdar_fpga_reg_mem->saved_trig_at_arp;
      uint32_t arp_clock_low = g_digdar_fpga_reg_mem->saved_arp_clock_low;
      uint32_t trig_clock_low = g_digdar_fpga_reg_mem->saved_trig_clock_low;
      uint32_t acp_clock_low = g_digdar_fpga_reg_mem->saved_acp_clock_low;
      uint32_t acp_at_arp = g_digdar_fpga_reg_mem->saved_acp_at_arp;
      uint32_t acp_count = g_digdar_fpga_reg_mem->saved_acp_count;
      uint32_t arp_count = g_digdar_fpga_reg_mem->saved_arp_count;

      // FIXME: do the ADC / RTC time pinning in the writer thread, not here,
      // so that we don't do a mode switch.
      // outgoing arp_clock_sec and arp_clock_nsec fields are set using a time pin:
      // whenever we notice a change in arp clock ticks, we grab the system time.

      // we only check the low order 32-bits of clock, because there's no
      // way it could have wrapped the full 32-bit range between two heading pulses
      // (that would be ~32 seconds)

      unsigned char need_new_chunk = 0;

      if (arp_clock_low != prev_arp_clock_low) {
        // we're onto a new ARP, so back-calculate what the RTC would have been
        // given that the current rtc corresponds to the current pulse, which
        // has come some time after the ARP.

        // First, pin the ADC clock to the red pitaya's RTC
        uint32_t adc_clock = (uint32_t) g_digdar_fpga_reg_mem->clocks; // lower order ADC clocks
        clock_gettime(CLOCK_REALTIME, &rtc);

        // back-calculate to time of ARP pulse
        rtc.tv_nsec -= 8 * (adc_clock - arp_clock_low); // @ 125 MHz, each ADC clock tick is 8ns
        if (rtc.tv_nsec < 0) {
          --rtc.tv_sec;
          rtc.tv_nsec += 1000000000;
        }
        prev_arp_clock_low = arp_clock_low;
        need_new_chunk = 1;
      }

      if (n == chunk_size || need_new_chunk) {
        // a new chunk is begun each time the count of pulses digitized has reached
        // the chunk size, or when the ARP has increased.  This aligns chunks so
        // that the reader thread can grab an entire sweep at a time, in situations
        // such as retention of only a sector of the image, where it is beneficial
        // to write out pulse data to clients during the dead portion of the sweep.

        pulses_in_chunk[writer_chunk_index] = n;
        n = 0;
        cur_pulse = rp_osc_get_chunk_index_for_writer() * chunk_size;
      }

      pulse_metadata *pbm = (pulse_metadata *) (((char *) pulse_buffer) + cur_pulse * psize);

      // trig clock is relative to arp clock
      pbm->trig_clock = trig_clock_low - arp_clock_low;

      // this is a bit dumb; we're recording the high-res ARP timestamp with
      // each digitized pulse, even though it only changes once per sweep.

      pbm->arp_clock_sec = rtc.tv_sec;
      pbm->arp_clock_nsec = rtc.tv_nsec;

      // acp clock is N + M, where N is the number of ACPs since the latest ARP,
      // and M is the fraction of 8 ms represented by the time since the latest ACP
      // i.e. M = elapsed ADC clock ticks / 1E6
      // it is up to the client to convert this to a true azimuth clock in 0..1,
      // based upon knowning how many ACPs there are per sweep.
      // The only assumption here is that ACPs are spaced no further than 8 ms
      // apart.   With the Furuno having 450 ACPs per sweep, even at the very slow
      // 20 rpm, ACPs are 6.67 ms apart.

      pbm->acp_clock = acp_count - acp_at_arp;
      float extra = (uint32_t) (trig_clock_low - acp_clock_low) / 1.0e6;
      if (extra >= 0.999)
        extra = 0.999;
      pbm->acp_clock += extra;

      pbm->num_trig = trig_count;

      pbm->num_arp = arp_count;

      // arm to allow acquisition of next pulse while we copy data from the BRAM buffer
      // for this one.

      osc_fpga_arm_trigger();

      /* Start the trigger: 10 is the digdar trigger source on TRIG line; FIXME: find the .H file where this is defined */
      osc_fpga_set_trigger(10);

      /* check whether this pulse is in a removal segment */
      if (num_removals) {
        int keep = 1;
        uint16_t rr = pbm->acp_clock;
        for (int i = 0; keep && i < num_removals; ++i) {
          if (removals[i].begin <= removals[i].end) {
            if (rr >= removals[i].begin && rr <= removals[i].end)
              keep = 0;
          } else if (rr >= removals[i].begin || rr <= removals[i].end) {
            keep = 0;
          }
        }
        if (! keep)
          continue;
      }

      uint16_t * data = & pbm->data[0];
      int32_t *src_data = & rp_fpga_cha_signal[tr_ptr];
      uint16_t n1 = max_data - src_data;
      uint16_t n2;
      if (n1 >= n_samples) {
        n1 = n_samples;
        n2 = 0;
      } else {
        n2 = n_samples - n1;
      }
      uint16_t i=0;
      // when tr_ptr is odd, we need to start with the higher-order word
      uint32_t tmp;
      if (tr_ptr & 1) {
        tmp = src_data[i]; // double-width read from the FPGA, as this is the rate-limiting step
        data[0] = tmp >> 16;
        ++i;
      }
      for (/**/ ; i < n1; ++i) {
        tmp = src_data[i]; // double-width read from the FPGA, as this is the rate-limiting step
        data[i] = tmp & 0xffff;
        if (++i < n1)
          data[i] = tmp >> 16;
      }
      if (n2) {
        src_data = & rp_fpga_cha_signal[0];
        data = &data[i];
        for (i = 0; i < n2; ++i) {
          tmp = src_data[i]; // double-width read from the FPGA, as this is the rate-limiting step
          data[i] = tmp & 0xffff;
          if (++i < n2)
            data[i] = tmp >> 16;
        }
      }
      ++cur_pulse;
      ++n;
    }
    return 0;
}
