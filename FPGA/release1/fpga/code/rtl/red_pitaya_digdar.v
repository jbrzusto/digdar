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

module red_pitaya_digdar
(
   input                 clk_i,       //!< clock
   input                 rstn_i ,      //!< reset - active low

                                       // Slow ADC
   input [ 12-1: 0]      xadc_a_i,     //!< most recent value from slow ADC channel A
   input [ 12-1: 0]      xadc_b_i,     //!< most recent value from slow ADC channel B

                                       // system bus
   input                 sys_clk_i ,   //!< bus clock
   input                 sys_rstn_i ,  //!< bus reset - active low
   input [ 32-1: 0]      sys_addr_i ,  //!< bus address
   input [ 32-1: 0]      sys_wdata_i , //!< bus write data
   input [ 4-1: 0]       sys_sel_i ,   //!< bus write byte select
   input                 sys_wen_i ,   //!< bus write enable
   input                 sys_ren_i ,   //!< bus read enable
   output reg [ 32-1: 0] sys_rdata_o , //!< bus read data
   output reg            sys_err_o ,   //!< bus error indicator
   output reg            sys_ack_o     //!< bus acknowledge signal

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
reg  [64-1: 0] clocks             ;
reg  [32-1: 0] acp_per_arp        ;
reg  [32-1: 0] prev_acp_count     ;
    

   wire       acp_trigger;
   wire       arp_trigger;


   red_pitaya_trigger_gen #( .width(12),
                             .counter_width(32),
                             .do_smoothing(0)
                             ) trigger_gen_acp  // not really a trigger; we're just counting these pulses
     (
      .clock(clk_i), 
      .reset(rstn_i),
      .enable(1'b1),
      .signal(xadc_a_i), 
      .thresh_excite(acp_thresh_excite),
      .thresh_relax(acp_thresh_relax),
      .delay(0), 
      .latency(acp_latency),
      .trigger(acp_trigger),
      .counter(acp_count)
      );
   
   red_pitaya_trigger_gen #( .width(12),
                             .counter_width(32),
                             .do_smoothing(0)
                             ) trigger_gen_arp  // not really a trigger; we're just counting these pulses
     (
      .clock(clk_i), 
      .reset(rstn_i),
      .enable(1'b1),
      .signal(xadc_a_i), 
      .thresh_excite(arp_thresh_excite),
      .thresh_relax(arp_thresh_relax),
      .delay(0), 
      .latency(arp_latency),
      .trigger(arp_trigger),
      .counter(arp_count)
      );
   

always @(posedge sys_clk_i) begin
   if (sys_rstn_i != 1'b1) begin
      // Not reset, so check for acp and arp pulses and record time,
      // keeping previous time
      if (acp_trigger) begin
         acp_clock           <= #1 clocks;
         acp_prev_clock      <= #1 acp_clock;
      end
      if (arp_trigger) begin
         arp_clock           <= #1 clocks;
         arp_prev_clock      <= #1 arp_clock;
         acp_per_arp         <= #1 acp_count - prev_acp_count;
         prev_acp_count      <= #1 acp_count;         
      end
   end
end
      
   
//---------------------------------------------------------------------------------
//
//  system bus connection

   
always @(posedge sys_clk_i) begin
   if (sys_rstn_i == 1'b0) begin

      clocks              <= 64'h0;

      acp_clock           <= 64'h0;
      acp_prev_clock      <= 64'h0;

      arp_clock           <= 64'h0;
      arp_prev_clock      <= 64'h0;

      acp_per_arp         <= 32'h0;
      prev_acp_count      <= 32'h0;
            
   end
   else begin
      if (sys_wen_i) begin
         casez (sys_addr_i[19:0])
           `OFFSET_ACP_THRESH_EXCITE   : acp_thresh_excite   <= sys_wdata_i[ 12-1: 0];
           `OFFSET_ACP_THRESH_RELAX    : acp_thresh_relax    <= sys_wdata_i[ 12-1: 0];
           `OFFSET_ACP_DIRECTION       : acp_direction       <= sys_wdata_i[  2-1: 0];
           `OFFSET_ACP_LATENCY         : acp_latency         <= sys_wdata_i[ 32-1: 0];
           `OFFSET_ARP_THRESH_EXCITE   : arp_thresh_excite   <= sys_wdata_i[ 12-1: 0];
           `OFFSET_ARP_THRESH_RELAX    : arp_thresh_relax    <= sys_wdata_i[ 12-1: 0];
           `OFFSET_ARP_DIRECTION       : arp_direction       <= sys_wdata_i[  2-1: 0];
           `OFFSET_ARP_LATENCY         : arp_latency         <= sys_wdata_i[ 32-1: 0];
         endcase
      end
   end
end

wire ack = sys_wen_i || sys_ren_i ;

always @(posedge sys_clk_i) begin
   sys_err_o <= 1'b0 ;

   casez (sys_addr_i[19:0])
     `OFFSET_ACP_THRESH_EXCITE   : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-12{1'b0}}, acp_thresh_excite       }; end
     `OFFSET_ACP_THRESH_RELAX    : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-12{1'b0}}, acp_thresh_relax        }; end
     `OFFSET_ACP_DIRECTION       : begin sys_ack_o <= ack;  sys_rdata_o <= {{32- 2{1'b0}}, acp_direction           }; end
     `OFFSET_ACP_LATENCY         : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-32{1'b0}}, acp_latency             }; end
     `OFFSET_ACP_COUNT           : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-32{1'b0}}, acp_count               }; end
     `OFFSET_ACP_CLOCK_LOW       : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-32{1'b0}}, acp_clock[32-1:0]   }; end
     `OFFSET_ACP_CLOCK_HIGH      : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-32{1'b0}}, acp_clock[64-1:32] }; end
     `OFFSET_ACP_PREV_CLOCK_LOW  : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-32{1'b0}}, acp_prev_clock[32-1:0]  }; end
     `OFFSET_ACP_PREV_CLOCK_HIGH : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-32{1'b0}}, acp_prev_clock[64-1:32] }; end
     `OFFSET_ARP_THRESH_EXCITE   : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-12{1'b0}}, arp_thresh_excite       }; end
     `OFFSET_ARP_THRESH_RELAX    : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-12{1'b0}}, arp_thresh_relax        }; end
     `OFFSET_ARP_DIRECTION       : begin sys_ack_o <= ack;  sys_rdata_o <= {{32- 2{1'b0}}, arp_direction           }; end
     `OFFSET_ARP_LATENCY         : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-32{1'b0}}, arp_latency             }; end
     `OFFSET_ARP_COUNT           : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-32{1'b0}}, arp_count               }; end
     `OFFSET_ARP_CLOCK_LOW       : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-32{1'b0}}, arp_clock[32-1:0]   }; end
     `OFFSET_ARP_CLOCK_HIGH      : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-32{1'b0}}, arp_clock[64-1:32] }; end
     `OFFSET_ARP_PREV_CLOCK_LOW  : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-32{1'b0}}, arp_prev_clock[32-1:0]  }; end
     `OFFSET_ARP_PREV_CLOCK_HIGH : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-32{1'b0}}, arp_prev_clock[64-1:32] }; end
     `OFFSET_CLOCKS_LOW          : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-32{1'b0}}, clocks[32-1:  0]        }; end
     `OFFSET_CLOCKS_HIGH         : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-32{1'b0}}, clocks[63-1: 32]        }; end
     `OFFSET_ACP_PER_ARP         : begin sys_ack_o <= ack;  sys_rdata_o <= {{32-32{1'b0}}, acp_per_arp             }; end
     
     default                     : begin sys_ack_o <= 1'b1; sys_rdata_o <= 32'h0                                    ; end
   endcase
end

endmodule // red_pitaya_digdar

    
