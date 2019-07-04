/**
 * @brief Red Pitaya oscilloscope application, used for capturing ADC data
 *        into BRAMs, which can be later read by SW.
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
 * This is a simple data aquisition module that captures raw signal on 4 channels
 * (2 fast ADC, 2 slow ADC), usually in sync with a trigger pulse detected on
 * ADC B.
 *
 *                 /-----------\            /-----\
 *   ADC CHA --->  | AVG & DEC | ---------> | BUF | --->  SW
 *                 \-----------/            \-----/
 *                   |
 *                /------\             /-------\
 *  ADC CHB --->  | TRIG | ----------> | COUNT | --->  SW
 *                \------/             \-------/
 *
 *                /------\             /-------\
 * XADC CHA --->  | TRIG | ----------> | COUNT | --->  SW
 *                \------/             \-------/
 *
 *                /------\             /-------\
 * XADC CHB --->  | TRIG | ----------> | COUNT | --->  SW
 *                \------/             \-------/
 *
 * Input data is optionaly averaged and decimated.
 *
 * The trigger section makes triggers from input ADC data or external digital
 * signal.  Debouncing is accomplished by use of separate excitation and relaxation
 * thresholds.  A trigger is detected when its signal level crosses the excitation threshold
 * in the direction away from the relaxation threshold.  No further triggers are detected
 * until the signal has crossed the relaxation threshold.  See trigger_gen.v
 *
 * After arming, detection of a trigger begins writing of decimated / averaged / summed
 * data to BRAM buffers.  Summing can happen for decimation rates 1, 2, 3, and 4, because
 * a sum of up to 4 unsigned samples of 14 bits each fits in an unsigned 16 bit word.
 * Averaging can happen for decimation rates 2, 4, 8, 64, 1024, 8192, 65536 because
 * it requires only summation followed by a shift.
 * For all other decimation rates n, only decimation is allowed:  the last of each
 * set of n consecutive samples is used.
 */



module red_pitaya_scope
  (
   // ADC
   input [ 14-1: 0]  adc_a_i, //!< ADC data CHA
   input [ 14-1: 0]  adc_b_i, //!< ADC data CHB
   input             adc_clk_i, //!< ADC clock
   input             adc_rstn_i, //!< ADC reset - active low

   input [ 12-1: 0]  xadc_a, //!< latest value from slow ADC 0
   input [ 12-1: 0]  xadc_b, //!< latest value from slow ADC 1

   input             radar_trig_i, //!< true for one cycle at start of radar trigger pulse
   input             acp_trig_i, //!< true for one cycle at start of acp pulse
   input             arp_trig_i, //!< true for one cycle at start of arp pulse

   output            capturing_o, //!< true while capturing samples
   output            negate_o, //!< true if ADC CHA data should be negated

   // System bus
   input             sys_clk_i, //!< bus clock
   input             sys_rstn_i, //!< bus reset - active low
   input [ 32-1: 0]  sys_addr_i, //!< bus saddress
   input [ 32-1: 0]  sys_wdata_i, //!< bus write data
   input [ 4-1: 0]   sys_sel_i, //!< bus write byte select
   input             sys_wen_i, //!< bus write enable
   input             sys_ren_i, //!< bus read enable
   output [ 32-1: 0] sys_rdata_o, //!< bus read data
   output            sys_err_o, //!< bus error indicator
   output            sys_ack_o      //!< bus acknowledge signal
   );

   wire [ 32-1: 0]   addr         ;
   wire [ 32-1: 0]   wdata        ;
   wire              wen          ;
   wire              ren          ;
   reg [ 32-1: 0]    rdata        ;
   reg               err          ;
   reg               ack          ;
   reg               adc_arm_do   ;
   reg               adc_rst_do   ;
   reg [32-1:0]      digdar_extra_options;
   reg [ 32-1:0 ]    bogus_reg   ;

   reg [16-1:0]      adc_counter; // counter for counting mode

   reg               adc_trig_sw      ;
   reg [   4-1: 0]   set_trig_src     ;



   //---------------------------------------------------------------------------------
   //  Input Y (ADC A can be set to counting mode instead of ADC values)

   wire [ 16-1: 0]   adc_a_y;

   assign adc_a_y = counting_mode ? adc_counter : $signed(adc_a_i);


   //---------------------------------------------------------------------------------
   //  Decimate input data

   reg [ 16-1: 0]    adc_a_dat     ;
   reg [ 14-1: 0]    adc_b_dat     ;
   reg [ 32-1: 0]    adc_a_sum     ;
   reg [ 32-1: 0]    adc_b_sum     ;
   reg [ 17-1: 0]    dec_rate      ;
   reg [ 17-1: 0]    adc_dec_cnt   ;
   reg               avg_en        ;
   wire              dec_done      ;

   assign dec_done = adc_dec_cnt >= dec_rate;

   always @(posedge adc_clk_i) begin
      if (adc_rstn_i == 1'b0) begin
         adc_a_sum   <= 32'h0 ;
         adc_b_sum   <= 32'h0 ;
         adc_dec_cnt <= 17'h0 ;
      end
      else begin
         adc_counter <= adc_counter + 16'b1;

         if (adc_arm_do) begin // arm
            adc_dec_cnt <= 17'h0;
            adc_a_sum   <= 'h0;
            adc_b_sum   <= 'h0;
         end
         else if (capturing) begin
            adc_dec_cnt <= adc_dec_cnt + 17'h1 ;
            adc_a_sum   <= $signed(adc_a_sum) + $signed(adc_a_y) ;
            adc_b_sum   <= $signed(adc_b_sum) + $signed(adc_b_i) ;
         end

         if (use_sum) begin
            // for decimation rates <= 4, the sum fits in 16 bits, so we can return
            // that instead of the average, retaining some bits.
            if (avg_en) begin
               adc_a_dat <= adc_a_sum[15+0 :  0];
               adc_b_dat <= adc_b_sum[15+0 :  0];
            end
            else begin// not average, just return decimated sample
               adc_a_dat <= adc_a_y;
               adc_b_dat <= adc_b_i;
            end
         end
         else begin
            case (dec_rate & {17{avg_en}})
              17'h0     : begin adc_a_dat <= adc_a_y;                   adc_b_dat <= adc_b_i;               end
              17'h1     : begin adc_a_dat <= adc_a_sum[15+0 :  0];      adc_b_dat <= adc_b_sum[15+0 :  0];  end
              17'h2     : begin adc_a_dat <= adc_a_sum[15+1 :  1];      adc_b_dat <= adc_b_sum[15+1 :  1];  end
              17'h4     : begin adc_a_dat <= adc_a_sum[15+2 :  2];      adc_b_dat <= adc_b_sum[15+2 :  2];  end
              17'h8     : begin adc_a_dat <= adc_a_sum[15+3 :  3];      adc_b_dat <= adc_b_sum[15+3 :  3];  end
              17'h40    : begin adc_a_dat <= adc_a_sum[15+6 :  6];      adc_b_dat <= adc_b_sum[15+6 :  6];  end
              17'h400   : begin adc_a_dat <= adc_a_sum[15+10: 10];      adc_b_dat <= adc_b_sum[15+10: 10];  end
              17'h2000  : begin adc_a_dat <= adc_a_sum[15+13: 13];      adc_b_dat <= adc_b_sum[15+13: 13];  end
              17'h10000 : begin adc_a_dat <= adc_a_sum[15+16: 16];      adc_b_dat <= adc_b_sum[15+16: 16];  end
              default   : begin adc_a_dat <= adc_a_sum[15+0 :  0];      adc_b_dat <= adc_b_sum[15+0 :  0];  end
            endcase
         end
      end
   end

   //---------------------------------------------------------------------------------
   //  ADC buffer RAM

   localparam RSZ = 14 ;  // RAM size 2^RSZ

   reg [  32-1: 0] adc_a_buf [0:(1<<(RSZ-1))-1] ; // 28 bits so we can do 32 bit reads
   reg [  16-1: 0] adc_a_prev ; // temporary register for saving previous 16-bit sample from ADC a because we combine two into a 32-bit write

   reg [  14-1: 0] adc_b_buf [0:(1<<RSZ)-1]  ;
   reg [  32-1: 0] adc_a_rd                  ;
   reg [  14-1: 0] adc_b_rd                  ;
   reg [  12-1: 0] xadc_a_buf [0:(1<<RSZ)-1] ;
   reg [  12-1: 0] xadc_b_buf [0:(1<<RSZ)-1] ;
   reg [  12-1: 0] xadc_a_rd                 ;
   reg [  12-1: 0] xadc_b_rd                 ;
   reg [ RSZ-1: 0] adc_wp                    ;
   reg [ RSZ-1: 0] adc_raddr                 ;
   reg [ RSZ-1: 0] adc_a_raddr               ;
   reg             adc_a_word_sel            ;

   reg [ RSZ-1: 0] adc_b_raddr               ;
   reg [ RSZ-1: 0] xadc_a_raddr              ;
   reg [ RSZ-1: 0] xadc_b_raddr              ;
   reg [   4-1: 0] adc_rval                  ;
   wire            adc_rd_dv                 ;
   reg             adc_trig                  ;

   reg [  32-1: 0] capture_size              ;
   reg [  32-1: 0] n_to_capture              ;
   reg             capturing                 ;


   assign capturing_o = capturing;

   assign negate = ~digdar_extra_options[1]; // sense of negation is reversed from what user intends, since we already have to do one negation to compensate for inverting pre-amp

   assign read32 = digdar_extra_options[2]; // 1 means reads from buffers are 32 bits, not 16, with specified address in lower 16 bits, next address in upper 16 bits

   assign counting_mode = digdar_extra_options[3]; // 1 means we use a counter instead of the real adc values

   assign use_sum = digdar_extra_options[4] & (dec_rate <= 4); // when decimation is 4 or less, we can return the sum rather than the average, of samples (16 bits)

   // Write
   always @(posedge adc_clk_i) begin
      if (adc_rstn_i == 1'b0 || adc_rst_do) begin
         adc_wp       <= 'h0 ;
         n_to_capture <= 32'h0 ;
         capturing    <=  1'b0 ;
      end

      else begin
         if ((capturing || adc_trig) && (n_to_capture == 32'h0)) //delayed reached or reset
           capturing <= 1'b0 ;

         if (adc_trig)
           begin
              capturing  <= 1'b1 ;
              adc_wp <= 'h0;
              n_to_capture <= capture_size;
           end

         if (capturing && dec_done)
           begin
              // Note: the adc_a buffer is 32 bits wide, so we only write into it on every 2nd sample
              // The later sample goes into the upper 16 bits, the earlier one into the lower 16 bits
              if (adc_wp[0])
                adc_a_buf[adc_wp[RSZ-1:1]] <= {adc_a_dat, adc_a_prev};
              else
                adc_a_prev <= adc_a_dat;
              adc_b_buf[adc_wp] <= adc_b_dat ;
              xadc_a_buf[adc_wp] <= xadc_a ;
              xadc_b_buf[adc_wp] <= xadc_b ;
              n_to_capture <= n_to_capture + {32{1'b1}} ; // -1
              adc_wp <= adc_wp + 1'b1 ;
              adc_dec_cnt <= 0;
           end
      end // else: !if(adc_rstn_i == 1'b0 || adc_rst_do)
   end


   // Read
   always @(posedge adc_clk_i) begin
      if (adc_rstn_i == 1'b0)
        adc_rval <= 4'h0 ;
      else
        adc_rval <= {adc_rval[2:0], (ren || wen)};
   end
   assign adc_rd_dv = adc_rval[3];

   always @(posedge adc_clk_i) begin
      adc_raddr      <= addr[RSZ+1:2] ; // address synchronous to clock
      adc_a_raddr    <= adc_raddr     ; // double register
      adc_b_raddr    <= adc_raddr     ; // otherwise memory corruption at reading
      xadc_a_raddr   <= adc_a_raddr     ; // double register
      xadc_b_raddr   <= adc_b_raddr     ; // otherwise memory corruption at reading
      adc_a_rd       <= adc_a_buf[adc_a_raddr[RSZ-1:1]] ;
      adc_a_word_sel <= adc_a_raddr[0]; // if 1, use higher 16 bits of 32 bit value in adc_a_rd; else use lower 16 bits
      adc_b_rd       <= adc_b_buf[adc_b_raddr] ;
      xadc_a_rd      <= xadc_a_buf[xadc_a_raddr] ;
      xadc_b_rd      <= xadc_b_buf[xadc_b_raddr] ;
   end





   //---------------------------------------------------------------------------------
   //
   //  Trigger source selector


   always @(posedge adc_clk_i) begin
      if (adc_rstn_i == 1'b0) begin
         adc_arm_do    <= 1'b0 ;
         adc_rst_do    <= 1'b0 ;
         adc_trig_sw   <= 1'b0 ;
         set_trig_src  <= 4'h0 ;
         adc_trig      <= 1'b0 ;
      end
      else begin
         adc_arm_do  <= wen && (addr[19:0]==20'h0) && wdata[0] ; // SW arm
         adc_rst_do  <= wen && (addr[19:0]==20'h0) && wdata[1] ; // SW reset
         adc_trig_sw <= wen && (addr[19:0]==20'h4) ; // SW trigger

         if (wen && (addr[19:0]==20'h4))
           set_trig_src <= wdata[3:0] ;
         else if (((capturing || adc_trig) && (n_to_capture == 32'h0)) || adc_rst_do) //delay reached or reset
           set_trig_src <= 4'h0 ;

         case (set_trig_src)
           4'd1 : adc_trig <= adc_trig_sw   ; // manual
           4'd2: adc_trig <= radar_trig_i  ; // trigger on channel B (rising or falling as determined by trig_thresh_excite/relax), but possibly after a delay
           4'd3: adc_trig <= acp_trig_i    ; // trigger on slow channel A
           4'd4: adc_trig <= arp_trig_i    ; // trigger on slow channel B

           default : adc_trig <= 1'b0          ;
         endcase
      end
   end









   //---------------------------------------------------------------------------------
   //
   //  System bus connection


   always @(posedge adc_clk_i) begin
      if (adc_rstn_i == 1'b0) begin
         capture_size       <=  32'd0      ;
         dec_rate      <=  17'd1      ;
         avg_en        <=   1'b1      ;
         digdar_extra_options <= 32'h0;
         adc_counter   <=  14'h0      ;
      end
      else begin
         if (wen) begin
            if (addr[19:0]==20'h10)   capture_size      <= wdata[32-1:0] ;
            if (addr[19:0]==20'h14)   dec_rate     <= wdata[17-1:0] ;
            if (addr[19:0]==20'h28)   avg_en       <= wdata[     0] ;
            if (addr[19:0]==20'h50)   digdar_extra_options <= wdata[32-1:0] ;
         end
      end
   end





   always @(*) begin
      err <= 1'b0 ;

      casez (addr[19:0])
        20'h00004 : begin ack <= 1'b1;          rdata <= {{32- 4{1'b0}}, set_trig_src}       ; end

        20'h00010 : begin ack <= 1'b1;          rdata <= {               capture_size}       ; end
        20'h00014 : begin ack <= 1'b1;          rdata <= {{32-17{1'b0}}, dec_rate}           ; end

        20'h00018 : begin ack <= 1'b1;          rdata <= 32'h0                               ; end
        20'h0001C : begin ack <= 1'b1;          rdata <= 32'h0                               ; end


        20'h00028 : begin ack <= 1'b1;          rdata <= {{32- 1{1'b0}}, avg_en}             ; end

        20'h00050 : begin ack <= 1'b1;          rdata <= digdar_extra_options                ; end
        20'h00054 : begin ack <= 1'b1;          rdata <= {{32-14{1'b0}}, adc_counter}        ; end

        20'h1???? : begin ack <= adc_rd_dv;     rdata <= read32 ? adc_a_rd :  {16'h0, adc_a_word_sel ? adc_a_rd[32-1:16] : adc_a_rd[16-1:0]}             ; end
        20'h2???? : begin ack <= adc_rd_dv;     rdata <= {16'h0, 2'h0, adc_b_rd}             ; end

        20'h3???? : begin ack <= adc_rd_dv;     rdata <= {16'h0, 4'h0, xadc_a_rd}            ; end
        20'h4???? : begin ack <= adc_rd_dv;     rdata <= {16'h0, 4'h0, xadc_b_rd}            ; end

        default : begin ack <= 1'b1;          rdata <=  32'h0                              ; end
      endcase
   end






   // bridge between ADC and sys clock
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

endmodule
