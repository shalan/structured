/////////////////////////////////////////////////////////////////////////////////////
// UART-to-SPI Bridge for SASIC Fabric
// Based on: https://github.com/FaresMehanna/UART-to-SPI-bridge
// Copyright (C) 2019 Fares Mehanna - GNU General Public License v2.0
/////////////////////////////////////////////////////////////////////////////////////

// ============================================================================
// SASIC Top-Level Wrapper
// ============================================================================

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
    output wire out_0, output wire out_1, output wire out_2, output wire out_3,
    output wire out_4, output wire out_5, output wire out_6, output wire out_7,
    output wire out_8, output wire out_9, output wire out_10, output wire out_11,
    output wire out_12, output wire out_13, output wire out_14, output wire out_15,
    output wire out_16, output wire out_17, output wire out_18, output wire out_19,
    output wire out_20, output wire out_21, output wire out_22, output wire out_23,
    output wire out_24, output wire out_25, output wire out_26, output wire out_27,
    output wire out_28, output wire out_29, output wire out_30, output wire out_31,
    output wire out_32, output wire out_33, output wire out_34, output wire out_35,
    output wire out_36, output wire out_37, output wire out_38, output wire out_39,
    output wire oeb_0, output wire oeb_1, output wire oeb_2, output wire oeb_3,
    output wire oeb_4, output wire oeb_5, output wire oeb_6, output wire oeb_7,
    output wire oeb_8, output wire oeb_9, output wire oeb_10, output wire oeb_11,
    output wire oeb_12, output wire oeb_13, output wire oeb_14, output wire oeb_15,
    output wire oeb_16, output wire oeb_17, output wire oeb_18, output wire oeb_19,
    output wire oeb_20, output wire oeb_21, output wire oeb_22, output wire oeb_23,
    output wire oeb_24, output wire oeb_25, output wire oeb_26, output wire oeb_27,
    output wire oeb_28, output wire oeb_29, output wire oeb_30, output wire oeb_31,
    output wire oeb_32, output wire oeb_33, output wire oeb_34, output wire oeb_35,
    output wire oeb_36, output wire oeb_37, output wire oeb_38, output wire oeb_39
);

    // ========================================================================
    // Pin Mapping:
    // ========================================================================
    // OUTPUTS (oeb = 0):
    //   out_0: tx_port (UART TX)
    //   out_1: sck (SPI Clock)
    //   out_2: mosi (SPI MOSI)
    //   out_3: ss_s (SPI Slave Select 0)
    //   out_4: ss_s_1 (SPI Slave Select 1)
    //   out_5: ss_s_2 (SPI Slave Select 2)
    //   out_6: ss_s_3 (SPI Slave Select 3)
    //
    // INPUTS (oeb = 1, high-Z):
    //   in_7: rx_port (UART RX)
    //   in_8: miso (SPI MISO)
    // ========================================================================

    wire rx_port = in_7;
    wire miso = in_8;

    wire tx_port;
    wire sck;
    wire mosi;
    wire ss_s;
    wire ss_s_1;
    wire ss_s_2;
    wire ss_s_3;

    // UART-to-SPI Bridge instance
    uart_to_spi_bridge u_bridge (
        .rx_port(rx_port),
        .tx_port(tx_port),
        .miso(miso),
        .sck(sck),
        .mosi(mosi),
        .ss_s(ss_s),
        .ss_s_1(ss_s_1),
        .ss_s_2(ss_s_2),
        .ss_s_3(ss_s_3),
        .sys_clk(clk),
        .sys_rst(~rst_n)
    );

    // ========================================================================
    // Output assignments
    // ========================================================================
    assign out_0 = tx_port;
    assign out_1 = sck;
    assign out_2 = mosi;
    assign out_3 = ss_s;
    assign out_4 = ss_s_1;
    assign out_5 = ss_s_2;
    assign out_6 = ss_s_3;

    // Unused outputs tied to 0
    assign {out_39, out_38, out_37, out_36, out_35, out_34, out_33, out_32} = 8'b0;
    assign {out_31, out_30, out_29, out_28, out_27, out_26, out_25, out_24} = 8'b0;
    assign {out_23, out_22, out_21, out_20, out_19, out_18, out_17, out_16} = 8'b0;
    assign {out_15, out_14, out_13, out_12, out_11, out_10, out_9,  out_8,  out_7} = 9'b0;

    // ========================================================================
    // Output enable assignments (0 = output active, 1 = high-Z/input)
    // ========================================================================
    // Outputs: pins 0-6
    assign {oeb_6, oeb_5, oeb_4, oeb_3, oeb_2, oeb_1, oeb_0} = 7'b0000000;

    // Inputs: pins 7-8 (high-Z to read from in_*)
    assign oeb_7 = 1'b1;
    assign oeb_8 = 1'b1;

    // Unused pins: high-Z
    assign {oeb_39, oeb_38, oeb_37, oeb_36, oeb_35, oeb_34, oeb_33, oeb_32} = 8'b11111111;
    assign {oeb_31, oeb_30, oeb_29, oeb_28, oeb_27, oeb_26, oeb_25, oeb_24} = 8'b11111111;
    assign {oeb_23, oeb_22, oeb_21, oeb_20, oeb_19, oeb_18, oeb_17, oeb_16} = 8'b11111111;
    assign {oeb_15, oeb_14, oeb_13, oeb_12, oeb_11, oeb_10, oeb_9} = 7'b1111111;

endmodule

// ============================================================================
// UART-to-SPI Bridge Core
// ============================================================================

module uart_to_spi_bridge(
    input rx_port,
    output reg tx_port,
    input miso,
    output reg sck,
    output reg mosi,
    output reg ss_s,
    output reg ss_s_1,
    output reg ss_s_2,
    output reg ss_s_3,
    input sys_clk,
    input sys_rst
);

reg uart_rx_ack = 1'd0;
reg [7:0] uart_rx_data = 8'd0;
reg uart_rx_ready = 1'd0;
reg [3:0] uart_rx_counter = 4'd9;
wire uart_rx_strobe;
reg [2:0] uart_rx_bitno = 3'd0;
reg [7:0] uart_tx_data = 8'd0;
reg uart_tx_ack = 1'd0;
reg uart_tx_ready = 1'd1;
reg [3:0] uart_tx_counter = 4'd0;
wire uart_tx_strobe;
reg [2:0] uart_tx_bitno = 3'd0;
reg [7:0] uart_tx_latch = 8'd0;
wire [3:0] spi_word_length;
wire [1:0] spi_ss_select;
wire spi_lsb_first;
wire spi_rising_edge;
reg spi_tx_start = 1'd0;
reg spi_rx_start = 1'd0;
reg spi_rx_ack = 1'd0;
reg [15:0] spi_tx_data = 16'd0;
wire [15:0] spi_rx_data;
reg spi_tx_ready = 1'd1;
reg spi_rx_ready = 1'd1;
reg spi_rx_data_ready = 1'd0;
reg [1:0] spi_clk_counter = 2'd3;
wire spi_tr_strobe_high;
wire spi_tr_strobe_low;
reg [3:0] spi_bitno = 4'd0;
reg [1:0] spi_ss_latch = 2'd0;
reg [3:0] spi_word_len_latch = 4'd0;
reg spi_operation_tx_latch = 1'd0;
reg [15:0] spi_rx_buffer = 16'd0;
reg [15:0] spi_tx_buffer = 16'd0;
reg [7:0] spi_man_instruction;
reg spi_man_valid_input;
wire [3:0] spi_man_word_length;
wire [1:0] spi_man_ss_select;
reg spi_man_lsb_first = 1'd1;
wire spi_man_rising_edge;
reg [3:0] spi_man_word_length_store = 4'd0;
reg [1:0] spi_man_ss_select_store = 2'd0;
reg spi_man_rising_edge_store = 1'd1;
reg [7:0] uart_buffer = 8'd0;
reg [15:0] spi_buffer = 16'd0;
reg [5:0] num_words = 6'd0;
reg [2:0] uart_rx_state = 3'd0;
reg [2:0] uart_rx_next_state;
reg [3:0] uart_rx_counter_uart_rx_t_next_value0;
reg uart_rx_counter_uart_rx_t_next_value_ce0;
reg uart_rx_ready_uart_rx_f_next_value;
reg uart_rx_ready_uart_rx_f_next_value_ce;
reg [7:0] uart_rx_data_uart_rx_t_next_value1;
reg uart_rx_data_uart_rx_t_next_value_ce1;
reg [2:0] uart_rx_bitno_uart_rx_t_next_value2;
reg uart_rx_bitno_uart_rx_t_next_value_ce2;
reg [1:0] uart_tx_state = 2'd0;
reg [1:0] uart_tx_next_state;
reg [3:0] uart_tx_counter_uart_tx_t_next_value0;
reg uart_tx_counter_uart_tx_t_next_value_ce0;
reg uart_tx_ready_uart_tx_t_next_value1;
reg uart_tx_ready_uart_tx_t_next_value_ce1;
reg [7:0] uart_tx_latch_uart_tx_t_next_value2;
reg uart_tx_latch_uart_tx_t_next_value_ce2;
reg uart_tx_port_uart_tx_f_next_value;
reg uart_tx_port_uart_tx_f_next_value_ce;
reg [2:0] uart_tx_bitno_uart_tx_t_next_value3;
reg uart_tx_bitno_uart_tx_t_next_value_ce3;
reg [1:0] spi_state = 2'd0;
reg [1:0] spi_next_state;
reg [15:0] spi_tx_buffer_spi_t_next_value0;
reg spi_tx_buffer_spi_t_next_value_ce0;
reg [1:0] spi_ss_latch_spi_t_next_value1;
reg spi_ss_latch_spi_t_next_value_ce1;
reg [3:0] spi_word_len_latch_spi_t_next_value2;
reg spi_word_len_latch_spi_t_next_value_ce2;
reg spi_operation_tx_latch_spi_t_next_value3;
reg spi_operation_tx_latch_spi_t_next_value_ce3;
reg spi_tx_ready_spi_t_next_value4;
reg spi_tx_ready_spi_t_next_value_ce4;
reg spi_rx_ready_spi_t_next_value5;
reg spi_rx_ready_spi_t_next_value_ce5;
reg spi_rx_data_ready_spi_f_next_value0;
reg spi_rx_data_ready_spi_f_next_value_ce0;
reg [15:0] spi_rx_buffer_spi_f_next_value1;
reg spi_rx_buffer_spi_f_next_value_ce1;
reg spi_next_value;
reg spi_next_value_ce;
reg spi_mosi_spi_t_next_value6;
reg spi_mosi_spi_t_next_value_ce6;
reg [3:0] spi_bitno_spi_t_next_value7;
reg spi_bitno_spi_t_next_value_ce7;
reg [3:0] fsm_state = 4'd0;
reg [3:0] fsm_next_state;
reg [7:0] uart_buffer_fsm_t_next_value0;
reg uart_buffer_fsm_t_next_value_ce0;
reg uart_rx_ack_fsm_t_next_value1;
reg uart_rx_ack_fsm_t_next_value_ce1;
reg spi_tx_start_fsm_f_next_value0;
reg spi_tx_start_fsm_f_next_value_ce0;
reg spi_rx_start_fsm_f_next_value1;
reg spi_rx_start_fsm_f_next_value_ce1;
reg spi_rx_ack_fsm_f_next_value2;
reg spi_rx_ack_fsm_f_next_value_ce2;
reg uart_tx_ack_fsm_f_next_value3;
reg uart_tx_ack_fsm_f_next_value_ce3;
reg [5:0] num_words_fsm_t_next_value2;
reg num_words_fsm_t_next_value_ce2;
reg [15:0] spi_buffer_fsm_t_next_value3;
reg spi_buffer_fsm_t_next_value_ce3;
reg [7:0] uart_tx_data_fsm_t_next_value4;
reg uart_tx_data_fsm_t_next_value_ce4;
reg [7:0] fsm_next_value0;
reg fsm_next_value_ce0;
reg [7:0] fsm_next_value1;
reg fsm_next_value_ce1;
reg [15:0] spi_tx_data_fsm_t_next_value5;
reg spi_tx_data_fsm_t_next_value_ce5;
reg array_muxed = 1'd0;

assign spi_word_length = spi_man_word_length_store;
assign spi_ss_select = spi_man_ss_select_store;
assign spi_lsb_first = spi_man_lsb_first;
assign spi_man_rising_edge = spi_man_rising_edge_store;
assign spi_rising_edge = spi_man_rising_edge;
assign uart_rx_strobe = (uart_rx_counter == 1'd0);

always @(*) begin
    uart_rx_next_state <= 3'd0;
    uart_rx_counter_uart_rx_t_next_value0 <= 4'd0;
    uart_rx_counter_uart_rx_t_next_value_ce0 <= 1'd0;
    uart_rx_ready_uart_rx_f_next_value <= 1'd0;
    uart_rx_ready_uart_rx_f_next_value_ce <= 1'd0;
    uart_rx_data_uart_rx_t_next_value1 <= 8'd0;
    uart_rx_data_uart_rx_t_next_value_ce1 <= 1'd0;
    uart_rx_bitno_uart_rx_t_next_value2 <= 3'd0;
    uart_rx_bitno_uart_rx_t_next_value_ce2 <= 1'd0;
    uart_rx_next_state <= uart_rx_state;
    case (uart_rx_state)
        1'd1: begin
            if (uart_rx_strobe) begin
                uart_rx_next_state <= 2'd2;
            end
        end
        2'd2: begin
            if (uart_rx_strobe) begin
                uart_rx_data_uart_rx_t_next_value1 <= {rx_port, uart_rx_data[7:1]};
                uart_rx_data_uart_rx_t_next_value_ce1 <= 1'd1;
                uart_rx_bitno_uart_rx_t_next_value2 <= (uart_rx_bitno + 1'd1);
                uart_rx_bitno_uart_rx_t_next_value_ce2 <= 1'd1;
                if ((uart_rx_bitno == 3'd7)) begin
                    uart_rx_next_state <= 2'd3;
                end
            end
        end
        2'd3: begin
            if ((uart_rx_strobe & rx_port)) begin
                uart_rx_ready_uart_rx_f_next_value <= 1'd1;
                uart_rx_ready_uart_rx_f_next_value_ce <= 1'd1;
                uart_rx_next_state <= 3'd4;
            end
        end
        3'd4: begin
            if (uart_rx_ack) begin
                uart_rx_ready_uart_rx_f_next_value <= 1'd0;
                uart_rx_ready_uart_rx_f_next_value_ce <= 1'd1;
                uart_rx_next_state <= 1'd0;
            end
        end
        default: begin
            if ((~rx_port)) begin
                uart_rx_counter_uart_rx_t_next_value0 <= 3'd5;
                uart_rx_counter_uart_rx_t_next_value_ce0 <= 1'd1;
                uart_rx_next_state <= 1'd1;
            end else begin
                uart_rx_ready_uart_rx_f_next_value <= 1'd0;
                uart_rx_ready_uart_rx_f_next_value_ce <= 1'd1;
            end
        end
    endcase
end

assign uart_tx_strobe = (uart_tx_counter == 1'd0);

always @(*) begin
    uart_tx_next_state <= 2'd0;
    uart_tx_counter_uart_tx_t_next_value0 <= 4'd0;
    uart_tx_counter_uart_tx_t_next_value_ce0 <= 1'd0;
    uart_tx_ready_uart_tx_t_next_value1 <= 1'd0;
    uart_tx_ready_uart_tx_t_next_value_ce1 <= 1'd0;
    uart_tx_latch_uart_tx_t_next_value2 <= 8'd0;
    uart_tx_latch_uart_tx_t_next_value_ce2 <= 1'd0;
    uart_tx_port_uart_tx_f_next_value <= 1'd0;
    uart_tx_port_uart_tx_f_next_value_ce <= 1'd0;
    uart_tx_bitno_uart_tx_t_next_value3 <= 3'd0;
    uart_tx_bitno_uart_tx_t_next_value_ce3 <= 1'd0;
    uart_tx_next_state <= uart_tx_state;
    case (uart_tx_state)
        1'd1: begin
            if (uart_tx_strobe) begin
                uart_tx_port_uart_tx_f_next_value <= 1'd0;
                uart_tx_port_uart_tx_f_next_value_ce <= 1'd1;
                uart_tx_next_state <= 2'd2;
            end
        end
        2'd2: begin
            if (uart_tx_strobe) begin
                uart_tx_port_uart_tx_f_next_value <= uart_tx_latch[0];
                uart_tx_port_uart_tx_f_next_value_ce <= 1'd1;
                uart_tx_latch_uart_tx_t_next_value2 <= {1'd0, uart_tx_latch[7:1]};
                uart_tx_latch_uart_tx_t_next_value_ce2 <= 1'd1;
                uart_tx_bitno_uart_tx_t_next_value3 <= (uart_tx_bitno + 1'd1);
                uart_tx_bitno_uart_tx_t_next_value_ce3 <= 1'd1;
                if ((uart_tx_bitno == 3'd7)) begin
                    uart_tx_next_state <= 2'd3;
                end
            end
        end
        2'd3: begin
            if (uart_tx_strobe) begin
                uart_tx_port_uart_tx_f_next_value <= 1'd1;
                uart_tx_port_uart_tx_f_next_value_ce <= 1'd1;
                uart_tx_ready_uart_tx_t_next_value1 <= 1'd1;
                uart_tx_ready_uart_tx_t_next_value_ce1 <= 1'd1;
                uart_tx_next_state <= 1'd0;
            end
        end
        default: begin
            if (uart_tx_ack) begin
                uart_tx_counter_uart_tx_t_next_value0 <= 4'd9;
                uart_tx_counter_uart_tx_t_next_value_ce0 <= 1'd1;
                uart_tx_ready_uart_tx_t_next_value1 <= 1'd0;
                uart_tx_ready_uart_tx_t_next_value_ce1 <= 1'd1;
                uart_tx_latch_uart_tx_t_next_value2 <= uart_tx_data;
                uart_tx_latch_uart_tx_t_next_value_ce2 <= 1'd1;
                uart_tx_next_state <= 1'd1;
            end else begin
                uart_tx_port_uart_tx_f_next_value <= 1'd1;
                uart_tx_port_uart_tx_f_next_value_ce <= 1'd1;
                uart_tx_ready_uart_tx_t_next_value1 <= 1'd1;
                uart_tx_ready_uart_tx_t_next_value_ce1 <= 1'd1;
            end
        end
    endcase
end

assign spi_tr_strobe_high = (spi_clk_counter == 1'd0);
assign spi_tr_strobe_low = (spi_clk_counter == 2'd2);
assign spi_rx_data = spi_rx_buffer;

always @(*) begin
    spi_next_state <= 2'd0;
    spi_tx_buffer_spi_t_next_value0 <= 16'd0;
    spi_tx_buffer_spi_t_next_value_ce0 <= 1'd0;
    spi_ss_latch_spi_t_next_value1 <= 2'd0;
    spi_ss_latch_spi_t_next_value_ce1 <= 1'd0;
    spi_word_len_latch_spi_t_next_value2 <= 4'd0;
    spi_word_len_latch_spi_t_next_value_ce2 <= 1'd0;
    spi_operation_tx_latch_spi_t_next_value3 <= 1'd0;
    spi_operation_tx_latch_spi_t_next_value_ce3 <= 1'd0;
    spi_tx_ready_spi_t_next_value4 <= 1'd0;
    spi_tx_ready_spi_t_next_value_ce4 <= 1'd0;
    spi_rx_ready_spi_t_next_value5 <= 1'd0;
    spi_rx_ready_spi_t_next_value_ce5 <= 1'd0;
    spi_rx_data_ready_spi_f_next_value0 <= 1'd0;
    spi_rx_data_ready_spi_f_next_value_ce0 <= 1'd0;
    spi_rx_buffer_spi_f_next_value1 <= 16'd0;
    spi_rx_buffer_spi_f_next_value_ce1 <= 1'd0;
    spi_next_value <= 1'd0;
    spi_next_value_ce <= 1'd0;
    spi_mosi_spi_t_next_value6 <= 1'd0;
    spi_mosi_spi_t_next_value_ce6 <= 1'd0;
    spi_bitno_spi_t_next_value7 <= 4'd0;
    spi_bitno_spi_t_next_value_ce7 <= 1'd0;
    spi_next_state <= spi_state;
    case (spi_state)
        1'd1: begin
            if (((spi_rising_edge & spi_tr_strobe_high) | ((~spi_rising_edge) & spi_tr_strobe_low))) begin
                spi_next_value <= 1'd0;
                spi_next_value_ce <= 1'd1;
                if (spi_lsb_first) begin
                    spi_rx_buffer_spi_f_next_value1 <= {miso, spi_rx_buffer[15:1]};
                    spi_rx_buffer_spi_f_next_value_ce1 <= 1'd1;
                end else begin
                    spi_rx_buffer_spi_f_next_value1 <= {spi_rx_buffer[14:0], miso};
                    spi_rx_buffer_spi_f_next_value_ce1 <= 1'd1;
                end
                if (spi_lsb_first) begin
                    spi_mosi_spi_t_next_value6 <= spi_tx_buffer[0];
                    spi_mosi_spi_t_next_value_ce6 <= 1'd1;
                    spi_tx_buffer_spi_t_next_value0 <= {1'd0, spi_tx_buffer[15:1]};
                    spi_tx_buffer_spi_t_next_value_ce0 <= 1'd1;
                end else begin
                    spi_mosi_spi_t_next_value6 <= spi_tx_buffer[15];
                    spi_mosi_spi_t_next_value_ce6 <= 1'd1;
                    spi_tx_buffer_spi_t_next_value0 <= {spi_tx_buffer[14:0], 1'd0};
                    spi_tx_buffer_spi_t_next_value_ce0 <= 1'd1;
                end
                spi_bitno_spi_t_next_value7 <= (spi_bitno + 1'd1);
                spi_bitno_spi_t_next_value_ce7 <= 1'd1;
                if ((spi_bitno == spi_word_len_latch)) begin
                    spi_next_state <= 2'd2;
                    if ((~spi_operation_tx_latch)) begin
                        spi_rx_data_ready_spi_f_next_value0 <= 1'd1;
                        spi_rx_data_ready_spi_f_next_value_ce0 <= 1'd1;
                    end
                end
            end
        end
        2'd2: begin
            spi_next_value <= 1'd1;
            spi_next_value_ce <= 1'd1;
            spi_bitno_spi_t_next_value7 <= 1'd0;
            spi_bitno_spi_t_next_value_ce7 <= 1'd1;
            if (spi_operation_tx_latch) begin
                spi_next_state <= 1'd0;
            end else begin
                if (spi_rx_ack) begin
                    spi_next_state <= 1'd0;
                    spi_rx_data_ready_spi_f_next_value0 <= 1'd0;
                    spi_rx_data_ready_spi_f_next_value_ce0 <= 1'd1;
                end
            end
        end
        default: begin
            if ((spi_tx_start | spi_rx_start)) begin
                spi_tx_buffer_spi_t_next_value0 <= spi_tx_data;
                spi_tx_buffer_spi_t_next_value_ce0 <= 1'd1;
                spi_ss_latch_spi_t_next_value1 <= spi_ss_select;
                spi_ss_latch_spi_t_next_value_ce1 <= 1'd1;
                spi_word_len_latch_spi_t_next_value2 <= spi_word_length;
                spi_word_len_latch_spi_t_next_value_ce2 <= 1'd1;
                spi_operation_tx_latch_spi_t_next_value3 <= spi_tx_start;
                spi_operation_tx_latch_spi_t_next_value_ce3 <= 1'd1;
                spi_tx_ready_spi_t_next_value4 <= 1'd0;
                spi_tx_ready_spi_t_next_value_ce4 <= 1'd1;
                spi_rx_ready_spi_t_next_value5 <= 1'd0;
                spi_rx_ready_spi_t_next_value_ce5 <= 1'd1;
                spi_next_state <= 1'd1;
            end else begin
                spi_tx_ready_spi_t_next_value4 <= 1'd1;
                spi_tx_ready_spi_t_next_value_ce4 <= 1'd1;
                spi_rx_ready_spi_t_next_value5 <= 1'd1;
                spi_rx_ready_spi_t_next_value_ce5 <= 1'd1;
                spi_rx_data_ready_spi_f_next_value0 <= 1'd0;
                spi_rx_data_ready_spi_f_next_value_ce0 <= 1'd1;
                spi_rx_buffer_spi_f_next_value1 <= 1'd0;
                spi_rx_buffer_spi_f_next_value_ce1 <= 1'd1;
                spi_tx_buffer_spi_t_next_value0 <= 1'd0;
                spi_tx_buffer_spi_t_next_value_ce0 <= 1'd1;
            end
        end
    endcase
end

assign spi_man_word_length = spi_man_word_length_store;
assign spi_man_ss_select = spi_man_ss_select_store;
assign spi_man_rising_edge = spi_man_rising_edge_store;

always @(*) begin
    spi_man_instruction <= 8'd0;
    spi_man_valid_input <= 1'd0;
    fsm_next_state <= 4'd0;
    uart_buffer_fsm_t_next_value0 <= 8'd0;
    uart_buffer_fsm_t_next_value_ce0 <= 1'd0;
    uart_rx_ack_fsm_t_next_value1 <= 1'd0;
    uart_rx_ack_fsm_t_next_value_ce1 <= 1'd0;
    spi_tx_start_fsm_f_next_value0 <= 1'd0;
    spi_tx_start_fsm_f_next_value_ce0 <= 1'd0;
    spi_rx_start_fsm_f_next_value1 <= 1'd0;
    spi_rx_start_fsm_f_next_value_ce1 <= 1'd0;
    spi_rx_ack_fsm_f_next_value2 <= 1'd0;
    spi_rx_ack_fsm_f_next_value_ce2 <= 1'd0;
    uart_tx_ack_fsm_f_next_value3 <= 1'd0;
    uart_tx_ack_fsm_f_next_value_ce3 <= 1'd0;
    num_words_fsm_t_next_value2 <= 6'd0;
    num_words_fsm_t_next_value_ce2 <= 1'd0;
    spi_buffer_fsm_t_next_value3 <= 16'd0;
    spi_buffer_fsm_t_next_value_ce3 <= 1'd0;
    uart_tx_data_fsm_t_next_value4 <= 8'd0;
    uart_tx_data_fsm_t_next_value_ce4 <= 1'd0;
    fsm_next_value0 <= 8'd0;
    fsm_next_value_ce0 <= 1'd0;
    fsm_next_value1 <= 8'd0;
    fsm_next_value_ce1 <= 1'd0;
    spi_tx_data_fsm_t_next_value5 <= 16'd0;
    spi_tx_data_fsm_t_next_value_ce5 <= 1'd0;
    fsm_next_state <= fsm_state;
    case (fsm_state)
        1'd1: begin
            uart_rx_ack_fsm_t_next_value1 <= 1'd0;
            uart_rx_ack_fsm_t_next_value_ce1 <= 1'd1;
            if (uart_buffer[7]) begin
                num_words_fsm_t_next_value2 <= uart_buffer[5:0];
                num_words_fsm_t_next_value_ce2 <= 1'd1;
                if (uart_buffer[6]) begin
                    fsm_next_state <= 2'd3;
                end else begin
                    fsm_next_state <= 4'd9;
                end
            end else begin
                spi_man_instruction <= uart_buffer;
                spi_man_valid_input <= 1'd1;
                fsm_next_state <= 2'd2;
            end
        end
        2'd2: begin
            spi_man_valid_input <= 1'd0;
            fsm_next_state <= 1'd0;
        end
        2'd3: begin
            uart_tx_ack_fsm_f_next_value3 <= 1'd0;
            uart_tx_ack_fsm_f_next_value_ce3 <= 1'd1;
            if ((num_words == 1'd0)) begin
                fsm_next_state <= 1'd0;
            end else begin
                num_words_fsm_t_next_value2 <= (num_words - 1'd1);
                num_words_fsm_t_next_value_ce2 <= 1'd1;
                fsm_next_state <= 3'd4;
            end
        end
        3'd4: begin
            if (spi_rx_ready) begin
                spi_rx_start_fsm_f_next_value1 <= 1'd1;
                spi_rx_start_fsm_f_next_value_ce1 <= 1'd1;
                fsm_next_state <= 3'd5;
            end
        end
        3'd5: begin
            spi_rx_start_fsm_f_next_value1 <= 1'd0;
            spi_rx_start_fsm_f_next_value_ce1 <= 1'd1;
            if (spi_rx_data_ready) begin
                spi_buffer_fsm_t_next_value3 <= spi_rx_data;
                spi_buffer_fsm_t_next_value_ce3 <= 1'd1;
                spi_rx_ack_fsm_f_next_value2 <= 1'd1;
                spi_rx_ack_fsm_f_next_value_ce2 <= 1'd1;
                fsm_next_state <= 3'd6;
            end
        end
        3'd6: begin
            spi_rx_ack_fsm_f_next_value2 <= 1'd0;
            spi_rx_ack_fsm_f_next_value_ce2 <= 1'd1;
            if (uart_tx_ready) begin
                uart_tx_data_fsm_t_next_value4 <= spi_buffer[7:0];
                uart_tx_data_fsm_t_next_value_ce4 <= 1'd1;
                uart_tx_ack_fsm_f_next_value3 <= 1'd1;
                uart_tx_ack_fsm_f_next_value_ce3 <= 1'd1;
                if ((spi_man_word_length > 3'd7)) begin
                    fsm_next_state <= 3'd7;
                end else begin
                    fsm_next_state <= 2'd3;
                end
            end
        end
        3'd7: begin
            uart_tx_ack_fsm_f_next_value3 <= 1'd0;
            uart_tx_ack_fsm_f_next_value_ce3 <= 1'd1;
            fsm_next_state <= 4'd8;
        end
        4'd8: begin
            if (uart_tx_ready) begin
                uart_tx_data_fsm_t_next_value4 <= spi_buffer[15:8];
                uart_tx_data_fsm_t_next_value_ce4 <= 1'd1;
                uart_tx_ack_fsm_f_next_value3 <= 1'd1;
                uart_tx_ack_fsm_f_next_value_ce3 <= 1'd1;
                fsm_next_state <= 2'd3;
            end
        end
        4'd9: begin
            spi_tx_start_fsm_f_next_value0 <= 1'd0;
            spi_tx_start_fsm_f_next_value_ce0 <= 1'd1;
            if ((num_words == 1'd0)) begin
                fsm_next_state <= 1'd0;
            end else begin
                num_words_fsm_t_next_value2 <= (num_words - 1'd1);
                num_words_fsm_t_next_value_ce2 <= 1'd1;
                fsm_next_state <= 4'd10;
            end
        end
        4'd10: begin
            if (uart_rx_ready) begin
                fsm_next_value0 <= uart_rx_data;
                fsm_next_value_ce0 <= 1'd1;
                uart_rx_ack_fsm_t_next_value1 <= 1'd1;
                uart_rx_ack_fsm_t_next_value_ce1 <= 1'd1;
                if ((spi_man_word_length > 3'd7)) begin
                    fsm_next_state <= 4'd11;
                end else begin
                    fsm_next_state <= 4'd13;
                end
            end
        end
        4'd11: begin
            uart_rx_ack_fsm_t_next_value1 <= 1'd0;
            uart_rx_ack_fsm_t_next_value_ce1 <= 1'd1;
            fsm_next_state <= 4'd12;
        end
        4'd12: begin
            if (uart_rx_ready) begin
                fsm_next_value1 <= uart_rx_data;
                fsm_next_value_ce1 <= 1'd1;
                uart_rx_ack_fsm_t_next_value1 <= 1'd1;
                uart_rx_ack_fsm_t_next_value_ce1 <= 1'd1;
                fsm_next_state <= 4'd13;
            end
        end
        4'd13: begin
            uart_rx_ack_fsm_t_next_value1 <= 1'd0;
            uart_rx_ack_fsm_t_next_value_ce1 <= 1'd1;
            if (spi_tx_ready) begin
                spi_tx_data_fsm_t_next_value5 <= spi_buffer;
                spi_tx_data_fsm_t_next_value_ce5 <= 1'd1;
                spi_tx_start_fsm_f_next_value0 <= 1'd1;
                spi_tx_start_fsm_f_next_value_ce0 <= 1'd1;
                fsm_next_state <= 4'd9;
            end
        end
        default: begin
            if (uart_rx_ready) begin
                uart_buffer_fsm_t_next_value0 <= uart_rx_data;
                uart_buffer_fsm_t_next_value_ce0 <= 1'd1;
                uart_rx_ack_fsm_t_next_value1 <= 1'd1;
                uart_rx_ack_fsm_t_next_value_ce1 <= 1'd1;
                fsm_next_state <= 1'd1;
            end else begin
                spi_tx_start_fsm_f_next_value0 <= 1'd0;
                spi_tx_start_fsm_f_next_value_ce0 <= 1'd1;
                spi_rx_start_fsm_f_next_value1 <= 1'd0;
                spi_rx_start_fsm_f_next_value_ce1 <= 1'd1;
                spi_rx_ack_fsm_f_next_value2 <= 1'd0;
                spi_rx_ack_fsm_f_next_value_ce2 <= 1'd1;
                uart_rx_ack_fsm_t_next_value1 <= 1'd0;
                uart_rx_ack_fsm_t_next_value_ce1 <= 1'd1;
                uart_tx_ack_fsm_f_next_value3 <= 1'd0;
                uart_tx_ack_fsm_f_next_value_ce3 <= 1'd1;
            end
        end
    endcase
end

always @(posedge sys_clk) begin
    if ((uart_rx_counter == 1'd0)) begin
        uart_rx_counter <= 4'd9;
    end else begin
        uart_rx_counter <= (uart_rx_counter - 1'd1);
    end
    uart_rx_state <= uart_rx_next_state;
    if (uart_rx_counter_uart_rx_t_next_value_ce0) begin
        uart_rx_counter <= uart_rx_counter_uart_rx_t_next_value0;
    end
    if (uart_rx_ready_uart_rx_f_next_value_ce) begin
        uart_rx_ready <= uart_rx_ready_uart_rx_f_next_value;
    end
    if (uart_rx_data_uart_rx_t_next_value_ce1) begin
        uart_rx_data <= uart_rx_data_uart_rx_t_next_value1;
    end
    if (uart_rx_bitno_uart_rx_t_next_value_ce2) begin
        uart_rx_bitno <= uart_rx_bitno_uart_rx_t_next_value2;
    end
    if ((uart_tx_counter == 1'd0)) begin
        uart_tx_counter <= 4'd9;
    end else begin
        uart_tx_counter <= (uart_tx_counter - 1'd1);
    end
    uart_tx_state <= uart_tx_next_state;
    if (uart_tx_counter_uart_tx_t_next_value_ce0) begin
        uart_tx_counter <= uart_tx_counter_uart_tx_t_next_value0;
    end
    if (uart_tx_ready_uart_tx_t_next_value_ce1) begin
        uart_tx_ready <= uart_tx_ready_uart_tx_t_next_value1;
    end
    if (uart_tx_latch_uart_tx_t_next_value_ce2) begin
        uart_tx_latch <= uart_tx_latch_uart_tx_t_next_value2;
    end
    if (uart_tx_port_uart_tx_f_next_value_ce) begin
        tx_port <= uart_tx_port_uart_tx_f_next_value;
    end
    if (uart_tx_bitno_uart_tx_t_next_value_ce3) begin
        uart_tx_bitno <= uart_tx_bitno_uart_tx_t_next_value3;
    end
    if ((spi_clk_counter == 1'd0)) begin
        spi_clk_counter <= 2'd3;
    end else begin
        spi_clk_counter <= (spi_clk_counter - 1'd1);
    end
    if (((spi_clk_counter == 1'd0) | (spi_clk_counter == 2'd2))) begin
        sck <= (~sck);
    end
    spi_state <= spi_next_state;
    if (spi_tx_buffer_spi_t_next_value_ce0) begin
        spi_tx_buffer <= spi_tx_buffer_spi_t_next_value0;
    end
    if (spi_ss_latch_spi_t_next_value_ce1) begin
        spi_ss_latch <= spi_ss_latch_spi_t_next_value1;
    end
    if (spi_word_len_latch_spi_t_next_value_ce2) begin
        spi_word_len_latch <= spi_word_len_latch_spi_t_next_value2;
    end
    if (spi_operation_tx_latch_spi_t_next_value_ce3) begin
        spi_operation_tx_latch <= spi_operation_tx_latch_spi_t_next_value3;
    end
    if (spi_tx_ready_spi_t_next_value_ce4) begin
        spi_tx_ready <= spi_tx_ready_spi_t_next_value4;
    end
    if (spi_rx_ready_spi_t_next_value_ce5) begin
        spi_rx_ready <= spi_rx_ready_spi_t_next_value5;
    end
    if (spi_rx_data_ready_spi_f_next_value_ce0) begin
        spi_rx_data_ready <= spi_rx_data_ready_spi_f_next_value0;
    end
    if (spi_rx_buffer_spi_f_next_value_ce1) begin
        spi_rx_buffer <= spi_rx_buffer_spi_f_next_value1;
    end
    if (spi_next_value_ce) begin
        array_muxed = spi_next_value;
        case (spi_ss_latch)
            1'd0: begin
                ss_s <= array_muxed;
            end
            1'd1: begin
                ss_s_1 <= array_muxed;
            end
            2'd2: begin
                ss_s_2 <= array_muxed;
            end
            default: begin
                ss_s_3 <= array_muxed;
            end
        endcase
    end
    if (spi_mosi_spi_t_next_value_ce6) begin
        mosi <= spi_mosi_spi_t_next_value6;
    end
    if (spi_bitno_spi_t_next_value_ce7) begin
        spi_bitno <= spi_bitno_spi_t_next_value7;
    end
    if ((spi_man_valid_input & (~spi_man_instruction[7]))) begin
        case (spi_man_instruction[6:4])
            1'd0: begin
                spi_man_word_length_store <= spi_man_instruction[3:0];
            end
            1'd1: begin
                spi_man_ss_select_store <= spi_man_instruction[1:0];
            end
            2'd2: begin
                spi_man_lsb_first <= spi_man_instruction[0];
            end
            2'd3: begin
                spi_man_rising_edge_store <= spi_man_instruction[0];
            end
        endcase
    end
    fsm_state <= fsm_next_state;
    if (uart_buffer_fsm_t_next_value_ce0) begin
        uart_buffer <= uart_buffer_fsm_t_next_value0;
    end
    if (uart_rx_ack_fsm_t_next_value_ce1) begin
        uart_rx_ack <= uart_rx_ack_fsm_t_next_value1;
    end
    if (spi_tx_start_fsm_f_next_value_ce0) begin
        spi_tx_start <= spi_tx_start_fsm_f_next_value0;
    end
    if (spi_rx_start_fsm_f_next_value_ce1) begin
        spi_rx_start <= spi_rx_start_fsm_f_next_value1;
    end
    if (spi_rx_ack_fsm_f_next_value_ce2) begin
        spi_rx_ack <= spi_rx_ack_fsm_f_next_value2;
    end
    if (uart_tx_ack_fsm_f_next_value_ce3) begin
        uart_tx_ack <= uart_tx_ack_fsm_f_next_value3;
    end
    if (num_words_fsm_t_next_value_ce2) begin
        num_words <= num_words_fsm_t_next_value2;
    end
    if (spi_buffer_fsm_t_next_value_ce3) begin
        spi_buffer <= spi_buffer_fsm_t_next_value3;
    end
    if (uart_tx_data_fsm_t_next_value_ce4) begin
        uart_tx_data <= uart_tx_data_fsm_t_next_value4;
    end
    if (fsm_next_value_ce0) begin
        spi_buffer[7:0] <= fsm_next_value0;
    end
    if (fsm_next_value_ce1) begin
        spi_buffer[15:8] <= fsm_next_value1;
    end
    if (spi_tx_data_fsm_t_next_value_ce5) begin
        spi_tx_data <= spi_tx_data_fsm_t_next_value5;
    end
    if (sys_rst) begin
        uart_rx_ack <= 1'd0;
        uart_rx_data <= 8'd0;
        uart_rx_ready <= 1'd0;
        uart_rx_counter <= 4'd9;
        uart_rx_bitno <= 3'd0;
        uart_tx_data <= 8'd0;
        uart_tx_ack <= 1'd0;
        tx_port <= 1'd1;
        uart_tx_ready <= 1'd1;
        uart_tx_counter <= 4'd0;
        uart_tx_bitno <= 3'd0;
        uart_tx_latch <= 8'd0;
        spi_tx_start <= 1'd0;
        spi_rx_start <= 1'd0;
        spi_rx_ack <= 1'd0;
        spi_tx_data <= 16'd0;
        spi_tx_ready <= 1'd1;
        spi_rx_ready <= 1'd1;
        spi_rx_data_ready <= 1'd0;
        sck <= 1'd1;
        mosi <= 1'd0;
        ss_s <= 1'd1;
        ss_s_1 <= 1'd1;
        ss_s_2 <= 1'd1;
        ss_s_3 <= 1'd1;
        spi_clk_counter <= 2'd3;
        spi_bitno <= 4'd0;
        spi_ss_latch <= 2'd0;
        spi_word_len_latch <= 4'd0;
        spi_operation_tx_latch <= 1'd0;
        spi_rx_buffer <= 16'd0;
        spi_tx_buffer <= 16'd0;
        spi_man_lsb_first <= 1'd1;
        spi_man_rising_edge_store <= 1'd1;
        spi_man_word_length_store <= 4'd0;
        spi_man_ss_select_store <= 2'd0;
        uart_buffer <= 8'd0;
        spi_buffer <= 16'd0;
        num_words <= 6'd0;
        uart_rx_state <= 3'd0;
        uart_tx_state <= 2'd0;
        spi_state <= 2'd0;
        fsm_state <= 4'd0;
    end
end

endmodule
