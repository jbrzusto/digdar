/**
 *
 * @brief Red Pitaya DIGDAR module. Detects pulses on Trigger, ACP and ARP channels.
 *
 * @Author John Brzustowski
 *
 * (c) John Brzustowski https://radr-project.org
 *
 */

/**
 * Memory Map for DIGDAR module; offsets are from 0x40600000, the start of the
 * UNUSED region of the standard redpitaya memory map.
 */

`define OFFSET_COMMAND                    20'h00000 // Command register
// bit     [0] - arm_trigger
// bit     [1] - rst_wr_state_machine
// bits [31:2] - reserved
`define OFFSET_TRIG_SOURCE                20'h00004 // Trigger source
`define OFFSET_NUM_SAMP                   20'h00008 // number of samples to capture once triggered
`define OFFSET_DEC_RATE                   20'h0000C // decimation rate; 1 means each sample; 2 means sum/avg/decim 2 samples at a time, ...
`define OFFSET_OPTIONS                    20'h00010 // bit 0: averaging; bit 1: negate video; bit 2: test mode - use counter instead of ADC output; bit 3: use sum not average when decimating
`define OFFSET_ADC_COUNTER                20'h00014 // 14-bit ADC counter used in test mode

/* 2. User parameters (rw); these are set to match radar signal characteristices */

`define OFFSET_TRIG_THRESH_EXCITE         20'h00018 // TRIG thresh_excite - excitation threshold for TRIG pulse (14 bits)
`define OFFSET_TRIG_THRESH_RELAX          20'h0001C // TRIG thresh_relax  - relaxation threshold for TRIG pulse (14 bits)
`define OFFSET_TRIG_LATENCY               20'h00020 // TRIG latency - count of clocks after detection before next detection
// is permitted (helps debounce)
`define OFFSET_TRIG_DELAY                 20'h00024 // trigger delay, in (non-decimated) ADC clocks; delay after trigger
// detection before first decimated sample is acquired
`define OFFSET_ACP_THRESH_EXCITE          20'h00028 // ACP thresh_excite - excitation threshold for ACP pulse (12 bits)
`define OFFSET_ACP_THRESH_RELAX           20'h0002C // ACP thresh_relax  - relaxation threshold for ACP pulse (12 bits)
`define OFFSET_ACP_LATENCY                20'h00030 // ACP latency - count of clocks after detection before next detection
// is permitted (helps debounce)
`define OFFSET_ARP_THRESH_EXCITE          20'h00034 // ARP thresh_excite - excitation threshold for ARP pulse (12 bits)
`define OFFSET_ARP_THRESH_RELAX           20'h00038 // ARP thresh_relax  - relaxation threshold for ARP pulse (12 bits)
`define OFFSET_ARP_LATENCY                20'h0003C // ARP latency - count of clocks after detection before next detection
// is permitted (helps debounce)

/* 3. Measurements (ro); these record results of processing the radar signals */
`define OFFSET_TRIG_COUNT                 20'h00040 // TRIG count since reset (32 bits; wraps)
`define OFFSET_TRIG_CLOCK_LOW             20'h00044 // clock at most recent TRIG (low 32 bits)
`define OFFSET_TRIG_CLOCK_HIGH            20'h00048 // clock at most recent TRIG (high 32 bits)
`define OFFSET_TRIG_PREV_CLOCK_LOW        20'h0004C // clock at previous TRIG (low 32 bits)
`define OFFSET_TRIG_PREV_CLOCK_HIGH       20'h00050 // clock at previous TRIG (high 32 bits)

`define OFFSET_ACP_COUNT                  20'h00054 // ACP count since reset (32 bits; wraps)
`define OFFSET_ACP_CLOCK_LOW              20'h00058 // clock at most recent ACP (low 32 bits)
`define OFFSET_ACP_CLOCK_HIGH             20'h0005C // clock at most recent ACP (high 32 bits)
`define OFFSET_ACP_PREV_CLOCK_LOW         20'h00060 // clock at previous ACP (low 32 bits)
`define OFFSET_ACP_PREV_CLOCK_HIGH        20'h00064 // clock at previous ACP (high 32 bits)

`define OFFSET_ARP_COUNT                  20'h00068 // ARP count since reset (32 bits; wraps)
`define OFFSET_ARP_CLOCK_LOW              20'h0006C // clock at most recent ARP (low 32 bits)
`define OFFSET_ARP_CLOCK_HIGH             20'h00070 // clock at most recent ARP (high 32 bits)
`define OFFSET_ARP_PREV_CLOCK_LOW         20'h00074 // clock at previous ARP (low 32 bits)
`define OFFSET_ARP_PREV_CLOCK_HIGH        20'h00078 // clock at previous ARP (high 32 bits)

`define OFFSET_ACP_PER_ARP                20'h0007C // count of ACP pulses between two most recent ARP pulses

// copies of registers saved at the start of each digitizing period

`define OFFSET_SAVED_TRIG_COUNT           20'h00080 // (saved) TRIG count since reset (32 bits; wraps)
`define OFFSET_SAVED_TRIG_CLOCK_LOW       20'h00084 // (saved) clock at most recent TRIG (low 32 bits)
`define OFFSET_SAVED_TRIG_CLOCK_HIGH      20'h00088 // (saved) clock at most recent TRIG (high 32 bits)
`define OFFSET_SAVED_TRIG_PREV_CLOCK_LOW  20'h0008C // (saved) clock at previous TRIG (low 32 bits)
`define OFFSET_SAVED_TRIG_PREV_CLOCK_HIGH 20'h00090 // (saved) clock at previous TRIG (high 32 bits)
`define OFFSET_SAVED_ACP_COUNT            20'h00094 // (saved) ACP count since reset (32 bits; wraps)
`define OFFSET_SAVED_ACP_CLOCK_LOW        20'h00098 // (saved) clock at most recent ACP (low 32 bits)
`define OFFSET_SAVED_ACP_CLOCK_HIGH       20'h0009C // (saved) clock at most recent ACP (high 32 bits)
`define OFFSET_SAVED_ACP_PREV_CLOCK_LOW   20'h000A0 // (saved) clock at previous ACP (low 32 bits)
`define OFFSET_SAVED_ACP_PREV_CLOCK_HIGH  20'h000A4 // (saved) clock at previous ACP (high 32 bits)
`define OFFSET_SAVED_ARP_COUNT            20'h000A8 // (saved) ARP count since reset (32 bits; wraps)
`define OFFSET_SAVED_ARP_CLOCK_LOW        20'h000AC // (saved) clock at most recent ARP (low 32 bits)
`define OFFSET_SAVED_ARP_CLOCK_HIGH       20'h000B0 // (saved) clock at most recent ARP (high 32 bits)
`define OFFSET_SAVED_ARP_PREV_CLOCK_LOW   20'h000B4 // (saved) clock at previous ARP (low 32 bits)
`define OFFSET_SAVED_ARP_PREV_CLOCK_HIGH  20'h000B8 // (saved) clock at previous ARP (high 32 bits)
`define OFFSET_SAVED_ACP_PER_ARP          20'h000BC // (saved) count of ACP pulses between two most recent ARP pulses

// utility / debugging registers

`define OFFSET_CLOCKS_LOW                 20'h000C0 // clock counter since reset (low 32 bits)
`define OFFSET_CLOCKS_HIGH                20'h000C4 // clock counter since reset (high 32 bits)

`define OFFSET_ACP_RAW                    20'h000C8 // most recent slow ADC value from ACP
`define OFFSET_ARP_RAW                    20'h000CC // most recent slow ADC value from ARP

`define OFFSET_ACP_AT_ARP                 20'h000D0 // most recent ACP count at ARP pulse
`define OFFSET_SAVED_ACP_AT_ARP           20'h000D4 // (saved) most recent ACP count at ARP pulse
`define OFFSET_TRIG_AT_ARP                20'h000D8 // most recent trig count at ARP pulse
`define OFFSET_SAVED_TRIG_AT_ARP          20'h000DC // (saved) most recent trig count at ARP pulse


module red_pitaya_digdar
  (
   input             adc_clk_i, //!< clock
   input             adc_rstn_i, //!< ADC reset - active low

   input [ 14-1: 0]  adc_a_i, //!< fast ADC channel A
   input [ 14-1: 0]  adc_b_i, //!< fast ADC channel B
   input [ 12-1: 0]  xadc_a_i, //!< most recent value from slow ADC channel A
   input [ 12-1: 0]  xadc_b_i, //!< most recent value from slow ADC channel B
   input             xadc_a_strobe_i, //!< strobe for most recent value from slow ADC channel A
   input             xadc_b_strobe_i, //!< strobe for most recent value from slow ADC channel B

   output            negate_o, //!< true if ADC CHA data should be negated

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
   wire              acp_trig           ;
   wire [32-1: 0]    acp_count          ;
   reg [64-1: 0]     acp_clock          ;
   reg [64-1: 0]     acp_prev_clock     ;
   reg [12-1: 0]     arp_thresh_excite  ;
   reg [12-1: 0]     arp_thresh_relax   ;
   reg [32-1: 0]     arp_latency        ;
   wire              arp_trig           ;
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
   wire              trig_trig           ;
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

   reg               adc_arm_do   ;
   reg               adc_rst_do   ;
   reg [32-1:0]      digdar_options;

   reg [16-1:0]      adc_counter; // counter for counting mode

   reg [   4-1: 0]   trig_src     ; // source for triggering scanline acquisition

   //---------------------------------------------------------------------------------
   //  Input Y (ADC A can be set to counting mode instead of ADC values)

   wire [ 16-1: 0]   adc_a_y;

   assign adc_a_y = counting_mode ? adc_counter : $signed(adc_a_i);
   wire              reset;

   assign reset = adc_rst_do | ~adc_rstn_i ;

   trigger_gen #( .width(12),
                  .counter_width(32),
                  .do_smoothing(1)
                  ) trigger_gen_acp  // not really a trigger; we're just counting these pulses
     (
      .clock(adc_clk_i),
      .reset(reset),
      .enable(1'b1),
      .strobe(xadc_a_strobe_i),
      .signal_in(xadc_a_i), // signed
      .thresh_excite(acp_thresh_excite), // signed
      .thresh_relax(acp_thresh_relax), //signed
      .delay(0),
      .latency(acp_latency),
      .trigger(acp_trig),
      .counter(acp_count)
      );

   trigger_gen #( .width(12),
                  .counter_width(32),
                  .do_smoothing(1)
                  ) trigger_gen_arp  // not really a trigger; we're just counting these pulses
     (
      .clock(adc_clk_i),
      .reset(reset),
      .enable(1'b1),
      .strobe(xadc_b_strobe_i),
      .signal_in(xadc_b_i), // signed
      .thresh_excite(arp_thresh_excite), // signed
      .thresh_relax(arp_thresh_relax), // signed
      .delay(0),
      .latency(arp_latency),
      .trigger(arp_trig),
      .counter(arp_count)
      );

   trigger_gen #( .width(14),
                  .counter_width(32),
                  .do_smoothing(1)
                  ) trigger_gen_trig // this counts trigger pulses and uses them
     (
      .clock(adc_clk_i),
      .reset(reset),
      .enable(1'b1),
      .strobe(1'b1),
      .signal_in(adc_b_i), // signed
      .thresh_excite(trig_thresh_excite), // signed
      .thresh_relax(trig_thresh_relax), // signed
      .delay(trig_delay),
      .latency(trig_latency),
      .trigger(trig_trig),
      .counter(trig_count)
      );



   //---------------------------------------------------------------------------------
   //
   //  reset
   always @(posedge adc_clk_i) begin
      if (reset) begin
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

         adc_arm_do    <= 1'b0 ;
         adc_rst_do    <= 1'b0 ;
         trig_src      <= 4'h0 ;
         adc_trig      <= 1'b0 ;
         adc_a_sum   <= 32'h0 ;
         adc_b_sum   <= 32'h0 ;
         adc_dec_cnt <= 17'h0 ;
         adc_wp       <= 'h0 ;
         n_to_capture <= 32'h0 ;
         capturing    <=  1'b0 ;

      end // if (reset)
   end

   //---------------------------------------------------------------------------------
   //  Decimate input data

   reg [ 16-1: 0]    adc_a_dat     ;
   reg [ 14-1: 0]    adc_b_dat     ;
   reg [ 32-1: 0]    adc_a_sum     ;
   reg [ 32-1: 0]    adc_b_sum     ;
   reg [ 17-1: 0]    dec_rate      ;
   reg [ 17-1: 0]    adc_dec_cnt   ;
   wire              dec_done      ;

   assign dec_done = adc_dec_cnt >= dec_rate;

   always @(posedge adc_clk_i) begin
      if (! reset) begin
         adc_counter <= adc_counter + 16'b1;

         if (adc_arm_do) begin // arm
            adc_dec_cnt <= 17'h0;
            adc_a_sum   <= 'h0;
            adc_b_sum   <= 'h0;
         end
         else if (capturing) begin
            adc_dec_cnt <= adc_dec_cnt + 17'h1 ;
            adc_a_sum   <= adc_a_sum + adc_a_y ;
            adc_b_sum   <= $signed(adc_b_sum) + $signed(adc_b_i) ;
         end

         if (use_sum) begin
            // for decimation rates <= 4, the sum fits in 16 bits, so we can return
            // that instead of the average, retaining some bits.
            // This path only used when avg_en is true.
               adc_a_dat <= adc_a_sum[15+0 :  0];
               adc_b_dat <= adc_b_sum[15+0 :  0];
         end
         else begin
            // not summing.  If avg_en is true and the decimation rate is one of the "special" powers of two,
            // return the average, truncated toward zero.
            // Otherwise, we're either not averaging or can't easily compute average because the decimation
            // rate is not a power of two, just return the bare sample.
            // The values adc_a_dat and adc_b_dat are only used at the end of the decimation interval
            // when it is time to save values in the appropriate buffers.
            case (dec_rate & {17{avg_en}})
              17'h1     : begin adc_a_dat <= adc_a_sum[15+0 :  0];      adc_b_dat <= adc_b_sum[15+0 :  0];  end
              17'h2     : begin adc_a_dat <= adc_a_sum[15+1 :  1];      adc_b_dat <= adc_b_sum[15+1 :  1];  end
              17'h4     : begin adc_a_dat <= adc_a_sum[15+2 :  2];      adc_b_dat <= adc_b_sum[15+2 :  2];  end
              17'h8     : begin adc_a_dat <= adc_a_sum[15+3 :  3];      adc_b_dat <= adc_b_sum[15+3 :  3];  end
              17'h40    : begin adc_a_dat <= adc_a_sum[15+6 :  6];      adc_b_dat <= adc_b_sum[15+6 :  6];  end
              17'h400   : begin adc_a_dat <= adc_a_sum[15+10: 10];      adc_b_dat <= adc_b_sum[15+10: 10];  end
              17'h2000  : begin adc_a_dat <= adc_a_sum[15+13: 13];      adc_b_dat <= adc_b_sum[15+13: 13];  end
              17'h10000 : begin adc_a_dat <= adc_a_sum[15+16: 16];      adc_b_dat <= adc_b_sum[15+16: 16];  end
              default   : begin adc_a_dat <= adc_a_y;                   adc_b_dat <= adc_b_i;               end
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

   reg [ RSZ-1: 0] adc_b_raddr               ;
   reg [ RSZ-1: 0] xadc_a_raddr              ;
   reg [ RSZ-1: 0] xadc_b_raddr              ;
   reg [   4-1: 0] adc_rval                  ;
   wire            adc_rd_dv                 ;
   reg             adc_trig                  ;

   reg [  32-1: 0] capture_size              ;
   reg [  32-1: 0] n_to_capture              ;
   reg             capturing                 ;

   assign negate = ~digdar_options[0]; // sense of negation is reversed from what user intends, since we already have to do one negation to compensate for inverting pre-amp

   assign avg_en = digdar_options[1]; // 1 means average (where possible) instead of simply decimating

   assign counting_mode = digdar_options[2]; // 1 means we use a counter instead of the real adc values

   assign use_sum = avg_en & digdar_options[3] & (dec_rate <= 4); // when decimation is 4 or less, we can return the sum rather than the average, of samples (16 bits)

   // Write to BRAM buffers
   always @(posedge adc_clk_i) begin
      if (!reset) begin
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
              // The later sample goes into the upper 16 bits, the earlier one into the lower 16 bits.
              // We divide adc_wp by two to use it as an index into the 32-bit array.
              if (adc_wp[0])
                adc_a_buf[adc_wp[RSZ-1:1]] <= {adc_a_dat, adc_a_prev};
              else
                adc_a_prev <= adc_a_dat;
              adc_b_buf[adc_wp] <= adc_b_dat ;
              xadc_a_buf[adc_wp] <= xadc_a_i ;
              xadc_b_buf[adc_wp] <= xadc_b_i ;
              n_to_capture <= n_to_capture + {32{1'b1}} ; // -1
              adc_wp <= adc_wp + 1'b1 ;
              adc_dec_cnt <= 0;
           end
      end // if (! reset)
   end


   // Read
   always @(posedge adc_clk_i) begin
      if (reset)
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
      adc_b_rd       <= adc_b_buf[adc_b_raddr] ;
      xadc_a_rd      <= xadc_a_buf[xadc_a_raddr] ;
      xadc_b_rd      <= xadc_b_buf[xadc_b_raddr] ;
   end

   //---------------------------------------------------------------------------------
   //
   //  Trigger source selector

   always @(posedge adc_clk_i) begin
      if (!reset) begin
         adc_arm_do  <= wen && (addr[19:0]==`OFFSET_COMMAND) && wdata[0] ; // SW arm
         adc_rst_do  <= wen && (addr[19:0]==`OFFSET_COMMAND) && wdata[1] ; // SW reset

         if (((capturing || adc_trig) && (n_to_capture == 32'h0)) || adc_rst_do) //delay reached or reset
           trig_src <= 4'h0 ;

         case (trig_src)
           4'd1: adc_trig <= adc_arm_do    ; // immediately upon arming
           4'd2: adc_trig <= trig_trig  ; // trigger on channel B (rising or falling as determined by trig_thresh_excite/relax), but possibly after a delay
           4'd3: adc_trig <= acp_trig    ; // trigger on slow channel A
           4'd4: adc_trig <= arp_trig    ; // trigger on slow channel B
           default : adc_trig <= 1'b0      ;
         endcase
      end
   end

   //---------------------------------------------------------------------------------
   //
   //  system bus connection
   //
   // bridge between ADC and system, for reading/writing registers and buffers

   //bus bridging components
   wire [ 32-1: 0]   addr         ;
   wire [ 32-1: 0]   wdata        ;
   wire              wen          ;
   wire              ren          ;
   reg [ 32-1: 0]    rdata        ;
   reg               err          ;
   reg               ack          ;

   always @(posedge adc_clk_i) begin
      if (!reset) begin
         if (wen) begin
            casez (addr[19:0])
              `OFFSET_ACP_THRESH_EXCITE   : acp_thresh_excite   <= wdata[ 12-1: 0];
              `OFFSET_ACP_THRESH_RELAX    : acp_thresh_relax    <= wdata[ 12-1: 0];
              `OFFSET_ACP_LATENCY         : acp_latency         <= wdata[ 32-1: 0];
              `OFFSET_ARP_THRESH_EXCITE   : arp_thresh_excite   <= wdata[ 12-1: 0];
              `OFFSET_ARP_THRESH_RELAX    : arp_thresh_relax    <= wdata[ 12-1: 0];
              `OFFSET_ARP_LATENCY         : arp_latency         <= wdata[ 32-1: 0];
              `OFFSET_TRIG_THRESH_EXCITE  : trig_thresh_excite  <= wdata[ 14-1: 0];
              `OFFSET_TRIG_THRESH_RELAX   : trig_thresh_relax   <= wdata[ 14-1: 0];
              `OFFSET_TRIG_DELAY          : trig_delay          <= wdata[ 32-1: 0];
              `OFFSET_TRIG_LATENCY        : trig_latency        <= wdata[ 32-1: 0];
            endcase
         end // if (wen)

         // Not reset, so check for acp and arp pulses and record time,
         // keeping previous time
         clock_counter <= clock_counter + 64'b1;

         if (acp_trig) begin
            acp_clock           <= clock_counter;
            acp_prev_clock      <= acp_clock;
         end
         if (arp_trig) begin
            arp_clock           <= clock_counter;
            arp_prev_clock      <= arp_clock;
            acp_per_arp         <= acp_count - acp_at_arp;
            acp_at_arp          <= acp_count;
            trig_at_arp         <= trig_count;
         end
         if (trig_trig) begin
            trig_clock           <= clock_counter;
            trig_prev_clock      <= trig_clock;
         end

         if (trig_trig & ! capturing) begin
            // we've been triggered but are not already capturing so
            // save copies of metadata registers for this pulse.
            // (If trig_trig is true but we are already capturing,
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
        `OFFSET_TRIG_THRESH_EXCITE   : begin ack <= 1'b1;  rdata <= {{32-14{1'b0}}, trig_thresh_excite       }; end
        `OFFSET_TRIG_THRESH_RELAX    : begin ack <= 1'b1;  rdata <= {{32-14{1'b0}}, trig_thresh_relax        }; end
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
