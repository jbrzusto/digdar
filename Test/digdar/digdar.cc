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
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <map>
#include <iostream>
#include <fstream>

#include "digdar.h"
#include "main_digdar.h"
#include "fpga_digdar.h"
#include "version.h"
#include "worker.h"
#include "pulse_metadata.h"

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

/** Print usage information */
void usage() {

  const char *format =
    "\n"
    "Usage: %s [OPTION]\n"
    "\n"
    "  --acps -a NACP Number of ACPs per sweep; default: 450, which is appropriate for a Furuno FR radar\n"
    "  --cut -C CUT Azimuth (given as a fraction in [0..1] from heading) at which sweeps begin.\n"
    "           Default: 0.  This is used to avoid the ~2.5 second discontinuity in data\n"
    "           from occuring at an inconvenient location in the data field.\n"
    "           NOTE: this option must come *after* --acps, if that option is given.\n"
    "  --decim  -d DECIM   Decimation rate: one of 1, 2, 3, 4, 8, 64, 1024, 8192, or 65536\n"
    "  --dump_params -D  don't run - just dump current FPGA parameter values as NAME VAL\n"
    "  --sum   If specified, return the sum (in 16-bits) of samples in the decimation period.\n"
    "          e.g. instead of returning (x[0]+x[1])/2 at decimation rate 2, return x[0]+x[1]\n"
    "          Only valid if the decimation rate is <= 4 so that the sum fits in 16 bits\n"
    "  --samples   -n SAMPLES   Samples per pulse. (Up to 16384; default is 3000)\n"
    "  --pulses -p PULSES Number of pulses to allocate buffer for (default; number that fit in 150MB of RAM)\n"
    "  --param_file -P FILE File of name value pairs for digitizer fpga parameters\n"
    "  --remove -r START:END  Remove sector.  START and END are portions of the circle in [0, 1]\n"
    "                         where 0 is the start of the ARP pulse, and 1 is the start of the next ARP\n"
    "                         pulse.  Pulses within the sector from START to END are remoted and not output.\n"
    "                         If START > END, the removed sector consists of [START, 1] U [0, END].\n"
    "                         Multiple --remove options may be given.\n"
    "           NOTE: this option must come *after* --acps, if that option is given.\n"
    "  --tcp HOST:PORT instead of writing to stdout, open a TCP socket connection to PORT on HOST and\n"
    "                  write there.\n"
    "  --version       -v    Print version info.\n"
    "  --help          -h    Print this message.\n"
    "\n";

  fprintf( stderr, format, g_argv0);
}

double now() {
  static struct timespec ts;
  clock_gettime(CLOCK_REALTIME, & ts);
  return ts.tv_sec + ts.tv_nsec / 1.0e9;
};



std::map<std::string, int> name_map;

void set_param (std::string name, uint32_t value) {
  // set the FPGA parameter given by name to the specified value
  // All settable FPGA register values are 32 bits.
  if (name_map.find(name) != name_map.end())
    * (uint32_t *) (((char *) g_digdar_fpga_reg_mem) + 4 * name_map[name]) = value;
};

uint32_t get_param (std::string name) {
  return * (uint32_t *) (((char *) g_digdar_fpga_reg_mem) + 4 * name_map[name]);
};

void setup_param_name_map() {
  // names must be in the same order as they are in the definition
  // of digdar_fpga_reg_mem_t
  // Not all of these make sense to set!
  int i = 0;
  name_map["trig_thresh_excite"]         = i++;
  name_map["trig_thresh_relax"]          = i++;
  name_map["trig_delay"]                 = i++;
  name_map["trig_latency"]               = i++;
  name_map["trig_count"]                 = i++;
  name_map["trig_clock_low"]             = i++;
  name_map["trig_clock_high"]            = i++;
  name_map["trig_prev_clock_low"]        = i++;
  name_map["trig_prev_clock_high"]       = i++;
  name_map["acp_thresh_excite"]          = i++;
  name_map["acp_thresh_relax"]           = i++;
  name_map["acp_latency"]                = i++;
  name_map["acp_count"]                  = i++;
  name_map["acp_clock_low"]              = i++;
  name_map["acp_clock_high"]             = i++;
  name_map["acp_prev_clock_low"]         = i++;
  name_map["acp_prev_clock_high"]        = i++;
  name_map["arp_thresh_excite"]          = i++;
  name_map["arp_thresh_relax"]           = i++;
  name_map["arp_latency"]                = i++;
  name_map["arp_count"]                  = i++;
  name_map["arp_clock_low"]              = i++;
  name_map["arp_clock_high"]             = i++;
  name_map["arp_prev_clock_low"]         = i++;
  name_map["arp_prev_clock_high"]        = i++;
  name_map["acp_per_arp"]                = i++;
  name_map["saved_trig_count"]           = i++;
  name_map["saved_trig_clock_low"]       = i++;
  name_map["saved_trig_clock_high"]      = i++;
  name_map["saved_trig_prev_clock_low"]  = i++;
  name_map["saved_trig_prev_clock_high"] = i++;
  name_map["saved_acp_count"]            = i++;
  name_map["saved_acp_clock_low"]        = i++;
  name_map["saved_acp_clock_high"]       = i++;
  name_map["saved_acp_prev_clock_low"]   = i++;
  name_map["saved_acp_prev_clock_high"]  = i++;
  name_map["saved_arp_count"]            = i++;
  name_map["saved_arp_clock_low"]        = i++;
  name_map["saved_arp_clock_high"]       = i++;
  name_map["saved_arp_prev_clock_low"]   = i++;
  name_map["saved_arp_prev_clock_high"]  = i++;
  name_map["saved_acp_per_arp"]          = i++;
  name_map["clocks_low"]                 = i++;
  name_map["clocks_high"]                = i++;
  name_map["acp_raw"]                    = i++;
  name_map["arp_raw"]                    = i++;
  name_map["acp_at_arp"]                 = i++;
  name_map["saved_acp_at_arp"]           = i++;
  name_map["trig_at_arp"]                = i++;
  name_map["saved_trig_at_arp"]          = i++;
};

sector removals[MAX_REMOVALS];
uint16_t num_removals = 0;

uint16_t n_samples = 3000;  // samples to grab per radar pulse
uint32_t decim = 1; // decimation: 1, 2, 8, etc.
uint32_t max_pulse_buffer_memory = 150000000; // 150Mb pulse buffer memory
uint32_t pulse_buff_size = 0; // number of pulses to maintain in ring buffer (filled by worker thread); default 0 means as many as fit in max memory
uint32_t psize = 0; // actual size of each pulse's storage (metadata + data) - will be set below
uint16_t use_sum = 0; // if non-zero, return sum of samples rather than truncated average
uint16_t acps = 450; // number of ACPs per sweep; used in calculating removal
uint16_t cut = 0; // number of ACPs after heading pulse at which to cut between sweeps
int outfd = -1; // file descriptor for output; fileno(stdout) by default;

// boilerplate ougoing socket connection fields, from Linux man-pages

struct addrinfo hints;
struct addrinfo *result, *rp;
int sfd, s;
struct sockaddr_storage peer_addr;
socklen_t peer_addr_len;
ssize_t nread;
pulse_metadata *pulse_buffer = 0;

char * host = 0;
char * port = 0;

bool dump_params = false; // if true, just dump all digdar FPGA registers as NAME VALUE
std::string param_file; // if specified, read parameters from this file and set FPGA regs appropriately

/** Acquire pulses main */
int main(int argc, char *argv[])
{
  g_argv0 = argv[0];

  if ( argc < MINARGS ) {
    usage();
    exit ( EXIT_FAILURE );
  }

  setup_param_name_map();

  /* Command line options */
  static struct option long_options[] = {
    /* These options set a flag. */
    {"acps", required_argument, 0, 'a'},
    {"decim", required_argument,       0, 'd'},
    {"dump_params", no_argument, 0, 'D'},
    {"samples",      required_argument,       0, 'n'},
    {"sum",      no_argument,       0, 's'},
    {"pulses",       required_argument,       0, 'p'},
    {"param_file",   required_argument,       0, 'P'},
    {"remove",    required_argument,          0, 'r'},
    {"tcp",    required_argument,          0, 't'},
    {"version",      no_argument,       0, 'v'},
    {"help",         no_argument,       0, 'h'},
    {0, 0, 0, 0}
  };
  const char *optstring = "aC:d:Dhn:p:P:r:st:v";

  /* getopt_long stores the option index here. */
  int option_index = 0;

  int ch = -1;
  while ( (ch = getopt_long( argc, argv, optstring, long_options, &option_index )) != -1 ) {
    switch ( ch ) {
    case 'a':
      acps = atoi(optarg);
      break;

    case 'C':
      cut = atof(optarg) * acps;
      break;

    case 'd':
      decim = atoi(optarg);
      break;

    case 'D':
      dump_params=true;
      break;

    case 'h':
      usage();
      exit( EXIT_SUCCESS );
      break;

    case 'n':
      n_samples = atoi(optarg);
      break;

    case 'p':
      pulse_buff_size = atoi(optarg);
      break;

    case 'P':
      param_file = std::string(optarg);
      break;

    case 'r':
      {
        if (num_removals == MAX_REMOVALS) {
          fprintf(stderr, "Too many removals specified; max is %d\n", MAX_REMOVALS);
          exit( EXIT_FAILURE );
        }
        char *split = strchr(optarg, ':');
        if (! split) {
          usage();
          exit (EXIT_FAILURE );
        }
        *split = '\0';
        removals[num_removals].begin = atof(optarg) * acps;
        removals[num_removals].end = atof(split + 1) * acps;
        ++num_removals;
      };
      break;

    case 's':
      use_sum = 1;
      break;

    case 't':
      {
        host = optarg;
        port = strchr(optarg, ':');
        if (! port) {
          usage();
          exit ( EXIT_FAILURE );
        }

        break;
      case 'v':
        fprintf(stdout, "%s version %s-%s\n", g_argv0, VERSION_STR, REVISION_STR);
        exit( EXIT_SUCCESS );
        break;

      default:
        usage();
        exit( EXIT_FAILURE );
      }
    }
  }

  if (host) {

    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_family = AF_INET;    /* Allow IPv4 only */
    hints.ai_socktype = SOCK_STREAM; /* Stream socket */
    hints.ai_flags = 0;
    hints.ai_protocol = 0;          /* Any protocol */

    *port++ = '\0';
    s = getaddrinfo(host, port, &hints, &result);
    if (s != 0) {
      fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(s));
      exit(EXIT_FAILURE);
    }

    /* getaddrinfo() returns a list of address structures.
       Try each address until we successfully connect(2).
       If socket(2) (or connect(2)) fails, we (close the socket
       and) try the next address. */

    for (rp = result; rp != NULL; rp = rp->ai_next) {
      outfd = socket(rp->ai_family, rp->ai_socktype,
                     rp->ai_protocol);
      if (outfd == -1)
        continue;

      if (connect(outfd, rp->ai_addr, rp->ai_addrlen) != -1)
        break;                  /* Success */

      close(outfd);
    }

    if (rp == NULL) {               /* No address succeeded */
      fprintf(stderr, "Could not connect\n");
      exit(EXIT_FAILURE);
    }
  }

  switch(decim) {
  case 1:
  case 2:
  case 3:
  case 4:
  case 8:
  case 64:
  case 1024:
  case 8192:
  case 65536:
    break;
  default:
    fprintf(stderr, "incorrect value (%d) for decimation; must be 1, 2, 3, 4, 8, 64, 1024, 8192, or 65536\n", decim);
    return -1;
  }

  t_params[DECIM_FACTOR_PARAM] = decim;

  if (n_samples > 16384 || n_samples < 0) {
    fprintf(stderr, "incorrect value (%d) for samples per pulse; must be 0..16384\n", n_samples);
    return -1;
  }

  if (use_sum && decim > 4) {
    fprintf(stderr, "warning cannot specify --sum when decimation rate is > 4; ignoring\n");
    use_sum = false;
  }

  if (outfd == -1) {
    outfd = fileno(stdout);
  }

  /* Standard radar triggering mode */
  t_params[TRIG_MODE_PARAM] = 1;
  t_params[TRIG_SRC_PARAM] = 10;

  /* Initialization of Oscilloscope application */
  if(rp_app_init() < 0) {
    fprintf(stderr, "rp_app_init() failed!\n");
    return -1;
  }

  if (param_file.size() > 0) {
    std::ifstream pin (param_file);
    std::string name;
    uint32_t val;
    for (;;) {
      if (! (pin >> name))
        break;
      if (name[0] == '#') {
        // comment: skip rest of line
        pin.ignore(100000, '\n');
        continue;
      }
      pin >> val;
      set_param(name, val);
    };
  }

  if (dump_params) {
    for (auto i = name_map.begin(); i != name_map.end(); ++i) {
      std::cout << i->first << ' ' << get_param(i->first) << std::endl;
    }
    exit(0);
  };


  /* Setting of parameters in Oscilloscope main module */

  if(rp_set_params((float *)&t_params, PARAMS_NUM) < 0) {
    fprintf(stderr, "rp_set_params() failed!\n");
    return -1;
  }

  /* storage for one pulse, in bytes */
  psize = sizeof(pulse_metadata) + sizeof(uint16_t) * (n_samples - 1);

  /* maximum number of pulses allowed for pulse buffer */
  uint32_t max_pulses = max_pulse_buffer_memory / psize;
  if (pulse_buff_size == 0 || pulse_buff_size > max_pulses)
    pulse_buff_size = max_pulses;


  pulse_buffer = (pulse_metadata *) calloc(pulse_buff_size, psize);
  if (!pulse_buffer) {
    fprintf(stderr, "couldn't allocate pulse buffer\n");
    return -1;
  }

  // start worker thread which captures to pulse buffer

  rp_osc_worker_change_state(rp_osc_start_state);

  uint32_t cur_pulse = 0; // index of first chunk pulse in ring buffer
  uint32_t num_pulses = 0; // number of pulses availabe in ring buffer (maxes out to max_pulses)

  /* Continuous thread loop (exited only with 'quit' state) */
  while(1) {
    if (! rp_osc_get_chunk_for_reader(& cur_pulse, & num_pulses)) {
      usleep(20);
      sched_yield();
      continue;
    }
    int n = num_pulses * psize;
    int offset = 0;
    int m;
    do {
      m = write(outfd, ((char *) pulse_buffer) + cur_pulse * psize + offset, n);
      if (m < 0)
        break;
      n -= m;
      offset += m;
    } while (n > 0);
    if (m < 0)
      break;
  }
  return 0;
}
