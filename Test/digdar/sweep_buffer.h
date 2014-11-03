/* -*- c++ -*- */
/*
 * Copyright 2011, 2014 John Brzustowski
 * 
 * This file is part of digdar.
 * 
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
#include "pulse_metadata.h"
#include "sweep_metadata.h"

typedef unsigned short t_sample;

class sweep_buffer;  // forward declaration
class pulse_buffer; // forward declaration

class sweep_buffer
{ 
 friend class pulse_buffer;
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
  int				spp;			/**< samples per pulse seen */
  unsigned int			i_next_pulse;		/**< index of next pulse slot in buffer to receive data */
  unsigned int			i_pulse_needing_ACP;	/**< index of latest pulse whose ACP interval needs to be updated */

  static const unsigned int NO_ACP_UPDATE_NEEDED = 0xFFFFFFFF;   /**< value for i_pulse_needing_ACP that indicates no pulse needs ACP update */
  static const unsigned int BUFFER_REALLOC_INCREMENT = 64;       /**< number of additional pulses to allocate space for when we notice an overrun */

};

#endif // INCLUDED_SWEEP_BUFFER_H
