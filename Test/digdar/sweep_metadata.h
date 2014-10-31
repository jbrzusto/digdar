/* -*- c++ -*- */
/*
 * Copyright 2011, 2014 John Brzustowski
 * 
 * This file is part of digdar.
 */

#ifndef _SWEEP_METADATA_H_
#define _SWEEP_METADATA_H_

#include <boost/date_time/posix_time/posix_time.hpp>
#include <boost/date_time/posix_time/posix_time_duration.hpp>

typedef boost::posix_time::time_duration	t_duration; // type for time durations
typedef boost::posix_time::ptime		t_timestamp;// type for timestamps

struct sweep_metadata
{
  uint32_t		serial_no;		/**< serial number (count of ARPs since last reset) */
  t_timestamp		timestamp;		/**< timestamp at start of first pulse */
  t_duration		duration;		/**< duration of sweep, in seconds */
  uint16_t              samples_per_pulse;	/**< number of samples per pulse */
  uint16_t		n_pulses;		/**< number of pulses copied into buffer */
  uint16_t		n_actual_pulses;	/**< actual number of pulses seen during the sweep */
  float  		radar_PRF;		/**< estimated mean radar PRF (including pulses dropped by digitizer) */
  float 		rx_PRF;			/**< receiver PRF (number of pulses actually digitized by receiver, per second) */
  float 		range_cell_size;	/**< range coverage by each sample, in metres */
  uint16_t		n_ACPs;			/**< number of ACPs in sweep (this should be constant across sweeps) */

  static const double NOT_A_DATE_TIME = -1;     /**< constant representing invalid/missing date/time */
};

#endif /* _SWEEP_METADATA_H_ */
