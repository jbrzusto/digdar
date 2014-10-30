/*
  digdar.h - digitize radar pulses

  For each pulse, we return/print the following structure:


*/

#ifndef _DIGDAR_H_
#define _DIGDAR_H_

#include <stdint.h>

typedef struct {
  uint64_t trig_clock;  // ADC clock count (125 MHz) at which trigger pulse occurred
  uint32_t num_trigs;   // number of trigger pulses counted so far, regardless of the number digitized
  uint32_t num_acp;     // number of ACP seen
  uint64_t acp_clock;   // ADC clock count (125 MHz) at most recent ACP pulse
  uint32_t num_arp;     // number of ARP seen
  uint64_t arp_clock;   // ADC clock count (125 MHz) at most recent ARP pulse
  uint32_t num_samples; // number of samples 0..16384 in data[] item
  uint16_t data[16384]; // 14-bit video unsigned samples, with 2 high-order bits zero;
} captured_pulse_t;


#endif /* _DIGDAR_H_ */
