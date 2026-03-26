// tt_sha256.v — Single-file TT design: SHA-256 Processor
// Source: https://github.com/dvirdc/ttsky-verilog-sha256-processor
// SPDX-License-Identifier: Apache-2.0
// Note: sha256_k_constants.v and sha256_k_lfsr.v excluded (not in instantiation path)

`default_nettype none

// =============================================================================
// SHA-256 K ROM (soft, combinational)
// =============================================================================
module sha256_k_rom_soft (
  input  wire [5:0] addr,
  output reg  [31:0] data
);
  always @* begin
    case (addr)
      6'd0  : data = 32'h428a2f98; 6'd1  : data = 32'h71374491;
      6'd2  : data = 32'hb5c0fbcf; 6'd3  : data = 32'he9b5dba5;
      6'd4  : data = 32'h3956c25b; 6'd5  : data = 32'h59f111f1;
      6'd6  : data = 32'h923f82a4; 6'd7  : data = 32'hab1c5ed5;
      6'd8  : data = 32'hd807aa98; 6'd9  : data = 32'h12835b01;
      6'd10 : data = 32'h243185be; 6'd11 : data = 32'h550c7dc3;
      6'd12 : data = 32'h72be5d74; 6'd13 : data = 32'h80deb1fe;
      6'd14 : data = 32'h9bdc06a7; 6'd15 : data = 32'hc19bf174;
      6'd16 : data = 32'he49b69c1; 6'd17 : data = 32'hefbe4786;
      6'd18 : data = 32'h0fc19dc6; 6'd19 : data = 32'h240ca1cc;
      6'd20 : data = 32'h2de92c6f; 6'd21 : data = 32'h4a7484aa;
      6'd22 : data = 32'h5cb0a9dc; 6'd23 : data = 32'h76f988da;
      6'd24 : data = 32'h983e5152; 6'd25 : data = 32'ha831c66d;
      6'd26 : data = 32'hb00327c8; 6'd27 : data = 32'hbf597fc7;
      6'd28 : data = 32'hc6e00bf3; 6'd29 : data = 32'hd5a79147;
      6'd30 : data = 32'h06ca6351; 6'd31 : data = 32'h14292967;
      6'd32 : data = 32'h27b70a85; 6'd33 : data = 32'h2e1b2138;
      6'd34 : data = 32'h4d2c6dfc; 6'd35 : data = 32'h53380d13;
      6'd36 : data = 32'h650a7354; 6'd37 : data = 32'h766a0abb;
      6'd38 : data = 32'h81c2c92e; 6'd39 : data = 32'h92722c85;
      6'd40 : data = 32'ha2bfe8a1; 6'd41 : data = 32'ha81a664b;
      6'd42 : data = 32'hc24b8b70; 6'd43 : data = 32'hc76c51a3;
      6'd44 : data = 32'hd192e819; 6'd45 : data = 32'hd6990624;
      6'd46 : data = 32'hf40e3585; 6'd47 : data = 32'h106aa070;
      6'd48 : data = 32'h19a4c116; 6'd49 : data = 32'h1e376c08;
      6'd50 : data = 32'h2748774c; 6'd51 : data = 32'h34b0bcb5;
      6'd52 : data = 32'h391c0cb3; 6'd53 : data = 32'h4ed8aa4a;
      6'd54 : data = 32'h5b9cca4f; 6'd55 : data = 32'h682e6ff3;
      6'd56 : data = 32'h748f82ee; 6'd57 : data = 32'h78a5636f;
      6'd58 : data = 32'h84c87814; 6'd59 : data = 32'h8cc70208;
      6'd60 : data = 32'h90befffa; 6'd61 : data = 32'ha4506ceb;
      6'd62 : data = 32'hbef9a3f7; 6'd63 : data = 32'hc67178f2;
      default: data = 32'h00000000;
    endcase
  end
endmodule

// =============================================================================
// SHA-256 Core v3 — 64-round compression engine
// =============================================================================
module sha256_core_v3 (
    input         clk,
    input         rst,
    input         start,
    input  [511:0] block_in,
    input         first_run,
    output [255:0] hash_out,
    output reg    ready
);

    reg  [6:0] t;
    reg [1:0] state;
    localparam IDLE = 2'd0, COMP = 2'd1, DONE = 2'd2;

    wire [31:0] k_value;
    sha256_k_rom_soft KROM (.addr(t[5:0]), .data(k_value));

    localparam [31:0] H0_INIT = 32'h6a09e667, H1_INIT = 32'hbb67ae85,
                      H2_INIT = 32'h3c6ef372, H3_INIT = 32'ha54ff53a,
                      H4_INIT = 32'h510e527f, H5_INIT = 32'h9b05688c,
                      H6_INIT = 32'h1f83d9ab, H7_INIT = 32'h5be0cd19;

    reg [31:0] a, b, c, d, e, f, g, h;
    reg [31:0] h0, h1, h2, h3, h4, h5, h6, h7;
    reg [31:0] w [0:15];

    wire [3:0] w_idx_m2   = t[3:0] - 4'd2;
    wire [3:0] w_idx_m7   = t[3:0] - 4'd7;
    wire [3:0] w_idx_m15  = t[3:0] - 4'd15;
    wire [3:0] w_idx_m16  = t[3:0];

    function [31:0] ror;
        input [31:0] x;
        input integer n;
        begin ror = (x >> n) | (x << (32 - n)); end
    endfunction
    function [31:0] sig0; input [31:0] x; begin sig0 = ror(x, 7) ^ ror(x, 18) ^ (x >> 3); end endfunction
    function [31:0] sig1; input [31:0] x; begin sig1 = ror(x, 17) ^ ror(x, 19) ^ (x >> 10); end endfunction

    wire [31:0] w_expanded = sig1(w[w_idx_m2]) + w[w_idx_m7] + sig0(w[w_idx_m15]) + w[w_idx_m16];
    wire [31:0] w_t = (t < 16) ? w[t[3:0]] : w_expanded;

    wire [31:0] S1 = (ror(e,6) ^ ror(e,11) ^ ror(e,25));
    wire [31:0] ch = (e & f) ^ ((~e) & g);
    wire [31:0] T1 = h + S1 + ch + k_value + w_t;
    wire [31:0] S0 = (ror(a,2) ^ ror(a,13) ^ ror(a,22));
    wire [31:0] maj = (a & b) ^ (a & c) ^ (b & c);
    wire [31:0] T2 = S0 + maj;

    assign hash_out = {h0, h1, h2, h3, h4, h5, h6, h7};

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; ready <= 1'b0; t <= 7'b0;
            a <= 0; b <= 0; c <= 0; d <= 0;
            e <= 0; f <= 0; g <= 0; h <= 0;
            h0 <= 0; h1 <= 0; h2 <= 0; h3 <= 0;
            h4 <= 0; h5 <= 0; h6 <= 0; h7 <= 0;
            w[0]<=0; w[1]<=0; w[2]<=0; w[3]<=0;
            w[4]<=0; w[5]<=0; w[6]<=0; w[7]<=0;
            w[8]<=0; w[9]<=0; w[10]<=0; w[11]<=0;
            w[12]<=0; w[13]<=0; w[14]<=0; w[15]<=0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        ready <= 1'b0;
                        if (first_run) begin
                            {h0,h1,h2,h3,h4,h5,h6,h7} <= {H0_INIT,H1_INIT,H2_INIT,H3_INIT,H4_INIT,H5_INIT,H6_INIT,H7_INIT};
                            {a,b,c,d,e,f,g,h} <= {H0_INIT,H1_INIT,H2_INIT,H3_INIT,H4_INIT,H5_INIT,H6_INIT,H7_INIT};
                        end else begin
                            {a,b,c,d,e,f,g,h} <= {h0,h1,h2,h3,h4,h5,h6,h7};
                        end
                        w[0]  <= block_in[511-32*0  -: 32]; w[1]  <= block_in[511-32*1  -: 32];
                        w[2]  <= block_in[511-32*2  -: 32]; w[3]  <= block_in[511-32*3  -: 32];
                        w[4]  <= block_in[511-32*4  -: 32]; w[5]  <= block_in[511-32*5  -: 32];
                        w[6]  <= block_in[511-32*6  -: 32]; w[7]  <= block_in[511-32*7  -: 32];
                        w[8]  <= block_in[511-32*8  -: 32]; w[9]  <= block_in[511-32*9  -: 32];
                        w[10] <= block_in[511-32*10 -: 32]; w[11] <= block_in[511-32*11 -: 32];
                        w[12] <= block_in[511-32*12 -: 32]; w[13] <= block_in[511-32*13 -: 32];
                        w[14] <= block_in[511-32*14 -: 32]; w[15] <= block_in[511-32*15 -: 32];
                        t <= 7'b0;
                        state <= COMP;
                    end
                end
                COMP: begin
                    if (t < 64) begin
                        a <= T1 + T2; b <= a; c <= b; d <= c;
                        e <= d + T1;  f <= e; g <= f; h <= g;
                        if (t >= 16) w[t[3:0]] <= w_expanded;
                        t <= t + 1;
                    end else begin
                        h0<=h0+a; h1<=h1+b; h2<=h2+c; h3<=h3+d;
                        h4<=h4+e; h5<=h5+f; h6<=h6+g; h7<=h7+h;
                        state <= DONE;
                    end
                end
                DONE: begin
                    ready <= 1'b1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule

// =============================================================================
// SHA-256 Streaming Processor
// =============================================================================
module sha256_processor (
    input         clk,
    input         rst,
    input         start,
    input  [7:0]  data_in,
    input         data_valid,
    input         data_last,
    output [255:0] hash_out,
    output        done,
    output        in_ready
);

    localparam BLOCK_SIZE = 64;

    reg [511:0] block_buffer;
    reg [5:0]   byte_index;
    reg         block_ready;

    reg [1:0] state;
    localparam IDLE = 0, LOAD = 1, HASH = 2, DONE_ST = 3;

    wire [255:0] core_hash_out;
    wire         core_ready;
    reg          core_start;
    reg          core_first_run;
    reg          core_busy;
    reg          core_ready_prev;

    sha256_core_v3 sha_core (
        .clk(clk), .rst(rst), .start(core_start),
        .block_in(block_buffer), .first_run(core_first_run),
        .hash_out(core_hash_out), .ready(core_ready)
    );

    assign hash_out = core_hash_out;
    assign done     = (state == DONE_ST);
    assign in_ready = (state == LOAD) || (state == IDLE);

    reg        seen_last;
    reg        has_staged_byte;
    reg  [7:0] staged_byte;
    reg        staged_last;

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; byte_index <= 0; block_ready <= 0;
            block_buffer <= 512'b0; core_start <= 0;
            core_first_run <= 0; core_busy <= 0; core_ready_prev <= 0;
            seen_last <= 0; has_staged_byte <= 0;
            staged_byte <= 8'h00; staged_last <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        core_first_run <= 1; state <= LOAD;
                        seen_last <= 0; block_buffer <= 512'b0;
                        has_staged_byte <= 0;
                        if (data_valid) begin
                            block_buffer[511 -: 8] <= data_in;
                            byte_index <= 1;
                            if (data_last) seen_last <= 1;
                        end else byte_index <= 0;
                    end
                end
                LOAD: begin
                    if (data_valid && byte_index < BLOCK_SIZE) begin
                        block_buffer[511 - byte_index*8 -: 8] <= data_in;
                        if (data_last) seen_last <= 1;
                        byte_index <= byte_index + 1;
                        if (byte_index + 1 == BLOCK_SIZE) begin
                            block_ready <= 1; state <= HASH;
                        end
                    end
                end
                HASH: begin
                    if (block_ready && !core_busy) begin
                        core_start <= 1; block_ready <= 0; core_busy <= 1;
                    end else begin
                        core_first_run <= 0; core_start <= 0;
                    end
                    if (data_valid && !has_staged_byte) begin
                        staged_byte <= data_in; staged_last <= data_last;
                        has_staged_byte <= 1'b1;
                        if (data_last) seen_last <= 1'b1;
                    end
                    if (core_ready && !core_ready_prev) begin
                        core_busy <= 0;
                        if (seen_last) begin
                            state <= DONE_ST;
                        end else begin
                            block_buffer <= 512'b0;
                            if (has_staged_byte) begin
                                block_buffer[511 -: 8] <= staged_byte;
                                byte_index <= 1;
                            end else byte_index <= 0;
                            has_staged_byte <= 1'b0;
                            state <= LOAD;
                        end
                        seen_last <= 0;
                    end
                    core_ready_prev <= core_ready;
                end
                DONE_ST: begin
                    core_start <= 0;
                end
            endcase
        end
    end
endmodule

// =============================================================================
// GPIO SHA-256 Top
// =============================================================================
module top_gpio_sha256 (
    input              clk,
    input              rst,
    input       [7:0]  din,
    input              valid,
    input              last,
    output reg         busy,
    output reg  [7:0]  dout,
    output reg         dvalid,
    output             ready
);

    reg start_core;
    reg data_valid;
    reg data_last;
    reg [7:0] data_byte;
    wire proc_in_ready;
    wire [255:0] hash;
    wire         proc_done;

    sha256_processor u_proc (
        .clk(clk), .rst(rst), .start(start_core),
        .data_in(data_byte), .data_valid(data_valid),
        .data_last(data_last), .hash_out(hash),
        .done(proc_done), .in_ready(proc_in_ready)
    );

    assign ready = proc_in_ready;

    reg        pend0_valid, pend1_valid;
    reg [7:0]  pend0_byte,  pend1_byte;
    reg        pend0_last,  pend1_last;

    localparam S_IDLE=0, S_FEED=1, S_WAIT=2, S_DUMP=3;
    reg [1:0]   state;
    reg [4:0]   byte_cntr;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE; busy <= 1'b0; dvalid <= 1'b0;
            start_core <= 1'b0; data_valid <= 1'b0; data_last <= 1'b0;
            dout <= 8'h00; data_byte <= 8'h00; byte_cntr <= 5'd0;
            pend0_valid <= 1'b0; pend1_valid <= 1'b0;
            pend0_byte <= 8'h00; pend1_byte <= 8'h00;
            pend0_last <= 1'b0; pend1_last <= 1'b0;
        end else begin
            dvalid     <= 1'b0;
            data_valid <= 1'b0;
            data_last  <= 1'b0;
            start_core <= 1'b0;

            if (valid && !proc_in_ready) begin
                if (!pend0_valid) begin
                    pend0_valid <= 1'b1; pend0_byte <= din; pend0_last <= last;
                end else if (!pend1_valid) begin
                    pend1_valid <= 1'b1; pend1_byte <= din; pend1_last <= last;
                end
            end

            case (state)
            S_IDLE: begin
                busy <= 1'b0;
                if (proc_in_ready && (pend0_valid || valid)) begin
                    start_core <= 1'b1; data_valid <= 1'b1; busy <= 1'b1;
                    if (pend0_valid) begin
                        data_byte <= pend0_byte; data_last <= pend0_last;
                        pend0_valid <= pend1_valid; pend0_byte <= pend1_byte;
                        pend0_last <= pend1_last; pend1_valid <= 1'b0;
                    end else begin
                        data_byte <= din; data_last <= last;
                    end
                    state <= ((pend0_valid ? pend0_last : last) ? S_WAIT : S_FEED);
                end
            end
            S_FEED: begin
                if (proc_in_ready && (pend0_valid || valid)) begin
                    data_valid <= 1'b1;
                    if (pend0_valid) begin
                        data_byte <= pend0_byte; data_last <= pend0_last;
                        pend0_valid <= pend1_valid; pend0_byte <= pend1_byte;
                        pend0_last <= pend1_last; pend1_valid <= 1'b0;
                    end else begin
                        data_byte <= din; data_last <= last;
                    end
                    if ((pend0_valid ? pend0_last : last)) state <= S_WAIT;
                end
            end
            S_WAIT: if (proc_done) begin
                byte_cntr <= 5'd0; state <= S_DUMP;
            end
            S_DUMP: begin
                dout <= hash[255 - byte_cntr*8 -: 8];
                dvalid <= 1'b1;
                byte_cntr <= byte_cntr + 1;
                if (byte_cntr == 5'd31) state <= S_IDLE;
            end
            endcase
        end
    end
endmodule

// =============================================================================
// TT Top: SHA-256 Processor
// =============================================================================
module tt_um_sha256_processor_dvirdc (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    wire busy, dvalid, ready;

    assign uio_out = {3'b000, ready, busy, dvalid, 2'b00};
    assign uio_oe = 8'b0001_1100;

    wire internal_rst = ~rst_n;

    top_gpio_sha256 top (
        .clk(clk), .rst(internal_rst), .din(ui_in),
        .valid(uio_in[0]), .last(uio_in[1]),
        .busy(busy), .dout(uo_out), .dvalid(dvalid), .ready(ready)
    );

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

    tt_um_sha256_processor_dvirdc tt_inst (
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
