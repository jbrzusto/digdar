/**
 * $Id$
 *
 * @brief Red Pitaya Spectrum Analyzer FPGA Interface.
 *
 * @Author Jure Menart <juremenart@gmail.com>
 *         
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in C programming language.
 * Please visit http://en.wikipedia.org/wiki/C_(programming_language)
 * for more details on the language used herein.
 */

#ifndef __FPGA_H
#define __FPGA_H

#include <stdint.h>

/* Housekeeping base address 0x40000000 */
#define HK_FPGA_BASE_ADDR 0x40000000
#define HK_FPGA_HW_REV_MASK 0x0000000f

typedef enum {
	eHwRevC=0,
	eHwRevD
} hw_rev_t;

/* FPGA housekeeping structure */
typedef struct hk_fpga_reg_mem_s {
    /* configuration:
     * bit   [3:0] - hw revision
     * bits [31:4] - reserved
     */
    uint32_t rev;
    /* DNA low word */
    uint32_t dna_lo;
    /* DNA high word */
    uint32_t dna_hi;
} hk_fpga_reg_mem_t;

/* Base address 0x40100000 */
#define SPECTR_FPGA_BASE_ADDR 0x40100000
#define SPECTR_FPGA_BASE_SIZE 0x30000

#define SPECTR_FPGA_SIG_LEN   (16*1024)

#define SPECTR_FPGA_CONF_ARM_BIT  1
#define SPECTR_FPGA_CONF_RST_BIT  2

#define SPECTR_FPGA_TRIG_SRC_MASK 0x00000007
#define SPECTR_FPGA_CHA_THR_MASK  0x00003fff
#define SPECTR_FPGA_CHB_THR_MASK  0x00003fff
#define SPECTR_FPGA_TRIG_DLY_MASK 0xffffffff
#define SPECTR_FPGA_DATA_DEC_MASK 0x0001ffff

#define SPECTR_FPGA_CHA_OFFSET    0x10000
#define SPECTR_FPGA_CHB_OFFSET    0x20000

typedef struct spectr_fpga_reg_mem_s {
    /* configuration:
     * bit     [0] - arm_trigger
     * bit     [1] - rst_wr_state_machine
     * bits [31:2] - reserved 
     */
    uint32_t conf;

    /* trigger source:
     * bits [ 2 : 0] - trigger source:
     *   1 - trig immediately
     *   2 - ChA positive edge
     *   3 - ChA negative edge
     *   4 - ChB positive edge 
     *   5 - ChB negative edge
     *   6 - External trigger 0
     *   7 - External trigger 1 
     * bits [31 : 3] -reserved
     */
    uint32_t trig_source;

    /* ChA threshold:
     * bits [13: 0] - ChA threshold
     * bits [31:14] - reserved
     */
    uint32_t cha_thr;

    /* ChB threshold:
     * bits [13: 0] - ChB threshold
     * bits [31:14] - reserved
     */
    uint32_t chb_thr;

    /* After trigger delay:
     * bits [31: 0] - trigger delay 
     * 32 bit number - how many decimated samples should be stored into a buffer.
     * (max 16k samples)
     */
    uint32_t trigger_delay;

    /* Data decimation
     * bits [16: 0] - decimation factor, legal values:
     *   1, 8, 64, 1024, 8192 65536
     *   If other values are written data is undefined 
     * bits [31:17] - reserved
     */
    uint32_t data_dec;

    /* Write pointers - both of the format:
     * bits [13: 0] - pointer
     * bits [31:14] - reserved
     * Current pointer - where machine stopped writting after trigger
     * Trigger pointer - where trigger was detected 
     */
    uint32_t wr_ptr_cur;
    uint32_t wr_ptr_trigger;
    
    /* ChA & ChB hysteresis - both of the format:
     * bits [13: 0] - hysteresis threshold
     * bits [31:14] - reserved
     */
    uint32_t cha_hystersis;
    uint32_t chb_hystersis;

    /*
     * bits [0] - enable signal average at decimation
     * bits [31:1] - reserved
     */
    uint32_t other;
    
    uint32_t reserved;
    

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
    

    /* ChA & ChB data - 14 LSB bits valid starts from 0x10000 and
     * 0x20000 and are each 16k samples long */
} spectr_fpga_reg_mem_t;

/** Starting address of FPGA registers handling the Digdar module. */
#define DIGDAR_FPGA_BASE_ADDR 	0x40600000
/** The size of FPGA register block handling the Digdar module. */
#define DIGDAR_FPGA_BASE_SIZE 0x0000B8

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

int spectr_fpga_init(void);
int spectr_fpga_exit(void);

int spectr_fpga_update_params(/*float trig_excite, float trig_relax, int trig_delay, int trig_latency,*/ int freq_range, int enable_avg_at_dec);
int spectr_fpga_reset(void);
int spectr_fpga_arm_trigger(void);
int spectr_fpga_set_trigger(void);

/* Returns 0 if no trigger, 1 if trigger */
int spectr_fpga_triggered(void);

/* Returns pointer to the ChA and ChB signals (of length SPECTR_FPGA_SIG_LEN) */
int spectr_fpga_get_sig_ptr(int **cha_signal, int **chb_signal);

/* Copies the last acquisition (trig wr. ptr -> curr. wr. ptr) */
int spectr_fpga_get_signal(double **cha_signal, double **chb_signal);

/* Returns signal pointers from the FPGA */
int spectr_fpga_get_wr_ptr(int *wr_ptr_curr, int *wr_ptr_trig);

/* Returnes signal content */
/* various constants */
extern const float c_spectr_fpga_smpl_freq;
extern const float c_spectr_fpga_smpl_period;

/* helper conversion functions */
/* Converts freq_range parameter (0-5) to decimation factor */
int spectr_fpga_cnv_freq_range_to_dec(int freq_range);
/* Converts freq_range parameter (0-5) to unit enumerator */
int spectr_fpga_cnv_freq_range_to_unit(int freq_range);

/* Converts time in [s] to ADC samples (depends on decimation) */
int spectr_fpga_cnv_time_to_smpls(float time, int dec_factor);
/* Converts voltage in [V] to ADC counts */
int spectr_fpga_cnv_v_to_cnt(float voltage);
/* Converts ADC ounts to [V] */
float spectr_fpga_cnv_cnt_to_v(int cnts);

/* debugging - will be removed */
extern spectr_fpga_reg_mem_t *g_spectr_fpga_reg_mem;
extern                int  g_spectr_fpga_mem_fd;
int __spectr_fpga_cleanup_mem(void);

#endif /* __FPGA_H*/
