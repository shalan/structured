// tt_spi_pwm.v — Single-file TT design: SPI PWM by djuara-rbz
// Source: https://github.com/djuara-rbz/tt_spi_pwm
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

// =============================================================================
// Edge Detector
// =============================================================================
module edge_detector
    #(parameter edge_type = 0)
    (input wire clk,
    input wire rst_n,
    input wire signal,
    output reg edge_detected);

    reg signal_z1;

    always @(posedge clk, negedge rst_n) begin
        if(rst_n == 0) begin
            signal_z1 <= 0;
        end else begin
            signal_z1 <= signal;
        end
    end

    always @* begin
        if(edge_type == 0) begin
            edge_detected = signal & ~signal_z1;
        end else begin
            edge_detected = ~signal & signal_z1;
        end
    end
endmodule

// =============================================================================
// PWM Generator
// =============================================================================
module pwm_generator
    (input  wire clk,
    input   wire rst_n,
    input   wire start,
    input   wire[15:0] cycles_high,
    input   wire[15:0] cycles_freq,
    output  reg pwm);

    reg[15:0] counter;

    always @(posedge clk, negedge rst_n) begin
        if(rst_n == 0) begin
            pwm     <= 0;
            counter <= 0;
        end else begin
            if(start == 1) begin
                counter     <= counter + 1;
                if(counter < cycles_high) begin
                    pwm     <= 1;
                end else if(counter < cycles_freq) begin
                    pwm     <= 0;
                end else begin
                    counter <= 0;
                end
            end else begin
                pwm     <= 0;
                counter <= 0;
            end
        end
    end

endmodule

// =============================================================================
// SPI Own Clock (driven by external SCLK)
// =============================================================================
module spi_own_clock
    #(parameter ADDR_REG_LEN=3)
    (
    input   wire    sclk,
    input   wire    mosi,
    output  reg     miso,
    input   wire    cs,
    input   wire    rst_n,
    output  reg[ADDR_REG_LEN-1:0] addr_reg,
    output  reg[7:0] data_wr,
    input   wire[7:0] data_rd_i,
    output  reg     wr_en
);

    reg[1:0] spi_state;
    localparam Idle     = 2'b00;
    localparam Get_data = 2'b01;
    localparam Read     = 2'b10;
    localparam Write    = 2'b11;
    reg[7:0] spi_data_reg;
    reg[3:0] index;
    reg[7:0] data_rd;
    reg[7:0] data_rd_z1;

    always @(negedge sclk or posedge cs) begin
        if(cs == 1) begin
            spi_data_reg <= 0;
        end else begin
            spi_data_reg <= {spi_data_reg[6:0],mosi};
        end
    end

    always @(posedge sclk or negedge rst_n or posedge cs) begin
        if(rst_n == 0)  begin
            spi_state   <= Idle;
            index       <= 0;
            addr_reg    <= 0;
            data_rd     <= 0;
            data_rd_z1  <= 0;
        end else if(cs == 1) begin
            spi_state   <= Idle;
            index       <= 0;
            addr_reg    <= 0;
            data_rd     <= 0;
            data_rd_z1  <= 0;
        end else begin
            case(spi_state)
                Idle: begin
                    if(index == 8) begin
                        index <= 1;
                        addr_reg    <= spi_data_reg[ADDR_REG_LEN-1:0];
                        if(spi_data_reg[7] == 1) begin
                            spi_state <= Get_data;
                        end else begin
                            spi_state <= Write;
                        end
                    end else begin
                        index <= index + 1;
                    end
                end
                Get_data: begin
                    data_rd_z1  <=  data_rd_i;
                    data_rd     <= data_rd_z1;
                    if(index == 8) begin
                        spi_state   <= Read;
                        index       <= 7;
                    end else begin
                        index <= index + 1;
                    end
                end
                Read: begin
                    if(index == 0) begin
                        spi_state <= Idle;
                    end else begin
                        index   <= index-1;
                    end
                end
                Write: begin
                    if(index == 8) begin
                    end else begin
                        index <= index + 1;
                    end
                end
                default:;
            endcase
        end
    end

    always @(*) begin
        case(spi_state)
            Idle: begin
                miso        = 0;
                data_wr     = 0;
                wr_en       = 0;
            end
            Read: begin
                miso        = data_rd[index[2:0]];
                data_wr     = 0;
                wr_en       = 0;
            end
            Write: begin
                miso        = 0;
                if(index == 8) begin
                    data_wr     = spi_data_reg;
                    wr_en       = 1;
                end else begin
                    data_wr     = 0;
                    wr_en       = 0;
                end
            end
            default: begin
                miso        = 0;
                data_wr     = 0;
                wr_en       = 0;
            end
        endcase
    end

endmodule

// =============================================================================
// SPI Sampled (system clock domain)
// =============================================================================
module spi_sampled
    #(parameter ADDR_REG_LEN=3)
    (
    input   wire    clk,
    input   wire    spi_sclk,
    input   wire    spi_mosi,
    output  reg     spi_miso,
    input   wire    spi_cs,
    input   wire    rst_n,
    output  reg[ADDR_REG_LEN-1:0] addr_reg,
    output  reg[7:0] data_wr,
    input   wire[7:0] data_rd_i,
    output  reg     wr_en
);

    reg[1:0] spi_state;
    localparam Idle     = 2'b00;
    localparam Read     = 2'b01;
    localparam Write    = 2'b10;
    reg[7:0] spi_data_reg;
    reg[3:0] index;

    reg         sclk_z1, sclk;
    reg         mosi_z1, mosi;
    reg         cs_z1, cs;
    reg         miso;

    wire pos_edge;
    wire neg_edge;

    assign spi_miso = miso;

    always @(posedge clk) begin
        sclk_z1     <= spi_sclk;
        sclk        <= sclk_z1;
        mosi_z1     <= spi_mosi;
        mosi        <= mosi_z1;
        cs_z1       <= spi_cs;
        cs          <= cs_z1;
    end

    always @(posedge clk or posedge cs) begin
        if(cs == 1) begin
            spi_data_reg <= 0;
        end else begin
            if(neg_edge == 1) begin
                spi_data_reg <= {spi_data_reg[6:0],mosi};
            end
        end
    end

    always @(posedge clk or negedge rst_n or posedge cs) begin
        if(rst_n == 0) begin
            spi_state       <= Idle;
            index           <= 0;
            addr_reg        <= 0;
        end else if(cs == 1) begin
            spi_state       <= Idle;
            index           <= 0;
            addr_reg        <= 0;
        end else begin
            case(spi_state)
                Idle: begin
                    if(neg_edge == 1) begin
                        if(index < 8) begin
                            index <= index+1;
                        end
                    end
                    if(index == 8) begin
                        if(pos_edge == 1) begin
                            addr_reg    <= spi_data_reg[ADDR_REG_LEN-1:0];
                            if(spi_data_reg[7] == 1) begin
                                index <= 7;
                                spi_state <= Read;
                            end else begin
                                index <= 1;
                                spi_state <= Write;
                            end
                        end
                    end
                end
                Read: begin
                    if(pos_edge == 1) begin
                        if(index == 0) begin
                            spi_state <= Idle;
                        end else begin
                            index   <= index-1;
                        end
                    end
                end
                Write: begin
                    if(pos_edge == 1) begin
                        if(index == 8) begin
                        end else begin
                            index <= index + 1;
                        end
                    end
                end
                default:;
            endcase
        end
    end

    always @(spi_state or data_rd_i or index or spi_data_reg) begin
        case(spi_state)
            Idle: begin
                miso        = 0;
                data_wr     = 0;
                wr_en       = 0;
            end
            Read: begin
                miso        = data_rd_i[index[2:0]];
                data_wr     = 0;
                wr_en       = 0;
            end
            Write: begin
                miso        = 0;
                if(index == 8) begin
                    data_wr     = spi_data_reg;
                    wr_en       = 1;
                end else begin
                    data_wr     = 0;
                    wr_en       = 0;
                end
            end
            default: begin
                miso        = 0;
                data_wr     = 0;
                wr_en       = 0;
            end
        endcase
    end

    edge_detector #(0) pos_edge_det(
        .clk(clk),
        .rst_n(rst_n),
        .signal(sclk),
        .edge_detected(pos_edge));

    edge_detector #(1) neg_edge_det(
        .clk(clk),
        .rst_n(rst_n),
        .signal(sclk),
        .edge_detected(neg_edge));

endmodule

// =============================================================================
// TT Top Module: SPI PWM
// =============================================================================
module tt_um_spi_pwm_djuara(
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    wire    sclk_clk;
    wire    miso_clk;
    wire    mosi_clk;
    wire    cs_clk;
    wire    sclk_sampled;
    wire    miso_sampled;
    wire    mosi_sampled;
    wire    cs_sampled;
    wire    start_pwm_ext;
    wire    spare_in;

    assign uo_out           = {5'b0, pwm, miso_sampled, miso_clk};

    assign sclk_clk         = ui_in[0];
    assign mosi_clk         = ui_in[1];
    assign cs_clk           = ui_in[2];
    assign sclk_sampled     = ui_in[3];
    assign mosi_sampled     = ui_in[4];
    assign cs_sampled       = ui_in[5];
    assign start_pwm_ext    = ui_in[6];
    assign spare_in         = ui_in[7] & ena;

    localparam ADDR_REG_LEN = 3;
    localparam ADDR_ID              = 0;
    localparam ADDR_PWM_CTRL        = 1;
    localparam ADDR_CYCLES_HIGH0    = 2;
    localparam ADDR_CYCLES_HIGH1    = 3;
    localparam ADDR_CYCLES_FREQ0    = 4;
    localparam ADDR_CYCLES_FREQ1    = 5;
    localparam ADDR_IODIR           = 6;
    localparam ADDR_IOVALUE         = 7;

    wire[2:0] addr_reg_clk;
    wire[2:0] addr_reg_sampled;
    reg[7:0] data_rd_clk;
    reg[7:0] data_rd_sampled;
    wire[7:0] data_wr_clk;
    wire[7:0] data_wr_sampled;
    reg[7:0] data_wr_z1;
    wire        wr_en_clk;
    wire        wr_en_sampled;
    reg [7:0]   dev_regs [(2**ADDR_REG_LEN)-1:0];
    wire        start_pwm;
    wire[15:0]  cycles_high;
    wire[15:0]  cycles_freq;
    wire        pwm;

    spi_own_clock #(ADDR_REG_LEN) spi_own_clock_ins (
        sclk_clk,
        mosi_clk,
        miso_clk,
        cs_clk,
        rst_n,
        addr_reg_clk,
        data_wr_clk,
        data_rd_clk,
        wr_en_clk
    );

    spi_sampled #(ADDR_REG_LEN) spi_sampled_ins (
        clk,
        sclk_sampled,
        mosi_sampled,
        miso_sampled,
        cs_sampled,
        rst_n,
        addr_reg_sampled,
        data_wr_sampled,
        data_rd_sampled,
        wr_en_sampled
    );

    pwm_generator  pwm_inst (
        clk,
        rst_n,
        start_pwm,
        cycles_high,
        cycles_freq,
        pwm
    );

    always @* begin
        if(addr_reg_clk == ADDR_IOVALUE) begin
            data_rd_clk         = uio_in;
        end else begin
            data_rd_clk         = dev_regs[addr_reg_clk];
        end
        if(addr_reg_sampled == ADDR_IOVALUE) begin
            data_rd_sampled     = uio_in;
        end else begin
            data_rd_sampled     = dev_regs[addr_reg_sampled];
        end
    end

    assign uio_out          = dev_regs[ADDR_IOVALUE];
    assign uio_oe           = dev_regs[ADDR_IODIR];
    assign start_pwm        = dev_regs[ADDR_PWM_CTRL][0] || start_pwm_ext;
    assign cycles_high      = {dev_regs[ADDR_CYCLES_HIGH1],dev_regs[ADDR_CYCLES_HIGH0]};
    assign cycles_freq      = {dev_regs[ADDR_CYCLES_FREQ1],dev_regs[ADDR_CYCLES_FREQ0]};

    always @(posedge clk, negedge rst_n) begin
        if(rst_n == 0) begin
            dev_regs[ADDR_ID]           <= 8'h96;
            dev_regs[ADDR_PWM_CTRL]     <= 8'h00;
            dev_regs[ADDR_CYCLES_HIGH0] <= 8'h14;
            dev_regs[ADDR_CYCLES_HIGH1] <= 8'h82;
            dev_regs[ADDR_CYCLES_FREQ0] <= 8'h50;
            dev_regs[ADDR_CYCLES_FREQ1] <= 8'hC3;
            dev_regs[ADDR_IODIR]        <= 8'h00;
            dev_regs[ADDR_IOVALUE]      <= 8'h00;
        end else begin
            dev_regs[ADDR_PWM_CTRL]     <= {spare_in,dev_regs[ADDR_PWM_CTRL][6:0]};
            if(wr_en_clk == 1 && addr_reg_clk != 0) begin
                if(start_pwm == 0 || addr_reg_clk == ADDR_PWM_CTRL || addr_reg_clk > ADDR_CYCLES_FREQ1) begin
                    data_wr_z1              <= data_wr_clk;
                    dev_regs[addr_reg_clk]  <= data_wr_z1;
                end
            end else if(wr_en_sampled == 1 && addr_reg_sampled != 0) begin
                if(start_pwm == 0 || addr_reg_sampled == ADDR_PWM_CTRL || addr_reg_sampled > ADDR_CYCLES_FREQ1) begin
                    dev_regs[addr_reg_sampled]  <= data_wr_sampled;
                end
            end
        end
    end

endmodule

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
    tt_um_spi_pwm_djuara tt_inst (
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
