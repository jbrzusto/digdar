/**
 * @brief Red Pitaya analog module. Connects to ADC.
 *
 * @Author Matej Oblak
 * @Author John Brzustowski
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 * (c) John Brzustowski
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */


/**
 * GENERAL DESCRIPTION:
 *
 * Interace module between fast ADC and DAC IC.
 *
 *                 /------------\
 *   ADC DAT ----> | RAW -> 2's | ----> ADC DATA TO USER
 *                 \------------/
 *                       ^
 *                       |
 *                    /-----\
 *   ADC CLK -------> | PLL |
 *                    \-----/
 *
 * ADC clock is used for main clock domain.
 *
 * ADC channel A (video): ADC returns values on a linear 0...3fff scale.  User can choose to invert
 * this, but 0x1 is always returned instead of 0x0, reserving the latter as a sentinel value.
 *
 * ADC channel B (trigger): ADC returns values on a linear 0...3fff scale.  This is inverted and
 * converted to twos complement before returning.
 *
 * This module introduces a delay of 1 ADC clock.
 *
 */

module red_pitaya_analog
  (
   // ADC IC
   input [ 16-1: 2]  adc_dat_a_i , //!< ADC IC CHA data connection
   input [ 16-1: 2]  adc_dat_b_i , //!< ADC IC CHB data connection
   input             adc_clk_p_i , //!< ADC IC clock P connection
   input             adc_clk_n_i , //!< ADC IC clock N connection
   input             adc_neg_a_i , //!< negate slope of ADC CHA?

   // user interface
   output [ 14-1: 0] adc_dat_a_o , //!< ADC CHA data (linear; optionally inverted; never 0)
   output [ 14-1: 0] adc_dat_b_o , //!< ADC CHB data (twos complement; always inverted)
   output            adc_clk_o , //!< ADC clock
   input             adc_rst_i , //!< ADC reset - active low
   output            ser_clk_o   //!< fast serial clock

   );

   //---------------------------------------------------------------------------------
   //
   //  ADC input registers

   reg [14-1: 0]     adc_dat_a  ;
   reg [14-1: 0]     adc_dat_b  ;
   wire              adc_clk_in ;
   wire              adc_clk    ;

   IBUFDS i_clk ( .I(adc_clk_p_i), .IB(adc_clk_n_i), .O(adc_clk_in));  // differential clock input
   BUFG i_adc_buf  (.O(adc_clk), .I(adc_clk_in)); // use global clock buffer

   always @(posedge adc_clk) begin
      // convert video to 2s complement and optionally invert
      adc_dat_a <= adc_neg_a_i ? {adc_dat_a_i[16-1], ~adc_dat_a_i[16-2:2]} : {~adc_dat_a_i[16-1], adc_dat_a_i[16-2:2]};
      // convert trigger to 2s complement
      adc_dat_b <= {adc_dat_b_i[16-1], ~adc_dat_b_i[16-2:2]};
   end

   assign adc_dat_a_o =  adc_dat_a == 14'h0 ? 14'h1 : adc_dat_a ;  // convert to 1 if zero
   assign adc_dat_b_o =  adc_dat_b ;
   assign adc_clk_o   =  adc_clk ;

endmodule
