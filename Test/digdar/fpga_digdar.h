/**
 * $Id: fpga.h 881 2013-12-16 05:37:34Z rp_jmenart $
 *
 * @brief Red Pitaya Digdar FPGA Interface.
 *
 * @Author Jure Menart <juremenart@gmail.com>
 * @Author John Brzustowski <jbrzusto@fastmail.fm>
 *         
 * (c) Red Pitaya  http://www.redpitaya.com
 * (c) 2014 John Brzustowski 
 *
 * This part of code is written in C programming language.
 * Please visit http://en.wikipedia.org/wiki/C_(programming_language)
 * for more details on the language used herein.
 */

#ifndef __FPGA_H
#define __FPGA_H

#include <stdint.h>


/** @defgroup fpga_h Acquisition
 * @{
 */

/** Starting address of FPGA registers handling Oscilloscope module. */
#define OSC_FPGA_BASE_ADDR 	0x40100000
/** The size of FPGA registers handling Oscilloscope module. */
#define OSC_FPGA_BASE_SIZE 0x50000
/** Size of data buffer into which input signal is captured , must be 2^n!. */
#define OSC_FPGA_SIG_LEN   (16*1024)

/** Bit index in FPGA configuration register for arming the trigger. */
#define OSC_FPGA_CONF_ARM_BIT  1
/** Bit index in FPGA configuration register for reseting write state machine. */
#define OSC_FPGA_CONF_RST_BIT  2
/** Bit index in FPGA configuration register for only writing after a trigger is detected */
#define OSC_FPGA_POST_TRIG_ONLY  4

/** Bit mask in the trigger_source register for depicting the trigger source type. */
#define OSC_FPGA_TRIG_SRC_MASK 0x0000000f
/** Bit mask in the cha_thr register for depicting trigger threshold on channel A. */
#define OSC_FPGA_CHA_THR_MASK  0x00003fff
/** Bit mask in the cha_thr register for depicting trigger threshold on channel B. */
#define OSC_FPGA_CHB_THR_MASK  0x00003fff
/** Bit mask in the trigger_delay register for depicting trigger delay. */
#define OSC_FPGA_TRIG_DLY_MASK 0xffffffff

/** Offset to the memory buffer where signal on channel A is captured. */
#define OSC_FPGA_CHA_OFFSET    0x10000
/** Offset to the memory buffer where signal on channel B is captured. */
#define OSC_FPGA_CHB_OFFSET    0x20000
/** Offset to the memory buffer where signal on slow channel A is captured. */
#define OSC_FPGA_XCHA_OFFSET   0x30000
/** Offset to the memory buffer where signal on slow channel B is captured. */
#define OSC_FPGA_XCHB_OFFSET   0x40000


/** Starting address of FPGA registers handling the Digdar module. */
#define DIGDAR_FPGA_BASE_ADDR 	0x40600000
/** The size of FPGA register block handling the Digdar module. */
#define DIGDAR_FPGA_BASE_SIZE 0x0000B8

/** The offsets to the metadata (read-only-by client) in the FPGA register block
    Must match values in red_pitaya_digdar.v from FPGA project
 */

#define OFFSET_SAVED_TRIG_COUNT           0x00068 // (saved) TRIG count since reset (32 bits; wraps)
#define OFFSET_SAVED_TRIG_CLOCK_LOW       0x0006C // (saved) clock at most recent TRIG (low 32 bits)
#define OFFSET_SAVED_TRIG_CLOCK_HIGH      0x00070 // (saved) clock at most recent TRIG (high 32 bits)
#define OFFSET_SAVED_TRIG_PREV_CLOCK_LOW  0x00074 // (saved) clock at previous TRIG (low 32 bits)
#define OFFSET_SAVED_TRIG_PREV_CLOCK_HIGH 0x00078 // (saved) clock at previous TRIG (high 32 bits)
#define OFFSET_SAVED_ACP_COUNT            0x0007C // (saved) ACP count since reset (32 bits; wraps)
#define OFFSET_SAVED_ACP_CLOCK_LOW        0x00080 // (saved) clock at most recent ACP (low 32 bits)
#define OFFSET_SAVED_ACP_CLOCK_HIGH       0x00084 // (saved) clock at most recent ACP (high 32 bits)
#define OFFSET_SAVED_ACP_PREV_CLOCK_LOW   0x00088 // (saved) clock at previous ACP (low 32 bits)
#define OFFSET_SAVED_ACP_PREV_CLOCK_HIGH  0x0008C // (saved) clock at previous ACP (high 32 bits)
#define OFFSET_SAVED_ARP_COUNT            0x00090 // (saved) ARP count since reset (32 bits; wraps)
#define OFFSET_SAVED_ARP_CLOCK_LOW        0x00094 // (saved) clock at most recent ARP (low 32 bits)
#define OFFSET_SAVED_ARP_CLOCK_HIGH       0x00098 // (saved) clock at most recent ARP (high 32 bits)
#define OFFSET_SAVED_ARP_PREV_CLOCK_LOW   0x0009C // (saved) clock at previous ARP (low 32 bits)
#define OFFSET_SAVED_ARP_PREV_CLOCK_HIGH  0x000A0 // (saved) clock at previous ARP (high 32 bits)
#define OFFSET_SAVED_ACP_PER_ARP          0x000A4 // (saved) count of ACP pulses between two most recent ARP pulses                                  

/** Hysteresis register default setting */

#define OSC_HYSTERESIS 0x3F


/** @brief FPGA registry structure for Oscilloscope core module.
 *
 * This structure is direct image of physical FPGA memory. It assures
 * direct read/write FPGA access when it is mapped to the appropriate memory address
 * through /dev/mem device.
 */
typedef struct osc_fpga_reg_mem_s {
    /** @brief  Configuration:
     * bit     [0] - arm_trigger
     * bit     [1] - rst_wr_state_machine
     * bits [31:2] - reserved 
     */
    uint32_t conf;

    /** @brief  Trigger source:
     * bits [ 3 : 0] - trigger source:
     *   1 - trig immediately
     *   2 - ChA positive edge
     *   3 - ChA negative edge
     *   4 - ChB positive edge 
     *   5 - ChB negative edge
     *   6 - External trigger 0
     *   7 - External trigger 1 
     *   8 - ASG positive edge
     *   9 - ASG negative edge
     *  10 - digdar counted trigger pulse
     *  11 - digdar acp pulse
     *  12 - digdar arp pulse
     * bits [31 : 4] -reserved
     */
    uint32_t trig_source;

    /** @brief  ChA threshold:
     * bits [13: 0] - ChA threshold
     * bits [31:14] - reserved
     */
    uint32_t cha_thr;

    /** @brief  ChB threshold:
     * bits [13: 0] - ChB threshold
     * bits [31:14] - reserved
     */
    uint32_t chb_thr;

    /** @brief  After trigger delay:
     * bits [31: 0] - trigger delay 
     * 32 bit number - how many decimated samples should be stored into a buffer.
     * (max 16k samples)
     */
    uint32_t trigger_delay;

    /** @brief  Data decimation
     * bits [16: 0] - decimation factor, legal values:
     *   1, 8, 64, 1024, 8192 65536
     *   If other values are written data is undefined 
     * bits [31:17] - reserved
     */
    uint32_t data_dec;

    /** @brief  Write pointers - both of the format:
     * bits [13: 0] - pointer
     * bits [31:14] - reserved
     * Current pointer - where machine stopped writing after trigger
     * Trigger pointer - where trigger was detected 
     */
    uint32_t wr_ptr_cur;
    uint32_t wr_ptr_trigger;

    /** @brief  ChA & ChB hysteresis - both of the format:
     * bits [13: 0] - hysteresis threshold
     * bits [31:14] - reserved
     */
    uint32_t cha_hystersis;
    uint32_t chb_hystersis;

    /** @brief
     * bits [0] - enable signal average at decimation
     * bits [31:1] - reserved
     */
    uint32_t other;
    
    uint32_t reseved;
    
    /** @brief ChA Equalization filter
     * bits [17:0] - AA coefficient (pole)
     * bits [31:18] - reserved
     */
    uint32_t cha_filt_aa;    
    
    /** @brief ChA Equalization filter
     * bits [24:0] - BB coefficient (zero)
     * bits [31:25] - reserved
     */
    uint32_t cha_filt_bb;    
    
    /** @brief ChA Equalization filter
     * bits [24:0] - KK coefficient (gain)
     * bits [31:25] - reserved
     */
    uint32_t cha_filt_kk;  
    
    /** @brief ChA Equalization filter
     * bits [24:0] - PP coefficient (pole)
     * bits [31:25] - reserved
     */
    uint32_t cha_filt_pp;     
    
    
    

    /** @brief ChB Equalization filter
     * bits [17:0] - AA coefficient (pole)
     * bits [31:18] - reserved
     */
    uint32_t chb_filt_aa;    
    
    /** @brief ChB Equalization filter
     * bits [24:0] - BB coefficient (zero)
     * bits [31:25] - reserved
     */
    uint32_t chb_filt_bb;    
    
    /** @brief ChB Equalization filter
     * bits [24:0] - KK coefficient (gain)
     * bits [31:25] - reserved
     */
    uint32_t chb_filt_kk;  
    
    /** @brief ChB Equalization filter
     * bits [24:0] - PP coefficient (pole)
     * bits [31:25] - reserved
     */
    uint32_t chb_filt_pp;            

    /** @brief Flag - only record samples after triggered
     * bits [0] - if 1, only record samples after trigger detected
     *            this serves to protect a digitized pulse, so that
     *            we can be reading it from BRAM into DRAM while the FPGA
     *            waits for and digitizes another pulse. (Provided the number
     *            of samples to be digitized is <= 1/2 the buffer size of 16 k samples)
     * bits [31:1] - reserved
     */
    uint32_t post_trig_only;
  
    /** @brief  ChA & ChB data - 14 LSB bits valid starts from 0x10000 and
     * 0x20000 and are each 16k samples long */
} osc_fpga_reg_mem_t;

typedef struct digdar_fpga_reg_mem_s {

  // --------------- TRIG -----------------

    /** @brief  trig_thresh_excite: trigger excitation threshold
     *          Trigger is raised for one FPGA clock after trigger channel
     *          ADC value meets or exceeds this value (in direction away 
     *          from trig_thresh_relax).
     * bits [13: 0] - threshold, signed
     * bit  [31:14] - reserved
     */
    uint32_t trig_thresh_excite;

    /** @brief  trig_thresh_relax: trigger relaxation threshold
     *          After a trigger has been raised, the trigger channel ADC value
     *          must meet or exceeds this value (in direction away 
     *          from trig_thresh_excite) before a trigger will be raised again.
     *          (Serves to debounce signal in schmitt-trigger style).
     * bits [13: 0] - threshold, signed
     * bit  [31:14] - reserved
     */
  uint32_t trig_thresh_relax;

    /** @brief  trig_delay: (traditional) trigger delay.
     *          How long to wait after trigger is raised
     *          before starting to capture samples from Video channel.
     *          Note: this usage of 'delay' is traditional for radar digitizing
     *          but differs from the red pitaya scope usage, which means 
     *          "number of decimated ADC samples to acquire after trigger is raised"
     * bits [31: 0] - unsigned wait time, in ADC clocks.
     */
  uint32_t trig_delay;

    /** @brief  trig_latency: how long to wait after trigger relaxation before
     *          allowing next excitation.
     *          To further debounce the trigger signal, we can specify a minimum
     *          wait time between relaxation and excitation.
     * bits [31: 0] - unsigned latency time, in ADC clocks.
     */
  uint32_t trig_latency;

    /** @brief  trig_count: number of trigger pulses detected since last reset
     * bits [31: 0] - unsigned count of trigger pulses detected
     */
  uint32_t trig_count;

    /** @brief  trig_clock_low: ADC clock count at last trigger pulse
     * bits [31: 0] - unsigned (low 32 bits) of ADC clock count
     */
  uint32_t trig_clock_low;

    /** @brief  trig_clock_high: ADC clock count at last trigger pulse
     * bits [31: 0] - unsigned (high 32 bits) of ADC clock count
     */
  uint32_t trig_clock_high;

    /** @brief  trig_prev_clock_low: ADC clock count at previous trigger pulse,
     *          so we can calculate trigger rate, regardless of capture rate
     * bits [31: 0] - unsigned (low 32 bits) of ADC clock count
     */
  uint32_t trig_prev_clock_low;

    /** @brief  trig_prev_clock_high: ADC clock count at previous trigger pulse
     * bits [31: 0] - unsigned (high 32 bits) of ADC clock count
     */
  uint32_t trig_prev_clock_high;

  // --------------- ACP -----------------

    /** @brief  acp_thresh_excite: acp excitation threshold
     *          the acp pulse is detected and counted when the ACP slow ADC
     *          channel meets or exceeds this value in the direction away
     *          from acp_thresh_relax
     * bits [11: 0] - threshold, signed
     * bit  [31:14] - reserved
     */

    uint32_t acp_thresh_excite;

    /** @brief  acp_thresh_relax: acp relaxation threshold
     *          After an acp has been detected, the acp channel ADC value
     *          must meet or exceeds this value (in direction away 
     *          from acp_thresh_excite) before a acp will be detected again.
     *          (Serves to debounce signal in schmitt-acp style).
     * bits [11: 0] - threshold, signed
     * bit  [31:14] - reserved
     */
  uint32_t acp_thresh_relax;

    /** @brief  acp_latency: how long to wait after acp relaxation before
     *          allowing next excitation.
     *          To further debounce the acp signal, we can specify a minimum
     *          wait time between relaxation and excitation.
     * bits [31: 0] - unsigned latency time, in ADC clocks.
     */
  uint32_t acp_latency;

    /** @brief  acp_count: number of acp pulses detected since last reset
     * bits [31: 0] - unsigned count of acp pulses detected
     */
  uint32_t acp_count;

    /** @brief  acp_clock_low: ADC clock count at last acp pulse
     * bits [31: 0] - unsigned (low 32 bits) of ADC clock count
     */
  uint32_t acp_clock_low;

    /** @brief  acp_clock_high: ADC clock count at last acp pulse
     * bits [31: 0] - unsigned (high 32 bits) of ADC clock count
     */
  uint32_t acp_clock_high;

    /** @brief  acp_prev_clock_low: ADC clock count at previous acp pulse,
     *          so we can calculate acp rate, regardless of capture rate
     * bits [31: 0] - unsigned (low 32 bits) of ADC clock count
     */
  uint32_t acp_prev_clock_low;

    /** @brief  acp_prev_clock_high: ADC clock count at previous acp pulse
     * bits [31: 0] - unsigned (high 32 bits) of ADC clock count
     */
  uint32_t acp_prev_clock_high;

  // --------------- ARP -----------------

    /** @brief  arp_thresh_excite: arp excitation threshold
     *          the arp pulse is detected and counted when the ARP slow ADC
     *          channel meets or exceeds this value in the direction away
     *          from arp_thresh_relax
     * bits [11: 0] - threshold, signed
     * bit  [31:14] - reserved
     */

    uint32_t arp_thresh_excite;

    /** @brief  arp_thresh_relax: arp relaxation threshold
     *          After an arp has been detected, the arp channel ADC value
     *          must meet or exceeds this value (in direction away 
     *          from arp_thresh_excite) before a arp will be detected again.
     *          (Serves to debounce signal in schmitt-arp style).
     * bits [11: 0] - threshold, signed
     * bit  [31:14] - reserved
     */
  uint32_t arp_thresh_relax;

    /** @brief  arp_latency: how long to wait after arp relaxation before
     *          allowing next excitation.
     *          To further debounce the arp signal, we can specify a minimum
     *          wait time between relaxation and excitation.
     * bits [31: 0] - unsigned latency time, in ADC clocks.
     */
  uint32_t arp_latency;

    /** @brief  arp_count: number of arp pulses detected since last reset
     * bits [31: 0] - unsigned count of arp pulses detected
     */
  uint32_t arp_count;

    /** @brief  arp_clock_low: ADC clock count at last arp pulse
     * bits [31: 0] - unsigned (low 32 bits) of ADC clock count
     */
  uint32_t arp_clock_low;

    /** @brief  arp_clock_high: ADC clock count at last arp pulse
     * bits [31: 0] - unsigned (high 32 bits) of ADC clock count
     */
  uint32_t arp_clock_high;

    /** @brief  arp_prev_clock_low: ADC clock count at previous arp pulse,
     *          so we can calculate arp rate, regardless of capture rate
     * bits [31: 0] - unsigned (low 32 bits) of ADC clock count
     */
  uint32_t arp_prev_clock_low;

    /** @brief  arp_prev_clock_high: ADC clock count at previous arp pulse
     * bits [31: 0] - unsigned (high 32 bits) of ADC clock count
     */
  uint32_t arp_prev_clock_high;

    /** @brief  acp_per_arp: count of ACP pulses between two most recent ARP pulses
     * bits [31: 0] - unsigned count of ACP pulses
     */
  uint32_t acp_per_arp;

  // --------------------- SAVED COPIES ----------------------------------------
  // For these metadata, we want to record the values at the time of the
  // most recently *captured* pulse.  So if the capture thread is not keeping up
  // with the radar, we still have correct values of these metadata for each
  // captured pulse (e.g. the value of the ACP count at each captured radar pulse).
  // The FPGA knows at trigger detection time whether or not
  // the pulse will be captured, and if so, copies the live metadata values to
  // these saved locations.

    /** @brief  saved_trig_count:  value at start of most recently captured pulse
     */
  uint32_t saved_trig_count;

    /** @brief  saved_trig_clock_low:  value at start of most recently captured pulse
     */
  uint32_t saved_trig_clock_low;

    /** @brief  saved_trig_clock_high:  value at start of most recently captured pulse
     */
  uint32_t saved_trig_clock_high;

    /** @brief  saved_trig_prev_clock_low:  value at start of most recently captured pulse
     */
  uint32_t saved_trig_prev_clock_low;

    /** @brief  saved_trig_prev_clock_high:  value at start of most recently captured pulse
     */
  uint32_t saved_trig_prev_clock_high;

    /** @brief  saved_acp_count:  value at start of most recently captured pulse
     */
  uint32_t saved_acp_count;

    /** @brief  saved_acp_clock_low:  value at start of most recently captured pulse
     */
  uint32_t saved_acp_clock_low;

    /** @brief  saved_acp_clock_high:  value at start of most recently captured pulse
     */
  uint32_t saved_acp_clock_high;

    /** @brief  saved_acp_prev_clock_low:  value at start of most recently captured pulse
     */
  uint32_t saved_acp_prev_clock_low;

    /** @brief  saved_acp_prev_clock_high:  value at start of most recently captured pulse
     */
  uint32_t saved_acp_prev_clock_high;

    /** @brief  saved_arp_count:  value at start of most recently captured pulse
     */
  uint32_t saved_arp_count;

    /** @brief  saved_arp_clock_low:  value at start of most recently captured pulse
     */
  uint32_t saved_arp_clock_low;

    /** @brief  saved_arp_clock_high:  value at start of most recently captured pulse
     */
  uint32_t saved_arp_clock_high;

    /** @brief  saved_arp_prev_clock_low:  value at start of most recently captured pulse
     */
  uint32_t saved_arp_prev_clock_low;

    /** @brief  saved_arp_prev_clock_high:  value at start of most recently captured pulse
     */
  uint32_t saved_arp_prev_clock_high;

    /** @brief  saved_acp_per_arp:  value at start of most recently captured pulse
     */
  uint32_t saved_acp_per_arp;

  // other scratch / debugging registers which we don't bother mapping for now

} digdar_fpga_reg_mem_t;

/** @} */


/* constants */
extern const float c_osc_fpga_smpl_freq;
extern const float c_osc_fpga_smpl_period;
extern const int   c_osc_fpga_adc_bits;
extern const int   c_osc_fpga_xadc_bits;


typedef struct {
    uint32_t aa;
    uint32_t bb;
    uint32_t pp;
    uint32_t kk;
} ecu_shape_filter_t;

/* function declarations, detailed descriptions is in apparent implementation file  */
int   osc_fpga_init(void);
int   osc_fpga_exit(void);
int osc_fpga_update_params(int trig_imm, int trig_source, int trig_edge, 
                           float trig_delay, float trig_level, int time_range,
                           int equal, int shaping, int gain1, int gain2);
/* int   osc_fpga_update_params(int trig_imm, int trig_source, int trig_edge, */
/*                              float trig_delay, float trig_level, int time_range, */
/*                              float ch1_adc_max_v, float ch2_adc_max_v, */
/*                              int ch1_calib_dc_off, float ch1_user_dc_off, */
/*                              int ch2_calib_dc_off, float ch2_user_dc_off, */
/*                              int ch1_probe_att, int ch2_probe_att, */
/* 			      int ch1_gain, int ch2_gain, */
/*                              int enable_avg_at_dec, */
/*                              float trig_excite, float trig_relax, float digdar_trig_delay, float trig_latency, */
/*                              float acp_excite, float acp_relax, float acp_latency, */
/*                              float arp_excite, float arp_relax, float arp_latency, */
/*                              float acps_per_arp */
/* ); */
int   osc_fpga_reset(void);
int   osc_fpga_arm_trigger(void);
int   osc_fpga_set_trigger(uint32_t trig_source);
int   osc_fpga_set_trigger_delay(uint32_t trig_delay);
int   osc_fpga_triggered(void);
int   osc_fpga_get_sig_ptr(int **cha_signal, int **chb_signal, int **xcha_signal, int **xchb_signal);
int   osc_fpga_get_wr_ptr(int *wr_ptr_curr, int *wr_ptr_trig);

int   osc_fpga_cnv_trig_source(int trig_imm, int trig_source, int trig_edge);
int   osc_fpga_cnv_time_range_to_dec(int time_range);
int   osc_fpga_cnv_time_to_smpls(float time, int dec_factor);
/* int   osc_fpga_cnv_v_to_cnt(float voltage, float max_adc_v, */
/*                             int calib_dc_off, float user_dc_off); */
/* float osc_fpga_cnv_cnt_to_v(int cnts, float max_adc_v, */
/*                             int calib_dc_off, float user_dc_off); */

/* Converts voltage in [V] to ADC counts */
int osc_fpga_cnv_v_to_cnt(float voltage);
/* Converts ADC ounts to [V] */
float osc_fpga_cnv_cnt_to_v(int cnts);


float osc_fpga_cnv_xcnt_to_v(int cnts);
float osc_fpga_cnv_cnt_to_rel(int cnts, int bits);

float osc_fpga_calc_adc_max_v(uint32_t fe_gain_fs, int probe_att);

int osc_fpga_get_digdar_ptr(uint32_t **digdar_memory);

#endif /* __FPGA_H */
