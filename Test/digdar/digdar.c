/**
 * 
 * forked from:
 *
 * $Id: acquire.c 1246 2014-02-22 19:05:19Z ales.bardorfer $
 *
 * @brief Red Pitaya simple signal acquisition utility.
 *
 * @Author Ales Bardorfer <ales.bardorfer@redpitaya.com>
 *         Jure Menart <juremenart@gmail.com>
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in C programming language.
 * Please visit http://en.wikipedia.org/wiki/C_(programming_language)
 * for more details on the language used herein.
 */

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <getopt.h>
#include <string.h>
#include <sys/param.h>

#include "digdar.h"
#include "main_digdar.h"
#include "fpga_digdar.h"
#include "version.h"
#include "worker.h"

/**
 * GENERAL DESCRIPTION:
 *
 * The code below acquires up to 16k samples on both Red Pitaya input
 * channels labeled ADC1 & ADC2.
 * 
 * It utilizes the routines of the Oscilloscope module for:
 *   - Triggered ADC signal acqusition to the FPGA buffers.
 *   - Parameter defined averaging & decimation.
 *   - Data transfer to SW buffers.
 *
 * Although the Oscilloscope routines export many functionalities, this 
 * simple signal acquisition utility only exploits a few of them:
 *   - Synchronization between triggering & data readout.
 *   - Only AUTO triggering is used by default.
 *   - Only decimation is parsed to t_params[8].
 *
 * Please feel free to exploit any other scope functionalities via 
 * parameters defined in t_params.
 *
 */

/** Program name */
const char *g_argv0 = NULL;

/** Minimal number of command line arguments */
#define MINARGS 0

/** Oscilloscope module parameters as defined in main module
 * @see rp_main_params
 */
float t_params[PARAMS_NUM] = { 0, 1e6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

/** Max decimation index */
#define DEC_MAX 6


/** Print usage information */
void usage() {

    const char *format =
            "\n"
            "Usage: %s [OPTION]\n"
            "\n"
            "  --decim  -d    Decimation rate: one of 0=1x[default], 1=2x, 2=8x, 3=64x, 4=1024x, 5=8192x, 6x=65536\n"
            "  --spp    -s    Samples per pulse. (Up to 16384; default is 3000)\n"
            "  --num_pulses -p Number of pulses to allocate buffer for (default, 1000)\n"
            "  --chunk_size -c Number of pulses to transfer in each chunk\n"
            "  --version       -v    Print version info.\n"
            "  --help          -h    Print this message.\n"
            "\n";

    fprintf( stderr, format, g_argv0);
}


uint16_t spp = 3000;  // samples to grab per radar pulse
uint16_t decim = 1; // decimation: 1, 2, or 8
uint16_t num_pulses = 1000; // pulses to maintain in ring buffer (filled by worker thread)
uint16_t chunk_size = 1; // pulses to transmit per chunk (main thread)
uint16_t cur_pulse = 0; // index into pulses buffer
uint32_t psize = 0; // actual size of each pulse's storage (metadata + data) - will be set below

pulse_metadata *pulse_buffer = 0;

/** Acquire pulses main */
int main(int argc, char *argv[])
{
    g_argv0 = argv[0];

    if ( argc < MINARGS ) {
        usage();
        exit ( EXIT_FAILURE );
    }

    /* Command line options */
    static struct option long_options[] = {
            /* These options set a flag. */
            {"decim", required_argument,       0, 'd'},
            {"spp",      required_argument,       0, 's'},
            {"num_pulses",       required_argument,       0, 'p'},
            {"chunk_size",    required_argument,          0, 'c'},
            {"version",      no_argument,       0, 'v'},
            {"help",         no_argument,       0, 'h'},
            {0, 0, 0, 0}
    };
    const char *optstring = "c:d:p:s:vh";

    /* getopt_long stores the option index here. */
    int option_index = 0;

    int ch = -1;
    while ( (ch = getopt_long( argc, argv, optstring, long_options, &option_index )) != -1 ) {
        switch ( ch ) {

        case 'd':
          decim = atoi(optarg);
            break;

        case 's':
          spp = atoi(optarg);
            break;

        case 'c':
          chunk_size = atoi(optarg);
            break;

        case 'p':
          num_pulses = atoi(optarg);
            break;

        case 'v':
            fprintf(stdout, "%s version %s-%s\n", g_argv0, VERSION_STR, REVISION_STR);
            exit( EXIT_SUCCESS );
            break;

        case 'h':
            usage();
            exit( EXIT_SUCCESS );
            break;

        default:
            usage();
            exit( EXIT_FAILURE );
        }
    }

    if (decim < 0 || decim > 6) {
      fprintf(stderr, "incorrect value (%d) for decimation; must be 0...6\n", decim);
      return -1;
    }
    t_params[DECIM_INDEX_PARAM] = decim;
      
    if (spp > 16384 || spp < 0) {
      fprintf(stderr, "incorrect value (%d) for samples per pulse; must be 0..16384\n", spp);
      return -1;
    }

    /* Standard radar triggering mode */
    t_params[TRIG_MODE_PARAM] = 1;
    t_params[TRIG_SRC_PARAM] = 10;

    /* Initialization of Oscilloscope application */
    if(rp_app_init() < 0) {
        fprintf(stderr, "rp_app_init() failed!\n");
        return -1;
    }

    /* Setting of parameters in Oscilloscope main module */

    // FIXME: load digdar params from JSON file, parse, and set

    if(rp_set_params((float *)&t_params, PARAMS_NUM) < 0) {
        fprintf(stderr, "rp_set_params() failed!\n");
        return -1;
    }
    
    psize = sizeof(pulse_metadata) + sizeof(uint16_t) * (spp - 1);

    pulse_buffer = calloc(num_pulses, psize);
    if (!pulse_buffer) {
        fprintf(stderr, "couldn't allocate pulse buffer\n");
        return -1;
    }
    cur_pulse = 0;

    // fill in magic number in pulse headers

    for (int i = 0; i < num_pulses; ++i) {
      pulse_metadata *pbm = (pulse_metadata *) (((char *) pulse_buffer) + i * psize);
      pbm->magic_number = PULSE_METADATA_MAGIC;
    }

    //    rp_osc_worker_init();

    // go ahead and start capturing

    rp_osc_worker_change_state(rp_osc_start_state);

    uint16_t my_cur_pulse = 0;

    // NB: should use boost circular_buffer here

    while(1) {
      uint16_t copy_cur_pulse = cur_pulse;
      uint16_t nc1, nc2;
      if (copy_cur_pulse < my_cur_pulse) {
        nc1 = num_pulses - my_cur_pulse;
        nc2 = cur_pulse;
      } else {
        nc1 = copy_cur_pulse - my_cur_pulse;
        nc2 = 0;
      }
      if (nc1 > 0) {
        fwrite(((char *) pulse_buffer) + my_cur_pulse * psize, nc1, psize, stdout);
        my_cur_pulse += nc1;
        if (my_cur_pulse == num_pulses)
          my_cur_pulse = 0;
      }
      if (nc2 > 0) {
        fwrite(((char *) pulse_buffer) + my_cur_pulse * psize, nc1, psize, stdout);
        my_cur_pulse += nc2;
        if (my_cur_pulse == num_pulses)
          my_cur_pulse = 0;
      }
      sched_yield();
    }
    return 0;
}
