/**
 * 
 * forked from: 
 *
 * $Id: main_osc.h 881 2013-12-16 05:37:34Z rp_jmenart $
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

#ifndef __MAIN_DIGDAR_H
#define __MAIN_DIGDAR_H

#ifdef __cplusplus
extern "C" {
#endif

#include "digdar.h"

/** @defgroup main_digdar_h main_digdar_h
 * @{
 */

/** @brief radar pulse capture  parameters structure
 *
 * Oscilloscope parameter structure, which is a holder for parameters, defines
 * the behavior (if FPGA update is needed, if it is read only) and minimal and
 * maximal values.
 */
typedef struct rp_osc_params_s {
    /** @brief Value holder */
    float value;
    /** @brief FPGA update needed for parameters. */
    int   fpga_update;
    /** @brief Read only parameters (writes are ignored) */
    int   read_only;
    /** @brief Minimal value allowed for the parameter */
    float min_val;
    /** @brief Maximum value allowed for the parameter */
    float max_val;
} rp_osc_params_t;

/* Parameters indexes */
/** Number of parameters defined in main module */
#define PARAMS_NUM      14
/** Minimal time in output time vector */
#define MIN_GUI_PARAM    0
/** Maximal time in output time vector */
#define MAX_GUI_PARAM    1
/** Trigger mode */
#define TRIG_MODE_PARAM  2
/** Trigger source */
#define TRIG_SRC_PARAM   3
/** Trigger edge */
#define TRIG_EDGE_PARAM  4
/** Trigger delay */
#define TRIG_DLY_PARAM   5
/** Trigger level */
#define TRIG_LEVEL_PARAM 6
/** Single acquisition requested */
#define SINGLE_BUT_PARAM 7
/** Decimation factor */
#define DECIM_FACTOR_PARAM 8
/** Time unit (read-only) */
#define TIME_UNIT_PARAM  9
/** Equalization filter */
#define EQUAL_FILT_PARAM 10
/** Shaping filter */
#define SHAPE_FILT_PARAM 11
/** Channel1 gain */
#define GAIN1_PARAM      12
/** Channel2 gain */
#define GAIN2_PARAM      13

/** Output signal length  */
#define SIGNAL_LENGTH (16*1024)
/** Number of output signals */
#define SIGNALS_NUM   5

/** @} */

int rp_app_init(void);
int rp_app_exit(void);
int rp_set_params(float *p, int len);
int rp_get_params(float **p);

#ifdef __cplusplus
}
#endif /* __cplusplus */
#endif /*  __MAIN_DIGDAR_H */
