/*
 * Structure representing a digitized radar pulse.
 *
 * Copyright 2011-2019 John Brzustowski
 *
 * This file is part of digdar.
*/

#ifndef _PULSE_METADATA_H_
#define _PULSE_METADATA_H_

#include <stdint.h>

typedef struct {
  uint32_t arp_clock_sec;  // RP realtime clock seconds at most recent ARP pulse
  uint32_t arp_clock_nsec; // RP realtime clock nanoseconds at most realtime ARP pulse
  uint32_t trig_clock;     // ADC clock count (125 MHz) at which trigger pulse occurred, relative to that at most recent ARP
  float    acp_clock;      // N + M, where N is the number of ACPs since the latest ARP,
                           // and M is the fraction of 8 ms represented by the time since the latest ACP
                           // i.e. M = elapsed ADC clock ticks (@125MHz) / 1E6
  uint32_t num_trig;       // number of trigger pulses seen since last ARP, regardless of the number digitized
  uint32_t num_arp;        // number of arp pulses since reset
  uint16_t data[1];        // stub; will hold all samples when allocated
}   __attribute__((packed))  pulse_metadata;


#endif /* _PULSE_METADATA_H_ */
