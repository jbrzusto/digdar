/**
 * forked from:
 * 
 * @brief Red Pitaya Oscilloscope worker module.
 * 
 * @Author Jure Menart <juremenart@gmail.com>
 * 
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in C programming language.
 * Please visit http://en.wikipedia.org/wiki/C_(programming_language)
 * for more details on the language used herein.
 */

#ifndef __WORKER_H
#define __WORKER_H

#ifdef __cplusplus
extern "C" {
#endif

#include "pulse_metadata.h"
#include "digdar.h"

#include "fpga_digdar.h"
extern digdar_fpga_reg_mem_t *g_digdar_fpga_reg_mem;

/** @defgroup digdar_h digdar_h
 * @{
 */

/** @brief Worker state enumenartion
 *
 * Enumeration used by main and worker modules to set workers module operation.
 */
typedef enum rp_osc_worker_state_e {
    /** do nothing, idling */
    rp_osc_idle_state = 0, 
    /** requests an shutdown of the worker thread */
    rp_osc_quit_state,
    /* abort current measurement */
    rp_osc_start_state,
    /* auto mode acquisition - continuous measurements without trigger */ 
    rp_osc_running_state, 
    /* non existing state - just to define the end of enumeration - must be
     * always last in the enumeration */
    rp_osc_nonexisting_state
} rp_osc_worker_state_t;

/** @} */

int rp_osc_worker_init(void);
int rp_osc_worker_exit(void);
int rp_osc_worker_change_state(rp_osc_worker_state_t new_state);
int rp_osc_worker_update_params(rp_osc_params_t *params, int fpga_update);

/* Returns:
 *  0 - no pulse captured
 *  1 - pulse captured
 */

int rp_osc_get_pulse(pulse_metadata * pm, uint16_t ns, uint16_t *data, uint32_t timeout);

int rp_osc_get_chunk_for_reader(uint16_t * cur_pulse, uint16_t * num_pulses);
int16_t rp_osc_get_chunk_index_for_writer();

extern uint16_t n_samples;  // samples to grab per radar pulse
extern uint32_t decim; // decimation: 1, 2, or 8
extern uint16_t num_pulses; // pulses to maintain in ring buffer (filled by worker thread)
extern uint16_t chunk_size; // pulses to transmit per chunk (main thread)
extern uint16_t num_chunks; // number of chunks in ring buffer
extern uint16_t *pulses_in_chunk; // number of pulses in each buffer chunk
extern uint32_t psize; // size of each pulse's storage

typedef struct {
  float begin;
  float end;
} sector;

#define MAX_REMOVALS 32
extern sector removals[MAX_REMOVALS];
extern uint16_t num_removals;

extern pulse_metadata *pulse_buffer;

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* __WORKER_H*/
