/**
 *
 * @brief Red Pitaya DIGDAR module.  Performs various functions related to
 * digitizing marine radar signals.
 *
 * @Author John Brzustowski
 *
 * (c) John Brzustowski https://radr-project.org
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 *
 */

/**
 * Memory Map for DIGDAR module; offsets are from 0x40600000, the start of the
 * UNUSED region of the standard redpitaya memory map.
 */

`define OFFSET_TRIG_THRESH_EXCITE         20'h00000 // TRIG thresh_excite - excitation threshold for TRIG pulse (14 bits)
`define OFFSET_TRIG_THRESH_RELAX          20'h00004 // TRIG thresh_relax  - relaxation threshold for TRIG pulse (14 bits)
`define OFFSET_TRIG_DELAY                 20'h00008 // trigger delay, in (non-decimated) ADC clocks; delay after trigger
// detection before first decimated sample is acquired
`define OFFSET_TRIG_LATENCY               20'h0000C // TRIG latency - countdown of clocks after detection before next detection
// is permitted (helps debounce)
`define OFFSET_TRIG_COUNT                 20'h00010 // TRIG count since reset (32 bits; wraps)
`define OFFSET_TRIG_CLOCK_LOW             20'h00014 // clock at most recent TRIG (low 32 bits)
`define OFFSET_TRIG_CLOCK_HIGH            20'h00018 // clock at most recent TRIG (high 32 bits)
`define OFFSET_TRIG_PREV_CLOCK_LOW        20'h0001C // clock at previous TRIG (low 32 bits)
`define OFFSET_TRIG_PREV_CLOCK_HIGH       20'h00020 // clock at previous TRIG (high 32 bits)

`define OFFSET_ACP_THRESH_EXCITE          20'h00024 // ACP thresh_excite - excitation threshold for ACP pulse (12 bits)
`define OFFSET_ACP_THRESH_RELAX           20'h00028 // ACP thresh_relax  - relaxation threshold for ACP pulse (12 bits)
`define OFFSET_ACP_LATENCY                20'h0002C // ACP latency - countdown of clocks after detection before next detection
// is permitted (helps debounce)
`define OFFSET_ACP_COUNT                  20'h00030 // ACP count since reset (32 bits; wraps)
`define OFFSET_ACP_CLOCK_LOW              20'h00034 // clock at most recent ACP (low 32 bits)
`define OFFSET_ACP_CLOCK_HIGH             20'h00038 // clock at most recent ACP (high 32 bits)
`define OFFSET_ACP_PREV_CLOCK_LOW         20'h0003C // clock at previous ACP (low 32 bits)
`define OFFSET_ACP_PREV_CLOCK_HIGH        20'h00040 // clock at previous ACP (high 32 bits)

`define OFFSET_ARP_THRESH_EXCITE          20'h00044 // ARP thresh_excite - excitation threshold for ARP pulse (12 bits)
`define OFFSET_ARP_THRESH_RELAX           20'h00048 // ARP thresh_relax  - relaxation threshold for ARP pulse (12 bits)
`define OFFSET_ARP_LATENCY                20'h0004C // ARP latency - countdown of clocks after detection before next detection
// is permitted (helps debounce)
`define OFFSET_ARP_COUNT                  20'h00050 // ARP count since reset (32 bits; wraps)
`define OFFSET_ARP_CLOCK_LOW              20'h00054 // clock at most recent ARP (low 32 bits)
`define OFFSET_ARP_CLOCK_HIGH             20'h00058 // clock at most recent ARP (high 32 bits)
`define OFFSET_ARP_PREV_CLOCK_LOW         20'h0005C // clock at previous ARP (low 32 bits)
`define OFFSET_ARP_PREV_CLOCK_HIGH        20'h00060 // clock at previous ARP (high 32 bits)

`define OFFSET_ACP_PER_ARP                20'h00064 // count of ACP pulses between two most recent ARP pulses

// copies of registers saved at the start of each digitizing period

`define OFFSET_SAVED_TRIG_COUNT           20'h00068 // (saved) TRIG count since reset (32 bits; wraps)
`define OFFSET_SAVED_TRIG_CLOCK_LOW       20'h0006C // (saved) clock at most recent TRIG (low 32 bits)
`define OFFSET_SAVED_TRIG_CLOCK_HIGH      20'h00070 // (saved) clock at most recent TRIG (high 32 bits)
`define OFFSET_SAVED_TRIG_PREV_CLOCK_LOW  20'h00074 // (saved) clock at previous TRIG (low 32 bits)
`define OFFSET_SAVED_TRIG_PREV_CLOCK_HIGH 20'h00078 // (saved) clock at previous TRIG (high 32 bits)
`define OFFSET_SAVED_ACP_COUNT            20'h0007C // (saved) ACP count since reset (32 bits; wraps)
`define OFFSET_SAVED_ACP_CLOCK_LOW        20'h00080 // (saved) clock at most recent ACP (low 32 bits)
`define OFFSET_SAVED_ACP_CLOCK_HIGH       20'h00084 // (saved) clock at most recent ACP (high 32 bits)
`define OFFSET_SAVED_ACP_PREV_CLOCK_LOW   20'h00088 // (saved) clock at previous ACP (low 32 bits)
`define OFFSET_SAVED_ACP_PREV_CLOCK_HIGH  20'h0008C // (saved) clock at previous ACP (high 32 bits)
`define OFFSET_SAVED_ARP_COUNT            20'h00090 // (saved) ARP count since reset (32 bits; wraps)
`define OFFSET_SAVED_ARP_CLOCK_LOW        20'h00094 // (saved) clock at most recent ARP (low 32 bits)
`define OFFSET_SAVED_ARP_CLOCK_HIGH       20'h00098 // (saved) clock at most recent ARP (high 32 bits)
`define OFFSET_SAVED_ARP_PREV_CLOCK_LOW   20'h0009C // (saved) clock at previous ARP (low 32 bits)
`define OFFSET_SAVED_ARP_PREV_CLOCK_HIGH  20'h000A0 // (saved) clock at previous ARP (high 32 bits)
`define OFFSET_SAVED_ACP_PER_ARP          20'h000A4 // (saved) count of ACP pulses between two most recent ARP pulses

// utility / debugging registers

`define OFFSET_CLOCKS_LOW                 20'h000A8 // clock counter since reset (low 32 bits)
`define OFFSET_CLOCKS_HIGH                20'h000AC // clock counter since reset (high 32 bits)

`define OFFSET_ACP_RAW                    20'h000B0 // most recent slow ADC value from ACP
`define OFFSET_ARP_RAW                    20'h000B4 // most recent slow ADC value from ARP

`define OFFSET_ACP_AT_ARP                 20'h000B8 // most recent ACP count at ARP pulse
`define OFFSET_SAVED_ACP_AT_ARP           20'h000BC // (saved) most recent ACP count at ARP pulse
`define OFFSET_TRIG_AT_ARP                20'h000C0 // most recent trig count at ARP pulse
`define OFFSET_SAVED_TRIG_AT_ARP          20'h000C4 // (saved) most recent trig count at ARP pulse

module red_pitaya_digdar
  (
   input             adc_clk_i, //!< clock
   input             adc_rstn_i, //!< ADC reset - active low
   // Slow ADC

   input [ 14-1: 0]  adc_b_i, //!< fast ADC channel B
   input [ 12-1: 0]  xadc_a_i, //!< most recent value from slow ADC channel A
   input [ 12-1: 0]  xadc_b_i, //!< most recent value from slow ADC channel B
   input             xadc_a_strobe_i, //!< strobe for most recent value from slow ADC channel A
   input             xadc_b_strobe_i, //!< strobe for most recent value from slow ADC channel B

   input             capturing_i, //!< true when ADC is armed but not yet triggered

   output            radar_trig_o, //!< edge of radar trigger signal
   output            acp_trig_o, //!< edge of acp pulse
   output            arp_trig_o, //!< edge of arp pulse

   // system bus
   input             sys_clk_i , //!< bus clock
   input             sys_rstn_i , //!< bus reset - active low
   input [ 32-1: 0]  sys_addr_i , //!< bus address
   input [ 32-1: 0]  sys_wdata_i , //!< bus write data
   input [ 4-1: 0]   sys_sel_i , //!< bus write byte select
   input             sys_wen_i , //!< bus write enable
   input             sys_ren_i , //!< bus read enable
   output [ 32-1: 0] sys_rdata_o , //!< bus read data
   output            sys_err_o , //!< bus error indicator
   output            sys_ack_o     //!< bus acknowledge signal

   );

   reg [12-1: 0]     acp_thresh_excite  ;
   reg [12-1: 0]     acp_thresh_relax   ;
   reg [32-1: 0]     acp_latency        ;
   wire [32-1: 0]    acp_count          ;
   reg [64-1: 0]     acp_clock          ;
   reg [64-1: 0]     acp_prev_clock     ;
   reg [12-1: 0]     arp_thresh_excite  ;
   reg [12-1: 0]     arp_thresh_relax   ;
   reg [32-1: 0]     arp_latency        ;
   wire [32-1: 0]    arp_count          ;
   reg [64-1: 0]     arp_clock          ;
   reg [64-1: 0]     arp_prev_clock     ;
   reg [64-1: 0]     clock_counter      ;
   reg [32-1: 0]     acp_per_arp        ;
   reg [32-1: 0]     acp_at_arp         ;
   reg [32-1: 0]     trig_at_arp        ;
   reg [14-1: 0]     trig_thresh_excite  ;
   reg [14-1: 0]     trig_thresh_relax   ;
   reg [32-1: 0]     trig_delay          ;
   reg [32-1: 0]     trig_latency        ;
   wire [32-1: 0]    trig_count          ;
   reg [64-1: 0]     trig_clock          ;
   reg [64-1: 0]     trig_prev_clock     ;

   // registers that record values of above registers at start of digitizing trigger

   reg [32-1: 0]     saved_acp_count           ;
   reg [64-1: 0]     saved_acp_clock           ;
   reg [64-1: 0]     saved_acp_prev_clock      ;
   reg [32-1: 0]     saved_arp_count           ;
   reg [64-1: 0]     saved_arp_clock           ;
   reg [64-1: 0]     saved_arp_prev_clock      ;
   reg [64-1: 0]     saved_clock_counter       ;
   reg [32-1: 0]     saved_acp_per_arp         ;
   reg [32-1: 0]     saved_acp_at_arp          ;
   reg [32-1: 0]     saved_trig_at_arp         ;
   reg [32-1: 0]     saved_trig_count          ;
   reg [64-1: 0]     saved_trig_clock          ;
   reg [64-1: 0]     saved_trig_prev_clock     ;

   trigger_gen #( .width(12),
                  .counter_width(32),
                  .do_smoothing(1)
                  ) trigger_gen_acp  // not really a trigger; we're just counting these pulses
     (
      .clock(adc_clk_i),
      .reset(! adc_rstn_i),  // active low
      .enable(1'b1),
      .strobe(xadc_a_strobe_i),
      .signal_in(xadc_a_i), // signed
      .thresh_excite(acp_thresh_excite), // signed
      .thresh_relax(acp_thresh_relax), //signed
      .delay(0),
      .latency(acp_latency),
      .trigger(acp_trig_o),
      .counter(acp_count)
      );

   trigger_gen #( .width(12),
                  .counter_width(32),
                  .do_smoothing(1)
                  ) trigger_gen_arp  // not really a trigger; we're just counting these pulses
     (
      .clock(adc_clk_i),
      .reset(! adc_rstn_i), // active low
      .enable(1'b1),
      .strobe(xadc_b_strobe_i),
      .signal_in(xadc_b_i), // signed
      .thresh_excite(arp_thresh_excite), // signed
      .thresh_relax(arp_thresh_relax), // signed
      .delay(0),
      .latency(arp_latency),
      .trigger(arp_trig_o),
      .counter(arp_count)
      );

   trigger_gen #( .width(14),
                  .counter_width(32),
                  .do_smoothing(1)
                  ) trigger_gen_trig // this counts trigger pulses and uses them
     (
      .clock(adc_clk_i),
      .reset(! adc_rstn_i), // active low
      .enable(1'b1),
      .strobe(1'b1),
      .signal_in(adc_b_i), // signed
      .thresh_excite(trig_thresh_excite), // signed
      .thresh_relax(trig_thresh_relax), // signed
      .delay(trig_delay),
      .latency(trig_latency),
      .trigger(radar_trig_o),
      .counter(trig_count)
      );



   //---------------------------------------------------------------------------------
   //
   //  system bus connection

   // bridge between ADC and sys clock

   //bus bridging components
   wire [ 32-1: 0]   addr         ;
   wire [ 32-1: 0]   wdata        ;
   wire              wen          ;
   wire              ren          ;
   reg [ 32-1: 0]    rdata        ;
   reg               err          ;
   reg               ack          ;

   always @(posedge adc_clk_i) begin
      if (adc_rstn_i == 1'b0) begin
         clock_counter              <= 64'h0;

         acp_clock           <= 64'h0;
         acp_prev_clock      <= 64'h0;

         arp_clock           <= 64'h0;
         arp_prev_clock      <= 64'h0;

         trig_clock          <= 64'h0;
         trig_prev_clock     <= 64'h0;

         acp_per_arp         <= 32'h0;

         acp_at_arp          <= 32'h0;
         trig_at_arp         <= 32'h0;

         // set thresholds at extremes to prevent triggering
         // before client values have been set

         trig_thresh_excite <= 14'h1fff;  // signed
         trig_thresh_relax  <= 14'h2000;  // signed

         acp_thresh_excite <= 12'h7ff;  // signed
         acp_thresh_relax  <= 12'h800;  // signed

         arp_thresh_excite <= 12'h7ff;  // signed
         arp_thresh_relax  <= 12'h800;  // signed

      end // if (adc_rstn_i == 1'b0)
      else begin
         if (wen) begin
            casez (addr[19:0])
              `OFFSET_ACP_THRESH_EXCITE   : acp_thresh_excite   <= wdata[ 12-1: 0];
              `OFFSET_ACP_THRESH_RELAX    : acp_thresh_relax    <= wdata[ 12-1: 0];
              `OFFSET_ACP_LATENCY         : acp_latency         <= wdata[ 32-1: 0];
              `OFFSET_ARP_THRESH_EXCITE   : arp_thresh_excite   <= wdata[ 12-1: 0];
              `OFFSET_ARP_THRESH_RELAX    : arp_thresh_relax    <= wdata[ 12-1: 0];
              `OFFSET_ARP_LATENCY         : arp_latency         <= wdata[ 32-1: 0];
              `OFFSET_TRIG_THRESH_EXCITE  : trig_thresh_excite  <= wdata[ 12-1: 0];
              `OFFSET_TRIG_THRESH_RELAX   : trig_thresh_relax   <= wdata[ 12-1: 0];
              `OFFSET_TRIG_DELAY          : trig_delay          <= wdata[ 32-1: 0];
              `OFFSET_TRIG_LATENCY        : trig_latency        <= wdata[ 32-1: 0];
            endcase
         end // if (wen)

         // Not reset, so check for acp and arp pulses and record time,
         // keeping previous time
         clock_counter <= clock_counter + 64'b1;

         if (acp_trig_o) begin
            acp_clock           <= clock_counter;
            acp_prev_clock      <= acp_clock;
         end
         if (arp_trig_o) begin
            arp_clock           <= clock_counter;
            arp_prev_clock      <= arp_clock;
            acp_per_arp         <= acp_count - acp_at_arp;
            acp_at_arp          <= acp_count;
            trig_at_arp         <= trig_count;
         end
         if (radar_trig_o) begin
            trig_clock           <= clock_counter;
            trig_prev_clock      <= trig_clock;
         end

         if (radar_trig_o & ! capturing_i) begin
            // we've been triggered but are not already capturing so
            // save copies of metadata registers for this pulse.
            // (If radar_trig_o is true but we are already capturing,
            // the capture interval is too long for the trigger rate!)
            saved_acp_count           <=  acp_count          ;
            saved_acp_clock           <=  acp_clock          ;
            saved_acp_prev_clock      <=  acp_prev_clock     ;
            saved_arp_count           <=  arp_count          ;
            saved_arp_clock           <=  arp_clock          ;
            saved_arp_prev_clock      <=  arp_prev_clock     ;
            saved_clock_counter       <=  clock_counter      ;
            saved_acp_per_arp         <=  acp_per_arp        ;
            saved_acp_at_arp          <=  acp_at_arp         ;
            saved_trig_at_arp         <=  trig_at_arp        ;
            saved_trig_count          <=  trig_count         ;
            saved_trig_clock          <=  clock_counter      ; // NB: not trig_clock, since that's not valid until the next tick.
            saved_trig_prev_clock     <=  trig_clock         ;
         end
      end // else: !if(adc_rstn_i == 1'b0)
   end

   always @(*) begin
      err <= 1'b0 ;

      casez (addr[19:0])
        `OFFSET_ACP_THRESH_EXCITE    : begin ack <= 1'b1;  rdata <= {{32-12{1'b0}}, acp_thresh_excite        }; end
        `OFFSET_ACP_THRESH_RELAX     : begin ack <= 1'b1;  rdata <= {{32-12{1'b0}}, acp_thresh_relax         }; end
        `OFFSET_ACP_LATENCY          : begin ack <= 1'b1;  rdata <= {               acp_latency              }; end
        `OFFSET_ACP_COUNT            : begin ack <= 1'b1;  rdata <= {               acp_count                }; end
        `OFFSET_ACP_CLOCK_LOW        : begin ack <= 1'b1;  rdata <= {               acp_clock[32-1:0]        }; end
        `OFFSET_ACP_CLOCK_HIGH       : begin ack <= 1'b1;  rdata <= {               acp_clock[64-1:32]       }; end
        `OFFSET_ACP_PREV_CLOCK_LOW   : begin ack <= 1'b1;  rdata <= {               acp_prev_clock[32-1:0]   }; end
        `OFFSET_ACP_PREV_CLOCK_HIGH  : begin ack <= 1'b1;  rdata <= {               acp_prev_clock[64-1:32]  }; end
        `OFFSET_ARP_THRESH_EXCITE    : begin ack <= 1'b1;  rdata <= {{32-12{1'b0}}, arp_thresh_excite        }; end
        `OFFSET_ARP_THRESH_RELAX     : begin ack <= 1'b1;  rdata <= {{32-12{1'b0}}, arp_thresh_relax         }; end
        `OFFSET_ARP_LATENCY          : begin ack <= 1'b1;  rdata <= {               arp_latency              }; end
        `OFFSET_ARP_COUNT            : begin ack <= 1'b1;  rdata <= {               arp_count                }; end
        `OFFSET_ARP_CLOCK_LOW        : begin ack <= 1'b1;  rdata <= {               arp_clock[32-1:0]        }; end
        `OFFSET_ARP_CLOCK_HIGH       : begin ack <= 1'b1;  rdata <= {               arp_clock[64-1:32]       }; end
        `OFFSET_ARP_PREV_CLOCK_LOW   : begin ack <= 1'b1;  rdata <= {               arp_prev_clock[32-1:0]   }; end
        `OFFSET_ARP_PREV_CLOCK_HIGH  : begin ack <= 1'b1;  rdata <= {               arp_prev_clock[64-1:32]  }; end
        `OFFSET_CLOCKS_LOW           : begin ack <= 1'b1;  rdata <= {               clock_counter[32-1:  0]  }; end
        `OFFSET_CLOCKS_HIGH          : begin ack <= 1'b1;  rdata <= {               clock_counter[63-1: 32]  }; end
        `OFFSET_ACP_PER_ARP          : begin ack <= 1'b1;  rdata <= {               acp_per_arp              }; end
        `OFFSET_ACP_AT_ARP           : begin ack <= 1'b1;  rdata <= {               acp_at_arp               }; end
        `OFFSET_TRIG_AT_ARP          : begin ack <= 1'b1;  rdata <= {               trig_at_arp              }; end
        `OFFSET_ACP_RAW              : begin ack <= 1'b1;  rdata <= {{32-12{1'b0}}, xadc_a_i                 }; end
        `OFFSET_ARP_RAW              : begin ack <= 1'b1;  rdata <= {{32-12{1'b0}}, xadc_b_i                 }; end
        `OFFSET_TRIG_THRESH_EXCITE   : begin ack <= 1'b1;  rdata <= {{32-12{1'b0}}, trig_thresh_excite       }; end
        `OFFSET_TRIG_THRESH_RELAX    : begin ack <= 1'b1;  rdata <= {{32-12{1'b0}}, trig_thresh_relax        }; end
        `OFFSET_TRIG_DELAY           : begin ack <= 1'b1;  rdata <= {               trig_delay               }; end
        `OFFSET_TRIG_LATENCY         : begin ack <= 1'b1;  rdata <= {               trig_latency             }; end
        `OFFSET_TRIG_COUNT           : begin ack <= 1'b1;  rdata <= {               trig_count               }; end
        `OFFSET_TRIG_CLOCK_LOW       : begin ack <= 1'b1;  rdata <= {               trig_clock[32-1:0]       }; end
        `OFFSET_TRIG_CLOCK_HIGH      : begin ack <= 1'b1;  rdata <= {               trig_clock[64-1:32]      }; end
        `OFFSET_TRIG_PREV_CLOCK_LOW  : begin ack <= 1'b1;  rdata <= {               trig_prev_clock[32-1:0]  }; end
        `OFFSET_TRIG_PREV_CLOCK_HIGH : begin ack <= 1'b1;  rdata <= {               trig_prev_clock[64-1:32] }; end

        `OFFSET_SAVED_ACP_COUNT            : begin ack <= 1'b1;  rdata <= { saved_acp_count                }; end
        `OFFSET_SAVED_ACP_CLOCK_LOW        : begin ack <= 1'b1;  rdata <= { saved_acp_clock[32-1:0]        }; end
        `OFFSET_SAVED_ACP_CLOCK_HIGH       : begin ack <= 1'b1;  rdata <= { saved_acp_clock[64-1:32]       }; end
        `OFFSET_SAVED_ACP_PREV_CLOCK_LOW   : begin ack <= 1'b1;  rdata <= { saved_acp_prev_clock[32-1:0]   }; end
        `OFFSET_SAVED_ACP_PREV_CLOCK_HIGH  : begin ack <= 1'b1;  rdata <= { saved_acp_prev_clock[64-1:32]  }; end
        `OFFSET_SAVED_ARP_COUNT            : begin ack <= 1'b1;  rdata <= { saved_arp_count                }; end
        `OFFSET_SAVED_ARP_CLOCK_LOW        : begin ack <= 1'b1;  rdata <= { saved_arp_clock[32-1:0]        }; end
        `OFFSET_SAVED_ARP_CLOCK_HIGH       : begin ack <= 1'b1;  rdata <= { saved_arp_clock[64-1:32]       }; end
        `OFFSET_SAVED_ARP_PREV_CLOCK_LOW   : begin ack <= 1'b1;  rdata <= { saved_arp_prev_clock[32-1:0]   }; end
        `OFFSET_SAVED_ARP_PREV_CLOCK_HIGH  : begin ack <= 1'b1;  rdata <= { saved_arp_prev_clock[64-1:32]  }; end
        `OFFSET_SAVED_ACP_PER_ARP          : begin ack <= 1'b1;  rdata <= { saved_acp_per_arp              }; end
        `OFFSET_SAVED_ACP_AT_ARP           : begin ack <= 1'b1;  rdata <= { saved_acp_at_arp               }; end
        `OFFSET_SAVED_TRIG_AT_ARP          : begin ack <= 1'b1;  rdata <= { saved_trig_at_arp              }; end
        `OFFSET_SAVED_TRIG_COUNT           : begin ack <= 1'b1;  rdata <= { saved_trig_count               }; end
        `OFFSET_SAVED_TRIG_CLOCK_LOW       : begin ack <= 1'b1;  rdata <= { saved_trig_clock[32-1:0]       }; end
        `OFFSET_SAVED_TRIG_CLOCK_HIGH      : begin ack <= 1'b1;  rdata <= { saved_trig_clock[64-1:32]      }; end
        `OFFSET_SAVED_TRIG_PREV_CLOCK_LOW  : begin ack <= 1'b1;  rdata <= { saved_trig_prev_clock[32-1:0]  }; end
        `OFFSET_SAVED_TRIG_PREV_CLOCK_HIGH : begin ack <= 1'b1;  rdata <= { saved_trig_prev_clock[64-1:32] }; end

        default                     : begin ack <= 1'b1;  rdata <= 32'h0                                    ; end
      endcase
   end

   bus_clk_bridge i_bridge
     (
      .sys_clk_i     (  sys_clk_i      ),
      .sys_rstn_i    (  sys_rstn_i     ),
      .sys_addr_i    (  sys_addr_i     ),
      .sys_wdata_i   (  sys_wdata_i    ),
      .sys_sel_i     (  sys_sel_i      ),
      .sys_wen_i     (  sys_wen_i      ),
      .sys_ren_i     (  sys_ren_i      ),
      .sys_rdata_o   (  sys_rdata_o    ),
      .sys_err_o     (  sys_err_o      ),
      .sys_ack_o     (  sys_ack_o      ),

      .clk_i         (  adc_clk_i      ),
      .rstn_i        (  adc_rstn_i     ),
      .addr_o        (  addr           ),
      .wdata_o       (  wdata          ),
      .wen_o         (  wen            ),
      .ren_o         (  ren            ),
      .rdata_i       (  rdata          ),
      .err_i         (  err            ),
      .ack_i         (  ack            )
      );

endmodule // red_pitaya_digdar
