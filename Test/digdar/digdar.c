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
            "  --decim  -d    Decimation rate: one of 1 [default], 8, 64, or 1024\n"
            "  --spp    -s    Samples per pulse. (Up to 16384; default is 4096)\n"
            "  --version       -v    Print version info.\n"
            "  --help          -h    Print this message.\n"
            "\n";

    fprintf( stderr, format, g_argv0);
}


/** Acquire pulses main */
int main(int argc, char *argv[])
{
    g_argv0 = argv[0];
    int decim = 0;
    int spp = 4096;

    if ( argc < MINARGS ) {
        usage();
        exit ( EXIT_FAILURE );
    }

    /* Command line options */
    static struct option long_options[] = {
            /* These options set a flag. */
            {"decim", required_argument,       0, 'd'},
            {"spp",      required_argument,       0, 's'},
            {"version",      no_argument,       0, 'v'},
            {"help",         no_argument,       0, 'h'},
            {0, 0, 0, 0}
    };
    const char *optstring = "d:s:vh";

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

    if (decim == 1)
      t_params[TIME_RANGE_PARAM] = 0;
    else if (decim == 2)
      t_params[TIME_RANGE_PARAM] = 1;
    else {
      fprintf(stderr, "incorrect value (%d) for decimation; must be 1 or 8\n", decim);
      return -1;
    }
      
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
    int num_pulses = 4000;
    pulse_metadata pm[num_pulses];
    uint16_t data[spp];

    {
      for(int i = 0; i < num_pulses; ++i) {
        if(rp_osc_get_pulse(&pm[i], spp, &data[0], 0))
          break;
      }
    }
    for (int i = 0; i < num_pulses; ++i) {
      fprintf(stdout, "%d,%.6f,%d,%d,%.6f,%d,%.6f\n", 
              i,
              pm[i].trig_clock / 125.0e6,
              pm[i].num_trig,
              pm[i].num_acp,
              pm[i].acp_clock / 125.0e6,
              pm[i].num_arp,
              pm[i].arp_clock / 125.0e6
              );
    }
    puts("Last pulse:\n");
    for (int i = 0; i < spp; ++i)
      fprintf(stdout, "%d,%d\n", i, data[i]);

    if(rp_app_exit() < 0) {
        fprintf(stderr, "rp_app_exit() failed!\n");
        return -1;
    }

    return 0;
}
