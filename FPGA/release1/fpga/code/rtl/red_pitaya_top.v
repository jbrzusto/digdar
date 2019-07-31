/**
 * $Id: red_pitaya_top.v 1271 2014-02-25 12:32:34Z matej.oblak $
 *
 * @brief Red Pitaya TOP module. It connects external pins and PS part with
 *        other application modules.
 *
 * @Author Matej Oblak
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */



/**
 * GENERAL DESCRIPTION:
 *
 * Top module connects the Processing System with the FPGA
 *
 *
 *
 *                   /-------\
 *   PS DDR <------> |  PS   |      AXI <-> custom bus
 *   PS MIO <------> |   /   | <------------+
 *   PS CLK -------> |  ARM  |              |
 *                   \-------/              |
 *                                          |
 *                                          |
 *                                          |
 *            /--------\      /--------\    |
 *            |        | ---> |        |    |
 *   ADC ---> | ANALOG |      | DIGDAR | <--+
 *            |        | <--- |        |
 *            \--------/      \--------/
 *
 *
 *
 * Inside the analog module, ADC data is translated from unsigned into
 * two's complement, optionally negated.
 *
 * The digdar module stores data from ADC into RAM.
 *
 */


module red_pitaya_top
  (
   // PS connections
`ifdef TOOL_AHEAD
   inout  [54-1: 0] processing_system7_0_MIO,
   input            processing_system7_0_PS_SRSTB_pin,
   input            processing_system7_0_PS_CLK_pin,
   input            processing_system7_0_PS_PORB_pin,
   inout            processing_system7_0_DDR_Clk,
   inout            processing_system7_0_DDR_Clk_n,
   inout            processing_system7_0_DDR_CKE,
   inout            processing_system7_0_DDR_CS_n,
   inout            processing_system7_0_DDR_RAS_n,
   inout            processing_system7_0_DDR_CAS_n,
   output           processing_system7_0_DDR_WEB_pin,
   inout  [ 3-1: 0] processing_system7_0_DDR_BankAddr,
   inout  [15-1: 0] processing_system7_0_DDR_Addr,
   inout            processing_system7_0_DDR_ODT,
   inout            processing_system7_0_DDR_DRSTB,
   inout  [32-1: 0] processing_system7_0_DDR_DQ,
   inout  [ 4-1: 0] processing_system7_0_DDR_DM,
   inout  [ 4-1: 0] processing_system7_0_DDR_DQS,
   inout  [ 4-1: 0] processing_system7_0_DDR_DQS_n,
   inout            processing_system7_0_DDR_VRN,
   inout            processing_system7_0_DDR_VRP,
`endif
`ifdef TOOL_VIVADO
   inout  [54-1: 0] FIXED_IO_mio       ,
   inout            FIXED_IO_ps_clk    ,
   inout            FIXED_IO_ps_porb   ,
   inout            FIXED_IO_ps_srstb  ,
   inout            FIXED_IO_ddr_vrn   ,
   inout            FIXED_IO_ddr_vrp   ,
   inout  [15-1: 0] DDR_addr           ,
   inout  [ 3-1: 0] DDR_ba             ,
   inout            DDR_cas_n          ,
   inout            DDR_ck_n           ,
   inout            DDR_ck_p           ,
   inout            DDR_cke            ,
   inout            DDR_cs_n           ,
   inout  [ 4-1: 0] DDR_dm             ,
   inout  [32-1: 0] DDR_dq             ,
   inout  [ 4-1: 0] DDR_dqs_n          ,
   inout  [ 4-1: 0] DDR_dqs_p          ,
   inout            DDR_odt            ,
   inout            DDR_ras_n          ,
   inout            DDR_reset_n        ,
   inout            DDR_we_n           ,
`endif

   // Red Pitaya periphery

   // ADC
   input  [16-1: 2] adc_dat_a_i        ,  // ADC CH1
   input  [16-1: 2] adc_dat_b_i        ,  // ADC CH2
   input            adc_clk_p_i        ,  // ADC data clock
   input            adc_clk_n_i        ,  // ADC data clock
   output [ 2-1: 0] adc_clk_o          ,  // optional ADC clock source
   output           adc_cdcs_o         ,  // ADC clock duty cycle stabilizer

   // XADC
   input  [ 5-1: 0] vinp_i             ,  // voltages p
   input  [ 5-1: 0] vinn_i             ,  // voltages n

   // Expansion connector
   inout  [ 8-1: 0] exp_p_io           ,
   inout  [ 8-1: 0] exp_n_io           ,


   // LED
   output [ 8-1: 0] led_o

   );






   //---------------------------------------------------------------------------------
   //
   //  Connections to PS

   wire [  4-1: 0]  fclk               ; //[0]-125MHz, [1]-250MHz, [2]-50MHz, [3]-200MHz
   wire [  4-1: 0]  frstn              ;

   wire             ps_sys_clk         ;
   wire             ps_sys_rstn        ;
   wire [ 32-1: 0]  ps_sys_addr        ;
   wire [ 32-1: 0]  ps_sys_wdata       ;
   wire [  4-1: 0]  ps_sys_sel         ;
   wire             ps_sys_wen         ;
   wire             ps_sys_ren         ;
   wire [ 32-1: 0]  ps_sys_rdata       ;
   wire             ps_sys_err         ;
   wire             ps_sys_ack         ;


   red_pitaya_ps i_ps
     (
`ifdef TOOL_AHEAD
      .processing_system7_0_MIO          (  processing_system7_0_MIO            ),
      .processing_system7_0_PS_SRSTB_pin (  processing_system7_0_PS_SRSTB_pin   ),
      .processing_system7_0_PS_CLK_pin   (  processing_system7_0_PS_CLK_pin     ),
      .processing_system7_0_PS_PORB_pin  (  processing_system7_0_PS_PORB_pin    ),
      .processing_system7_0_DDR_Clk      (  processing_system7_0_DDR_Clk        ),
      .processing_system7_0_DDR_Clk_n    (  processing_system7_0_DDR_Clk_n      ),
      .processing_system7_0_DDR_CKE      (  processing_system7_0_DDR_CKE        ),
      .processing_system7_0_DDR_CS_n     (  processing_system7_0_DDR_CS_n       ),
      .processing_system7_0_DDR_RAS_n    (  processing_system7_0_DDR_RAS_n      ),
      .processing_system7_0_DDR_CAS_n    (  processing_system7_0_DDR_CAS_n      ),
      .processing_system7_0_DDR_WEB_pin  (  processing_system7_0_DDR_WEB_pin    ),
      .processing_system7_0_DDR_BankAddr (  processing_system7_0_DDR_BankAddr   ),
      .processing_system7_0_DDR_Addr     (  processing_system7_0_DDR_Addr       ),
      .processing_system7_0_DDR_ODT      (  processing_system7_0_DDR_ODT        ),
      .processing_system7_0_DDR_DRSTB    (  processing_system7_0_DDR_DRSTB      ),
      .processing_system7_0_DDR_DQ       (  processing_system7_0_DDR_DQ         ),
      .processing_system7_0_DDR_DM       (  processing_system7_0_DDR_DM         ),
      .processing_system7_0_DDR_DQS      (  processing_system7_0_DDR_DQS        ),
      .processing_system7_0_DDR_DQS_n    (  processing_system7_0_DDR_DQS_n      ),
      .processing_system7_0_DDR_VRN      (  processing_system7_0_DDR_VRN        ),
      .processing_system7_0_DDR_VRP      (  processing_system7_0_DDR_VRP        ),
`endif
`ifdef TOOL_VIVADO
      .FIXED_IO_mio       (  FIXED_IO_mio                ),
      .FIXED_IO_ps_clk    (  FIXED_IO_ps_clk             ),
      .FIXED_IO_ps_porb   (  FIXED_IO_ps_porb            ),
      .FIXED_IO_ps_srstb  (  FIXED_IO_ps_srstb           ),
      .FIXED_IO_ddr_vrn   (  FIXED_IO_ddr_vrn            ),
      .FIXED_IO_ddr_vrp   (  FIXED_IO_ddr_vrp            ),
      .DDR_addr           (  DDR_addr                    ),
      .DDR_ba             (  DDR_ba                      ),
      .DDR_cas_n          (  DDR_cas_n                   ),
      .DDR_ck_n           (  DDR_ck_n                    ),
      .DDR_ck_p           (  DDR_ck_p                    ),
      .DDR_cke            (  DDR_cke                     ),
      .DDR_cs_n           (  DDR_cs_n                    ),
      .DDR_dm             (  DDR_dm                      ),
      .DDR_dq             (  DDR_dq                      ),
      .DDR_dqs_n          (  DDR_dqs_n                   ),
      .DDR_dqs_p          (  DDR_dqs_p                   ),
      .DDR_odt            (  DDR_odt                     ),
      .DDR_ras_n          (  DDR_ras_n                   ),
      .DDR_reset_n        (  DDR_reset_n                 ),
      .DDR_we_n           (  DDR_we_n                    ),
`endif

      .fclk_clk_o      (  fclk               ),
      .fclk_rstn_o     (  frstn              ),

      // system read/write channel
      .sys_clk_o       (  ps_sys_clk         ),  // system clock
      .sys_rstn_o      (  ps_sys_rstn        ),  // system reset - active low
      .sys_addr_o      (  ps_sys_addr        ),  // system read/write address
      .sys_wdata_o     (  ps_sys_wdata       ),  // system write data
      .sys_sel_o       (  ps_sys_sel         ),  // system write byte select
      .sys_wen_o       (  ps_sys_wen         ),  // system write enable
      .sys_ren_o       (  ps_sys_ren         ),  // system read enable
      .sys_rdata_i     (  ps_sys_rdata       ),  // system read data
      .sys_err_i       (  ps_sys_err         ),  // system error indicator
      .sys_ack_i       (  ps_sys_ack         ),  // system acknowledge signal

      // SPI master
      .spi_ss_o        (                     ),  // select slave 0
      .spi_ss1_o       (                     ),  // select slave 1
      .spi_ss2_o       (                     ),  // select slave 2
      .spi_sclk_o      (                     ),  // serial clock
      .spi_mosi_o      (                     ),  // master out slave in
      .spi_miso_i      (  1'b0               ),  // master in slave out

      // SPI slave
      .spi_ss_i        (  1'b1               ),  // slave selected
      .spi_sclk_i      (  1'b0               ),  // serial clock
      .spi_mosi_i      (  1'b0               ),  // master out slave in
      .spi_miso_o      (                     )   // master in slave out

      );








   //---------------------------------------------------------------------------------
   //
   //  Analog peripherials

   // ADC clock duty cycle stabilizer is enabled
   assign adc_cdcs_o = 1'b1 ;

   // generating ADC clock is disabled
   assign adc_clk_o = 2'b10;
   //ODDR i_adc_clk_p ( .Q(adc_clk_o[0]), .D1(1'b1), .D2(1'b0), .C(fclk[0]), .CE(1'b1), .R(1'b0), .S(1'b0));
   //ODDR i_adc_clk_n ( .Q(adc_clk_o[1]), .D1(1'b0), .D2(1'b1), .C(fclk[0]), .CE(1'b1), .R(1'b0), .S(1'b0));

   wire             ser_clk     ;
   wire             adc_clk     ;
   reg              adc_rstn    ;
   wire [ 14-1: 0]  adc_a       ;
   wire             adc_neg_a   ;

   wire [ 14-1: 0]  adc_b       ;

   wire [ 12-1: 0]  xadc_a      ;  // most recent value from slow ADCs
   wire [ 12-1: 0]  xadc_b      ;

   wire             xadc_a_strobe      ;  //asserted for 1 sys_clk when slow ADC values have been read
   wire             xadc_b_strobe      ;

   red_pitaya_analog i_analog
     (
      // ADC IC
      .adc_dat_a_i        (  adc_dat_a_i      ),  // CH 1
      .adc_dat_b_i        (  adc_dat_b_i      ),  // CH 2
      .adc_clk_p_i        (  adc_clk_p_i      ),  // data clock
      .adc_clk_n_i        (  adc_clk_n_i      ),  // data clock

      // user interface
      .adc_dat_a_o        (  adc_a            ),  // ADC CH1
      .adc_dat_b_o        (  adc_b            ),  // ADC CH2
      .adc_neg_a_i        (  adc_neg_a        ),  // negate ADC CH1?
      .adc_clk_o          (  adc_clk          ),  // ADC received clock
      .adc_rst_i          (  adc_rstn         ),  // reset - active low
      .ser_clk_o          (  ser_clk          )   // fast serial clock
      );

   always @(posedge adc_clk) begin
      adc_rstn <= frstn[0] ;
   end








   //---------------------------------------------------------------------------------
   //
   //  system bus decoder & multiplexer
   //  it breaks memory addresses into 8 regions

   wire                sys_clk    = ps_sys_clk      ;
   wire                sys_rstn   = ps_sys_rstn     ;
   wire [    32-1: 0]  sys_addr   = ps_sys_addr     ;
   wire [    32-1: 0]  sys_wdata  = ps_sys_wdata    ;
   wire [     4-1: 0]  sys_sel    = ps_sys_sel      ;
   wire [     8-1: 0]  sys_wen    ;
   wire [     8-1: 0]  sys_ren    ;
   wire [(8*32)-1: 0]  sys_rdata  ;
   wire [ (8*1)-1: 0]  sys_err    ;
   wire [ (8*1)-1: 0]  sys_ack    ;
   reg [     8-1: 0]   sys_cs     ;

   always @(sys_addr) begin
      sys_cs = 8'h0 ;
      case (sys_addr[22:20])
        3'h0, 3'h1, 3'h2, 3'h3, 3'h4, 3'h5, 3'h6, 3'h7 :
          sys_cs[sys_addr[22:20]] = 1'b1 ;
      endcase
   end

   assign sys_wen = sys_cs & {8{ps_sys_wen}}  ;
   assign sys_ren = sys_cs & {8{ps_sys_ren}}  ;


   assign ps_sys_rdata = {32{sys_cs[ 0]}} & sys_rdata[ 0*32+31: 0*32] |
                         {32{sys_cs[ 1]}} & sys_rdata[ 1*32+31: 1*32] |
                         {32{sys_cs[ 2]}} & sys_rdata[ 2*32+31: 2*32] |
                         {32{sys_cs[ 3]}} & sys_rdata[ 3*32+31: 3*32] |
                         {32{sys_cs[ 4]}} & sys_rdata[ 4*32+31: 4*32] |
                         {32{sys_cs[ 5]}} & sys_rdata[ 5*32+31: 5*32] |
                         {32{sys_cs[ 6]}} & sys_rdata[ 6*32+31: 6*32] |
                         {32{sys_cs[ 7]}} & sys_rdata[ 7*32+31: 7*32] ;

   assign ps_sys_err   = sys_cs[ 0] & sys_err[  0] |
                         sys_cs[ 1] & sys_err[  1] |
                         sys_cs[ 2] & sys_err[  2] |
                         sys_cs[ 3] & sys_err[  3] |
                         sys_cs[ 4] & sys_err[  4] |
                         sys_cs[ 5] & sys_err[  5] |
                         sys_cs[ 6] & sys_err[  6] |
                         sys_cs[ 7] & sys_err[  7] ;

   assign ps_sys_ack   = sys_cs[ 0] & sys_ack[  0] |
                         sys_cs[ 1] & sys_ack[  1] |
                         sys_cs[ 2] & sys_ack[  2] |
                         sys_cs[ 3] & sys_ack[  3] |
                         sys_cs[ 4] & sys_ack[  4] |
                         sys_cs[ 5] & sys_ack[  5] |
                         sys_cs[ 6] & sys_ack[  6] |
                         sys_cs[ 7] & sys_ack[  7] ;


   // assign sys_rdata[ 6*32+31: 6*32] = 32'h0;

   // assign sys_err[6] = {1{1'b0}} ;
   // assign sys_ack[6] = {1{1'b1}} ;








   //---------------------------------------------------------------------------------
   //
   //  House Keeping

   wire  [  8-1: 0] exp_p_in     ;
   wire [  8-1: 0]  exp_p_out    ;
   wire [  8-1: 0]  exp_p_dir    ;
   wire [  8-1: 0]  exp_n_in     ;
   wire [  8-1: 0]  exp_n_out    ;
   wire [  8-1: 0]  exp_n_dir    ;

   red_pitaya_hk i_hk
     (
      .clk_i           (  adc_clk                    ),  // clock
      .rstn_i          (  adc_rstn                   ),  // reset - active low

      // LED
      .led_o           (  led_o                      ),  // LED output
      // Expansion connector
      .exp_p_dat_i     (  exp_p_in                   ),  // input data
      .exp_p_dat_o     (  exp_p_out                  ),  // output data
      .exp_p_dir_o     (  exp_p_dir                  ),  // 1-output enable
      .exp_n_dat_i     (  exp_n_in                   ),
      .exp_n_dat_o     (  exp_n_out                  ),
      .exp_n_dir_o     (  exp_n_dir                  ),

      // System bus
      .sys_clk_i       (  sys_clk                    ),  // clock
      .sys_rstn_i      (  sys_rstn                   ),  // reset - active low
      .sys_addr_i      (  sys_addr                   ),  // address
      .sys_wdata_i     (  sys_wdata                  ),  // write data
      .sys_sel_i       (  sys_sel                    ),  // write byte select
      .sys_wen_i       (  sys_wen[0]                 ),  // write enable
      .sys_ren_i       (  sys_ren[0]                 ),  // read enable
      .sys_rdata_o     (  sys_rdata[ 0*32+31: 0*32]  ),  // read data
      .sys_err_o       (  sys_err[0]                 ),  // error indicator
      .sys_ack_o       (  sys_ack[0]                 )   // acknowledge signal
      );



   genvar           GV ;

   generate
      for( GV = 0 ; GV < 8 ; GV = GV + 1)
        begin : exp_iobuf
           IOBUF i_iobufp (.O(exp_p_in[GV]), .IO(exp_p_io[GV]), .I(exp_p_out[GV]), .T(!exp_p_dir[GV]) );
           IOBUF i_iobufn (.O(exp_n_in[GV]), .IO(exp_n_io[GV]), .I(exp_n_out[GV]), .T(!exp_n_dir[GV]) );
        end
   endgenerate





   //---------------------------------------------------------------------------------
   //
   //  Analog mixed signals
   //  XADC and slow PWM DAC control

   red_pitaya_ams i_ams
     (
      .clk_i           (  adc_clk                    ),  // clock
      .rstn_i          (  adc_rstn                   ),  // reset - active low

      .vinp_i          (  vinp_i                     ),  // voltages p
      .vinn_i          (  vinn_i                     ),  // voltages n

      .xadc_a_o        (  xadc_a                     ),  // latest value from slow ADC a
      .xadc_b_o        (  xadc_b                     ),  // latest value from slow ADC b

      .xadc_a_strobe_o   (  xadc_a_strobe                ),  // when slow ADC a value has been read
      .xadc_b_strobe_o   (  xadc_b_strobe                ),  // when slow ADC b value has been read

      // System bus
      .sys_clk_i       (  sys_clk                    ),  // clock
      .sys_rstn_i      (  sys_rstn                   ),  // reset - active low
      .sys_addr_i      (  sys_addr                   ),  // address
      .sys_wdata_i     (  sys_wdata                  ),  // write data
      .sys_sel_i       (  sys_sel                    ),  // write byte select
      .sys_wen_i       (  sys_wen[4]                 ),  // write enable
      .sys_ren_i       (  sys_ren[4]                 ),  // read enable
      .sys_rdata_o     (  sys_rdata[ 4*32+31: 4*32]  ),  // read data
      .sys_err_o       (  sys_err[4]                 ),  // error indicator
      .sys_ack_o       (  sys_ack[4]                 )   // acknowledge signal

      );


   //--------------------------------------------------------------------------------
   //
   //  Radar digitizer application
   //

   red_pitaya_digdar i_digdar
     (
      .adc_clk_i       (  adc_clk                    ),  // clock
      .adc_rstn_i      (  adc_rstn                   ),  // clock

      .adc_a_i         (  adc_a                      ),  // CH 1
      .adc_b_i         (  adc_b                      ),  // fast ADC channel B (for generating trigger)
      .xadc_a_i        (  xadc_a                     ),  // latest value from slow ADC a
      .xadc_b_i        (  xadc_b                     ),  // latest value from slow ADC b

      .xadc_a_strobe_i (  xadc_a_strobe              ),  // true when slow ADC A value is valid
      .xadc_b_strobe_i (  xadc_b_strobe              ),  // true when slow ADC B value is valid

      .negate_o        (  adc_neg_a                  ),  // true if video signal should be negated (taking into account that the pre-amp already does this!)

      // System bus
      .sys_clk_i       (  sys_clk                    ),  // clock
      .sys_rstn_i      (  sys_rstn                   ),  // reset - active low
      .sys_addr_i      (  sys_addr                   ),  // address
      .sys_wdata_i     (  sys_wdata                  ),  // write data
      .sys_sel_i       (  sys_sel                    ),  // write byte select
      .sys_wen_i       (  sys_wen[1]                 ),  // write enable
      .sys_ren_i       (  sys_ren[1]                 ),  // read enable
      .sys_rdata_o     (  sys_rdata[ 1*32+31: 1*32]  ),  // read data
      .sys_err_o       (  sys_err[1]                 ),  // error indicator
      .sys_ack_o       (  sys_ack[1]                 )   // acknowledge signal

      );

endmodule
