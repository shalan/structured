// arithmetic_fabric_testbench.v
// Comprehensive test design for arithmetic-optimized techmap
//
// Tests:
//  - Single-bit addition (HA)
//  - Multi-bit addition (FA chains)
//  - Subtraction (FA with inversion)
//  - XOR operations (HA.SUM)
//  - Counters and accumulators
//  - Arithmetic comparisons
//  - Mixed arithmetic operations

`default_nettype none

// =============================================================================
// Simple Arithmetic Operations Test
// =============================================================================
module simple_arithmetic (
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire [7:0] sum,
    output wire [7:0] diff,
    output wire [7:0] xor_out,
    output wire       single_bit_add
);
    // 8-bit addition - should map to HA + FA chain
    assign sum = a + b;
    
    // 8-bit subtraction - should map to FA chain with inverted inputs
    assign diff = a - b;
    
    // XOR operations - should use HA.SUM outputs
    assign xor_out = a ^ b;
    
    // Single-bit addition - should use single HA
    assign single_bit_add = a[0] + b[0];

endmodule

// =============================================================================
// Counter (Increment Test)
// =============================================================================
module counter_4bit (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    output reg  [3:0] count
);
    // Counter using increment - should optimize to HA chain
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 4'b0;
        else if (enable)
            count <= count + 1'b1;  // Increment - optimized path
    end

endmodule

// =============================================================================
// Accumulator (Repeated Addition)
// =============================================================================
module accumulator_8bit (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [7:0]  data_in,
    output reg  [7:0]  acc_out
);
    // Accumulator - exercises multi-bit FA chains
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            acc_out <= 8'b0;
        else if (enable)
            acc_out <= acc_out + data_in;  // 8-bit addition
    end

endmodule

// =============================================================================
// Up/Down Counter (Addition and Subtraction)
// =============================================================================
module updown_counter (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       up,
    input  wire       down,
    output reg  [7:0] count
);
    // Tests both addition and subtraction paths
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 8'b0;
        else begin
            if (up)
                count <= count + 1'b1;      // Addition
            else if (down)
                count <= count - 1'b1;      // Subtraction
        end
    end

endmodule

// =============================================================================
// Arithmetic Comparator
// =============================================================================
module comparator_8bit (
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire       eq,
    output wire       lt,
    output wire       gt
);
    wire [7:0] diff;
    wire [7:0] xor_result;
    
    // Equality using XOR (all bits must be 0)
    assign xor_result = a ^ b;
    assign eq = ~(|xor_result);
    
    // Less than using subtraction
    assign diff = a - b;
    assign lt = diff[7];  // MSB indicates negative (signed)
    
    // Greater than
    assign gt = ~eq & ~lt;

endmodule

// =============================================================================
// Multi-Function ALU
// =============================================================================
module simple_alu (
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    input  wire [2:0]  op,
    output reg  [7:0]  result,
    output wire        carry_out,
    output wire        zero
);
    wire [8:0] add_result;
    wire [8:0] sub_result;
    
    // Pre-compute operations
    assign add_result = {1'b0, a} + {1'b0, b};
    assign sub_result = {1'b0, a} - {1'b0, b};
    
    // ALU operations
    always @(*) begin
        case (op)
            3'b000: result = a + b;           // ADD
            3'b001: result = a - b;           // SUB
            3'b010: result = a ^ b;           // XOR
            3'b011: result = a & b;           // AND
            3'b100: result = a | b;           // OR
            3'b101: result = a + 1'b1;        // INC
            3'b110: result = a - 1'b1;        // DEC
            3'b111: result = ~a;              // NOT
            default: result = 8'b0;
        endcase
    end
    
    assign carry_out = (op == 3'b000) ? add_result[8] : 
                       (op == 3'b001) ? sub_result[8] : 1'b0;
    assign zero = (result == 8'b0);

endmodule

// =============================================================================
// Parallel Adder Tree (Tests Multiple Adder Instances)
// =============================================================================
module adder_tree_4input (
    input  wire [7:0] in0,
    input  wire [7:0] in1,
    input  wire [7:0] in2,
    input  wire [7:0] in3,
    output wire [9:0] sum_out
);
    // Level 1: Two parallel additions
    wire [8:0] sum01;
    wire [8:0] sum23;
    
    assign sum01 = {1'b0, in0} + {1'b0, in1};
    assign sum23 = {1'b0, in2} + {1'b0, in3};
    
    // Level 2: Final addition
    assign sum_out = {1'b0, sum01} + {1'b0, sum23};

endmodule

// =============================================================================
// Parity Generator (XOR Tree)
// =============================================================================
module parity_8bit (
    input  wire [7:0] data,
    output wire       parity
);
    // XOR tree - should map to HA.SUM outputs efficiently
    wire [3:0] xor_level1;
    wire [1:0] xor_level2;
    
    assign xor_level1[0] = data[0] ^ data[1];
    assign xor_level1[1] = data[2] ^ data[3];
    assign xor_level1[2] = data[4] ^ data[5];
    assign xor_level1[3] = data[6] ^ data[7];
    
    assign xor_level2[0] = xor_level1[0] ^ xor_level1[1];
    assign xor_level2[1] = xor_level1[2] ^ xor_level1[3];
    
    assign parity = xor_level2[0] ^ xor_level2[1];

endmodule

// =============================================================================
// Gray Code Counter (XOR + Addition)
// =============================================================================
module gray_counter_4bit (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    output reg  [3:0] gray_out
);
    reg [3:0] binary_count;
    wire [3:0] gray_next;
    
    // Binary to Gray conversion using XOR
    assign gray_next[3] = binary_count[3];
    assign gray_next[2] = binary_count[3] ^ binary_count[2];
    assign gray_next[1] = binary_count[2] ^ binary_count[1];
    assign gray_next[0] = binary_count[1] ^ binary_count[0];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            binary_count <= 4'b0;
            gray_out <= 4'b0;
        end else if (enable) begin
            binary_count <= binary_count + 1'b1;  // Increment
            gray_out <= gray_next;                 // Convert to Gray
        end
    end

endmodule

// =============================================================================
// TOP-LEVEL TEST MODULE
// Integrates all test blocks
// =============================================================================
module arith (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  data_a,
    input  wire [7:0]  data_b,
    input  wire [2:0]  alu_op,
    input  wire        counter_en,
    input  wire        acc_en,
    
    // Simple arithmetic outputs
    output wire [7:0]  simple_sum,
    output wire [7:0]  simple_diff,
    output wire [7:0]  simple_xor,
    
    // Counter outputs
    output wire [3:0]  count_4bit,
    output wire [7:0]  updown_count,
    output wire [3:0]  gray_count,
    
    // Accumulator output
    output wire [7:0]  acc_result,
    
    // ALU outputs
    output wire [7:0]  alu_result,
    output wire        alu_carry,
    output wire        alu_zero,
    
    // Comparator outputs
    output wire        cmp_eq,
    output wire        cmp_lt,
    output wire        cmp_gt,
    
    // Adder tree output
    output wire [9:0]  tree_sum,
    
    // Parity output
    output wire        parity_a,
    output wire        parity_b
);

    // Instantiate simple arithmetic
    simple_arithmetic arith_inst (
        .a(data_a),
        .b(data_b),
        .sum(simple_sum),
        .diff(simple_diff),
        .xor_out(simple_xor),
        .single_bit_add()  // Unused
    );
    
    // Instantiate 4-bit counter
    counter_4bit counter_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(counter_en),
        .count(count_4bit)
    );
    
    // Instantiate accumulator
    accumulator_8bit acc_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(acc_en),
        .data_in(data_a),
        .acc_out(acc_result)
    );
    
    // Instantiate up/down counter
    updown_counter updown_inst (
        .clk(clk),
        .rst_n(rst_n),
        .up(counter_en),
        .down(~counter_en),
        .count(updown_count)
    );
    
    // Instantiate ALU
    simple_alu alu_inst (
        .a(data_a),
        .b(data_b),
        .op(alu_op),
        .result(alu_result),
        .carry_out(alu_carry),
        .zero(alu_zero)
    );
    
    // Instantiate comparator
    comparator_8bit cmp_inst (
        .a(data_a),
        .b(data_b),
        .eq(cmp_eq),
        .lt(cmp_lt),
        .gt(cmp_gt)
    );
    
    // Instantiate adder tree
    adder_tree_4input tree_inst (
        .in0(data_a),
        .in1(data_b),
        .in2(simple_sum),
        .in3(simple_diff),
        .sum_out(tree_sum)
    );
    
    // Instantiate parity generators
    parity_8bit parity_a_inst (
        .data(data_a),
        .parity(parity_a)
    );
    
    parity_8bit parity_b_inst (
        .data(data_b),
        .parity(parity_b)
    );
    
    // Instantiate Gray counter
    gray_counter_4bit gray_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(counter_en),
        .gray_out(gray_count)
    );

endmodule

// Empty top-level for SASIC fabric (ports match fixed IO pin names)

module sasic_top (
    input  wire clk,
    input  wire rst_n,
    input  wire in_0,
    input  wire in_1,
    input  wire in_2,
    input  wire in_3,
    input  wire in_4,
    input  wire in_5,
    input  wire in_6,
    input  wire in_7,
    input  wire in_8,
    input  wire in_9,
    input  wire in_10,
    input  wire in_11,
    input  wire in_12,
    input  wire in_13,
    input  wire in_14,
    input  wire in_15,
    input  wire in_16,
    input  wire in_17,
    input  wire in_18,
    input  wire in_19,
    input  wire in_20,
    input  wire in_21,
    input  wire in_22,
    input  wire in_23,
    input  wire in_24,
    input  wire in_25,
    input  wire in_26,
    input  wire in_27,
    input  wire in_28,
    input  wire in_29,
    input  wire in_30,
    input  wire in_31,
    input  wire in_32,
    input  wire in_33,
    input  wire in_34,
    input  wire in_35,
    input  wire in_36,
    input  wire in_37,
    input  wire in_38,
    input  wire in_39,
    output  wire oeb_0,
    output  wire oeb_1,
    output  wire oeb_2,
    output  wire oeb_3,
    output  wire oeb_4,
    output  wire oeb_5,
    output  wire oeb_6,
    output  wire oeb_7,
    output  wire oeb_8,
    output  wire oeb_9,
    output  wire oeb_10,
    output  wire oeb_11,
    output  wire oeb_12,
    output  wire oeb_13,
    output  wire oeb_14,
    output  wire oeb_15,
    output  wire oeb_16,
    output  wire oeb_17,
    output  wire oeb_18,
    output  wire oeb_19,
    output  wire oeb_20,
    output  wire oeb_21,
    output  wire oeb_22,
    output  wire oeb_23,
    output  wire oeb_24,
    output  wire oeb_25,
    output  wire oeb_26,
    output  wire oeb_27,
    output  wire oeb_28,
    output  wire oeb_29,
    output  wire oeb_30,
    output  wire oeb_31,
    output  wire oeb_32,
    output  wire oeb_33,
    output  wire oeb_34,
    output  wire oeb_35,
    output  wire oeb_36,
    output  wire oeb_37,
    output  wire oeb_38,
    output  wire oeb_39,
    output wire out_0,
    output wire out_1,
    output wire out_2,
    output wire out_3,
    output wire out_4,
    output wire out_5,
    output wire out_6,
    output wire out_7,
    output wire out_8,
    output wire out_9,
    output wire out_10,
    output wire out_11,
    output wire out_12,
    output wire out_13,
    output wire out_14,
    output wire out_15,
    output wire out_16,
    output wire out_17,
    output wire out_18,
    output wire out_19,
    output wire out_20,
    output wire out_21,
    output wire out_22,
    output wire out_23,
    output wire out_24,
    output wire out_25,
    output wire out_26,
    output wire out_27,
    output wire out_28,
    output wire out_29,
    output wire out_30,
    output wire out_31,
    output wire out_32,
    output wire out_33,
    output wire out_34,
    output wire out_35,
    output wire out_36,
    output wire out_37,
    output wire out_38,
    output wire out_39
);

  // TODO: implement your logic here.
    arith A (
        .clk(clk),
        .rst_n(rst_n),
        .data_a({in_7, in_6, in_5, in_4, in_3, in_2, in_1, in_0}),
        .data_b({in_15, in_14, in_13, in_12, in_11, in_10, in_9, in_8}),
        .alu_op({in_18, in_17, in_16}),
        .counter_en(in_20),
        .acc_en(in_21),
    
    // Simple arithmetic outputs
    //output wire [7:0]  simple_sum,
    //output wire [7:0]  simple_diff,
    //output wire [7:0]  simple_xor,
    
    // Counter outputs
        .count_4bit({out_25, out_24, out_23, out_22}),
    //output wire [7:0]  updown_count,
        .gray_count({out_29, out_28, out_27, out_26}),
    
    // Accumulator output
    //output wire [7:0]  acc_result,
    
    // ALU outputs
        .alu_result({out_37, out_36, out_35, out_34, out_33, out_32, out_31, out_30}),
        .alu_carry(out_38),
        .alu_zero(out_39)
    //,
    
    // Comparator outputs
    //output wire        cmp_eq,
    //output wire        cmp_lt,
    //output wire        cmp_gt,
    
    // Adder tree output
    //output wire [9:0]  tree_sum,
    
    // Parity output
    //output wire        parity_a,
    //output wire        parity_b
);

assign {oeb_39,oeb_38,oeb_37,oeb_36,oeb_35,oeb_34,oeb_33,oeb_32,
          oeb_31,oeb_30,oeb_29,oeb_28,oeb_27,oeb_26,oeb_25,oeb_24,
          oeb_23,oeb_22,oeb_21,oeb_20,oeb_19,oeb_18,oeb_17,oeb_16,
          oeb_15,oeb_14,oeb_13,oeb_12,oeb_11,oeb_10,oeb_9, oeb_8,
          oeb_7, oeb_6, oeb_5, oeb_4, oeb_3, oeb_2, oeb_1, oeb_0} = 40'h00003FFFFF;

assign {out_21, out_20, out_19, out_18, out_17, out_16,
        out_15, out_14, out_13, out_12, out_11, out_10,
        out_9,  out_8,  out_7,  out_6,  out_5,  out_4,
        out_3,  out_2,  out_1,  out_0} = 22'b0;

endmodule


`default_nettype wire