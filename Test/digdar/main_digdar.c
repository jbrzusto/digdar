/**
 * forked from:
 *
 * $Id: main_osc.c 892 2013-12-17 12:16:18Z rp_jmenart $
 *
 * @brief Red Pitaya Oscilloscope main module.
 *
 * @Author Jure Menart <juremenart@gmail.com>
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in C programming language.
 * Please visit http://en.wikipedia.org/wiki/C_(programming_language)
 * for more details on the language used herein.
 */

#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <pthread.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <errno.h>

#include "digdar.h"
#include "main_digdar.h"
#include "fpga_digdar.h"
#include "worker.h"

/** 
 * GENERAL DESCRIPTION:
 *
 * Main oscilloscope module takes care of setting up the oscilloscope application
 * (initializing worker thread and FPGA) and providing the interface for the
 * client, which includes parameters and signal handling.
 * 
 * This module can be used as standalone application (example acquire.c) or as 
 * part of Red Pitaya Bazaar application (together with web server and web page).
 * 
 */

/** Main oscilloscope application parameter table */
static rp_osc_params_t rp_main_params[PARAMS_NUM] = {
    { /** min_gui_time   */ -1000000, 1, 0, -10000000, +10000000 },
    { /** max_gui_time   */ +1000000, 1, 0, -10000000, +10000000 },
    { /** trig_mode:
       *    0 - auto
       *    1 - normal
       *    2 - single  */         1, 1, 0,         0,         2 },
    { /** trig_source:
       *    0 - ChA
       *    1 - ChB
       *    2 - ext.    */         10, 1, 0,        1,         12 },
    { /** trig_edge:
       *    0 - rising
       *    1 - falling */         0, 1, 0,         0,         1 },
    { /** trig_delay     */        0, 1, 0, -10000000, +10000000 },
    { /** trig_level     */        0, 1, 0,       -14,       +14 },
    { /** single_button:
       *    0 - ignore 
       *    1 - trigger */         0, 1, 0,         0,         1 },
    { /** decimation:
       *    1, 2, 8, 64, 1024, 8192, 65536  */
                                   1, 1, 0,         1,         65536 },
    { /** time_unit_used:
       *    0 - [us]
       *    1 - [ms]
       *    2 - [s]     */         0, 0, 1,         0,         2 },
    { /** Equalization filter:
       *    0 - Disabled
       *    1 - Enabled */         0, 0, 0,         0,         1 },
    { /** Shaping filter:
       *    0 - Disabled
       *    1 - Enabled */         0, 0, 0,         0,         1 },
    { /** Channel1 gain:
       *    0 - LV
       *    1 - HV */              0, 0, 0,         0,         1 },
    { /** Channel2 gain:
       *    0 - LV
       *    1 - HV */              0, 0, 0,         0,         1 }
};


/** @brief Returns application description.
 *
 * This function returns constant string with application description.
 *
 * @retval <string> Application description string.
 */
const char *rp_app_desc(void)
{
    return (const char *)"Red Pitaya osciloscope application.\n";
}

/** @brief Initializes oscilloscope application sub-modules and structures.
 *
 * This function initializes worker module and initializes the parameters.
 *
 * @retval -1 Failure
 * @retval 0  Success
*/
int rp_app_init(void)
{
    float p[PARAMS_NUM];
    int i;

    if(rp_osc_worker_init() < 0) {
        return -1;
    }

    for(i = 0; i < PARAMS_NUM; i++)
        p[i] = rp_main_params[i].value;
    p[TRIG_DLY_PARAM] = -100;

    rp_set_params(&p[0], PARAMS_NUM);

    return 0;
}

/** @brief Cleans up oscilloscope application sub-modules and structures.
 * 
 * This function cleans up worker module.
 *
 * @retval 0 Always returns 0.
 */
int rp_app_exit(void)
{
    rp_osc_worker_exit();

    return 0;
}

/** @brief Sets parameters in the worker class.
 *
 * This function takes as an argument the array of parameters p of length len
 * checks the parameters and adopt them if necessary. When new parameters are
 * calculated it passes them to worker module.
 *
 * @param [in] p Input parameters array.
 * @param [in] len Input parameters array length.
 * 
 * @retval -1 Failure
 * @retval 0 Success
*/
int rp_set_params(float *p, int len)
{
    int i;
    int params_change = 0;

    if(len > PARAMS_NUM) {
        fprintf(stderr, "Too much parameters, max=%d\n", PARAMS_NUM);
        return -1;
    }

    for(i = 0; i < len; i++) {
        if(rp_main_params[i].read_only)
            continue;

        if(rp_main_params[i].value != p[i]) {
            params_change = 1;
        }
        if(rp_main_params[i].min_val > p[i]) {
            fprintf(stderr, "Incorrect parameters value: %f (min:%f), "
                    " correcting it\n", p[i], rp_main_params[i].min_val);
            p[i] = rp_main_params[i].min_val;
        } else if(rp_main_params[i].max_val < p[i]) {
            fprintf(stderr, "Incorrect parameters value: %f (max:%f), "
                    " correcting it\n", p[i], rp_main_params[i].max_val);
            p[i] = rp_main_params[i].max_val;
        }

        rp_main_params[i].value = p[i];
    }

    /* If new parameters were set, check them and adopt needed things */
    if(params_change) {
        /* First do health check and then send it to the worker! */
        int mode = rp_main_params[TRIG_MODE_PARAM].value;
        int dec_factor = rp_main_params[DECIM_FACTOR_PARAM].value;
        float smpl_period = c_osc_fpga_smpl_period * dec_factor;
        /* t_delay - trigger delay in seconds */
        float t_delay = rp_main_params[TRIG_DLY_PARAM].value;
        float t_unit_factor = 1; /* to convert to seconds */

        /* Our time window with current settings:
         *   - time_delay is added later, when we check if it is correct 
         *     setting 
         */
        float t_min = 0;
        float t_max = ((OSC_FPGA_SIG_LEN-1) * smpl_period);

        /* in time units time_unit, needs to be converted */
        float t_start = rp_main_params[MIN_GUI_PARAM].value;
        float t_stop  = rp_main_params[MAX_GUI_PARAM].value;
        int t_start_idx;
        int t_stop_idx;
        int t_step_idx = 0;

        /* if AUTO reset trigger delay */
        if(mode == 0) 
            t_delay = 0;

        /* Check if trigger delay in correct range, otherwise correct it
         * Correct trigger delay is:
         *  t_delay >= -t_max
         *  t_delay <= OSC_FPGA_MAX_TRIG_DELAY
         */
        if(t_delay < -t_max) {
            t_delay = -t_max;
        } else if(t_delay > (OSC_FPGA_TRIG_DLY_MASK * smpl_period)) {
            t_delay = OSC_FPGA_TRIG_DLY_MASK * smpl_period;
        } else {
            t_delay = round(t_delay / smpl_period) * smpl_period;
        }
        t_min = t_min + t_delay;
        t_max = t_max + t_delay;
        rp_main_params[TRIG_DLY_PARAM].value = t_delay;

        /* convert to seconds */
        t_start = t_start / t_unit_factor;
        t_stop  = t_stop  / t_unit_factor;

        /* Select correct time window with this settings:
         * time window is defined from:
         *  ([ 0 - 16k ] * smpl_period) + trig_delay */
        /* round to correct/possible values - convert to nearest index
         * and back 
         */
        t_start_idx = round(t_start / smpl_period);
        t_stop_idx  = round(t_stop / smpl_period);

        t_start = (t_start_idx * smpl_period);
        t_stop  = (t_stop_idx * smpl_period);

        if(t_start < t_min) 
            t_start = t_min;
        if(t_stop > t_max)
            t_stop = t_max;
        if(t_stop <= t_start )
            t_stop = t_max;

        /* Correct the window according to possible decimations - always
         * provide at least the data demanded by the user (ceil() instead
         * of round() for step calculation)
         */
        t_start_idx = round(t_start / smpl_period);
        t_stop_idx  = round(t_stop / smpl_period);

        if((((t_stop_idx-t_start_idx)/(float)(SIGNAL_LENGTH-1))) < 1)
            t_step_idx = 1;
        else {
            t_step_idx = ceil((t_stop_idx-t_start_idx)/(float)(SIGNAL_LENGTH-1));
            if(t_step_idx > 8)
                t_step_idx = 8;
        }

        t_stop = t_start + SIGNAL_LENGTH * t_step_idx * smpl_period;

        /* write back and convert to set units */
        rp_main_params[MIN_GUI_PARAM].value = t_start;
        rp_main_params[MAX_GUI_PARAM].value = t_stop;


    }

    return 0;
}

/** @brief Returns current parameters.
 * 
 * This function returns an array of parameters.
 *
 * @param [out] p Returned pointer to the parameters array.
 *
 * @retval -1 Failure
 * @retval otherwise Length of returned parameters array.
 *
 * @note Returned parameters pointer must be cleaned up externally!
 */
int rp_get_params(float **p)
{
    float *p_copy = NULL;

    p_copy = (float *)malloc(PARAMS_NUM * sizeof(float));
    if(p_copy == NULL)
        return -1;

    return PARAMS_NUM;
}

