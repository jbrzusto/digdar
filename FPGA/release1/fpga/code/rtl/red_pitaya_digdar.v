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

`define OFFSET_ACP_THRESH_EXCITE   20'h00000 // ACP thresh_excite - excitation threshold for ACP pulse (12 bits)
`define OFFSET_ACP_THRESH_RELAX    20'h00004 // ACP thresh_relax  - relaxation threshold for ACP pulse (12 bits)
`define OFFSET_ACP_DIRECTION       20'h00008 // ACP direction - which directions are detected; 2 bits:
                                             //   bit 0: if true, detect on crossing thresh_excite away from thresh_relax
                                             //   bit 1: if true, detect on crossing thresh_relax away from thresh_excite
                                             //   (both bits can be true)
`define OFFSET_ACP_LATENCY         20'h0000C // ACP latency - countdown of clocks after detection before next detection 
                                             // is permitted (helps debounce)
`define OFFSET_ACP_COUNT           20'h00010 // ACP count since reset (32 bits; wraps)
`define OFFSET_ACP_CLOCK_LOW       20'h00014 // clock at most recent ACP (low 32 bits)
`define OFFSET_ACP_CLOCK_HIGH      20'h00018 // clock at most recent ACP (high 32 bits)
`define OFFSET_ACP_PREV_CLOCK_LOW  20'h0001C // clock at previous ACP (low 32 bits)
`define OFFSET_ACP_PREV_CLOCK_HIGH 20'h00020 // clock at previous ACP (high 32 bits)

`define OFFSET_ARP_THRESH_EXCITE   20'h00100 // ARP thresh_excite - excitation threshold for ARP pulse (12 bits)
`define OFFSET_ARP_THRESH_RELAX    20'h00104 // ARP thresh_relax  - relaxation threshold for ARP pulse (12 bits)
`define OFFSET_ARP_DIRECTION       20'h00108 // ARP direction - which directions are detected; 2 bits:
                                             //   bit 0: if true, detect on crossing thresh_excite away from thresh_relax
                                             //   bit 1: if true, detect on crossing thresh_relax away from thresh_excite
                                             //   (both bits can be true)
`define OFFSET_ARP_LATENCY         20'h0010C // ARP latency - countdown of clocks after detection before next detection 
                                             // is permitted (helps debounce)
`define OFFSET_ARP_COUNT           20'h00110 // ARP count since reset (32 bits; wraps)
`define OFFSET_ARP_CLOCK_LOW       20'h00114 // clock at most recent ARP (low 32 bits)
`define OFFSET_ARP_CLOCK_HIGH      20'h00118 // clock at most recent ARP (high 32 bits)
`define OFFSET_ARP_PREV_CLOCK_LOW  20'h0011C // clock at previous ARP (low 32 bits)
`define OFFSET_ARP_PREV_CLOCK_HIGH 20'h00120 // clock at previous ARP (high 32 bits)

`define OFFSET_CLOCKS_LOW          20'h00200 // clock counter since reset (low 32 bits)
`define OFFSET_CLOCKS_HIGH         20'h00204 // clock counter since reset (high 32 bits)

`define OFFSET_ACP_PER_ARP         20'h00208 // count of ACP pulses between two most recent ARP pulses

`define OFFSET_ACP_RAW             20'h0020C // most recent slow ADC value from ACP
`define OFFSET_ARP_RAW             20'h00210 // most recent slow ADC value from ARP

module red_pitaya_digdar
(
   input                 adc_clk_i, //!< clock
   input                 adc_rstn_i, //!< ADC reset - active low
                                       // Slow ADC
   input [ 12-1: 0]      xadc_a_i, //!< most recent value from slow ADC channel A
   input [ 12-1: 0]      xadc_b_i, //!< most recent value from slow ADC channel B

                                       // system bus
   input                 sys_clk_i , //!< bus clock
   input                 sys_rstn_i , //!< bus reset - active low
   input [ 32-1: 0]      sys_addr_i , //!< bus address
   input [ 32-1: 0]      sys_wdata_i , //!< bus write data
   input [ 4-1: 0]       sys_sel_i , //!< bus write byte select
   input                 sys_wen_i , //!< bus write enable
   input                 sys_ren_i , //!< bus read enable
   output     [ 32-1: 0] sys_rdata_o , //!< bus read data
   output                sys_err_o , //!< bus error indicator
   output                sys_ack_o     //!< bus acknowledge signal

);

reg  [12-1: 0] acp_thresh_excite  ;
reg  [12-1: 0] acp_thresh_relax   ;
reg  [ 2-1: 0] acp_direction      ;
reg  [32-1: 0] acp_latency        ;
wire [32-1: 0] acp_count          ;
reg  [64-1: 0] acp_clock          ;
reg  [64-1: 0] acp_prev_clock     ;
reg  [12-1: 0] arp_thresh_excite  ;
reg  [12-1: 0] arp_thresh_relax   ;
reg  [ 2-1: 0] arp_direction      ;
reg  [32-1: 0] arp_latency        ;
wire [32-1: 0] arp_count          ;
reg  [64-1: 0] arp_clock          ;
reg  [64-1: 0] arp_prev_clock     ;
reg  [64-1: 0] clock_counter      ;
reg  [32-1: 0] acp_per_arp        ;
reg  [32-1: 0] prev_acp_count     ;
    

   wire       acp_trigger;
   wire       arp_trigger;


   trigger_gen #( .width(12),
                             .counter_width(32),
                             .do_smoothing(1)
                             ) trigger_gen_acp  // not really a trigger; we're just counting these pulses
     (
      .clock(adc_clk_i), 
      .reset(! adc_rstn_i),  // active low
      .enable(1'b1),
      .signal_in(xadc_a_i), // signed
      .thresh_excite(acp_thresh_excite), // signed
      .thresh_relax(acp_thresh_relax), //signed
      .delay(0), 
      .latency(acp_latency),
      .trigger(acp_trigger),
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
      .signal_in(xadc_b_i), // signed
      .thresh_excite(arp_thresh_excite), // signed
      .thresh_relax(arp_thresh_relax), // signed
      .delay(0), 
      .latency(arp_latency),
      .trigger(arp_trigger),
      .counter(arp_count)
      );
   

   
//---------------------------------------------------------------------------------
//
//  system bus connection

// bridge between ADC and sys clock

   //bus bridging components
wire [ 32-1: 0] addr         ;
wire [ 32-1: 0] wdata        ;
wire            wen          ;
wire            ren          ;
reg  [ 32-1: 0] rdata        ;
reg             err          ;
reg             ack          ;
   

   always @(posedge adc_clk_i) begin
   if (adc_rstn_i == 1'b0) begin
      clock_counter              <= 64'h0;

      acp_clock           <= 64'h0;
      acp_prev_clock      <= 64'h0;

      arp_clock           <= 64'h0;
      arp_prev_clock      <= 64'h0;

      acp_per_arp         <= 32'h0;
      prev_acp_count      <= 32'h0;

   end // if (adc_rstn_i == 1'b0)
   else begin
      if (wen) begin
         casez (addr[19:0])
           `OFFSET_ACP_THRESH_EXCITE   : acp_thresh_excite   <= wdata[ 12-1: 0];
           `OFFSET_ACP_THRESH_RELAX    : acp_thresh_relax    <= wdata[ 12-1: 0];
           `OFFSET_ACP_DIRECTION       : acp_direction       <= wdata[  2-1: 0];
           `OFFSET_ACP_LATENCY         : acp_latency         <= wdata[ 32-1: 0];
           `OFFSET_ARP_THRESH_EXCITE   : arp_thresh_excite   <= wdata[ 12-1: 0];
           `OFFSET_ARP_THRESH_RELAX    : arp_thresh_relax    <= wdata[ 12-1: 0];
           `OFFSET_ARP_DIRECTION       : arp_direction       <= wdata[  2-1: 0];
           `OFFSET_ARP_LATENCY         : arp_latency         <= wdata[ 32-1: 0];
         endcase
      end // if (wen)
      
      // Not reset, so check for acp and arp pulses and record time,
      // keeping previous time
      clock_counter <= clock_counter + 64'b1; // use #1 ?
      
      if (acp_trigger) begin
         acp_clock           <= clock_counter;  // use #1?
         acp_prev_clock      <= acp_clock;   // use #1?
      end
      if (arp_trigger) begin
         arp_clock           <= clock_counter;  // use #1?
         arp_prev_clock      <= arp_clock;  // use #1?
         acp_per_arp         <= acp_count - prev_acp_count;  // use #1?
         prev_acp_count      <= acp_count;           // use #1?
      end

   end // else: !if(adc_rstn_i == 1'b0)
end
   
always @(*) begin
   err <= 1'b0 ;

   casez (addr[19:0])
     `OFFSET_ACP_THRESH_EXCITE   : begin ack <= 1'b1;  rdata <= {{32-12{1'b0}}, acp_thresh_excite       }; end
     `OFFSET_ACP_THRESH_RELAX    : begin ack <= 1'b1;  rdata <= {{32-12{1'b0}}, acp_thresh_relax        }; end
     `OFFSET_ACP_DIRECTION       : begin ack <= 1'b1;  rdata <= {{32- 2{1'b0}}, acp_direction           }; end
     `OFFSET_ACP_LATENCY         : begin ack <= 1'b1;  rdata <= {{32-32{1'b0}}, acp_latency             }; end
     `OFFSET_ACP_COUNT           : begin ack <= 1'b1;  rdata <= {{32-32{1'b0}}, acp_count               }; end
     `OFFSET_ACP_CLOCK_LOW       : begin ack <= 1'b1;  rdata <= {{32-32{1'b0}}, acp_clock[32-1:0]   }; end
     `OFFSET_ACP_CLOCK_HIGH      : begin ack <= 1'b1;  rdata <= {{32-32{1'b0}}, acp_clock[64-1:32] }; end
     `OFFSET_ACP_PREV_CLOCK_LOW  : begin ack <= 1'b1;  rdata <= {{32-32{1'b0}}, acp_prev_clock[32-1:0]  }; end
     `OFFSET_ACP_PREV_CLOCK_HIGH : begin ack <= 1'b1;  rdata <= {{32-32{1'b0}}, acp_prev_clock[64-1:32] }; end
     `OFFSET_ARP_THRESH_EXCITE   : begin ack <= 1'b1;  rdata <= {{32-12{1'b0}}, arp_thresh_excite       }; end
     `OFFSET_ARP_THRESH_RELAX    : begin ack <= 1'b1;  rdata <= {{32-12{1'b0}}, arp_thresh_relax        }; end
     `OFFSET_ARP_DIRECTION       : begin ack <= 1'b1;  rdata <= {{32- 2{1'b0}}, arp_direction           }; end
     `OFFSET_ARP_LATENCY         : begin ack <= 1'b1;  rdata <= {{32-32{1'b0}}, arp_latency             }; end
     `OFFSET_ARP_COUNT           : begin ack <= 1'b1;  rdata <= {{32-32{1'b0}}, arp_count               }; end
     `OFFSET_ARP_CLOCK_LOW       : begin ack <= 1'b1;  rdata <= {{32-32{1'b0}}, arp_clock[32-1:0]       }; end
     `OFFSET_ARP_CLOCK_HIGH      : begin ack <= 1'b1;  rdata <= {{32-32{1'b0}}, arp_clock[64-1:32]      }; end
     `OFFSET_ARP_PREV_CLOCK_LOW  : begin ack <= 1'b1;  rdata <= {{32-32{1'b0}}, arp_prev_clock[32-1:0]  }; end
     `OFFSET_ARP_PREV_CLOCK_HIGH : begin ack <= 1'b1;  rdata <= {{32-32{1'b0}}, arp_prev_clock[64-1:32] }; end
     `OFFSET_CLOCKS_LOW          : begin ack <= 1'b1;  rdata <= {{32-32{1'b0}}, clock_counter[32-1:  0] }; end
     `OFFSET_CLOCKS_HIGH         : begin ack <= 1'b1;  rdata <= {{32-32{1'b0}}, clock_counter[63-1: 32] }; end
     `OFFSET_ACP_PER_ARP         : begin ack <= 1'b1;  rdata <= {{32-32{1'b0}}, acp_per_arp             }; end
     `OFFSET_ACP_RAW             : begin ack <= 1'b1;  rdata <= {{32-12{1'b0}}, xadc_a_i                }; end
     `OFFSET_ARP_RAW             : begin ack <= 1'b1;  rdata <= {{32-12{1'b0}}, xadc_b_i                }; end
     
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
