/**
 * $Id: fpga_osc.c 881 2013-12-16 05:37:34Z rp_jmenart $
 *
 * @brief Red Pitaya Oscilloscope FPGA controller.
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
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>

#include "fpga_digdar.h"

/**
 * GENERAL DESCRIPTION:
 *
 * This module initializes and provides for other SW modules the access to the
 * FPGA OSC module. The oscilloscope memory space is divided to three parts:
 *   - registers (control and status)
 *   - input signal buffer (Channel A)
 *   - input signal buffer (Channel B)
 *
 * This module maps physical address of the oscilloscope core to the logical
 * address, which can be used in the GNU/Linux user-space. To achieve this,
 * OSC_FPGA_BASE_ADDR from CPU memory space is translated automatically to
 * logical address with the function mmap(). After all the initialization is done,
 * other modules can use this module to controll oscilloscope FPGA core. Before
 * any functions or functionality from this module can be used it needs to be
 * initialized with osc_fpga_init() function. When this module is no longer
 * needed osc_fpga_exit() must be called.
 *
 * FPGA oscilloscope state machine in various modes. Basic principle is that
 * SW sets the machine, 'arm' the writting machine (FPGA writes from ADC to
 * input buffer memory) and then set the triggers. FPGA machine is continue
 * writting to the buffers until the trigger is detected plus the amount set
 * in trigger delay register. For more detauled description see the FPGA OSC
 * registers description.
 *
 * Nice example how to use this module can be seen in worker.c module.
 */

/* internal structures */
/** The FPGA register structure (defined in fpga_osc.h) */
osc_fpga_reg_mem_t *g_osc_fpga_reg_mem = NULL;

/* @brief Pointer to FPGA digdar control registers. */
digdar_fpga_reg_mem_t *g_digdar_fpga_reg_mem = NULL;

/** The FPGA input signal buffer pointer for channel A */
uint32_t           *g_osc_fpga_cha_mem = NULL;
/** The FPGA input signal buffer pointer for channel B */
uint32_t           *g_osc_fpga_chb_mem = NULL;

/** The FPGA input signal buffer pointer for slow channel A */
uint32_t           *g_osc_fpga_xcha_mem = NULL;
/** The FPGA input signal buffer pointer for slow channel B */
uint32_t           *g_osc_fpga_xchb_mem = NULL;

/** The memory file descriptor used to mmap() the FPGA space */
int             g_osc_fpga_mem_fd = -1;

/* Constants */
/** ADC number of bits */
const int c_osc_fpga_adc_bits = 14;

/** Slow ADC number of bits */
const int c_osc_fpga_xadc_bits = 12;

/** @brief Max and min voltage on ADCs.
 * Symetrical - Max Voltage = +14, Min voltage = -1 * c_osc_fpga_max_v
 */
const float c_osc_fpga_adc_max_v  = +14;
/** Sampling frequency = 125Mspmpls (non-decimated) */
const float c_osc_fpga_smpl_freq = 125e6;
/** Sampling period (non-decimated) - 8 [ns] */
const float c_osc_fpga_smpl_period = (1. / 125e6);

/**
 * @brief Internal function used to clean up memory.
 *
 * This function un-maps FPGA register and signal buffers, closes memory file
 * descriptor and cleans all memory allocated by this module.
 *
 * @retval 0 Success
 * @retval -1 Error happened during cleanup.
 */
int __osc_fpga_cleanup_mem(void)
{
    /* If register structure is NULL we do not need to un-map and clean up */
    if(g_osc_fpga_reg_mem) {
        if(munmap(g_osc_fpga_reg_mem, OSC_FPGA_BASE_SIZE) < 0) {
            fprintf(stderr, "munmap() failed: %s\n", strerror(errno));
            return -1;
        }
        g_osc_fpga_reg_mem = NULL;
        if(g_osc_fpga_cha_mem)
            g_osc_fpga_cha_mem = NULL;
        if(g_osc_fpga_chb_mem)
            g_osc_fpga_chb_mem = NULL;
        if(g_osc_fpga_xcha_mem)
            g_osc_fpga_xcha_mem = NULL;
        if(g_osc_fpga_xchb_mem)
            g_osc_fpga_xchb_mem = NULL;
    }
    if(g_osc_fpga_mem_fd >= 0) {
        close(g_osc_fpga_mem_fd);
        g_osc_fpga_mem_fd = -1;
    }
    return 0;
}

/**
 * @brief Maps FPGA memory space and prepares register and buffer variables.
 *
 * This function opens memory device (/dev/mem) and maps physical memory address
 * OSC_FPGA_BASE_ADDR (of length OSC_FPGA_BASE_SIZE) to logical addresses. It
 * initializes the pointers g_osc_fpga_reg_mem, g_osc_fpga_cha_mem and
 * g_osc_fpga_chb_mem to point to FPGA OSC.
 * If function failes FPGA variables must not be used.
 *
 * @retval 0  Success
 * @retval -1 Failure, error is printed to standard error output.
 */
int osc_fpga_init(void)
{
    /* Page variables used to calculate correct mapping addresses */
    void *page_ptr;
    long page_addr, page_off, page_size = sysconf(_SC_PAGESIZE);

    /* If module was already initialized once, clean all internals. */
    if(__osc_fpga_cleanup_mem() < 0)
        return -1;

    /* Open /dev/mem to access directly system memory */
    g_osc_fpga_mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    if(g_osc_fpga_mem_fd < 0) {
        fprintf(stderr, "open(/dev/mem) failed: %s\n", strerror(errno));
        return -1;
    }

    /* Calculate correct page address and offset from OSC_FPGA_BASE_ADDR and
     * OSC_FPGA_BASE_SIZE
     */
    page_addr = OSC_FPGA_BASE_ADDR & (~(page_size-1));
    page_off  = OSC_FPGA_BASE_ADDR - page_addr;

    /* Map FPGA memory space to page_ptr. */
    page_ptr = mmap(NULL, OSC_FPGA_BASE_SIZE, PROT_READ | PROT_WRITE,
                          MAP_SHARED, g_osc_fpga_mem_fd, page_addr);
    if((void *)page_ptr == MAP_FAILED) {
        fprintf(stderr, "mmap() failed: %s\n", strerror(errno));
        __osc_fpga_cleanup_mem();
        return -1;
    }


    /* Set FPGA OSC module pointers to correct values. */
    g_osc_fpga_reg_mem = page_ptr + page_off;

    g_osc_fpga_cha_mem = (uint32_t *)g_osc_fpga_reg_mem +
        (OSC_FPGA_CHA_OFFSET / sizeof(uint32_t));

    g_osc_fpga_chb_mem = (uint32_t *)g_osc_fpga_reg_mem +
        (OSC_FPGA_CHB_OFFSET / sizeof(uint32_t));

    g_osc_fpga_xcha_mem = (uint32_t *)g_osc_fpga_reg_mem +
        (OSC_FPGA_XCHA_OFFSET / sizeof(uint32_t));

    g_osc_fpga_xchb_mem = (uint32_t *)g_osc_fpga_reg_mem +
        (OSC_FPGA_XCHB_OFFSET / sizeof(uint32_t));

    page_addr = DIGDAR_FPGA_BASE_ADDR & (~(page_size-1));
    page_off  = DIGDAR_FPGA_BASE_ADDR - page_addr;

    page_ptr = mmap(NULL, DIGDAR_FPGA_BASE_SIZE, PROT_READ | PROT_WRITE,
                          MAP_SHARED, g_osc_fpga_mem_fd, page_addr);

    if((void *)page_ptr == MAP_FAILED) {
        fprintf(stderr, "mmap() failed: %s\n", strerror(errno));
        __osc_fpga_cleanup_mem();
        return -1;
    }
    g_digdar_fpga_reg_mem = page_ptr + page_off;

    return 0;
}

/**
 * @brief Cleans up FPGA OSC module internals.
 *
 * This function closes the memory file descriptor, unmap the FPGA memory space
 * and cleans also all other internal things from FPGA OSC module.
 * @retval 0 Sucess
 * @retval -1 Failure
 */
int osc_fpga_exit(void)
{
  //    if(g_osc_fpga_reg_mem)
    /* tell FPGA to stop packing slow ADC values into upper 16 bits of CHA, CHB */
      //      *(int *)(OSC_FPGA_SLOW_ADC_OFFSET + (char *) g_osc_fpga_reg_mem) = 0;
    return __osc_fpga_cleanup_mem();
}

// TODO: Move to a shared folder and share with scope & spectrum.
/**
 * @brief Provides equalization & shaping filter coefficients.
 *
 *
 * This function provides equalization & shaping filter coefficients, based on
 * the type of use and gain settings.
 *
 * @param [in]  equal    Enable(1)/disable(0) equalization filter.
 * @param [in]  shaping  Enable(1)/disable(0) shaping filter.
 * @param [in]  gain     Gain setting (0 = LV, 1 = HV).
 * @param [out] filt     Filter coefficients.
 */
void get_equ_shape_filter(ecu_shape_filter_t *filt, uint32_t equal,
                          uint32_t shaping, uint32_t gain)
{
    /* Equalization filter */
    if (equal) {
        if (gain == 0) {
            /* High gain = LV */
            filt->aa = 0x7D93;
            filt->bb = 0x437C7;
        } else {
            /* Low gain = HV */
            filt->aa = 0x4C5F;
            filt->bb = 0x2F38B;
        }
    } else {
        filt->aa = 0;
        filt->bb = 0;
    }

    /* Shaping filter */
    if (shaping) {
        filt->pp = 0x2666;
        filt->kk = 0xd9999a;
    } else {
        filt->pp = 0;
        filt->kk = 0xffffff;
    }
}



/** @brief OSC FPGA ARM
 *
 * ARM internal oscilloscope FPGA state machine to start writting input buffers.

 * @retval 0 Always returns 0.
 */
int osc_fpga_arm_trigger(void)
{
  g_osc_fpga_reg_mem->digdar_extra_options = 21;  // 1: only buffer samples *after* being triggered; (no: 2: negate range of sample values); 4: double-width reads; 16: return sum
  g_osc_fpga_reg_mem->conf |= OSC_FPGA_CONF_ARM_BIT;
    return 0;
}

/** @brief Sets the trigger source in OSC FPGA register.
 *
 * Sets the trigger source in oscilloscope FPGA register.
 *
 * @param [in] trig_source Trigger source, as defined in FPGA register
 *                         description.
 */
int osc_fpga_set_trigger(uint32_t trig_source)
{
    g_osc_fpga_reg_mem->trig_source = trig_source;
    return 0;
}

/** @brief Sets the decimation rate in the OSC FPGA register.
 *
 * Sets the decimation rate in the oscilloscope FPGA register.
 *
 * @param [in] decim_factor decimation factor, which must be
 * one of the valid values for the FPGA build:
 * 1, 2, 8, 64, 1024, 8192, 65536
 */
int osc_fpga_set_decim(uint32_t decim_factor)
{
    g_osc_fpga_reg_mem->data_dec = decim_factor;
    return 0;
}

/** @brief Sets the trigger delay in OSC FPGA register.
 *
 * Sets the trigger delay in oscilloscope FPGA register.
 *
 * @param [in] trig_delay Trigger delay, as defined in FPGA register
 *                         description.
 *
 * @retval 0 Always returns 0.
 */
int osc_fpga_set_trigger_delay(uint32_t trig_delay)
{
    g_osc_fpga_reg_mem->trigger_delay = trig_delay;
    return 0;
}

/** @brief Checks if FPGA detected trigger.
 *
 * This function checks if trigger was detected by the FPGA.
 *
 * @retval 0 Trigger not detected.
 * @retval 1 Trigger detected.
 */
int osc_fpga_triggered(void)
{
    return ((g_osc_fpga_reg_mem->trig_source & OSC_FPGA_TRIG_SRC_MASK)==0);
}

/** @brief Returns memory pointers for both input signal buffers.
 *
 * This function returns pointers for input signal buffers for all 4 channels.
 *
 * @param [out] cha_signal Output pointer for Channel A buffer
 * @param [out] chb_signal Output pointer for Channel B buffer
 * @param [out] xcha_signal Output pointer for Slow Channel A buffer
 * @param [out] xchb_signal Output pointer for Slow Channel B buffer
 *
 * @retval 0 Always returns 0.
 */
int osc_fpga_get_sig_ptr(int **cha_signal, int **chb_signal, int **xcha_signal, int **xchb_signal)
{
    *cha_signal = (int *)g_osc_fpga_cha_mem;
    *chb_signal = (int *)g_osc_fpga_chb_mem;
    *xcha_signal = (int *)g_osc_fpga_xcha_mem;
    *xchb_signal = (int *)g_osc_fpga_xchb_mem;
    return 0;
}

/** @brief Returns values for current and trigger write FPGA pointers.
 *
 * This functions returns values for current and trigger write pointers. They
 * are an address of the input signal buffer and are the same for both channels.
 *
 * @param [out] wr_ptr_curr Current FPGA input buffer address.
 * @param [out] wr_ptr_trig Trigger FPGA input buffer address.
 *
 * @retval 0 Always returns 0.
  */
int osc_fpga_get_wr_ptr(int *wr_ptr_curr, int *wr_ptr_trig)
{
    if(wr_ptr_curr)
        *wr_ptr_curr = g_osc_fpga_reg_mem->wr_ptr_cur;
    if(wr_ptr_trig)
        *wr_ptr_trig = g_osc_fpga_reg_mem->wr_ptr_trigger;
    return 0;
}
