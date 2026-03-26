// tt_bit_serial_cpu.v — Single-file TT design: SKY130 Bit-Serial CPU
// Source: https://github.com/ndrwng/SKY130-bit-serial-cpu
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

// =============================================================================
// Accumulator — shift register with optional parallel load
// =============================================================================
module accumulator
#(parameter WIDTH = 8)
(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      acc_write_en,
    input  wire                      acc_load_en,
    input  wire  [WIDTH-1:0]         acc_parallel_in,
    input  wire                      alu_result,
    input  wire  [$clog2(WIDTH)-1:0] bit_index_d,
    output reg   [WIDTH-1:0]         acc_bits,
    output reg                       done
);

    always @(posedge clk) begin
        if (!rst_n) begin
            acc_bits <= {WIDTH{1'b0}};
        end else if (acc_load_en) begin
            acc_bits <= acc_parallel_in;
        end else if (acc_write_en) begin
            acc_bits[bit_index_d] <= alu_result;
        end
    end

    always @(*) begin
        if (bit_index_d == WIDTH - 2) begin
            done = 1;
        end
        else begin
            done = 0;
        end
    end

endmodule

// =============================================================================
// 1-bit Serial ALU
// =============================================================================
module alu_1bit (
    input  wire clk,
    input  wire rst_n,
    input  wire rs1,
    input  wire rs2,
    input  wire [2:0] alu_op,
    input  wire alu_en,
    input  wire alu_start,
    output reg alu_result
);

    wire carry_out;
    reg carry_in;
    wire inverted = ~rs2;

    always @(posedge clk) begin
        carry_in   <= carry_out;
        if (!rst_n) begin
            carry_in   <= 1'b0;
            alu_result <= 1'b0;
        end else if (alu_en) begin
            case (alu_op)
                3'b000: alu_result <= rs1 ^ rs2 ^ carry_in;        // ADD
                3'b001:                                             // SUB
                    if (alu_start)
                        alu_result <= rs1 ^ inverted ^ 1'b1;
                    else
                        alu_result <= rs1 ^ inverted ^ carry_in;
                3'b010: alu_result <= rs1 ^ rs2;                    // XOR
                3'b011: alu_result <= rs1 & rs2;                    // AND
                3'b100: alu_result <= rs1 | rs2;                    // OR
                3'b101,
                3'b110: alu_result <= rs1;                          // SLLI, SRLI
                default: alu_result <= 1'b0;
            endcase
        end
    end

    assign carry_out = (alu_start && (alu_op == 3'b001)) ? 1'b1 :
                       (alu_en && (alu_op == 3'b001)) ? (rs1 & inverted) | (rs1 & carry_in) | (inverted & carry_in) :
                       (alu_en && (alu_op == 3'b000)) ? (rs1 & rs2) | (rs1 & carry_in) | (rs2 & carry_in) :
                       1'b0;

endmodule

// =============================================================================
// Serial-access Register File
// =============================================================================
module regfile_serial #(
    parameter REG_WIDTH = 8,
    parameter REG_COUNT = 8
)(
    input  wire               clk,
    input  wire               rstn,
    input  wire               reg_shift_en,
    input  wire [11:0]        instr,
    input  wire [7:0]         regs_parallel_in,
    input  wire [2:0]         alu_op,
    output reg  [2:0]         bit_index,
    output wire [7:0]         regfile_bits,
    output wire               rs1_bit,
    output wire               rs2_bit,
    input  wire               reg_store_en
);

    wire [2:0] rs1_addr  = instr[2:0];
    wire [2:0] rs2_addr  = instr[6:4];
    wire [2:0] shift_imm = (instr[11:4] >= 7) ? 3'b111 : instr[6:4];

    reg [REG_WIDTH-1:0] regs [0:REG_COUNT-1];

    /* verilator lint_off UNUSED */
    wire unused_instr3 = instr[3];
    /* verilator lint_on UNUSED */

    integer i;

    always @(posedge clk) begin
        if (!rstn) begin
            bit_index <= 0;
            for (i = 0; i < REG_COUNT; i = i + 1)
                regs[i] <= 0;
        end else if (reg_shift_en) begin
            bit_index <= bit_index + 1;
        end else if (reg_store_en & rs1_addr != 3'b0) begin
            regs[rs1_addr] <= regs_parallel_in;
        end
    end

    wire sl_bit = (bit_index >= shift_imm)
                ? regs[rs1_addr][bit_index - shift_imm]
                : 1'b0;
    wire sr_bit = ((bit_index + shift_imm) < REG_WIDTH)
                ? regs[rs1_addr][bit_index + shift_imm]
                : 1'b0;
    assign rs1_bit =
        (alu_op == 3'b101) ? sl_bit :
        (alu_op == 3'b110) ? sr_bit :
        regs[rs1_addr][bit_index];

    assign rs2_bit = regs[rs2_addr][bit_index];
    assign regfile_bits = regs[rs1_addr];

endmodule

// =============================================================================
// FSM Control
// =============================================================================
module fsm_control (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  opcode,
    input  wire        inst_done,
    input  wire        btn_edge,
    input  wire        bit_done,
    output reg         alu_start,
    output reg         reg_shift_en,
    output reg         reg_store_en,
    output reg         acc_write_en,
    output reg         acc_load_en,
    output reg  [2:0]  alu_op,
    output reg         alu_en,
    output reg         out_en
);

    parameter S_IDLE      = 3'd0;
    parameter S_DECODE    = 3'd1;
    parameter S_SHIFT_REGS   = 3'd2;
    parameter S_WRITE_ACC = 3'd3;
    parameter S_OUTPUT = 3'd4;

    reg [2:0] state, next_state;

    function [2:0] decode_alu_op(input [3:0] opc);
        case (opc)
            4'b0000, 4'b1000: decode_alu_op = 3'b000;
            4'b0001, 4'b1001: decode_alu_op = 3'b001;
            4'b0110, 4'b1100: decode_alu_op = 3'b010;
            4'b0101, 4'b1011: decode_alu_op = 3'b011;
            4'b0100, 4'b1010: decode_alu_op = 3'b100;
            4'b0010:          decode_alu_op = 3'b101;
            4'b0011:          decode_alu_op = 3'b110;
            default:          decode_alu_op = 3'b000;
        endcase
    endfunction

    always @(posedge clk) begin
        if (!rst_n)
            state <= S_IDLE;
        else begin
            if (state == S_OUTPUT || state == S_DECODE)
                out_en <= 1;
            else
                out_en <= 0;
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            default:
                next_state = S_IDLE;
            S_IDLE:
                if (btn_edge && inst_done)
                    next_state = S_DECODE;
            S_DECODE:
                if (opcode == 4'b0111 || opcode == 4'b1101 || opcode == 4'b1110)
                    next_state = S_IDLE;
                else next_state = S_SHIFT_REGS;
            S_SHIFT_REGS:
                if (bit_done)
                    next_state = S_OUTPUT;
            S_WRITE_ACC:
                    next_state = S_OUTPUT;
            S_OUTPUT:
                    next_state = S_IDLE;
        endcase
    end

    wire        is_load    = (opcode == 4'b0111) || (opcode == 4'b1101);
    wire        is_store   = (opcode == 4'b1110);
    wire        do_shift   = (state == S_SHIFT_REGS);
    wire        do_write   = (state == S_WRITE_ACC) || (state == S_OUTPUT);
    wire        do_calc    = (state == S_DECODE && !is_load && !is_store)
                        || do_shift
                        || do_write;

    wire [2:0]  alu_decoded = decode_alu_op(opcode);

    always @(*) begin
        alu_op       = alu_decoded;
        alu_en       = do_calc;
        alu_start    = (state == S_DECODE && !is_load && !is_store);
        acc_load_en  = (state == S_DECODE && is_load);
        reg_store_en = (state == S_DECODE && is_store);
        reg_shift_en = (state == S_DECODE && !is_load && !is_store) || do_shift;
        acc_write_en = do_shift || do_write;
    end

endmodule

// =============================================================================
// CPU Core
// =============================================================================
module cpu_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  opcode,
    input  wire [11:0] instr,
    input  wire        inst_done,
    input  wire        btn_edge,
    output reg  [7:0]  out_result
);

    wire [7:0] acc_bits;
    wire out_en;

    wire [2:0] bit_index;
    reg [2:0] bit_index_d;

    wire alu_bit1, alu_bit2, rs2_bit, alu_result;
    wire [2:0] alu_op;
    wire alu_start;
    wire alu_en;

    wire reg_shift_en, acc_write_en;
    wire reg_store_en, acc_load_en;
    wire bit_done;

    wire [7:0] acc_parallel_in;
    wire [7:0] regfile_bits;

    assign acc_parallel_in = acc_load_en ? (opcode[3] ? regfile_bits : instr[11:4]) : 8'b0;
    assign alu_bit2 = (opcode[3]) ? rs2_bit : (instr[bit_index + 4]);

    always @(posedge clk) begin
        if (!rst_n) begin
            bit_index_d <= 0;
            out_result <= 0;
        end else begin
            if (out_en)
                out_result <= acc_bits;
            bit_index_d <= bit_index;
        end
    end

    regfile_serial regfile (
        .clk(clk), .rstn(rst_n), .reg_shift_en(reg_shift_en),
        .instr(instr), .alu_op(alu_op), .rs1_bit(alu_bit1), .rs2_bit(rs2_bit),
        .regs_parallel_in(acc_bits), .bit_index(bit_index),
        .regfile_bits(regfile_bits), .reg_store_en(reg_store_en)
    );

    accumulator #(8) acc (
        .clk(clk), .rst_n(rst_n), .acc_load_en(acc_load_en),
        .acc_parallel_in(acc_parallel_in), .acc_write_en(acc_write_en),
        .alu_result(alu_result), .acc_bits(acc_bits),
        .bit_index_d(bit_index_d), .done(bit_done)
    );

    alu_1bit alu (
        .clk(clk), .rst_n(rst_n), .rs1(alu_bit1), .rs2(alu_bit2),
        .alu_start(alu_start), .alu_op(alu_op),
        .alu_en(alu_en), .alu_result(alu_result)
    );

    fsm_control ctrl (
        .clk(clk), .rst_n(rst_n), .opcode(opcode),
        .inst_done(inst_done), .btn_edge(btn_edge), .bit_done(bit_done),
        .alu_op(alu_op), .alu_start(alu_start), .acc_load_en(acc_load_en),
        .acc_write_en(acc_write_en), .reg_shift_en(reg_shift_en),
        .reg_store_en(reg_store_en), .alu_en(alu_en), .out_en(out_en)
    );

endmodule

// =============================================================================
// TT Top: Bit-Serial CPU
// =============================================================================
module tt_um_bit_serial_cpu_top (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    assign uio_out = 0;
    assign uio_oe  = 0;

    reg [3:0] opcode;
    reg [11:0] instr;
    reg inst_done;

    always @(posedge clk) begin
        if (!rst_n) begin
            opcode      <= 4'b0;
            instr       <= 12'b0;
            inst_done   <= 0;
        end
        else if (btn_edge) begin
            if (!inst_done) begin
                opcode       <= ui_in[3:0];
                instr[3:0]   <= ui_in[7:4];
                inst_done    <= 1'b1;
            end else begin
                instr[11:4]  <= ui_in;
                inst_done    <= 1'b0;
            end
        end
    end

    reg btn_sync0, btn_sync1, btn_prev;
    wire btn_level = uio_in[0];
    wire btn_edge = btn_sync1 & ~btn_prev;

    always @(posedge clk) begin
        if (!rst_n) begin
            btn_sync0       <= 1'b0;
            btn_sync1       <= 1'b0;
            btn_prev        <= 1'b0;
        end else begin
            btn_sync0       <= btn_level;
            btn_sync1       <= btn_sync0;
            btn_prev        <= btn_sync1;
        end
    end

    wire [7:0] out_result;

    cpu_core u_cpu_core (
        .clk(clk), .rst_n(rst_n), .opcode(opcode), .instr(instr),
        .btn_edge(btn_edge), .inst_done(inst_done), .out_result(out_result)
    );

    assign uo_out = out_result;

    wire _unused = &{uio_in[7:1], ena};

endmodule

// =============================================================================
// SASIC Wrapper
// =============================================================================
module sasic_top (
    input  wire clk, input  wire rst_n,
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
    wire [7:0] ui_in  = {in_7,  in_6,  in_5,  in_4,  in_3,  in_2,  in_1,  in_0};
    wire [7:0] uio_in = {in_15, in_14, in_13, in_12, in_11, in_10, in_9,  in_8};
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    tt_um_bit_serial_cpu_top tt_inst (
        .ui_in(ui_in), .uo_out(uo_out), .uio_in(uio_in),
        .uio_out(uio_out), .uio_oe(uio_oe),
        .ena(1'b1), .clk(clk), .rst_n(rst_n)
    );

    assign {out_7, out_6, out_5, out_4, out_3, out_2, out_1, out_0} = uo_out;
    assign {out_15, out_14, out_13, out_12, out_11, out_10, out_9, out_8} = uio_out;
    assign {out_39, out_38, out_37, out_36, out_35, out_34, out_33, out_32,
            out_31, out_30, out_29, out_28, out_27, out_26, out_25, out_24,
            out_23, out_22, out_21, out_20, out_19, out_18, out_17, out_16} = 24'd0;
    assign {oeb_7, oeb_6, oeb_5, oeb_4, oeb_3, oeb_2, oeb_1, oeb_0} = 8'hFF;
    assign {oeb_15, oeb_14, oeb_13, oeb_12, oeb_11, oeb_10, oeb_9, oeb_8} = ~uio_oe;
    assign {oeb_39, oeb_38, oeb_37, oeb_36, oeb_35, oeb_34, oeb_33, oeb_32,
            oeb_31, oeb_30, oeb_29, oeb_28, oeb_27, oeb_26, oeb_25, oeb_24,
            oeb_23, oeb_22, oeb_21, oeb_20, oeb_19, oeb_18, oeb_17, oeb_16} = 24'hFFFFFF;
endmodule
