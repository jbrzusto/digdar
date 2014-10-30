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
    rp_osc_abort_state,
    /* auto mode acquisition - continuous measurements without trigger */ 
    rp_osc_auto_state, 
    /* normal mode - continuous measurements with trigger */
    rp_osc_normal_state,
    /* single mode - one measurement with trigger then go to idle state */
    rp_osc_single_state,
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
int rp_osc_get_pulse(captured_pulse_t *pulse);

#endif /* __WORKER_H*/
