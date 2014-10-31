/* -*- c++ -*- */
/*
 * Copyright 2011 John Brzustowski
 * 
 * This file is part of GNU Radio
 * 
 * GNU Radio is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
 * any later version.
 * 
 * GNU Radio is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with GNU Radio; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */

#ifndef INCLUDED_SWEEP_BUFFER_H
#define INCLUDED_SWEEP_BUFFER_H

#define BOOST_THREAD_USE_LIB 
#include <boost/thread/thread.hpp>
#include <boost/thread/locks.hpp>
#include <boost/thread/condition_variable.hpp>
#include <boost/bind.hpp>
#include <boost/date_time/posix_time/posix_time.hpp>
#include <boost/date_time/posix_time/posix_time_duration.hpp>
#include <math.h>
#include "usrp/usrp_marine_radar.h"
#include "sweep_metadata.h"

typedef unsigned short t_sample;

class sweep_buffer;  // forward declaration
class usrp_pulse_buffer; // forward declaration

class sweep_buffer
{ 
 friend class usrp_pulse_buffer;
 friend class std::vector<sweep_buffer>;

 public:

  typedef enum {BUF_EMPTY, BUF_FILLING, BUF_FULL_NEEDS_META, BUF_FULL_HAS_META, BUF_EMPTYING} t_buf_status;

  /*!
   * \brief set the sizes of the sample and metadata buffers
   * \param n_pulses the initial number of pulse for which to allocate buffers
   * \param the number of samples per pulse for which to allocate buffers
   */
  void set_size (unsigned int n_pulses, unsigned int spp);

  /*!
   * \brief return a pointer to the location in samples where the
   * first sample of the next pulse should be received
   */
  t_sample* curr_sample ();

  /*!
   * \brief return a pointer to the location in pmeta where the
   * metadata for the next pulse should be received
   */
  pulse_metadata* curr_pulse ();

  /*!
   * \brief return number of pulses in buffer
   */
  unsigned int n_pulses();

  /*!
   * \brief return angle for i'th pulse, in radians clockwise from the ARP pulse
   */
  double pulse_angle(unsigned int i);
  
  /*!
   * \brief mark buffer as empty
   */
  void clear();

  /*!
   * \brief factory method
   */
  static sweep_buffer* make ();

  
private:
  /*!
   * \brief constructor
   */
  sweep_buffer();                                       

  sweep_metadata		smeta;			/**< metadata for the sweep in this buffer */
  t_buf_status                  status;			/**< status of the buffer */
  std::vector<t_sample>		samples;		/**< sample buffer */
  std::vector<pulse_metadata>	pmeta;			/**< pulse metadata buffer */
  int				spp;			/**< samples per pulse sent by USRP */
  unsigned int			i_next_pulse;		/**< index of next pulse slot in buffer to receive data */
  unsigned int			i_pulse_needing_ACP;	/**< index of latest pulse whose ACP interval needs to be updated */

  static const unsigned int NO_ACP_UPDATE_NEEDED = 0xFFFFFFFF;   /**< value for i_pulse_needing_ACP that indicates no pulse needs ACP update */
  static const unsigned int BUFFER_REALLOC_INCREMENT = 64;       /**< number of additional pulses to allocate space for when we notice an overrun */

};

#endif // INCLUDED_SWEEP_BUFFER_H
