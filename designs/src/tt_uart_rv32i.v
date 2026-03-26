// tt_uart_rv32i.v — Single-file TT design: UART Programmable RV32I by enieman
// Source: https://github.com/enieman/uart_programmable_rv32i
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

// =============================================================================
// Synchronizer (converted from SystemVerilog)
// =============================================================================
module synchronizer (
   input  wire clk,
   input  wire async,
   output wire sync);

   reg [1:0] buff;

   always @(posedge clk)
      buff <= {buff[0], async};

   assign sync = buff[1];

endmodule

// =============================================================================
// Positive Edge Detector
// =============================================================================
module pos_edge_detector (
   input  wire clk,
   input  wire rst,
   input  wire signal_in,
   output wire edge_detected);

   reg register;

   always @(posedge clk) begin
      if (rst) register <= 1;
      else register <= signal_in;
   end

   assign edge_detected = ~register & signal_in;

endmodule

// =============================================================================
// Negative Edge Detector
// =============================================================================
module neg_edge_detector (
   input  wire clk,
   input  wire rst,
   input  wire signal_in,
   output wire edge_detected);

   reg register;

   always @(posedge clk) begin
      if (rst) register <= 1;
      else register <= signal_in;
   end

   assign edge_detected = register & ~signal_in;

endmodule

// =============================================================================
// Shift Register
// =============================================================================
module shift_register #(
   parameter NUM_BITS = 8,
   parameter RST_VALUE = 0)
(
   input  wire clk,
   input  wire rst,
   input  wire serial_in,
   input  wire shift_enable,
   input  wire [NUM_BITS-1:0] parallel_in,
   input  wire load_enable,
   output wire serial_out,
   output wire [NUM_BITS-1:0] parallel_out);

   reg [NUM_BITS-1:0] register;

   always @(posedge clk) begin
      if (rst) register <= RST_VALUE[NUM_BITS-1:0];
      else if (load_enable) register <= parallel_in;
      else if (shift_enable) begin : shift_blk
         integer i;
         for (i = 0; i < NUM_BITS-1; i = i + 1) register[i] <= register[i+1];
         register[NUM_BITS-1] <= serial_in;
      end
   end

   assign parallel_out = register;
   assign serial_out = register[0];

endmodule

// =============================================================================
// Byte to Word Converter
// =============================================================================
module byte_to_word #(
   parameter BYTE_ADDR_WIDTH = 6)
(
   input  wire [BYTE_ADDR_WIDTH-1:0] byte_addr_in,
   input  wire [7:0]                 byte_data_in,
   output reg  [BYTE_ADDR_WIDTH-3:0] word_addr_out,
   output reg  [3:0]                 word_byte_en_out,
   output reg  [31:0]                word_data_out);

   always @(*) begin
      word_addr_out = byte_addr_in[BYTE_ADDR_WIDTH-1:2];
      case (byte_addr_in[1:0])
         2'b00: begin
                word_byte_en_out = 4'b0001;
                word_data_out = {24'h00_0000, byte_data_in};
                end
         2'b01: begin
                word_byte_en_out = 4'b0010;
                word_data_out = {16'h0000, byte_data_in, 8'h00};
                end
         2'b10: begin
                word_byte_en_out = 4'b0100;
                word_data_out = {8'h00, byte_data_in, 16'h0000};
                end
         2'b11: begin
                word_byte_en_out = 4'b1000;
                word_data_out = {byte_data_in, 24'h00_0000};
                end
      endcase
   end

endmodule

// =============================================================================
// Word to Byte Converter
// =============================================================================
module word_to_byte #(
   parameter BYTE_ADDR_WIDTH = 6)
(
   input  wire [BYTE_ADDR_WIDTH-1:0] byte_addr_in,
   output reg  [7:0]                 byte_data_out,
   output reg  [BYTE_ADDR_WIDTH-3:0] word_addr_out,
   input  wire [31:0]                word_data_in);

   always @(*) begin
      word_addr_out = byte_addr_in[BYTE_ADDR_WIDTH-1:2];
      case (byte_addr_in[1:0])
         2'b00: byte_data_out = word_data_in[7:0];
         2'b01: byte_data_out = word_data_in[15:8];
         2'b10: byte_data_out = word_data_in[23:16];
         2'b11: byte_data_out = word_data_in[31:24];
      endcase
   end

endmodule

// =============================================================================
// Register File (Memory) — converted from SystemVerilog
// =============================================================================
module reg_file #(
   parameter BYTE_ADDR_WIDTH = 6)
(
   input  wire clk,
   input  wire rst,
   input  wire rd_en0,
   input  wire [BYTE_ADDR_WIDTH-3:0] rd_addr0,
   output reg  [31:0] rd_data0,
   input  wire rd_en1,
   input  wire [BYTE_ADDR_WIDTH-3:0] rd_addr1,
   output reg  [31:0] rd_data1,
   input  wire wr_en,
   input  wire [BYTE_ADDR_WIDTH-3:0] wr_addr,
   input  wire [3:0] byte_en,
   input  wire [31:0] wr_data);

   localparam NUM_BYTES = 2**BYTE_ADDR_WIDTH;
   reg [7:0] register [0:NUM_BYTES-1];

   always @(posedge clk) begin
      if (rst) begin : rst_blk
         integer i;
         for (i = 0; i < NUM_BYTES; i = i + 1)
            register[i] = 8'h00;
      end
      else if (wr_en) begin
         if (byte_en[3]) register[{wr_addr, 2'b11}] <= wr_data[31:24];
         if (byte_en[2]) register[{wr_addr, 2'b10}] <= wr_data[23:16];
         if (byte_en[1]) register[{wr_addr, 2'b01}] <= wr_data[15:8];
         if (byte_en[0]) register[{wr_addr, 2'b00}] <= wr_data[7:0];
      end
   end

   always @(posedge clk) begin
      if (rst) begin
         rd_data0 <= 32'h0000_0000;
         rd_data1 <= 32'h0000_0000;
      end
      else begin
         if (rd_en0) rd_data0 <= {
            register[{rd_addr0, 2'b11}],
            register[{rd_addr0, 2'b10}],
            register[{rd_addr0, 2'b01}],
            register[{rd_addr0, 2'b00}]};
         if (rd_en1) rd_data1 <= {
            register[{rd_addr1, 2'b11}],
            register[{rd_addr1, 2'b10}],
            register[{rd_addr1, 2'b01}],
            register[{rd_addr1, 2'b00}]};
      end
   end

endmodule

// =============================================================================
// UART RX
// =============================================================================
module uart_rx #(
   parameter COUNTER_WIDTH = 24)
(
   input  wire clk,
   input  wire rst,
   input  wire uart_rx_in,
   output wire [7:0] data,
   output reg  [COUNTER_WIDTH-1:0] cycles_per_bit,
   output wire ready);

   localparam STATE_IDLE  = 4'h0;
   localparam STATE_START = 4'h1;
   localparam STATE_D0    = 4'h2;
   localparam STATE_D1    = 4'h3;
   localparam STATE_D2    = 4'h4;
   localparam STATE_D3    = 4'h5;
   localparam STATE_D4    = 4'h6;
   localparam STATE_D5    = 4'h7;
   localparam STATE_D6    = 4'h8;
   localparam STATE_D7    = 4'h9;
   localparam STATE_STOP  = 4'hA;

   reg baud_rate_known;
   reg [COUNTER_WIDTH-1:0] counter_val;
   reg [3:0] state;
   wire uart_rx_in_synced, start_detected, rising_edge, timer_rst, half_bit, full_bit, shift_en;

   always @(posedge clk) begin
      if (rst) baud_rate_known <= 1'b0;
      else if ((state == STATE_STOP) && (start_detected || full_bit)) baud_rate_known <= 1'b1;
   end

   synchronizer uart_rx_in_synchronizer(
      .clk(clk), .async(uart_rx_in), .sync(uart_rx_in_synced));

   neg_edge_detector start_detector(
      .clk(clk), .rst(rst), .signal_in(uart_rx_in_synced), .edge_detected(start_detected));

   pos_edge_detector rising_edge_detector(
      .clk(clk), .rst(rst), .signal_in(uart_rx_in_synced), .edge_detected(rising_edge));

   assign shift_en = ((state > STATE_START) && (state < STATE_STOP) && half_bit && baud_rate_known) ? 1'b1:1'b0;
   shift_register #(.NUM_BITS(8), .RST_VALUE(0))
   shift_reg(
      .clk(clk), .rst(rst), .serial_in(uart_rx_in_synced), .shift_enable(shift_en),
      .parallel_in(8'h0), .load_enable(1'b0), .serial_out(), .parallel_out(data));

   assign timer_rst = ((state == STATE_IDLE) || (state == STATE_STOP && start_detected) || full_bit || rst) ? 1'b1:1'b0;
   assign half_bit = counter_val == cycles_per_bit >> 1 ? 1'b1 : 1'b0;
   assign full_bit = (counter_val >= cycles_per_bit) || (state == STATE_START && !baud_rate_known && rising_edge) ? 1'b1 : 1'b0;

   always @(posedge clk) begin
      if (rst) cycles_per_bit <= {COUNTER_WIDTH{1'b1}};
      else if (state == STATE_START && rising_edge) cycles_per_bit <= counter_val;
   end
   always @(posedge clk) begin
      if (timer_rst) counter_val <= {COUNTER_WIDTH{1'b0}};
      else counter_val <= counter_val + 1;
   end

   always @(posedge clk) begin
      if (rst || (state > STATE_STOP)) state <= STATE_IDLE;
      else if (start_detected && (state == STATE_IDLE || state == STATE_STOP)) state <= STATE_START;
      else if (full_bit)
         case (state)
            STATE_START: state <= STATE_D0;
            STATE_D0:    state <= STATE_D1;
            STATE_D1:    state <= STATE_D2;
            STATE_D2:    state <= STATE_D3;
            STATE_D3:    state <= STATE_D4;
            STATE_D4:    state <= STATE_D5;
            STATE_D5:    state <= STATE_D6;
            STATE_D6:    state <= STATE_D7;
            STATE_D7:    state <= STATE_STOP;
            STATE_STOP:  state <= STATE_IDLE;
            default:     state <= state;
         endcase
   end

   assign ready = (state == STATE_STOP && baud_rate_known) ? 1'b1:1'b0;

endmodule

// =============================================================================
// UART TX
// =============================================================================
module uart_tx #(
   parameter COUNTER_WIDTH = 24)
(
   input  wire clk,
   input  wire rst,
   output wire uart_tx_out,
   input  wire [7:0] data,
   input  wire req,
   input  wire [COUNTER_WIDTH-1:0] cycles_per_bit,
   output wire empty,
   output wire error);

   localparam STATE_IDLE  = 4'h0;
   localparam STATE_START = 4'h1;
   localparam STATE_D0    = 4'h2;
   localparam STATE_D1    = 4'h3;
   localparam STATE_D2    = 4'h4;
   localparam STATE_D3    = 4'h5;
   localparam STATE_D4    = 4'h6;
   localparam STATE_D5    = 4'h7;
   localparam STATE_D6    = 4'h8;
   localparam STATE_D7    = 4'h9;
   localparam STATE_STOP  = 4'hA;

   wire full_bit, idle_state;
   reg [COUNTER_WIDTH-1:0] counter_val;
   reg [3:0] state;

   assign idle_state = (state == STATE_IDLE) ? 1'b1:1'b0;

   shift_register #(.NUM_BITS(9), .RST_VALUE(1))
   shift_reg(
      .clk(clk), .rst(rst), .serial_in(1'b1), .shift_enable(full_bit),
      .parallel_in({data, 1'b0}), .load_enable(idle_state & req),
      .serial_out(uart_tx_out), .parallel_out());

   assign full_bit = (counter_val >= cycles_per_bit) ? 1'b1 : 1'b0;
   always @(posedge clk) begin
      if (full_bit || idle_state || rst) counter_val <= {COUNTER_WIDTH{1'b0}};
      else counter_val <= counter_val + 1;
   end

   always @(posedge clk) begin
      if (rst || (state > STATE_STOP)) state <= STATE_IDLE;
      else if (idle_state & req) state <= STATE_START;
      else if (full_bit)
         case (state)
            STATE_START: state <= STATE_D0;
            STATE_D0:    state <= STATE_D1;
            STATE_D1:    state <= STATE_D2;
            STATE_D2:    state <= STATE_D3;
            STATE_D3:    state <= STATE_D4;
            STATE_D4:    state <= STATE_D5;
            STATE_D5:    state <= STATE_D6;
            STATE_D6:    state <= STATE_D7;
            STATE_D7:    state <= STATE_STOP;
            STATE_STOP:  state <= STATE_IDLE;
            default:     state <= STATE_IDLE;
         endcase
   end

   assign empty = idle_state;
   assign error = ~idle_state & req;

endmodule

// =============================================================================
// UART Controller
// =============================================================================
module uart_ctrl #(
   parameter IMEM_BYTE_ADDR_WIDTH = 6,
   parameter DMEM_BYTE_ADDR_WIDTH = 6)
(
   input  wire clk,
   input  wire rst,
   input  wire rx_ready,
   input  wire tx_empty,
   input  wire tx_error,
   output wire cpu_rst,
   output reg  tx_req,
   output wire imem_ctrl,
   output wire imem_wr_en,
   output reg  [IMEM_BYTE_ADDR_WIDTH-1:0] imem_addr,
   output wire dmem_ctrl,
   output wire dmem_rd_en,
   output reg  [DMEM_BYTE_ADDR_WIDTH-1:0] dmem_addr);

   localparam NUM_IMEM_BYTES = 2**IMEM_BYTE_ADDR_WIDTH;
   localparam NUM_DMEM_BYTES = 2**DMEM_BYTE_ADDR_WIDTH;

   localparam STATE_RESET = 2'b00;
   localparam STATE_DATA_WRITE = 2'b01;
   localparam STATE_IDLE = 2'b10;
   localparam STATE_DATA_READ = 2'b11;

   wire rd_complete, wr_data_ready, all_imem_written, tx_ready;
   reg [1:0] state;

   assign rd_complete = ((state == STATE_DATA_READ) && (dmem_addr == NUM_DMEM_BYTES[DMEM_BYTE_ADDR_WIDTH-1:0]-1) && dmem_rd_en) ? 1'b1 : 1'b0;
   assign all_imem_written = ((state == STATE_DATA_WRITE) && (imem_addr == NUM_IMEM_BYTES[IMEM_BYTE_ADDR_WIDTH-1:0]-1) && imem_wr_en) ? 1'b1 : 1'b0;

   pos_edge_detector wr_data_ready_detect (
      .clk(clk), .rst(rst), .signal_in(rx_ready), .edge_detected(wr_data_ready));

   pos_edge_detector tx_ready_detect (
      .clk(clk), .rst(rst), .signal_in((state == STATE_DATA_READ) & tx_empty), .edge_detected(tx_ready));

   always @(posedge clk) begin
      if (rst) state <= STATE_RESET;
      else begin
         case (state)
            STATE_RESET:      if (!rst)             state <= STATE_DATA_WRITE;
            STATE_DATA_WRITE: if (all_imem_written) state <= STATE_IDLE;
            STATE_IDLE:       if (wr_data_ready)    state <= STATE_DATA_READ;
            STATE_DATA_READ:  if (rd_complete)      state <= STATE_IDLE;
         endcase
      end
   end

   always @(posedge clk) begin
      if (rst) imem_addr <= {IMEM_BYTE_ADDR_WIDTH{1'b0}};
      else if (state == STATE_RESET) imem_addr <= {IMEM_BYTE_ADDR_WIDTH{1'b0}};
      else if (state == STATE_IDLE)  imem_addr <= {IMEM_BYTE_ADDR_WIDTH{1'b0}};
      else if (state == STATE_DATA_WRITE && imem_wr_en) imem_addr <= imem_addr + 1;
   end

   always @(posedge clk) begin
      if (rst) dmem_addr <= {DMEM_BYTE_ADDR_WIDTH{1'b0}};
      else if (state == STATE_RESET) dmem_addr <= {DMEM_BYTE_ADDR_WIDTH{1'b0}};
      else if (state == STATE_IDLE)  dmem_addr <= {DMEM_BYTE_ADDR_WIDTH{1'b0}};
      else if (state == STATE_DATA_READ && tx_req) dmem_addr <= dmem_addr + 1;
   end

   always @(posedge clk) begin
      if (rst) tx_req <= 1'b0;
      else tx_req <= dmem_rd_en;
   end

   assign cpu_rst    = (state == STATE_RESET || state == STATE_DATA_WRITE || rst) ? 1'b1 : 1'b0;
   assign imem_ctrl  = cpu_rst;
   assign dmem_ctrl  = cpu_rst;
   assign dmem_rd_en = (state == STATE_DATA_READ && tx_ready) ? 1'b1 : 1'b0;
   assign imem_wr_en = (state == STATE_DATA_WRITE && wr_data_ready) ? 1'b1 : 1'b0;

endmodule

// =============================================================================
// UART Top
// =============================================================================
module uart_top #(
   parameter COUNTER_WIDTH = 24,
   parameter IMEM_BYTE_ADDR_WIDTH = 6,
   parameter DMEM_BYTE_ADDR_WIDTH = 6)
(
   input  wire clk,
   input  wire rst,
   input  wire rx_in,
   output wire tx_out,
   output wire cpu_rst,
   output wire imem_ctrl,
   output wire imem_wr_en,
   output wire [IMEM_BYTE_ADDR_WIDTH-3:0] imem_addr,
   output wire [3:0] imem_byte_en,
   output wire [31:0] imem_wr_data,
   output wire dmem_ctrl,
   output wire dmem_rd_en,
   output wire [DMEM_BYTE_ADDR_WIDTH-3:0] dmem_addr,
   input  wire [31:0] dmem_rd_data);

   wire rx_ready, tx_empty, tx_error, tx_req;
   wire [IMEM_BYTE_ADDR_WIDTH-1:0] imem_byte_addr;
   wire [DMEM_BYTE_ADDR_WIDTH-1:0] dmem_byte_addr;
   wire [7:0] rx_data, tx_data;
   wire [COUNTER_WIDTH-1:0] cycles_per_bit;

   uart_rx #(.COUNTER_WIDTH(COUNTER_WIDTH))
   uart_rx0 (.clk(clk), .rst(rst), .uart_rx_in(rx_in), .data(rx_data),
             .cycles_per_bit(cycles_per_bit), .ready(rx_ready));

   uart_tx #(.COUNTER_WIDTH(COUNTER_WIDTH))
   uart_tx0 (.clk(clk), .rst(rst), .uart_tx_out(tx_out), .data(tx_data),
             .req(tx_req), .cycles_per_bit(cycles_per_bit), .empty(tx_empty),
             .error(tx_error));

   uart_ctrl #(.IMEM_BYTE_ADDR_WIDTH(IMEM_BYTE_ADDR_WIDTH),
               .DMEM_BYTE_ADDR_WIDTH(DMEM_BYTE_ADDR_WIDTH))
   uart_ctrl0 (.clk(clk), .rst(rst), .rx_ready(rx_ready), .tx_empty(tx_empty),
               .tx_error(tx_error), .cpu_rst(cpu_rst), .tx_req(tx_req),
               .imem_ctrl(imem_ctrl), .imem_wr_en(imem_wr_en),
               .imem_addr(imem_byte_addr), .dmem_ctrl(dmem_ctrl),
               .dmem_rd_en(dmem_rd_en), .dmem_addr(dmem_byte_addr));

   byte_to_word #(.BYTE_ADDR_WIDTH(IMEM_BYTE_ADDR_WIDTH))
   byte_to_word0 (.byte_addr_in(imem_byte_addr), .byte_data_in(rx_data),
                  .word_addr_out(imem_addr), .word_byte_en_out(imem_byte_en),
                  .word_data_out(imem_wr_data));

   word_to_byte #(.BYTE_ADDR_WIDTH(DMEM_BYTE_ADDR_WIDTH))
   word_to_byte0 (.byte_addr_in(dmem_byte_addr), .byte_data_out(tx_data),
                  .word_addr_out(dmem_addr), .word_data_in(dmem_rd_data));

endmodule

//_\TLV_version 1d: tl-x.org, generated by SandPiper(TM) 1.14-2022/10/10-beta-Pro
//_\source top.tlv 81

//_\SV
   // Include Tiny Tapeout Lab.
   // Included URL: "https://raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/35e36bd144fddd75495d4cbc01c4fc50ac5bde6f/tlv_lib/tiny_tapeout_lib.tlv"// Included URL: "https://raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlv_lib/fpga_includes.tlv"
   // Included URL: "https://raw.githubusercontent.com/efabless/chipcraft---mest-course/main/tlv_lib/risc-v_shell_lib.tlv"// Included URL: "https://raw.githubusercontent.com/stevehoover/warp-v_includes/450357b4993fa480e7fca57dc346e39cba21b6bc/risc-v_defs.tlv"

   // Include CPU Design
   // Included URL: "https://raw.githubusercontent.com/enieman/uart_programmable_rv32i/main/src/tlv/cpu_custom.tlv"
//_\source top.tlv 140

//_\SV




// Provide a wrapper module to debounce input signals if requested.

//_\SV



// =======================
// The Tiny Tapeout module
// =======================

module tt_um_enieman (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
       // The FPGA is based on TinyTapeout 3 which has no bidirectional I/Os (vs. TT6 for the ASIC).
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
   

   // UART Connections
   

   // Parameters for Memory Sizing and UART Baud
   localparam COUNTER_WIDTH = 16;       // Width of the clock counters in the UART RX and TX modules; at 50MHz, 16 bits should allow baud as low as 763
   localparam IMEM_BYTE_ADDR_WIDTH = 4 + 2; // 64 bytes / 16 words of I-Memory
   localparam DMEM_BYTE_ADDR_WIDTH = 2 + 2; // 16 bytes /  4 words of D-Memory
   // CPU Reset
   wire reset;

   // User Interface
   wire rst = ! rst_n | ui_in[7]; // Provide a dedicated button input for RESET
   wire rx_in = ui_in[2];         // Should be wired to Pin 2 of the USBUART Pmod (data from host to Pmod)
   wire tx_out;
   assign uo_out[7] = rst;        // Feedback of RST button, intended to use with LED
   assign uo_out[6] = reset;      // Feedback of CPU reset, indicates if UART controller is in write mode (reset = 1) or read mode (reset = 0)
   assign uo_out[5] = ~rx_in;     // Feedback of RX line, intended to use with LED
   assign uo_out[4] = ~tx_out;    // Feedback of TX line, intended to use with LED
   assign uo_out[3] = 1'b0;       // Unused
   assign uo_out[2] = tx_out;     // Should be wired to Pin 3 of the USBUART Pmod (data from Pmod to host)
   assign uo_out[1] = 1'b0;       // Unused
   assign uo_out[0] = 1'b0;       // Unused

   // I-Memory Interface
   wire uart_imem_ctrl;
   wire imem_rd_en, uart_imem_wr_en;
   wire [IMEM_BYTE_ADDR_WIDTH-3:0] imem_rd_addr, uart_imem_addr;
   wire [3:0] uart_imem_byte_en;
   wire [31:0] imem_rd_data, uart_imem_wr_data;

   // D-Memory Interface
   wire dmem_rd_en, dmem_wr_en, uart_dmem_rd_en;
   wire [DMEM_BYTE_ADDR_WIDTH-3:0] dmem_addr, uart_dmem_addr;
   wire [3:0] dmem_wr_byte_en;
   wire [31:0] dmem_wr_data, dmem_rd_data, uart_dmem_rd_data;

   // UART Module
   uart_top #(
      .COUNTER_WIDTH(COUNTER_WIDTH),
      .IMEM_BYTE_ADDR_WIDTH(IMEM_BYTE_ADDR_WIDTH),
      .DMEM_BYTE_ADDR_WIDTH(DMEM_BYTE_ADDR_WIDTH))
   uart_top0 (
      .clk(clk),
      .rst(rst),
      .rx_in(rx_in),
      .tx_out(tx_out),
      .cpu_rst(reset),
      .imem_ctrl(uart_imem_ctrl),
      .imem_wr_en(uart_imem_wr_en),
      .imem_addr(uart_imem_addr),
      .imem_byte_en(uart_imem_byte_en),
      .imem_wr_data(uart_imem_wr_data),
      .dmem_ctrl(),
      .dmem_rd_en(uart_dmem_rd_en),
      .dmem_addr(uart_dmem_addr),
      .dmem_rd_data(uart_dmem_rd_data));

   // I-Memory
   reg_file #(
      .BYTE_ADDR_WIDTH(IMEM_BYTE_ADDR_WIDTH))
   imem0 (
      .clk(clk),
      .rst(rst),
      .rd_en0(uart_imem_ctrl ? 1'b0 : imem_rd_en),
      .rd_addr0(uart_imem_ctrl ? {(IMEM_BYTE_ADDR_WIDTH-2){1'b0}} : imem_rd_addr),
      .rd_data0(imem_rd_data),
      .rd_en1(1'b0),
      .rd_addr1({(IMEM_BYTE_ADDR_WIDTH-2){1'b0}}),
      .rd_data1(),
      .wr_en(uart_imem_ctrl ? uart_imem_wr_en : 1'b0),
      .wr_addr(uart_imem_ctrl ? uart_imem_addr : {(IMEM_BYTE_ADDR_WIDTH-2){1'b0}}),
      .byte_en(uart_imem_ctrl ? uart_imem_byte_en : 4'h0),
      .wr_data(uart_imem_ctrl ? uart_imem_wr_data : 32'h0));

   // D-Memory
   reg_file #(
      .BYTE_ADDR_WIDTH(DMEM_BYTE_ADDR_WIDTH))
   dmem0 (
      .clk(clk),
      .rst(rst),
      .rd_en0(dmem_rd_en),
      .rd_addr0(dmem_addr),
      .rd_data0(dmem_rd_data),
      .rd_en1(uart_dmem_rd_en),
      .rd_addr1(uart_dmem_addr),
      .rd_data1(uart_dmem_rd_data),
      .wr_en(dmem_wr_en),
      .wr_addr(dmem_addr),
      .byte_en(dmem_wr_byte_en),
      .wr_data(dmem_wr_data));

   

// ---------- Generated Code Inlined Here (before 1st \TLV) ----------
// Generated by SandPiper(TM) 1.14-2022/10/10-beta-Pro from Redwood EDA, LLC.
// (Installed here: /usr/local/mono/sandpiper/distro.)
// Redwood EDA, LLC does not claim intellectual property rights to this file and provides no warranty regarding its correctness or quality.


// For silencing unused signal messages.
`define BOGUS_USE(ignore)


genvar digit, input_label, leds, switch, xreg;


//
// Signals declared top-level.
//

// For $slideswitch.
wire [7:0] L0_slideswitch_a0;

// For $sseg_decimal_point_n.
wire L0_sseg_decimal_point_n_a0;

// For $sseg_digit_n.
wire [7:0] L0_sseg_digit_n_a0;

// For $sseg_segment_n.
wire [6:0] L0_sseg_segment_n_a0;

// For /fpga_pins/fpga|cpu$alu_op1.
wire [31:0] FpgaPins_Fpga_CPU_alu_op1_a2;
reg  [31:0] FpgaPins_Fpga_CPU_alu_op1_a3;

// For /fpga_pins/fpga|cpu$alu_op2.
wire [31:0] FpgaPins_Fpga_CPU_alu_op2_a2;
reg  [31:0] FpgaPins_Fpga_CPU_alu_op2_a3;

// For /fpga_pins/fpga|cpu$funct3.
wire [2:0] FpgaPins_Fpga_CPU_funct3_a1;

// For /fpga_pins/fpga|cpu$funct7.
wire [6:0] FpgaPins_Fpga_CPU_funct7_a1;

// For /fpga_pins/fpga|cpu$imm.
wire [31:0] FpgaPins_Fpga_CPU_imm_a1;
reg  [31:0] FpgaPins_Fpga_CPU_imm_a2;

// For /fpga_pins/fpga|cpu$inc_pc.
wire [31:0] FpgaPins_Fpga_CPU_inc_pc_a1;
reg  [31:0] FpgaPins_Fpga_CPU_inc_pc_a2,
            FpgaPins_Fpga_CPU_inc_pc_a3;

// For /fpga_pins/fpga|cpu$instr.
wire [31:0] FpgaPins_Fpga_CPU_instr_a1;

// For /fpga_pins/fpga|cpu$is_add.
wire FpgaPins_Fpga_CPU_is_add_a1;

// For /fpga_pins/fpga|cpu$is_add_op.
wire FpgaPins_Fpga_CPU_is_add_op_a1;
reg  FpgaPins_Fpga_CPU_is_add_op_a2,
     FpgaPins_Fpga_CPU_is_add_op_a3;

// For /fpga_pins/fpga|cpu$is_addi.
wire FpgaPins_Fpga_CPU_is_addi_a1;

// For /fpga_pins/fpga|cpu$is_and.
wire FpgaPins_Fpga_CPU_is_and_a1;

// For /fpga_pins/fpga|cpu$is_and_op.
wire FpgaPins_Fpga_CPU_is_and_op_a1;
reg  FpgaPins_Fpga_CPU_is_and_op_a2,
     FpgaPins_Fpga_CPU_is_and_op_a3;

// For /fpga_pins/fpga|cpu$is_andi.
wire FpgaPins_Fpga_CPU_is_andi_a1;

// For /fpga_pins/fpga|cpu$is_auipc.
wire FpgaPins_Fpga_CPU_is_auipc_a1;
reg  FpgaPins_Fpga_CPU_is_auipc_a2;

// For /fpga_pins/fpga|cpu$is_b_instr.
wire FpgaPins_Fpga_CPU_is_b_instr_a1;
reg  FpgaPins_Fpga_CPU_is_b_instr_a2;

// For /fpga_pins/fpga|cpu$is_beq.
wire FpgaPins_Fpga_CPU_is_beq_a1;
reg  FpgaPins_Fpga_CPU_is_beq_a2,
     FpgaPins_Fpga_CPU_is_beq_a3;

// For /fpga_pins/fpga|cpu$is_bge.
wire FpgaPins_Fpga_CPU_is_bge_a1;
reg  FpgaPins_Fpga_CPU_is_bge_a2,
     FpgaPins_Fpga_CPU_is_bge_a3;

// For /fpga_pins/fpga|cpu$is_bgeu.
wire FpgaPins_Fpga_CPU_is_bgeu_a1;
reg  FpgaPins_Fpga_CPU_is_bgeu_a2,
     FpgaPins_Fpga_CPU_is_bgeu_a3;

// For /fpga_pins/fpga|cpu$is_blt.
wire FpgaPins_Fpga_CPU_is_blt_a1;
reg  FpgaPins_Fpga_CPU_is_blt_a2,
     FpgaPins_Fpga_CPU_is_blt_a3;

// For /fpga_pins/fpga|cpu$is_bltu.
wire FpgaPins_Fpga_CPU_is_bltu_a1;
reg  FpgaPins_Fpga_CPU_is_bltu_a2,
     FpgaPins_Fpga_CPU_is_bltu_a3;

// For /fpga_pins/fpga|cpu$is_bne.
wire FpgaPins_Fpga_CPU_is_bne_a1;
reg  FpgaPins_Fpga_CPU_is_bne_a2,
     FpgaPins_Fpga_CPU_is_bne_a3;

// For /fpga_pins/fpga|cpu$is_i_instr.
wire FpgaPins_Fpga_CPU_is_i_instr_a1;

// For /fpga_pins/fpga|cpu$is_j_instr.
wire FpgaPins_Fpga_CPU_is_j_instr_a1;

// For /fpga_pins/fpga|cpu$is_jal.
wire FpgaPins_Fpga_CPU_is_jal_a1;

// For /fpga_pins/fpga|cpu$is_jalr.
wire FpgaPins_Fpga_CPU_is_jalr_a1;
reg  FpgaPins_Fpga_CPU_is_jalr_a2;

// For /fpga_pins/fpga|cpu$is_jump.
wire FpgaPins_Fpga_CPU_is_jump_a1;
reg  FpgaPins_Fpga_CPU_is_jump_a2,
     FpgaPins_Fpga_CPU_is_jump_a3;

// For /fpga_pins/fpga|cpu$is_lb.
wire FpgaPins_Fpga_CPU_is_lb_a1;

// For /fpga_pins/fpga|cpu$is_lbu.
wire FpgaPins_Fpga_CPU_is_lbu_a1;

// For /fpga_pins/fpga|cpu$is_lh.
wire FpgaPins_Fpga_CPU_is_lh_a1;

// For /fpga_pins/fpga|cpu$is_lhu.
wire FpgaPins_Fpga_CPU_is_lhu_a1;

// For /fpga_pins/fpga|cpu$is_load.
wire FpgaPins_Fpga_CPU_is_load_a1;
reg  FpgaPins_Fpga_CPU_is_load_a2,
     FpgaPins_Fpga_CPU_is_load_a3;

// For /fpga_pins/fpga|cpu$is_lui.
wire FpgaPins_Fpga_CPU_is_lui_a1;
reg  FpgaPins_Fpga_CPU_is_lui_a2,
     FpgaPins_Fpga_CPU_is_lui_a3;

// For /fpga_pins/fpga|cpu$is_lw.
wire FpgaPins_Fpga_CPU_is_lw_a1;

// For /fpga_pins/fpga|cpu$is_or.
wire FpgaPins_Fpga_CPU_is_or_a1;

// For /fpga_pins/fpga|cpu$is_or_op.
wire FpgaPins_Fpga_CPU_is_or_op_a1;
reg  FpgaPins_Fpga_CPU_is_or_op_a2,
     FpgaPins_Fpga_CPU_is_or_op_a3;

// For /fpga_pins/fpga|cpu$is_ori.
wire FpgaPins_Fpga_CPU_is_ori_a1;

// For /fpga_pins/fpga|cpu$is_r_instr.
wire FpgaPins_Fpga_CPU_is_r_instr_a1;
reg  FpgaPins_Fpga_CPU_is_r_instr_a2;

// For /fpga_pins/fpga|cpu$is_s_instr.
wire FpgaPins_Fpga_CPU_is_s_instr_a1;

// For /fpga_pins/fpga|cpu$is_sb.
wire FpgaPins_Fpga_CPU_is_sb_a1;

// For /fpga_pins/fpga|cpu$is_sh.
wire FpgaPins_Fpga_CPU_is_sh_a1;

// For /fpga_pins/fpga|cpu$is_sll.
wire FpgaPins_Fpga_CPU_is_sll_a1;

// For /fpga_pins/fpga|cpu$is_sll_op.
wire FpgaPins_Fpga_CPU_is_sll_op_a1;
reg  FpgaPins_Fpga_CPU_is_sll_op_a2,
     FpgaPins_Fpga_CPU_is_sll_op_a3;

// For /fpga_pins/fpga|cpu$is_slli.
wire FpgaPins_Fpga_CPU_is_slli_a1;

// For /fpga_pins/fpga|cpu$is_slt.
wire FpgaPins_Fpga_CPU_is_slt_a1;

// For /fpga_pins/fpga|cpu$is_slt_op.
wire FpgaPins_Fpga_CPU_is_slt_op_a1;
reg  FpgaPins_Fpga_CPU_is_slt_op_a2,
     FpgaPins_Fpga_CPU_is_slt_op_a3;

// For /fpga_pins/fpga|cpu$is_slti.
wire FpgaPins_Fpga_CPU_is_slti_a1;

// For /fpga_pins/fpga|cpu$is_sltiu.
wire FpgaPins_Fpga_CPU_is_sltiu_a1;

// For /fpga_pins/fpga|cpu$is_sltu.
wire FpgaPins_Fpga_CPU_is_sltu_a1;

// For /fpga_pins/fpga|cpu$is_sltu_op.
wire FpgaPins_Fpga_CPU_is_sltu_op_a1;
reg  FpgaPins_Fpga_CPU_is_sltu_op_a2,
     FpgaPins_Fpga_CPU_is_sltu_op_a3;

// For /fpga_pins/fpga|cpu$is_sra.
wire FpgaPins_Fpga_CPU_is_sra_a1;

// For /fpga_pins/fpga|cpu$is_sra_op.
wire FpgaPins_Fpga_CPU_is_sra_op_a1;
reg  FpgaPins_Fpga_CPU_is_sra_op_a2,
     FpgaPins_Fpga_CPU_is_sra_op_a3;

// For /fpga_pins/fpga|cpu$is_srai.
wire FpgaPins_Fpga_CPU_is_srai_a1;

// For /fpga_pins/fpga|cpu$is_srl.
wire FpgaPins_Fpga_CPU_is_srl_a1;

// For /fpga_pins/fpga|cpu$is_srl_op.
wire FpgaPins_Fpga_CPU_is_srl_op_a1;
reg  FpgaPins_Fpga_CPU_is_srl_op_a2,
     FpgaPins_Fpga_CPU_is_srl_op_a3;

// For /fpga_pins/fpga|cpu$is_srli.
wire FpgaPins_Fpga_CPU_is_srli_a1;

// For /fpga_pins/fpga|cpu$is_store.
wire FpgaPins_Fpga_CPU_is_store_a1;
reg  FpgaPins_Fpga_CPU_is_store_a2,
     FpgaPins_Fpga_CPU_is_store_a3;

// For /fpga_pins/fpga|cpu$is_sub.
wire FpgaPins_Fpga_CPU_is_sub_a1;
reg  FpgaPins_Fpga_CPU_is_sub_a2,
     FpgaPins_Fpga_CPU_is_sub_a3;

// For /fpga_pins/fpga|cpu$is_sw.
wire FpgaPins_Fpga_CPU_is_sw_a1;

// For /fpga_pins/fpga|cpu$is_u_instr.
wire FpgaPins_Fpga_CPU_is_u_instr_a1;

// For /fpga_pins/fpga|cpu$is_xor.
wire FpgaPins_Fpga_CPU_is_xor_a1;

// For /fpga_pins/fpga|cpu$is_xor_op.
wire FpgaPins_Fpga_CPU_is_xor_op_a1;
reg  FpgaPins_Fpga_CPU_is_xor_op_a2,
     FpgaPins_Fpga_CPU_is_xor_op_a3;

// For /fpga_pins/fpga|cpu$is_xori.
wire FpgaPins_Fpga_CPU_is_xori_a1;

// For /fpga_pins/fpga|cpu$ld_data.
wire [31:0] FpgaPins_Fpga_CPU_ld_data_a5;

// For /fpga_pins/fpga|cpu$opcode.
wire [6:0] FpgaPins_Fpga_CPU_opcode_a1;

// For /fpga_pins/fpga|cpu$pc.
wire [31:0] FpgaPins_Fpga_CPU_pc_a0;
reg  [31:0] FpgaPins_Fpga_CPU_pc_a1,
            FpgaPins_Fpga_CPU_pc_a2;

// For /fpga_pins/fpga|cpu$rd.
wire [4:0] FpgaPins_Fpga_CPU_rd_a1;
reg  [4:0] FpgaPins_Fpga_CPU_rd_a2,
           FpgaPins_Fpga_CPU_rd_a3,
           FpgaPins_Fpga_CPU_rd_a4,
           FpgaPins_Fpga_CPU_rd_a5;

// For /fpga_pins/fpga|cpu$rd_valid.
wire FpgaPins_Fpga_CPU_rd_valid_a1;
reg  FpgaPins_Fpga_CPU_rd_valid_a2,
     FpgaPins_Fpga_CPU_rd_valid_a3;

// For /fpga_pins/fpga|cpu$reset.
wire FpgaPins_Fpga_CPU_reset_a0;
reg  FpgaPins_Fpga_CPU_reset_a1,
     FpgaPins_Fpga_CPU_reset_a2,
     FpgaPins_Fpga_CPU_reset_a3;

// For /fpga_pins/fpga|cpu$result.
wire [31:0] FpgaPins_Fpga_CPU_result_a3;
reg  [3:2] FpgaPins_Fpga_CPU_result_a4;

// For /fpga_pins/fpga|cpu$rf_rd_data1.
wire [31:0] FpgaPins_Fpga_CPU_rf_rd_data1_a2;

// For /fpga_pins/fpga|cpu$rf_rd_data2.
wire [31:0] FpgaPins_Fpga_CPU_rf_rd_data2_a2;

// For /fpga_pins/fpga|cpu$rf_rd_en1.
wire FpgaPins_Fpga_CPU_rf_rd_en1_a2;

// For /fpga_pins/fpga|cpu$rf_rd_en2.
wire FpgaPins_Fpga_CPU_rf_rd_en2_a2;

// For /fpga_pins/fpga|cpu$rf_rd_index1.
wire [4:0] FpgaPins_Fpga_CPU_rf_rd_index1_a2;

// For /fpga_pins/fpga|cpu$rf_rd_index2.
wire [4:0] FpgaPins_Fpga_CPU_rf_rd_index2_a2;

// For /fpga_pins/fpga|cpu$rf_wr_data.
wire [31:0] FpgaPins_Fpga_CPU_rf_wr_data_a3;

// For /fpga_pins/fpga|cpu$rf_wr_en.
wire FpgaPins_Fpga_CPU_rf_wr_en_a3;

// For /fpga_pins/fpga|cpu$rf_wr_index.
wire [4:0] FpgaPins_Fpga_CPU_rf_wr_index_a3;

// For /fpga_pins/fpga|cpu$rs1.
wire [4:0] FpgaPins_Fpga_CPU_rs1_a1;
reg  [4:0] FpgaPins_Fpga_CPU_rs1_a2;

// For /fpga_pins/fpga|cpu$rs1_valid.
wire FpgaPins_Fpga_CPU_rs1_valid_a1;
reg  FpgaPins_Fpga_CPU_rs1_valid_a2;

// For /fpga_pins/fpga|cpu$rs2.
wire [4:0] FpgaPins_Fpga_CPU_rs2_a1;
reg  [4:0] FpgaPins_Fpga_CPU_rs2_a2;

// For /fpga_pins/fpga|cpu$rs2_valid.
wire FpgaPins_Fpga_CPU_rs2_valid_a1;
reg  FpgaPins_Fpga_CPU_rs2_valid_a2;

// For /fpga_pins/fpga|cpu$sltu_result.
wire [31:0] FpgaPins_Fpga_CPU_sltu_result_a3;

// For /fpga_pins/fpga|cpu$sra_result.
wire [63:0] FpgaPins_Fpga_CPU_sra_result_a3;

// For /fpga_pins/fpga|cpu$src1_value.
wire [31:0] FpgaPins_Fpga_CPU_src1_value_a2;

// For /fpga_pins/fpga|cpu$src2_value.
wire [31:0] FpgaPins_Fpga_CPU_src2_value_a2;
reg  [31:0] FpgaPins_Fpga_CPU_src2_value_a3,
            FpgaPins_Fpga_CPU_src2_value_a4;

// For /fpga_pins/fpga|cpu$tgt_pc.
wire [31:0] FpgaPins_Fpga_CPU_tgt_pc_a3;

// For /fpga_pins/fpga|cpu$tgt_pc_op1.
wire [31:0] FpgaPins_Fpga_CPU_tgt_pc_op1_a2;
reg  [31:0] FpgaPins_Fpga_CPU_tgt_pc_op1_a3;

// For /fpga_pins/fpga|cpu$tgt_pc_op2.
wire [31:0] FpgaPins_Fpga_CPU_tgt_pc_op2_a2;
reg  [31:0] FpgaPins_Fpga_CPU_tgt_pc_op2_a3;

// For /fpga_pins/fpga|cpu$valid.
wire FpgaPins_Fpga_CPU_valid_a3;

// For /fpga_pins/fpga|cpu$valid_jump.
wire FpgaPins_Fpga_CPU_valid_jump_a3;
reg  FpgaPins_Fpga_CPU_valid_jump_a4,
     FpgaPins_Fpga_CPU_valid_jump_a5;

// For /fpga_pins/fpga|cpu$valid_load.
wire FpgaPins_Fpga_CPU_valid_load_a3;
reg  FpgaPins_Fpga_CPU_valid_load_a4,
     FpgaPins_Fpga_CPU_valid_load_a5;

// For /fpga_pins/fpga|cpu$valid_store.
wire FpgaPins_Fpga_CPU_valid_store_a3;
reg  FpgaPins_Fpga_CPU_valid_store_a4;

// For /fpga_pins/fpga|cpu$valid_taken_br.
wire FpgaPins_Fpga_CPU_valid_taken_br_a3;
reg  FpgaPins_Fpga_CPU_valid_taken_br_a4,
     FpgaPins_Fpga_CPU_valid_taken_br_a5;

// For /fpga_pins/fpga|cpu$valid_tgt_pc.
wire FpgaPins_Fpga_CPU_valid_tgt_pc_a3;

// For /fpga_pins/fpga|cpu/xreg$value.
wire [31:0] FpgaPins_Fpga_CPU_Xreg_value_a3 [15:0];
reg  [31:0] FpgaPins_Fpga_CPU_Xreg_value_a4 [15:0];




   //
   // Scope: /fpga_pins
   //


      //
      // Scope: /fpga
      //


         //
         // Scope: |cpu
         //

            // Staging of $alu_op1.
            always @(posedge clk) FpgaPins_Fpga_CPU_alu_op1_a3[31:0] <= FpgaPins_Fpga_CPU_alu_op1_a2[31:0];

            // Staging of $alu_op2.
            always @(posedge clk) FpgaPins_Fpga_CPU_alu_op2_a3[31:0] <= FpgaPins_Fpga_CPU_alu_op2_a2[31:0];

            // Staging of $imm.
            always @(posedge clk) FpgaPins_Fpga_CPU_imm_a2[31:0] <= FpgaPins_Fpga_CPU_imm_a1[31:0];

            // Staging of $inc_pc.
            always @(posedge clk) FpgaPins_Fpga_CPU_inc_pc_a2[31:0] <= FpgaPins_Fpga_CPU_inc_pc_a1[31:0];
            always @(posedge clk) FpgaPins_Fpga_CPU_inc_pc_a3[31:0] <= FpgaPins_Fpga_CPU_inc_pc_a2[31:0];

            // Staging of $is_add_op.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_add_op_a2 <= FpgaPins_Fpga_CPU_is_add_op_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_add_op_a3 <= FpgaPins_Fpga_CPU_is_add_op_a2;

            // Staging of $is_and_op.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_and_op_a2 <= FpgaPins_Fpga_CPU_is_and_op_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_and_op_a3 <= FpgaPins_Fpga_CPU_is_and_op_a2;

            // Staging of $is_auipc.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_auipc_a2 <= FpgaPins_Fpga_CPU_is_auipc_a1;

            // Staging of $is_b_instr.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_b_instr_a2 <= FpgaPins_Fpga_CPU_is_b_instr_a1;

            // Staging of $is_beq.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_beq_a2 <= FpgaPins_Fpga_CPU_is_beq_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_beq_a3 <= FpgaPins_Fpga_CPU_is_beq_a2;

            // Staging of $is_bge.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_bge_a2 <= FpgaPins_Fpga_CPU_is_bge_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_bge_a3 <= FpgaPins_Fpga_CPU_is_bge_a2;

            // Staging of $is_bgeu.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_bgeu_a2 <= FpgaPins_Fpga_CPU_is_bgeu_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_bgeu_a3 <= FpgaPins_Fpga_CPU_is_bgeu_a2;

            // Staging of $is_blt.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_blt_a2 <= FpgaPins_Fpga_CPU_is_blt_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_blt_a3 <= FpgaPins_Fpga_CPU_is_blt_a2;

            // Staging of $is_bltu.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_bltu_a2 <= FpgaPins_Fpga_CPU_is_bltu_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_bltu_a3 <= FpgaPins_Fpga_CPU_is_bltu_a2;

            // Staging of $is_bne.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_bne_a2 <= FpgaPins_Fpga_CPU_is_bne_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_bne_a3 <= FpgaPins_Fpga_CPU_is_bne_a2;

            // Staging of $is_jalr.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_jalr_a2 <= FpgaPins_Fpga_CPU_is_jalr_a1;

            // Staging of $is_jump.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_jump_a2 <= FpgaPins_Fpga_CPU_is_jump_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_jump_a3 <= FpgaPins_Fpga_CPU_is_jump_a2;

            // Staging of $is_load.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_load_a2 <= FpgaPins_Fpga_CPU_is_load_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_load_a3 <= FpgaPins_Fpga_CPU_is_load_a2;

            // Staging of $is_lui.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_lui_a2 <= FpgaPins_Fpga_CPU_is_lui_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_lui_a3 <= FpgaPins_Fpga_CPU_is_lui_a2;

            // Staging of $is_or_op.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_or_op_a2 <= FpgaPins_Fpga_CPU_is_or_op_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_or_op_a3 <= FpgaPins_Fpga_CPU_is_or_op_a2;

            // Staging of $is_r_instr.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_r_instr_a2 <= FpgaPins_Fpga_CPU_is_r_instr_a1;

            // Staging of $is_sll_op.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_sll_op_a2 <= FpgaPins_Fpga_CPU_is_sll_op_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_sll_op_a3 <= FpgaPins_Fpga_CPU_is_sll_op_a2;

            // Staging of $is_slt_op.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_slt_op_a2 <= FpgaPins_Fpga_CPU_is_slt_op_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_slt_op_a3 <= FpgaPins_Fpga_CPU_is_slt_op_a2;

            // Staging of $is_sltu_op.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_sltu_op_a2 <= FpgaPins_Fpga_CPU_is_sltu_op_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_sltu_op_a3 <= FpgaPins_Fpga_CPU_is_sltu_op_a2;

            // Staging of $is_sra_op.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_sra_op_a2 <= FpgaPins_Fpga_CPU_is_sra_op_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_sra_op_a3 <= FpgaPins_Fpga_CPU_is_sra_op_a2;

            // Staging of $is_srl_op.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_srl_op_a2 <= FpgaPins_Fpga_CPU_is_srl_op_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_srl_op_a3 <= FpgaPins_Fpga_CPU_is_srl_op_a2;

            // Staging of $is_store.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_store_a2 <= FpgaPins_Fpga_CPU_is_store_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_store_a3 <= FpgaPins_Fpga_CPU_is_store_a2;

            // Staging of $is_sub.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_sub_a2 <= FpgaPins_Fpga_CPU_is_sub_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_sub_a3 <= FpgaPins_Fpga_CPU_is_sub_a2;

            // Staging of $is_xor_op.
            always @(posedge clk) FpgaPins_Fpga_CPU_is_xor_op_a2 <= FpgaPins_Fpga_CPU_is_xor_op_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_is_xor_op_a3 <= FpgaPins_Fpga_CPU_is_xor_op_a2;

            // Staging of $pc.
            always @(posedge clk) FpgaPins_Fpga_CPU_pc_a1[31:0] <= FpgaPins_Fpga_CPU_pc_a0[31:0];
            always @(posedge clk) FpgaPins_Fpga_CPU_pc_a2[31:0] <= FpgaPins_Fpga_CPU_pc_a1[31:0];

            // Staging of $rd.
            always @(posedge clk) FpgaPins_Fpga_CPU_rd_a2[4:0] <= FpgaPins_Fpga_CPU_rd_a1[4:0];
            always @(posedge clk) FpgaPins_Fpga_CPU_rd_a3[4:0] <= FpgaPins_Fpga_CPU_rd_a2[4:0];
            always @(posedge clk) FpgaPins_Fpga_CPU_rd_a4[4:0] <= FpgaPins_Fpga_CPU_rd_a3[4:0];
            always @(posedge clk) FpgaPins_Fpga_CPU_rd_a5[4:0] <= FpgaPins_Fpga_CPU_rd_a4[4:0];

            // Staging of $rd_valid.
            always @(posedge clk) FpgaPins_Fpga_CPU_rd_valid_a2 <= FpgaPins_Fpga_CPU_rd_valid_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_rd_valid_a3 <= FpgaPins_Fpga_CPU_rd_valid_a2;

            // Staging of $reset.
            always @(posedge clk) FpgaPins_Fpga_CPU_reset_a1 <= FpgaPins_Fpga_CPU_reset_a0;
            always @(posedge clk) FpgaPins_Fpga_CPU_reset_a2 <= FpgaPins_Fpga_CPU_reset_a1;
            always @(posedge clk) FpgaPins_Fpga_CPU_reset_a3 <= FpgaPins_Fpga_CPU_reset_a2;

            // Staging of $result.
            always @(posedge clk) FpgaPins_Fpga_CPU_result_a4[3:2] <= FpgaPins_Fpga_CPU_result_a3[3:2];

            // Staging of $rs1.
            always @(posedge clk) FpgaPins_Fpga_CPU_rs1_a2[4:0] <= FpgaPins_Fpga_CPU_rs1_a1[4:0];

            // Staging of $rs1_valid.
            always @(posedge clk) FpgaPins_Fpga_CPU_rs1_valid_a2 <= FpgaPins_Fpga_CPU_rs1_valid_a1;

            // Staging of $rs2.
            always @(posedge clk) FpgaPins_Fpga_CPU_rs2_a2[4:0] <= FpgaPins_Fpga_CPU_rs2_a1[4:0];

            // Staging of $rs2_valid.
            always @(posedge clk) FpgaPins_Fpga_CPU_rs2_valid_a2 <= FpgaPins_Fpga_CPU_rs2_valid_a1;

            // Staging of $src2_value.
            always @(posedge clk) FpgaPins_Fpga_CPU_src2_value_a3[31:0] <= FpgaPins_Fpga_CPU_src2_value_a2[31:0];
            always @(posedge clk) FpgaPins_Fpga_CPU_src2_value_a4[31:0] <= FpgaPins_Fpga_CPU_src2_value_a3[31:0];

            // Staging of $tgt_pc_op1.
            always @(posedge clk) FpgaPins_Fpga_CPU_tgt_pc_op1_a3[31:0] <= FpgaPins_Fpga_CPU_tgt_pc_op1_a2[31:0];

            // Staging of $tgt_pc_op2.
            always @(posedge clk) FpgaPins_Fpga_CPU_tgt_pc_op2_a3[31:0] <= FpgaPins_Fpga_CPU_tgt_pc_op2_a2[31:0];

            // Staging of $valid_jump.
            always @(posedge clk) FpgaPins_Fpga_CPU_valid_jump_a4 <= FpgaPins_Fpga_CPU_valid_jump_a3;
            always @(posedge clk) FpgaPins_Fpga_CPU_valid_jump_a5 <= FpgaPins_Fpga_CPU_valid_jump_a4;

            // Staging of $valid_load.
            always @(posedge clk) FpgaPins_Fpga_CPU_valid_load_a4 <= FpgaPins_Fpga_CPU_valid_load_a3;
            always @(posedge clk) FpgaPins_Fpga_CPU_valid_load_a5 <= FpgaPins_Fpga_CPU_valid_load_a4;

            // Staging of $valid_store.
            always @(posedge clk) FpgaPins_Fpga_CPU_valid_store_a4 <= FpgaPins_Fpga_CPU_valid_store_a3;

            // Staging of $valid_taken_br.
            always @(posedge clk) FpgaPins_Fpga_CPU_valid_taken_br_a4 <= FpgaPins_Fpga_CPU_valid_taken_br_a3;
            always @(posedge clk) FpgaPins_Fpga_CPU_valid_taken_br_a5 <= FpgaPins_Fpga_CPU_valid_taken_br_a4;


            //
            // Scope: /xreg[15:0]
            //
            generate for (xreg = 0; xreg <= 15; xreg=xreg+1) begin : L1gen_FpgaPins_Fpga_CPU_Xreg
               // Staging of $value.
               always @(posedge clk) FpgaPins_Fpga_CPU_Xreg_value_a4[xreg][31:0] <= FpgaPins_Fpga_CPU_Xreg_value_a3[xreg][31:0];

            end endgenerate




/* ----------------------------------------------------------------- COMMENTING OUT DEBUG SIGNALS AFTER MAKERCHIP COMPILE; DEBUG SIGNALS TAKE UP RESOURCES IN SYNTHESIS -----------------------------------------------------------------


//
// Debug Signals
//

generate

   if (1) begin : DEBUG_SIGS_GTKWAVE

      (* keep *) wire [7:0] \@0$slideswitch ;
      assign \@0$slideswitch = L0_slideswitch_a0;
      (* keep *) wire  \@0$sseg_decimal_point_n ;
      assign \@0$sseg_decimal_point_n = L0_sseg_decimal_point_n_a0;
      (* keep *) wire [7:0] \@0$sseg_digit_n ;
      assign \@0$sseg_digit_n = L0_sseg_digit_n_a0;
      (* keep *) wire [6:0] \@0$sseg_segment_n ;
      assign \@0$sseg_segment_n = L0_sseg_segment_n_a0;

      //
      // Scope: /digit[0:0]
      //
      for (digit = 0; digit <= 0; digit=digit+1) begin : \/digit 

         //
         // Scope: /leds[7:0]
         //
         for (leds = 0; leds <= 7; leds=leds+1) begin : \/leds 
            (* keep *) wire  \//@0$viz_lit ;
            assign \//@0$viz_lit = L1_Digit[digit].L2_Leds[leds].L2_viz_lit_a0;
         end
      end

      //
      // Scope: /fpga_pins
      //
      if (1) begin : \/fpga_pins 

         //
         // Scope: /fpga
         //
         if (1) begin : \/fpga 

            //
            // Scope: |cpu
            //
            if (1) begin : P_cpu
               (* keep *) wire [31:0] \///@2$alu_op1 ;
               assign \///@2$alu_op1 = FpgaPins_Fpga_CPU_alu_op1_a2;
               (* keep *) wire [31:0] \///@2$alu_op2 ;
               assign \///@2$alu_op2 = FpgaPins_Fpga_CPU_alu_op2_a2;
               (* keep *) wire [2:0] \///@1$funct3 ;
               assign \///@1$funct3 = FpgaPins_Fpga_CPU_funct3_a1;
               (* keep *) wire [6:0] \///@1$funct7 ;
               assign \///@1$funct7 = FpgaPins_Fpga_CPU_funct7_a1;
               (* keep *) wire [31:0] \///@1$imm ;
               assign \///@1$imm = FpgaPins_Fpga_CPU_imm_a1;
               (* keep *) wire [31:0] \///@1$inc_pc ;
               assign \///@1$inc_pc = FpgaPins_Fpga_CPU_inc_pc_a1;
               (* keep *) wire [31:0] \///@1$instr ;
               assign \///@1$instr = FpgaPins_Fpga_CPU_instr_a1;
               (* keep *) wire  \///@1$is_add ;
               assign \///@1$is_add = FpgaPins_Fpga_CPU_is_add_a1;
               (* keep *) wire  \///@1$is_add_op ;
               assign \///@1$is_add_op = FpgaPins_Fpga_CPU_is_add_op_a1;
               (* keep *) wire  \///@1$is_addi ;
               assign \///@1$is_addi = FpgaPins_Fpga_CPU_is_addi_a1;
               (* keep *) wire  \///@1$is_and ;
               assign \///@1$is_and = FpgaPins_Fpga_CPU_is_and_a1;
               (* keep *) wire  \///@1$is_and_op ;
               assign \///@1$is_and_op = FpgaPins_Fpga_CPU_is_and_op_a1;
               (* keep *) wire  \///@1$is_andi ;
               assign \///@1$is_andi = FpgaPins_Fpga_CPU_is_andi_a1;
               (* keep *) wire  \///@1$is_auipc ;
               assign \///@1$is_auipc = FpgaPins_Fpga_CPU_is_auipc_a1;
               (* keep *) wire  \///@1$is_b_instr ;
               assign \///@1$is_b_instr = FpgaPins_Fpga_CPU_is_b_instr_a1;
               (* keep *) wire  \///@1$is_beq ;
               assign \///@1$is_beq = FpgaPins_Fpga_CPU_is_beq_a1;
               (* keep *) wire  \///@1$is_bge ;
               assign \///@1$is_bge = FpgaPins_Fpga_CPU_is_bge_a1;
               (* keep *) wire  \///@1$is_bgeu ;
               assign \///@1$is_bgeu = FpgaPins_Fpga_CPU_is_bgeu_a1;
               (* keep *) wire  \///@1$is_blt ;
               assign \///@1$is_blt = FpgaPins_Fpga_CPU_is_blt_a1;
               (* keep *) wire  \///@1$is_bltu ;
               assign \///@1$is_bltu = FpgaPins_Fpga_CPU_is_bltu_a1;
               (* keep *) wire  \///@1$is_bne ;
               assign \///@1$is_bne = FpgaPins_Fpga_CPU_is_bne_a1;
               (* keep *) wire  \///@1$is_i_instr ;
               assign \///@1$is_i_instr = FpgaPins_Fpga_CPU_is_i_instr_a1;
               (* keep *) wire  \///@1$is_j_instr ;
               assign \///@1$is_j_instr = FpgaPins_Fpga_CPU_is_j_instr_a1;
               (* keep *) wire  \///@1$is_jal ;
               assign \///@1$is_jal = FpgaPins_Fpga_CPU_is_jal_a1;
               (* keep *) wire  \///@1$is_jalr ;
               assign \///@1$is_jalr = FpgaPins_Fpga_CPU_is_jalr_a1;
               (* keep *) wire  \///@1$is_jump ;
               assign \///@1$is_jump = FpgaPins_Fpga_CPU_is_jump_a1;
               (* keep *) wire  \///@1$is_lb ;
               assign \///@1$is_lb = FpgaPins_Fpga_CPU_is_lb_a1;
               (* keep *) wire  \///@1$is_lbu ;
               assign \///@1$is_lbu = FpgaPins_Fpga_CPU_is_lbu_a1;
               (* keep *) wire  \///@1$is_lh ;
               assign \///@1$is_lh = FpgaPins_Fpga_CPU_is_lh_a1;
               (* keep *) wire  \///@1$is_lhu ;
               assign \///@1$is_lhu = FpgaPins_Fpga_CPU_is_lhu_a1;
               (* keep *) wire  \///@1$is_load ;
               assign \///@1$is_load = FpgaPins_Fpga_CPU_is_load_a1;
               (* keep *) wire  \///@1$is_lui ;
               assign \///@1$is_lui = FpgaPins_Fpga_CPU_is_lui_a1;
               (* keep *) wire  \///@1$is_lw ;
               assign \///@1$is_lw = FpgaPins_Fpga_CPU_is_lw_a1;
               (* keep *) wire  \///@1$is_or ;
               assign \///@1$is_or = FpgaPins_Fpga_CPU_is_or_a1;
               (* keep *) wire  \///@1$is_or_op ;
               assign \///@1$is_or_op = FpgaPins_Fpga_CPU_is_or_op_a1;
               (* keep *) wire  \///@1$is_ori ;
               assign \///@1$is_ori = FpgaPins_Fpga_CPU_is_ori_a1;
               (* keep *) wire  \///@1$is_r_instr ;
               assign \///@1$is_r_instr = FpgaPins_Fpga_CPU_is_r_instr_a1;
               (* keep *) wire  \///@1$is_s_instr ;
               assign \///@1$is_s_instr = FpgaPins_Fpga_CPU_is_s_instr_a1;
               (* keep *) wire  \///@1$is_sb ;
               assign \///@1$is_sb = FpgaPins_Fpga_CPU_is_sb_a1;
               (* keep *) wire  \///@1$is_sh ;
               assign \///@1$is_sh = FpgaPins_Fpga_CPU_is_sh_a1;
               (* keep *) wire  \///@1$is_sll ;
               assign \///@1$is_sll = FpgaPins_Fpga_CPU_is_sll_a1;
               (* keep *) wire  \///@1$is_sll_op ;
               assign \///@1$is_sll_op = FpgaPins_Fpga_CPU_is_sll_op_a1;
               (* keep *) wire  \///@1$is_slli ;
               assign \///@1$is_slli = FpgaPins_Fpga_CPU_is_slli_a1;
               (* keep *) wire  \///@1$is_slt ;
               assign \///@1$is_slt = FpgaPins_Fpga_CPU_is_slt_a1;
               (* keep *) wire  \///@1$is_slt_op ;
               assign \///@1$is_slt_op = FpgaPins_Fpga_CPU_is_slt_op_a1;
               (* keep *) wire  \///@1$is_slti ;
               assign \///@1$is_slti = FpgaPins_Fpga_CPU_is_slti_a1;
               (* keep *) wire  \///@1$is_sltiu ;
               assign \///@1$is_sltiu = FpgaPins_Fpga_CPU_is_sltiu_a1;
               (* keep *) wire  \///@1$is_sltu ;
               assign \///@1$is_sltu = FpgaPins_Fpga_CPU_is_sltu_a1;
               (* keep *) wire  \///@1$is_sltu_op ;
               assign \///@1$is_sltu_op = FpgaPins_Fpga_CPU_is_sltu_op_a1;
               (* keep *) wire  \///@1$is_sra ;
               assign \///@1$is_sra = FpgaPins_Fpga_CPU_is_sra_a1;
               (* keep *) wire  \///@1$is_sra_op ;
               assign \///@1$is_sra_op = FpgaPins_Fpga_CPU_is_sra_op_a1;
               (* keep *) wire  \///@1$is_srai ;
               assign \///@1$is_srai = FpgaPins_Fpga_CPU_is_srai_a1;
               (* keep *) wire  \///@1$is_srl ;
               assign \///@1$is_srl = FpgaPins_Fpga_CPU_is_srl_a1;
               (* keep *) wire  \///@1$is_srl_op ;
               assign \///@1$is_srl_op = FpgaPins_Fpga_CPU_is_srl_op_a1;
               (* keep *) wire  \///@1$is_srli ;
               assign \///@1$is_srli = FpgaPins_Fpga_CPU_is_srli_a1;
               (* keep *) wire  \///@1$is_store ;
               assign \///@1$is_store = FpgaPins_Fpga_CPU_is_store_a1;
               (* keep *) wire  \///@1$is_sub ;
               assign \///@1$is_sub = FpgaPins_Fpga_CPU_is_sub_a1;
               (* keep *) wire  \///@1$is_sw ;
               assign \///@1$is_sw = FpgaPins_Fpga_CPU_is_sw_a1;
               (* keep *) wire  \///@1$is_u_instr ;
               assign \///@1$is_u_instr = FpgaPins_Fpga_CPU_is_u_instr_a1;
               (* keep *) wire  \///@1$is_xor ;
               assign \///@1$is_xor = FpgaPins_Fpga_CPU_is_xor_a1;
               (* keep *) wire  \///@1$is_xor_op ;
               assign \///@1$is_xor_op = FpgaPins_Fpga_CPU_is_xor_op_a1;
               (* keep *) wire  \///@1$is_xori ;
               assign \///@1$is_xori = FpgaPins_Fpga_CPU_is_xori_a1;
               (* keep *) wire [31:0] \///@5$ld_data ;
               assign \///@5$ld_data = FpgaPins_Fpga_CPU_ld_data_a5;
               (* keep *) wire [6:0] \///@1$opcode ;
               assign \///@1$opcode = FpgaPins_Fpga_CPU_opcode_a1;
               (* keep *) wire [31:0] \///@0$pc ;
               assign \///@0$pc = FpgaPins_Fpga_CPU_pc_a0;
               (* keep *) wire [4:0] \///@1$rd ;
               assign \///@1$rd = FpgaPins_Fpga_CPU_rd_a1;
               (* keep *) wire  \///@1$rd_valid ;
               assign \///@1$rd_valid = FpgaPins_Fpga_CPU_rd_valid_a1;
               (* keep *) wire  \///@0$reset ;
               assign \///@0$reset = FpgaPins_Fpga_CPU_reset_a0;
               (* keep *) wire [31:0] \///@3$result ;
               assign \///@3$result = FpgaPins_Fpga_CPU_result_a3;
               (* keep *) wire [31:0] \///?$rf_rd_en1@2$rf_rd_data1 ;
               assign \///?$rf_rd_en1@2$rf_rd_data1 = FpgaPins_Fpga_CPU_rf_rd_data1_a2;
               (* keep *) wire [31:0] \///?$rf_rd_en2@2$rf_rd_data2 ;
               assign \///?$rf_rd_en2@2$rf_rd_data2 = FpgaPins_Fpga_CPU_rf_rd_data2_a2;
               (* keep *) wire  \///@2$rf_rd_en1 ;
               assign \///@2$rf_rd_en1 = FpgaPins_Fpga_CPU_rf_rd_en1_a2;
               (* keep *) wire  \///@2$rf_rd_en2 ;
               assign \///@2$rf_rd_en2 = FpgaPins_Fpga_CPU_rf_rd_en2_a2;
               (* keep *) wire [4:0] \///@2$rf_rd_index1 ;
               assign \///@2$rf_rd_index1 = FpgaPins_Fpga_CPU_rf_rd_index1_a2;
               (* keep *) wire [4:0] \///@2$rf_rd_index2 ;
               assign \///@2$rf_rd_index2 = FpgaPins_Fpga_CPU_rf_rd_index2_a2;
               (* keep *) wire [31:0] \///@3$rf_wr_data ;
               assign \///@3$rf_wr_data = FpgaPins_Fpga_CPU_rf_wr_data_a3;
               (* keep *) wire  \///@3$rf_wr_en ;
               assign \///@3$rf_wr_en = FpgaPins_Fpga_CPU_rf_wr_en_a3;
               (* keep *) wire [4:0] \///@3$rf_wr_index ;
               assign \///@3$rf_wr_index = FpgaPins_Fpga_CPU_rf_wr_index_a3;
               (* keep *) wire [4:0] \///@1$rs1 ;
               assign \///@1$rs1 = FpgaPins_Fpga_CPU_rs1_a1;
               (* keep *) wire  \///@1$rs1_valid ;
               assign \///@1$rs1_valid = FpgaPins_Fpga_CPU_rs1_valid_a1;
               (* keep *) wire [4:0] \///@1$rs2 ;
               assign \///@1$rs2 = FpgaPins_Fpga_CPU_rs2_a1;
               (* keep *) wire  \///@1$rs2_valid ;
               assign \///@1$rs2_valid = FpgaPins_Fpga_CPU_rs2_valid_a1;
               (* keep *) wire [31:0] \///@3$sltu_result ;
               assign \///@3$sltu_result = FpgaPins_Fpga_CPU_sltu_result_a3;
               (* keep *) wire [63:0] \///@3$sra_result ;
               assign \///@3$sra_result = FpgaPins_Fpga_CPU_sra_result_a3;
               (* keep *) wire [31:0] \///@2$src1_value ;
               assign \///@2$src1_value = FpgaPins_Fpga_CPU_src1_value_a2;
               (* keep *) wire [31:0] \///@2$src2_value ;
               assign \///@2$src2_value = FpgaPins_Fpga_CPU_src2_value_a2;
               (* keep *) wire [31:0] \///@3$tgt_pc ;
               assign \///@3$tgt_pc = FpgaPins_Fpga_CPU_tgt_pc_a3;
               (* keep *) wire [31:0] \///@2$tgt_pc_op1 ;
               assign \///@2$tgt_pc_op1 = FpgaPins_Fpga_CPU_tgt_pc_op1_a2;
               (* keep *) wire [31:0] \///@2$tgt_pc_op2 ;
               assign \///@2$tgt_pc_op2 = FpgaPins_Fpga_CPU_tgt_pc_op2_a2;
               (* keep *) wire  \///@3$valid ;
               assign \///@3$valid = FpgaPins_Fpga_CPU_valid_a3;
               (* keep *) wire  \///@3$valid_jump ;
               assign \///@3$valid_jump = FpgaPins_Fpga_CPU_valid_jump_a3;
               (* keep *) wire  \///@3$valid_load ;
               assign \///@3$valid_load = FpgaPins_Fpga_CPU_valid_load_a3;
               (* keep *) wire  \///@3$valid_store ;
               assign \///@3$valid_store = FpgaPins_Fpga_CPU_valid_store_a3;
               (* keep *) wire  \///@3$valid_taken_br ;
               assign \///@3$valid_taken_br = FpgaPins_Fpga_CPU_valid_taken_br_a3;
               (* keep *) wire  \///@3$valid_tgt_pc ;
               assign \///@3$valid_tgt_pc = FpgaPins_Fpga_CPU_valid_tgt_pc_a3;

               //
               // Scope: /xreg[15:0]
               //
               for (xreg = 0; xreg <= 15; xreg=xreg+1) begin : \/xreg 
                  (* keep *) wire [31:0] \////@3$value ;
                  assign \////@3$value = FpgaPins_Fpga_CPU_Xreg_value_a3[xreg];
                  (* keep *) wire  \////@3$wr ;
                  assign \////@3$wr = L1_FpgaPins_Fpga_CPU_Xreg[xreg].L1_wr_a3;
               end
            end
         end
      end

      //
      // Scope: /switch[7:0]
      //
      for (switch = 0; switch <= 7; switch=switch+1) begin : \/switch 
         (* keep *) wire  \/@0$viz_switch ;
         assign \/@0$viz_switch = L1_Switch[switch].L1_viz_switch_a0;
      end


   end

endgenerate

----------------------------------------------------------------- COMMENTING OUT DEBUG SIGNALS AFTER MAKERCHIP COMPILE; DEBUG SIGNALS TAKE UP RESOURCES IN SYNTHESIS ----------------------------------------------------------------- */

// ---------- Generated Code Ends ----------
//_\TLV
   /* verilator lint_off UNOPTFLAT */
   // Connect Tiny Tapeout I/Os to Virtual FPGA Lab.
   //_\source /raw.githubusercontent.com/osfpga/VirtualFPGALab/35e36bd144fddd75495d4cbc01c4fc50ac5bde6f/tlvlib/tinytapeoutlib.tlv 76   // Instantiated from top.tlv, 295 as: m5+tt_connections()
      assign L0_slideswitch_a0[7:0] = ui_in;
      assign L0_sseg_segment_n_a0[6:0] = ~ uo_out[6:0];
      assign L0_sseg_decimal_point_n_a0 = ~ uo_out[7];
      assign L0_sseg_digit_n_a0[7:0] = 8'b11111110;
   //_\end_source

   // Instantiate the Virtual FPGA Lab.
   //_\source /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv 307   // Instantiated from top.tlv, 298 as: m5+board(/top, /fpga, 7, $, , cpu)
      
      //_\source /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv 355   // Instantiated from /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv, 309 as: m4+thanks(m5__l(309)m5_eval(m5_get(BOARD_THANKS_ARGS)))
         //_/thanks
            
      //_\end_source
      
   
      // Board VIZ.
   
      // Board Image.
      
      //_/fpga_pins
         
         //_/fpga
            //_\source top.tlv 92   // Instantiated from /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv, 340 as: m4+cpu.
            
               //_\source M5-FN-riscv_gen 0   // Instantiated from top.tlv, 94 as: m5+riscv_gen()
                  
               //_\end_source
               //_\source M5-FN-riscv_sum_prog 0   // Instantiated from top.tlv, 95 as: m5+riscv_sum_prog()
                  // Inst #0: ADD x10, x0, x0
                  // Inst #1: ADD x14, x10, x0
                  // Inst #2: ADDI x12, x10, 10
                  // Inst #3: ADD x13, x10, x0
                  // Inst #4: ADD x14, x13, x14
                  // Inst #5: ADDI x13, x13, 1
                  // Inst #6: BLT x13, x12, loop
                  // Inst #7: ADD x10, x14, x0
                  
               //_\end_source
               
               // -----------------------------------------------------------------------------------------------------------------------------------------------------
               // ---------------------------- UNCOMMENT THIS BLOCK IF CREATING CPU IN THIS FILE INSTEAD OF CONNECTING EXTERNAL CPU DESIGN ----------------------------
               // -----------------------------------------------------------------------------------------------------------------------------------------------------
               // |cpu
               //    @0
               //       $reset = *reset;
               //
               //
               //
               //    // ==================
               //    // |                |
               //    // | YOUR CODE HERE |
               //    // |                |
               //    // ==================
               //
               //    // Note that pipesignals assigned here can be found under /fpga_pins/fpga.
               //
               // -----------------------------------------------------------------------------------------------------------------------------------------------------
            
               // Connect External CPU - COMMENT THESE TWO LINES OUT IF CREATING CPU IN THIS FILE (ABOVE)
               
               //_\source /raw.githubusercontent.com/enieman/uartprogrammablerv32i/main/src/tlv/cpucustom.tlv 11   // Instantiated from top.tlv, 118 as: m5+cpu_custom.
                  //_|cpu
                     //_@0 // Instruction Fetch, PC Select
                        assign FpgaPins_Fpga_CPU_reset_a0 = reset;
                        assign FpgaPins_Fpga_CPU_pc_a0[31:0] =
                           FpgaPins_Fpga_CPU_reset_a0             ? 32'h0000_0000 :
                           FpgaPins_Fpga_CPU_reset_a1          ? 32'h0000_0000 :
                           FpgaPins_Fpga_CPU_valid_tgt_pc_a3   ? FpgaPins_Fpga_CPU_tgt_pc_a3 :
                           FpgaPins_Fpga_CPU_valid_load_a3     ? FpgaPins_Fpga_CPU_inc_pc_a3 :
                                                FpgaPins_Fpga_CPU_inc_pc_a1;
                        assign imem_rd_en = ! (FpgaPins_Fpga_CPU_reset_a0);
                        assign imem_rd_addr[3:0] = FpgaPins_Fpga_CPU_pc_a0[5:2];
               
                     //_@1 // Instruction Decode, PC Increment
                        assign FpgaPins_Fpga_CPU_instr_a1[31:0] = imem_rd_data[31:0];
                        assign FpgaPins_Fpga_CPU_inc_pc_a1[31:0] = FpgaPins_Fpga_CPU_pc_a1 + 32'h4;
               
                        // Instruction Fields
                        assign FpgaPins_Fpga_CPU_opcode_a1[6:0] = FpgaPins_Fpga_CPU_instr_a1[6:0];
                        assign FpgaPins_Fpga_CPU_funct3_a1[2:0] = FpgaPins_Fpga_CPU_instr_a1[14:12];
                        assign FpgaPins_Fpga_CPU_funct7_a1[6:0] = FpgaPins_Fpga_CPU_instr_a1[31:25];
                        assign FpgaPins_Fpga_CPU_rd_a1[4:0] = FpgaPins_Fpga_CPU_instr_a1[11:7];
                        assign FpgaPins_Fpga_CPU_rs1_a1[4:0] = FpgaPins_Fpga_CPU_instr_a1[19:15];
                        assign FpgaPins_Fpga_CPU_rs2_a1[4:0] = FpgaPins_Fpga_CPU_instr_a1[24:20];
                        assign FpgaPins_Fpga_CPU_imm_a1[31:0] =
                           FpgaPins_Fpga_CPU_is_s_instr_a1 ? {{21{FpgaPins_Fpga_CPU_instr_a1[31]}}, FpgaPins_Fpga_CPU_instr_a1[30:25], FpgaPins_Fpga_CPU_instr_a1[11:7]} :
                           FpgaPins_Fpga_CPU_is_b_instr_a1 ? {{20{FpgaPins_Fpga_CPU_instr_a1[31]}}, FpgaPins_Fpga_CPU_instr_a1[7], FpgaPins_Fpga_CPU_instr_a1[30:25], FpgaPins_Fpga_CPU_instr_a1[11:8], 1'b0} :
                           FpgaPins_Fpga_CPU_is_u_instr_a1 ? {FpgaPins_Fpga_CPU_instr_a1[31:12], {12{1'b0}}} :
                           FpgaPins_Fpga_CPU_is_j_instr_a1 ? {{12{FpgaPins_Fpga_CPU_instr_a1[31]}}, FpgaPins_Fpga_CPU_instr_a1[19:12], FpgaPins_Fpga_CPU_instr_a1[20], FpgaPins_Fpga_CPU_instr_a1[30:25], FpgaPins_Fpga_CPU_instr_a1[24:21], 1'b0} :
                           //default to I-type format for simplicity
                                         {{21{FpgaPins_Fpga_CPU_instr_a1[31]}}, FpgaPins_Fpga_CPU_instr_a1[30:20]};
               
                        // Instruction Set
                        assign FpgaPins_Fpga_CPU_is_lui_a1   = FpgaPins_Fpga_CPU_opcode_a1 == 7'b0110111;
                        assign FpgaPins_Fpga_CPU_is_auipc_a1 = FpgaPins_Fpga_CPU_opcode_a1 == 7'b0010111;
                        assign FpgaPins_Fpga_CPU_is_jal_a1   = FpgaPins_Fpga_CPU_opcode_a1 == 7'b1101111;
                        assign FpgaPins_Fpga_CPU_is_jalr_a1  = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b000_1100111;
                        assign FpgaPins_Fpga_CPU_is_beq_a1   = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b000_1100011;
                        assign FpgaPins_Fpga_CPU_is_bne_a1   = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b001_1100011;
                        assign FpgaPins_Fpga_CPU_is_blt_a1   = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b100_1100011;
                        assign FpgaPins_Fpga_CPU_is_bge_a1   = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b101_1100011;
                        assign FpgaPins_Fpga_CPU_is_bltu_a1  = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b110_1100011;
                        assign FpgaPins_Fpga_CPU_is_bgeu_a1  = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b111_1100011;
                        assign FpgaPins_Fpga_CPU_is_lb_a1    = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b000_0000011;
                        assign FpgaPins_Fpga_CPU_is_lh_a1    = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b001_0000011;
                        assign FpgaPins_Fpga_CPU_is_lw_a1    = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b010_0000011;
                        assign FpgaPins_Fpga_CPU_is_lbu_a1   = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b100_0000011;
                        assign FpgaPins_Fpga_CPU_is_lhu_a1   = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b101_0000011;
                        assign FpgaPins_Fpga_CPU_is_sb_a1    = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b000_0100011;
                        assign FpgaPins_Fpga_CPU_is_sh_a1    = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b001_0100011;
                        assign FpgaPins_Fpga_CPU_is_sw_a1    = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b010_0100011;
                        assign FpgaPins_Fpga_CPU_is_addi_a1  = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b000_0010011;
                        assign FpgaPins_Fpga_CPU_is_slti_a1  = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b010_0010011;
                        assign FpgaPins_Fpga_CPU_is_sltiu_a1 = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b011_0010011;
                        assign FpgaPins_Fpga_CPU_is_xori_a1  = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b100_0010011;
                        assign FpgaPins_Fpga_CPU_is_ori_a1   = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b110_0010011;
                        assign FpgaPins_Fpga_CPU_is_andi_a1  = {FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 10'b111_0010011;
                        assign FpgaPins_Fpga_CPU_is_slli_a1  = {FpgaPins_Fpga_CPU_funct7_a1, FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 17'b0000000_001_0010011;
                        assign FpgaPins_Fpga_CPU_is_srli_a1  = {FpgaPins_Fpga_CPU_funct7_a1, FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 17'b0000000_101_0010011;
                        assign FpgaPins_Fpga_CPU_is_srai_a1  = {FpgaPins_Fpga_CPU_funct7_a1, FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 17'b0100000_101_0010011;
                        assign FpgaPins_Fpga_CPU_is_add_a1   = {FpgaPins_Fpga_CPU_funct7_a1, FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 17'b0000000_000_0110011;
                        assign FpgaPins_Fpga_CPU_is_sub_a1   = {FpgaPins_Fpga_CPU_funct7_a1, FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 17'b0100000_000_0110011;
                        assign FpgaPins_Fpga_CPU_is_sll_a1   = {FpgaPins_Fpga_CPU_funct7_a1, FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 17'b0000000_001_0110011;
                        assign FpgaPins_Fpga_CPU_is_slt_a1   = {FpgaPins_Fpga_CPU_funct7_a1, FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 17'b0000000_010_0110011;
                        assign FpgaPins_Fpga_CPU_is_sltu_a1  = {FpgaPins_Fpga_CPU_funct7_a1, FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 17'b0000000_011_0110011;
                        assign FpgaPins_Fpga_CPU_is_xor_a1   = {FpgaPins_Fpga_CPU_funct7_a1, FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 17'b0000000_100_0110011;
                        assign FpgaPins_Fpga_CPU_is_srl_a1   = {FpgaPins_Fpga_CPU_funct7_a1, FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 17'b0000000_101_0110011;
                        assign FpgaPins_Fpga_CPU_is_sra_a1   = {FpgaPins_Fpga_CPU_funct7_a1, FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 17'b0100000_101_0110011;
                        assign FpgaPins_Fpga_CPU_is_or_a1    = {FpgaPins_Fpga_CPU_funct7_a1, FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 17'b0000000_110_0110011;
                        assign FpgaPins_Fpga_CPU_is_and_a1   = {FpgaPins_Fpga_CPU_funct7_a1, FpgaPins_Fpga_CPU_funct3_a1, FpgaPins_Fpga_CPU_opcode_a1} == 17'b0000000_111_0110011;
               
                        // Instruction Categories
                        assign FpgaPins_Fpga_CPU_is_load_a1    = FpgaPins_Fpga_CPU_is_lb_a1 | FpgaPins_Fpga_CPU_is_lh_a1 | FpgaPins_Fpga_CPU_is_lw_a1 | FpgaPins_Fpga_CPU_is_lbu_a1 | FpgaPins_Fpga_CPU_is_lhu_a1;
                        assign FpgaPins_Fpga_CPU_is_store_a1   = FpgaPins_Fpga_CPU_is_sb_a1 | FpgaPins_Fpga_CPU_is_sh_a1 | FpgaPins_Fpga_CPU_is_sw_a1;
                        assign FpgaPins_Fpga_CPU_is_jump_a1    = FpgaPins_Fpga_CPU_is_jal_a1  | FpgaPins_Fpga_CPU_is_jalr_a1;
                        assign FpgaPins_Fpga_CPU_is_add_op_a1  = FpgaPins_Fpga_CPU_is_add_a1  | FpgaPins_Fpga_CPU_is_addi_a1 | FpgaPins_Fpga_CPU_is_auipc_a1 | FpgaPins_Fpga_CPU_is_jump_a1 | FpgaPins_Fpga_CPU_is_load_a1 | FpgaPins_Fpga_CPU_is_store_a1;
                        assign FpgaPins_Fpga_CPU_is_and_op_a1  = FpgaPins_Fpga_CPU_is_and_a1  | FpgaPins_Fpga_CPU_is_andi_a1;
                        assign FpgaPins_Fpga_CPU_is_or_op_a1   = FpgaPins_Fpga_CPU_is_or_a1   | FpgaPins_Fpga_CPU_is_ori_a1;
                        assign FpgaPins_Fpga_CPU_is_sll_op_a1  = FpgaPins_Fpga_CPU_is_sll_a1  | FpgaPins_Fpga_CPU_is_slli_a1;
                        assign FpgaPins_Fpga_CPU_is_slt_op_a1  = FpgaPins_Fpga_CPU_is_slt_a1  | FpgaPins_Fpga_CPU_is_slti_a1  | FpgaPins_Fpga_CPU_is_blt_a1  | FpgaPins_Fpga_CPU_is_bge_a1;
                        assign FpgaPins_Fpga_CPU_is_sltu_op_a1 = FpgaPins_Fpga_CPU_is_sltu_a1 | FpgaPins_Fpga_CPU_is_sltiu_a1 | FpgaPins_Fpga_CPU_is_bltu_a1 | FpgaPins_Fpga_CPU_is_bgeu_a1;
                        assign FpgaPins_Fpga_CPU_is_sra_op_a1  = FpgaPins_Fpga_CPU_is_sra_a1  | FpgaPins_Fpga_CPU_is_srai_a1;
                        assign FpgaPins_Fpga_CPU_is_srl_op_a1  = FpgaPins_Fpga_CPU_is_srl_a1  | FpgaPins_Fpga_CPU_is_srli_a1;
                        assign FpgaPins_Fpga_CPU_is_xor_op_a1  = FpgaPins_Fpga_CPU_is_xor_a1  | FpgaPins_Fpga_CPU_is_xori_a1;
               
                        // Instruction Types
                        assign FpgaPins_Fpga_CPU_is_r_instr_a1 = FpgaPins_Fpga_CPU_is_add_a1 | FpgaPins_Fpga_CPU_is_sub_a1 | FpgaPins_Fpga_CPU_is_sll_a1 | FpgaPins_Fpga_CPU_is_slt_a1 | FpgaPins_Fpga_CPU_is_sltu_a1 | FpgaPins_Fpga_CPU_is_xor_a1 | FpgaPins_Fpga_CPU_is_srl_a1 | FpgaPins_Fpga_CPU_is_sra_a1 | FpgaPins_Fpga_CPU_is_or_a1 | FpgaPins_Fpga_CPU_is_and_a1;
                        assign FpgaPins_Fpga_CPU_is_i_instr_a1 = FpgaPins_Fpga_CPU_is_jalr_a1 | FpgaPins_Fpga_CPU_is_load_a1 | FpgaPins_Fpga_CPU_is_addi_a1 | FpgaPins_Fpga_CPU_is_slti_a1 | FpgaPins_Fpga_CPU_is_sltiu_a1 | FpgaPins_Fpga_CPU_is_xori_a1 | FpgaPins_Fpga_CPU_is_ori_a1 | FpgaPins_Fpga_CPU_is_andi_a1 | FpgaPins_Fpga_CPU_is_slli_a1 | FpgaPins_Fpga_CPU_is_srli_a1 | FpgaPins_Fpga_CPU_is_srai_a1;
                        assign FpgaPins_Fpga_CPU_is_s_instr_a1 = FpgaPins_Fpga_CPU_is_store_a1;
                        assign FpgaPins_Fpga_CPU_is_b_instr_a1 = FpgaPins_Fpga_CPU_is_beq_a1 | FpgaPins_Fpga_CPU_is_bne_a1 | FpgaPins_Fpga_CPU_is_blt_a1 | FpgaPins_Fpga_CPU_is_bge_a1 | FpgaPins_Fpga_CPU_is_bltu_a1 | FpgaPins_Fpga_CPU_is_bgeu_a1;
                        assign FpgaPins_Fpga_CPU_is_u_instr_a1 = FpgaPins_Fpga_CPU_is_lui_a1 | FpgaPins_Fpga_CPU_is_auipc_a1;
                        assign FpgaPins_Fpga_CPU_is_j_instr_a1 = FpgaPins_Fpga_CPU_is_jal_a1;
               
                        // Validity
                        assign FpgaPins_Fpga_CPU_rd_valid_a1    = !FpgaPins_Fpga_CPU_reset_a1 & (FpgaPins_Fpga_CPU_is_r_instr_a1 | FpgaPins_Fpga_CPU_is_i_instr_a1 | FpgaPins_Fpga_CPU_is_u_instr_a1 | FpgaPins_Fpga_CPU_is_j_instr_a1);
                        assign FpgaPins_Fpga_CPU_rs1_valid_a1   = !FpgaPins_Fpga_CPU_reset_a1 & (FpgaPins_Fpga_CPU_is_r_instr_a1 | FpgaPins_Fpga_CPU_is_i_instr_a1 | FpgaPins_Fpga_CPU_is_s_instr_a1 | FpgaPins_Fpga_CPU_is_b_instr_a1);
                        assign FpgaPins_Fpga_CPU_rs2_valid_a1   = !FpgaPins_Fpga_CPU_reset_a1 & (FpgaPins_Fpga_CPU_is_r_instr_a1 | FpgaPins_Fpga_CPU_is_s_instr_a1 | FpgaPins_Fpga_CPU_is_b_instr_a1);
               
                     //_@2 // Operand Selection
                        assign FpgaPins_Fpga_CPU_rf_rd_en1_a2 = FpgaPins_Fpga_CPU_rs1_valid_a2;
                        assign FpgaPins_Fpga_CPU_rf_rd_en2_a2 = FpgaPins_Fpga_CPU_rs2_valid_a2;
                        assign FpgaPins_Fpga_CPU_rf_rd_index1_a2[4:0] = FpgaPins_Fpga_CPU_rs1_a2;
                        assign FpgaPins_Fpga_CPU_rf_rd_index2_a2[4:0] = FpgaPins_Fpga_CPU_rs2_a2;
               
                        assign FpgaPins_Fpga_CPU_src1_value_a2[31:0] = (FpgaPins_Fpga_CPU_rf_wr_en_a3 && (FpgaPins_Fpga_CPU_rf_wr_index_a3 == FpgaPins_Fpga_CPU_rf_rd_index1_a2)) ? FpgaPins_Fpga_CPU_rf_wr_data_a3 : FpgaPins_Fpga_CPU_rf_rd_data1_a2;
                        assign FpgaPins_Fpga_CPU_src2_value_a2[31:0] = (FpgaPins_Fpga_CPU_rf_wr_en_a3 && (FpgaPins_Fpga_CPU_rf_wr_index_a3 == FpgaPins_Fpga_CPU_rf_rd_index2_a2)) ? FpgaPins_Fpga_CPU_rf_wr_data_a3 : FpgaPins_Fpga_CPU_rf_rd_data2_a2;
               
                        assign FpgaPins_Fpga_CPU_alu_op1_a2[31:0] =
                           FpgaPins_Fpga_CPU_is_auipc_a2 | FpgaPins_Fpga_CPU_is_jump_a2 ? FpgaPins_Fpga_CPU_pc_a2 :
                                                  FpgaPins_Fpga_CPU_src1_value_a2;
                        assign FpgaPins_Fpga_CPU_alu_op2_a2[31:0] =
                           FpgaPins_Fpga_CPU_is_r_instr_a2 || FpgaPins_Fpga_CPU_is_b_instr_a2 ? FpgaPins_Fpga_CPU_src2_value_a2 :
                           FpgaPins_Fpga_CPU_is_jump_a2                   ? 32'h0000_0004 :
                                                        FpgaPins_Fpga_CPU_imm_a2;
               
                        assign FpgaPins_Fpga_CPU_tgt_pc_op1_a2[31:0] = FpgaPins_Fpga_CPU_is_jalr_a2 ? FpgaPins_Fpga_CPU_src1_value_a2 : FpgaPins_Fpga_CPU_pc_a2;
                        assign FpgaPins_Fpga_CPU_tgt_pc_op2_a2[31:0] = FpgaPins_Fpga_CPU_imm_a2;
               
                     //_@3 // Execute, Register Write
                        assign FpgaPins_Fpga_CPU_valid_a3 = !FpgaPins_Fpga_CPU_reset_a3 && !(FpgaPins_Fpga_CPU_valid_taken_br_a4 || FpgaPins_Fpga_CPU_valid_taken_br_a5 || FpgaPins_Fpga_CPU_valid_load_a4 || FpgaPins_Fpga_CPU_valid_load_a5 || FpgaPins_Fpga_CPU_valid_jump_a4 || FpgaPins_Fpga_CPU_valid_jump_a5);
                        assign FpgaPins_Fpga_CPU_valid_load_a3  = FpgaPins_Fpga_CPU_is_load_a3  && FpgaPins_Fpga_CPU_valid_a3;
                        assign FpgaPins_Fpga_CPU_valid_store_a3 = FpgaPins_Fpga_CPU_is_store_a3 && FpgaPins_Fpga_CPU_valid_a3;
                        assign FpgaPins_Fpga_CPU_valid_jump_a3  = FpgaPins_Fpga_CPU_is_jump_a3  && FpgaPins_Fpga_CPU_valid_a3;
                        assign FpgaPins_Fpga_CPU_valid_taken_br_a3 =
                           !FpgaPins_Fpga_CPU_valid_a3  ? 1'b0 :
                           FpgaPins_Fpga_CPU_is_beq_a3  ? FpgaPins_Fpga_CPU_alu_op1_a3 == FpgaPins_Fpga_CPU_alu_op2_a3 :
                           FpgaPins_Fpga_CPU_is_bne_a3  ? FpgaPins_Fpga_CPU_alu_op1_a3 != FpgaPins_Fpga_CPU_alu_op2_a3 :
                           FpgaPins_Fpga_CPU_is_bltu_a3 ? FpgaPins_Fpga_CPU_result_a3[0] :
                           FpgaPins_Fpga_CPU_is_bgeu_a3 ? !FpgaPins_Fpga_CPU_result_a3[0] :
                           FpgaPins_Fpga_CPU_is_blt_a3  ? FpgaPins_Fpga_CPU_result_a3[0] :
                           FpgaPins_Fpga_CPU_is_bge_a3  ? !FpgaPins_Fpga_CPU_result_a3[0] :
                                      1'b0;
                        assign FpgaPins_Fpga_CPU_valid_tgt_pc_a3 = FpgaPins_Fpga_CPU_valid_taken_br_a3 | FpgaPins_Fpga_CPU_valid_jump_a3;
               
                        // Target PC Adder
                        assign FpgaPins_Fpga_CPU_tgt_pc_a3[31:0] = FpgaPins_Fpga_CPU_tgt_pc_op1_a3 + FpgaPins_Fpga_CPU_tgt_pc_op2_a3;
               
                        // ALU
                        assign FpgaPins_Fpga_CPU_sra_result_a3[63:0] = { {32{FpgaPins_Fpga_CPU_alu_op1_a3[31]}}, FpgaPins_Fpga_CPU_alu_op1_a3} >> FpgaPins_Fpga_CPU_alu_op2_a3[4:0];
                        assign FpgaPins_Fpga_CPU_sltu_result_a3[31:0] = FpgaPins_Fpga_CPU_alu_op1_a3 < FpgaPins_Fpga_CPU_alu_op2_a3 ? 32'h0000_0001 : 32'h0000_0000;
                        assign FpgaPins_Fpga_CPU_result_a3[31:0] =
                           FpgaPins_Fpga_CPU_is_add_op_a3  ? FpgaPins_Fpga_CPU_alu_op1_a3 + FpgaPins_Fpga_CPU_alu_op2_a3 :
                           FpgaPins_Fpga_CPU_is_and_op_a3  ? FpgaPins_Fpga_CPU_alu_op1_a3 & FpgaPins_Fpga_CPU_alu_op2_a3 :
                           FpgaPins_Fpga_CPU_is_lui_a3     ? {FpgaPins_Fpga_CPU_alu_op2_a3[31:12], 12'h000} :
                           FpgaPins_Fpga_CPU_is_or_op_a3   ? FpgaPins_Fpga_CPU_alu_op1_a3 | FpgaPins_Fpga_CPU_alu_op2_a3 :
                           FpgaPins_Fpga_CPU_is_sll_op_a3  ? FpgaPins_Fpga_CPU_alu_op1_a3 << FpgaPins_Fpga_CPU_alu_op2_a3[4:0] :
                           FpgaPins_Fpga_CPU_is_slt_op_a3  ? ((FpgaPins_Fpga_CPU_alu_op1_a3[31] == FpgaPins_Fpga_CPU_alu_op2_a3[31]) ? FpgaPins_Fpga_CPU_sltu_result_a3 : (FpgaPins_Fpga_CPU_alu_op1_a3[31] == 1'b1 ? 32'h0000_0001 : 32'h0000_0000)) :
                           FpgaPins_Fpga_CPU_is_sltu_op_a3 ? FpgaPins_Fpga_CPU_sltu_result_a3 :
                           FpgaPins_Fpga_CPU_is_sra_op_a3  ? FpgaPins_Fpga_CPU_sra_result_a3[31:0] :
                           FpgaPins_Fpga_CPU_is_srl_op_a3  ? FpgaPins_Fpga_CPU_alu_op1_a3 >> FpgaPins_Fpga_CPU_alu_op2_a3[4:0] :
                           FpgaPins_Fpga_CPU_is_sub_a3     ? FpgaPins_Fpga_CPU_alu_op1_a3 - FpgaPins_Fpga_CPU_alu_op2_a3 :
                           FpgaPins_Fpga_CPU_is_xor_op_a3  ? FpgaPins_Fpga_CPU_alu_op1_a3 ^ FpgaPins_Fpga_CPU_alu_op2_a3 :
                                         32'hxxxx_xxxx;
               
                        // Register Write
                        assign FpgaPins_Fpga_CPU_rf_wr_en_a3 = (FpgaPins_Fpga_CPU_valid_a3 && FpgaPins_Fpga_CPU_rd_valid_a3 && (FpgaPins_Fpga_CPU_rd_a3 != 5'h00) && !FpgaPins_Fpga_CPU_valid_load_a3) || FpgaPins_Fpga_CPU_valid_load_a5;
                        assign FpgaPins_Fpga_CPU_rf_wr_index_a3[4:0] = FpgaPins_Fpga_CPU_valid_a3 ? FpgaPins_Fpga_CPU_rd_a3 : FpgaPins_Fpga_CPU_rd_a5;
                        assign FpgaPins_Fpga_CPU_rf_wr_data_a3[31:0] = FpgaPins_Fpga_CPU_valid_a3 ? FpgaPins_Fpga_CPU_result_a3 : FpgaPins_Fpga_CPU_ld_data_a5;
               
                     //_@4 // Data Memory Write
                        assign dmem_rd_en = FpgaPins_Fpga_CPU_valid_load_a4;
                        assign dmem_wr_en = FpgaPins_Fpga_CPU_valid_store_a4;
                        assign dmem_addr[1:0] = FpgaPins_Fpga_CPU_result_a4[3:2];
                        assign dmem_wr_byte_en[3:0] = 4'b1111; // Just implement LW/SW for now
                        assign dmem_wr_data[31:0] = FpgaPins_Fpga_CPU_src2_value_a4;
               
                     //_@5 // Data Memory Read
                        assign FpgaPins_Fpga_CPU_ld_data_a5[31:0] = dmem_rd_data[31:0];
               //_\end_source
            
               // Assert these to end simulation (before Makerchip cycle limit).
               // Note, for Makerchip simulation these are passed in uo_out to top-level module's passed/failed signals.
               
               
            
               // Connect Tiny Tapeout outputs. Note that uio_ outputs are not available in the Tiny-Tapeout-3-based FPGA boards.
               
               assign uio_out = 8'b0;
               assign uio_oe = 8'b0;
            
               // Macro instantiations to be uncommented when instructed for:
               //  o instruction memory
               //  o register file
               //  o data memory
               //  o CPU visualization
               //_|cpu
                  //_\source /raw.githubusercontent.com/efabless/chipcraftmestcourse/main/tlvlib/riscvshelllib.tlv 33   // Instantiated from top.tlv, 136 as: m4+rf(@2, @3)
                     // Reg File
                     //_@3
                        generate for (xreg = 0; xreg <= 15; xreg=xreg+1) begin : L1_FpgaPins_Fpga_CPU_Xreg //_/xreg

                           // For $wr.
                           wire L1_wr_a3;

                           assign L1_wr_a3 = FpgaPins_Fpga_CPU_rf_wr_en_a3 && (FpgaPins_Fpga_CPU_rf_wr_index_a3 != 5'b0) && (FpgaPins_Fpga_CPU_rf_wr_index_a3 == xreg);
                           assign FpgaPins_Fpga_CPU_Xreg_value_a3[xreg][31:0] = FpgaPins_Fpga_CPU_reset_a3 ?   xreg           :
                                          L1_wr_a3        ?   FpgaPins_Fpga_CPU_rf_wr_data_a3 :
                                                         FpgaPins_Fpga_CPU_Xreg_value_a4[xreg][31:0];
                        end endgenerate
                     //_@2
                        //_?$rf_rd_en1
                           assign FpgaPins_Fpga_CPU_rf_rd_data1_a2[31:0] = FpgaPins_Fpga_CPU_Xreg_value_a4[FpgaPins_Fpga_CPU_rf_rd_index1_a2[3:0]];
                        //_?$rf_rd_en2
                           assign FpgaPins_Fpga_CPU_rf_rd_data2_a2[31:0] = FpgaPins_Fpga_CPU_Xreg_value_a4[FpgaPins_Fpga_CPU_rf_rd_index2_a2[3:0]];
                        `BOGUS_USE(FpgaPins_Fpga_CPU_rf_rd_data1_a2 FpgaPins_Fpga_CPU_rf_rd_data2_a2)
                  //_\end_source // Args: (read stage, write stage) - if equal, no register bypass is required
                   // Args: (read stage)
                   // Args: (read/write stage)
            
                // For visualisation, argument should be at least equal to the last stage of CPU logic. @4 would work for all labs.
            //_\end_source
   
      // LEDs.
      
   
      // 7-Segment
      //_\source /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv 395   // Instantiated from /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv, 346 as: m4+fpga_sseg.
         generate for (digit = 0; digit <= 0; digit=digit+1) begin : L1_Digit //_/digit
            
            for (leds = 0; leds <= 7; leds=leds+1) begin : L2_Leds //_/leds

               // For $viz_lit.
               wire L2_viz_lit_a0;

               assign L2_viz_lit_a0 = (! L0_sseg_digit_n_a0[digit]) && ! ((leds == 7) ? L0_sseg_decimal_point_n_a0 : L0_sseg_segment_n_a0[leds % 7]);
               
            end
         end endgenerate
      //_\end_source
   
      // slideswitches
      //_\source /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv 454   // Instantiated from /raw.githubusercontent.com/osfpga/VirtualFPGALab/a069f1e4e19adc829b53237b3e0b5d6763dc3194/tlvlib/fpgaincludes.tlv, 349 as: m4+fpga_switch.
         generate for (switch = 0; switch <= 7; switch=switch+1) begin : L1_Switch //_/switch

            // For $viz_switch.
            wire L1_viz_switch_a0;

            assign L1_viz_switch_a0 = L0_slideswitch_a0[switch];
            
         end endgenerate
      //_\end_source
   
      // pushbuttons
      
   //_\end_source
   // Label the switch inputs [0..7] (1..8 on the physical switch panel) (top-to-bottom).
   //_\source /raw.githubusercontent.com/osfpga/VirtualFPGALab/35e36bd144fddd75495d4cbc01c4fc50ac5bde6f/tlvlib/tinytapeoutlib.tlv 82   // Instantiated from top.tlv, 300 as: m5+tt_input_labels_viz(⌈"UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED"⌉)
      generate for (input_label = 0; input_label <= 7; input_label=input_label+1) begin : L1_InputLabel //_/input_label
         
      end endgenerate
   //_\end_source

//_\SV
endmodule


// Undefine macros defined by SandPiper.
`undef BOGUS_USE

// =============================================================================
// SASIC Wrapper
// =============================================================================
module sasic_top (
    input  wire clk,
    input  wire rst_n,

    input  wire in_0,  input  wire in_1,  input  wire in_2,  input  wire in_3,
    input  wire in_4,  input  wire in_5,  input  wire in_6,  input  wire in_7,
    input  wire in_8,  input  wire in_9,  input  wire in_10, input  wire in_11,
    input  wire in_12, input  wire in_13, input  wire in_14, input  wire in_15,
    input  wire in_16, input  wire in_17, input  wire in_18, input  wire in_19,
    input  wire in_20, input  wire in_21, input  wire in_22, input  wire in_23,
    input  wire in_24, input  wire in_25, input  wire in_26, input  wire in_27,
    input  wire in_28, input  wire in_29, input  wire in_30, input  wire in_31,
    input  wire in_32, input  wire in_33, input  wire in_34, input  wire in_35,
    input  wire in_36, input  wire in_37, input  wire in_38, input  wire in_39,

    output wire oeb_0,  output wire oeb_1,  output wire oeb_2,  output wire oeb_3,
    output wire oeb_4,  output wire oeb_5,  output wire oeb_6,  output wire oeb_7,
    output wire oeb_8,  output wire oeb_9,  output wire oeb_10, output wire oeb_11,
    output wire oeb_12, output wire oeb_13, output wire oeb_14, output wire oeb_15,
    output wire oeb_16, output wire oeb_17, output wire oeb_18, output wire oeb_19,
    output wire oeb_20, output wire oeb_21, output wire oeb_22, output wire oeb_23,
    output wire oeb_24, output wire oeb_25, output wire oeb_26, output wire oeb_27,
    output wire oeb_28, output wire oeb_29, output wire oeb_30, output wire oeb_31,
    output wire oeb_32, output wire oeb_33, output wire oeb_34, output wire oeb_35,
    output wire oeb_36, output wire oeb_37, output wire oeb_38, output wire oeb_39,

    output wire out_0,  output wire out_1,  output wire out_2,  output wire out_3,
    output wire out_4,  output wire out_5,  output wire out_6,  output wire out_7,
    output wire out_8,  output wire out_9,  output wire out_10, output wire out_11,
    output wire out_12, output wire out_13, output wire out_14, output wire out_15,
    output wire out_16, output wire out_17, output wire out_18, output wire out_19,
    output wire out_20, output wire out_21, output wire out_22, output wire out_23,
    output wire out_24, output wire out_25, output wire out_26, output wire out_27,
    output wire out_28, output wire out_29, output wire out_30, output wire out_31,
    output wire out_32, output wire out_33, output wire out_34, output wire out_35,
    output wire out_36, output wire out_37, output wire out_38, output wire out_39
);

    // --- Bundle SASIC pins into TT buses ---
    wire [7:0] ui_in  = {in_7,  in_6,  in_5,  in_4,  in_3,  in_2,  in_1,  in_0};
    wire [7:0] uio_in = {in_15, in_14, in_13, in_12, in_11, in_10, in_9,  in_8};

    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // --- Instantiate TT project ---
    tt_um_enieman tt_inst (
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (1'b1),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    // --- Dedicated outputs ---
    assign {out_7, out_6, out_5, out_4, out_3, out_2, out_1, out_0} = uo_out;

    // --- Bidirectional outputs ---
    assign {out_15, out_14, out_13, out_12, out_11, out_10, out_9, out_8} = uio_out;

    // --- Unused outputs: tie low ---
    assign {out_39, out_38, out_37, out_36, out_35, out_34, out_33, out_32,
            out_31, out_30, out_29, out_28, out_27, out_26, out_25, out_24,
            out_23, out_22, out_21, out_20, out_19, out_18, out_17, out_16} = 24'd0;

    // --- OEB: dedicated inputs always tristate ---
    assign {oeb_7, oeb_6, oeb_5, oeb_4, oeb_3, oeb_2, oeb_1, oeb_0} = 8'hFF;

    // --- OEB: bidirectional — invert TT polarity ---
    assign {oeb_15, oeb_14, oeb_13, oeb_12, oeb_11, oeb_10, oeb_9, oeb_8} = ~uio_oe;

    // --- OEB: unused pins tristate ---
    assign {oeb_39, oeb_38, oeb_37, oeb_36, oeb_35, oeb_34, oeb_33, oeb_32,
            oeb_31, oeb_30, oeb_29, oeb_28, oeb_27, oeb_26, oeb_25, oeb_24,
            oeb_23, oeb_22, oeb_21, oeb_20, oeb_19, oeb_18, oeb_17, oeb_16} = 24'hFFFFFF;

endmodule
