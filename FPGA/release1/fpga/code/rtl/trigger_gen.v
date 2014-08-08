/** -*- verilog -*-
 *
 * @brief Red Pitaya trigger generation module.  It detects and counts trigger
 *        pulses in a digitized signal.  Input signal and thresholds are signed.
 *
 * @Author John Brzustowski
 *
 * (c) 2014 John Brzustowski https://radr-project.org
 *
 *
 * Generate a trigger a fixed delay after the signal crosses an
 * excitation threshold after having crossed a relaxation threshold.
 *
 * The threshold values are independent, and when unequal, "crossing"
 * a threshold means being found at or beyond it in the direction away
 * from the other threshold.  If the thresholds are equal, a positive
 * crossing is treated as excitation, a negative crossing as
 * relaxation.
 *
 * If a non-zero latency is specified, then at least that number of
 * clock ticks must elapse between consecutive excitation events (and
 * a relaxation event is still required between these).  Actual latency
 * is 2 plus the specified value.
 *
 * The count of ticks since the most recent excitation is maintained
 * in register "age".  The delay value does not affect the sequence of
 * "age" values, but is merely the age at which an excitation causes
 * output "trigger" to be asserted.
 *
 * Timing: if the input at clock pulse N crosses the excitation
 * threshold after a crossing of the relaxation threshold and any
 * required latency, then the trigger output is high at the start of
 * the clock pulse N+1+delay.
 *
 * Each trigger is held high for one clock.
 * 
 */

// mode of triggering depends on ordering of relax and excite thresholds:

`define MODE_NORMAL             2'd0  // thresh_relax < thresh_excite (usual situation)
`define MODE_INVERTED           2'd1  // thresh_relax > thresh_excite (inverted signal)
`define MODE_NOHYSTERESIS       2'd2  // thresh_relax == thresh_excite (single threshold; crossing upward is excitation)

// current state is waiting for either relax or excite, or delaying

`define STATE_WAITING_RELAX     2'd0  // waiting for signal to cross threshold in relaxation direction
`define STATE_WAITING_EXCITE    2'd1  // waiting for signal to cross threshold in excitation direction
`define STATE_DELAYING          2'd2  // threshold crossed; delaying before triggering

module trigger_gen 
  ( input clock,
    input                          reset,
    input                          enable,
    input [width-1:0]              signal_in,
    input [width-1:0]              thresh_relax,
    input [width-1:0]              thresh_excite,
    input [delay_width-1:0]        delay,
    input [age_width-1:0]          latency,
    output reg                     trigger,
    output reg [counter_width-1:0] counter
    );
   
   parameter width         = 12;
   parameter delay_width   = 32;
   parameter counter_width = 32;
   parameter age_width     = 32;
   parameter do_smoothing  = 1;
   
   reg [2-1:0] 			   state;           // one of STATE values above
   reg [delay_width-1:0] 	   delay_counter;   // countdown wait between trigger detection and assertion
   reg [width-1:0] 		   sig_smoothed;    // possibly smoothed version of signal_in
   reg [age_width-1:0]             age;             // number of clock ticks since assertion of trigger

   reg [2-1:0]                     mode;            // one of MODE values above

   wire                            excited;         // true when smoothed signal is at or beyond excitation threshold, away from relaxation
   wire                            relaxed;         // true when smoothed signal is at or beyond relaxation threshold, away from excitation
   
    
   reg [width + 3 - 1: 0]          smoother;

   always @(posedge clock)
     begin
        if ($signed(thresh_relax) < $signed(thresh_excite))
          mode <= `MODE_NORMAL;
        else if ($signed(thresh_relax) > $signed(thresh_excite))
          mode <= `MODE_INVERTED;
        else
          mode <= `MODE_NOHYSTERESIS;
     end

   assign excited = ((mode == `MODE_NORMAL)       && $signed(sig_smoothed) >= $signed(thresh_excite)) ||
                    ((mode == `MODE_INVERTED)     && $signed(sig_smoothed) <= $signed(thresh_excite)) ||
                    ((mode == `MODE_NOHYSTERESIS) && $signed(sig_smoothed) >  $signed(thresh_excite));

   assign relaxed = ((mode == `MODE_NORMAL)       && $signed(sig_smoothed) <= $signed(thresh_relax)) ||
                    ((mode == `MODE_INVERTED)     && $signed(sig_smoothed) >= $signed(thresh_relax)) ||
                    ((mode == `MODE_NOHYSTERESIS) && $signed(sig_smoothed) <  $signed(thresh_relax));
     
   always @(posedge clock)
     if (reset | ~enable)
       begin
          state <= `STATE_WAITING_EXCITE;
	  trigger <=  1'b0;
	  counter <=  1'b0;
	  sig_smoothed <=  signal_in;
          smoother <= {signal_in, 3'b0};
	  age <=  latency;  // so that we don't wait for latency before the very first trigger
       end
     else
       begin	  
	  age <= age + 1'b1;

   // smooth the signal with an IIR filter:  smooth[i+1] <= (7 * smooth[i] + value[i+1]) / 8
   // FIXME: make the weighting a control parameter, instead of hardwiring 7/8, 1/8.
   // Note the sign extension, as we treat signal as signed.

          smoother[width + 3 - 1: 0] <= {sig_smoothed[width-1:0], 3'b0} - {{3{sig_smoothed[width - 1]}}, sig_smoothed[width-1:0]} + {{3{signal_in[width - 1]}}, signal_in[width - 1:0]};

	  sig_smoothed <= do_smoothing ? smoother[3 + width - 1 : 3] : signal_in;

	  case (state)
	    `STATE_WAITING_RELAX:
	      begin
		 trigger <=  1'b0;
		 if (relaxed)
		   begin
		      state <=  `STATE_WAITING_EXCITE;
		   end
	      end
                        
	    `STATE_WAITING_EXCITE:
	      begin
                 if (excited & age >= latency)
		   begin
		      age <=  1'b0;
		      counter <=  counter + 1'b1;
		      if (delay == 0)
			begin
			   state <=  `STATE_WAITING_RELAX;
			   trigger <=  1'b1;
			end
		      else
			begin
			   state <=  `STATE_DELAYING;
			   delay_counter <=  delay;
			end
		   end
              end
	    
	    `STATE_DELAYING:
              if (| delay_counter)
                begin
		   delay_counter <= delay_counter - 1'b1;
		end
              else
                begin
		   state <=  `STATE_WAITING_RELAX;
		   trigger <=  1'b1;
		end
          endcase
       end
endmodule // red_pitaya_trigger_gen
