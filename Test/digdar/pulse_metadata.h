/*
  digdar.h - digitize radar pulses

  For each pulse, we return/print the following structure:


*/

#ifndef _PULSE_METADATA_H_
#define _PULSE_METADATA_H_

#include <stdint.h>

typedef struct {
  uint32_t num_trig;   // number of trigger pulses counted so far, regardless of the number digitized
  uint64_t trig_clock;  // ADC clock count (125 MHz) at which trigger pulse occurred
  uint32_t num_acp;     // number of ACP seen
  uint64_t acp_clock;   // ADC clock count (125 MHz) at most recent ACP pulse
  uint32_t num_arp;     // number of ARP seen
  uint64_t arp_clock;   // ADC clock count (125 MHz) at most recent ARP pulse
}  pulse_metadata;


#endif /* _PULSE_METADATA_H_ */
