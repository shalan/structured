/******************************************************************************/
/* VGA Glyph Demo - Combined file for SASIC Structured ASIC                  */
/*                                                                            */
/* Original: https://github.com/jar/tt08_vga_glyph_mode                      */
/* Copyright (c) 2024 James Ross                                              */
/* SPDX-License-Identifier: Apache-2.0                                        */
/*                                                                            */
/* This design generates VGA video output (640x480) with glyph rendering.    */
/* Features:                                                                  */
/*   - 640x480 @ 60Hz VGA output                                              */
/*   - 48 character glyphs (8x12 pixels each)                                 */
/*   - 4 color palettes (green, red, blue, pride)                             */
/*   - Animated patterns using frame counter                                  */
/*                                                                            */
/* Combined modules:                                                          */
/*   - hvsync_generator: VGA sync timing generator                            */
/*   - glyphs_rom: 48-character font ROM (8x12 pixels)                        */
/*   - div3_rom: Division-by-3 lookup table                                   */
/*   - sasic_top: Top-level wrapper with SASIC interface                      */
/******************************************************************************/

`default_nettype none

// =============================================================================
// Module: hvsync_generator
// Description: Video sync generator for VGA monitor
// Timing from: https://en.wikipedia.org/wiki/Video_Graphics_Array
// Generates 640x480 @ 60Hz VGA timing signals
// =============================================================================

module hvsync_generator(
    input  wire       clk,
    input  wire       reset,
    output reg        hsync,
    output reg        vsync,
    output wire       display_on,
    output reg [9:0]  hpos,
    output reg [9:0]  vpos
);

    // Horizontal timing constants
    parameter H_DISPLAY    = 640;  // Horizontal display width
    parameter H_BACK       =  48;  // Horizontal left border (back porch)
    parameter H_FRONT      =  16;  // Horizontal right border (front porch)
    parameter H_SYNC       =  96;  // Horizontal sync width

    // Vertical timing constants
    parameter V_DISPLAY    = 480;  // Vertical display height
    parameter V_TOP        =  33;  // Vertical top border
    parameter V_BOTTOM     =  10;  // Vertical bottom border
    parameter V_SYNC       =   2;  // Vertical sync # lines

    // Derived constants
    parameter H_SYNC_START = H_DISPLAY + H_FRONT;
    parameter H_SYNC_END   = H_DISPLAY + H_FRONT + H_SYNC - 1;
    parameter H_MAX        = H_DISPLAY + H_BACK + H_FRONT + H_SYNC - 1;
    parameter V_SYNC_START = V_DISPLAY + V_BOTTOM;
    parameter V_SYNC_END   = V_DISPLAY + V_BOTTOM + V_SYNC - 1;
    parameter V_MAX        = V_DISPLAY + V_TOP + V_BOTTOM + V_SYNC - 1;

    wire hmaxxed = (hpos == H_MAX) || reset;
    wire vmaxxed = (vpos == V_MAX) || reset;

    // Horizontal position counter
    always @(posedge clk) begin
        hsync <= (hpos >= H_SYNC_START && hpos <= H_SYNC_END);
        if (hmaxxed)
            hpos <= 0;
        else
            hpos <= hpos + 1;
    end

    // Vertical position counter
    always @(posedge clk) begin
        vsync <= (vpos >= V_SYNC_START && vpos <= V_SYNC_END);
        if (hmaxxed) begin
            if (vmaxxed)
                vpos <= 0;
            else
                vpos <= vpos + 1;
        end
    end

    // display_on is set when beam is in visible frame
    assign display_on = (hpos < H_DISPLAY) && (vpos < V_DISPLAY);

endmodule

// =============================================================================
// Module: div3_rom
// Description: Division-by-3 lookup table (combinational logic version)
// Maps 7-bit input to 6-bit quotient
// =============================================================================

module div3_rom(
    input  wire [6:0] in,
    output reg  [5:0] out
);

    always @(*) begin
        case (in)
            7'd0, 7'd1, 7'd2:        out = 6'd0;
            7'd3, 7'd4, 7'd5:        out = 6'd1;
            7'd6, 7'd7, 7'd8:        out = 6'd2;
            7'd9, 7'd10, 7'd11:      out = 6'd3;
            7'd12, 7'd13, 7'd14:     out = 6'd4;
            7'd15, 7'd16, 7'd17:     out = 6'd5;
            7'd18, 7'd19, 7'd20:     out = 6'd6;
            7'd21, 7'd22, 7'd23:     out = 6'd7;
            7'd24, 7'd25, 7'd26:     out = 6'd8;
            7'd27, 7'd28, 7'd29:     out = 6'd9;
            7'd30, 7'd31, 7'd32:     out = 6'd10;
            7'd33, 7'd34, 7'd35:     out = 6'd11;
            7'd36, 7'd37, 7'd38:     out = 6'd12;
            7'd39, 7'd40, 7'd41:     out = 6'd13;
            7'd42, 7'd43, 7'd44:     out = 6'd14;
            7'd45, 7'd46, 7'd47:     out = 6'd15;
            7'd48, 7'd49, 7'd50:     out = 6'd16;
            7'd51, 7'd52, 7'd53:     out = 6'd17;
            7'd54, 7'd55, 7'd56:     out = 6'd18;
            7'd57, 7'd58, 7'd59:     out = 6'd19;
            7'd60, 7'd61, 7'd62:     out = 6'd20;
            7'd63, 7'd64, 7'd65:     out = 6'd21;
            7'd66, 7'd67, 7'd68:     out = 6'd22;
            7'd69, 7'd70, 7'd71:     out = 6'd23;
            7'd72, 7'd73, 7'd74:     out = 6'd24;
            7'd75, 7'd76, 7'd77:     out = 6'd25;
            7'd78, 7'd79, 7'd80:     out = 6'd26;
            7'd81, 7'd82, 7'd83:     out = 6'd27;
            7'd84, 7'd85, 7'd86:     out = 6'd28;
            7'd87, 7'd88, 7'd89:     out = 6'd29;
            7'd90, 7'd91, 7'd92:     out = 6'd30;
            7'd93, 7'd94, 7'd95:     out = 6'd31;
            7'd96, 7'd97, 7'd98:     out = 6'd32;
            7'd99, 7'd100, 7'd101:   out = 6'd33;
            7'd102, 7'd103, 7'd104:  out = 6'd34;
            7'd105, 7'd106, 7'd107:  out = 6'd35;
            7'd108, 7'd109, 7'd110:  out = 6'd36;
            7'd111, 7'd112, 7'd113:  out = 6'd37;
            7'd114, 7'd115, 7'd116:  out = 6'd38;
            7'd117, 7'd118, 7'd119:  out = 6'd39;
            default:                  out = 6'd39;
        endcase
    end

endmodule

// =============================================================================
// Module: glyphs_rom
// Description: Glyph ROM - 48 characters (8x12 pixels each)
// Character set includes: letters, numbers, symbols
// Combinational logic version for synthesis
// =============================================================================

module glyphs_rom(
    input  wire [5:0] c,
    input  wire [3:0] y,
    input  wire [2:0] x,
    output reg        pixel
);

    wire [5:0] c_idx = (c < 48) ? c : c - 48;
    wire [9:0] addr = {c_idx, y};
    reg [7:0] row_data;

    // Character data (48 chars x 12 rows)
    always @(*) begin
        case (addr)
            10'd0: row_data = 8'b00000000;
            10'd1: row_data = 8'b11011000;
            10'd2: row_data = 8'b11011000;
            10'd3: row_data = 8'b11011000;
            10'd4: row_data = 8'b11011000;
            10'd5: row_data = 8'b11001100;
            10'd6: row_data = 8'b11001100;
            10'd7: row_data = 8'b11001100;
            10'd8: row_data = 8'b10000110;
            10'd9: row_data = 8'b10000110;
            10'd10: row_data = 8'b10000110;
            10'd11: row_data = 8'b00000110;
            10'd16: row_data = 8'b00000000;
            10'd17: row_data = 8'b00000000;
            10'd18: row_data = 8'b00000000;
            10'd19: row_data = 8'b00000000;
            10'd20: row_data = 8'b00000000;
            10'd21: row_data = 8'b00000000;
            10'd22: row_data = 8'b00000000;
            10'd23: row_data = 8'b00000000;
            10'd24: row_data = 8'b00000000;
            10'd25: row_data = 8'b00000000;
            10'd26: row_data = 8'b00000000;
            10'd27: row_data = 8'b11101110;
            10'd32: row_data = 8'b00000000;
            10'd33: row_data = 8'b11000000;
            10'd34: row_data = 8'b11000000;
            10'd35: row_data = 8'b11111110;
            10'd36: row_data = 8'b11111110;
            10'd37: row_data = 8'b11000000;
            10'd38: row_data = 8'b11000000;
            10'd39: row_data = 8'b11000000;
            10'd40: row_data = 8'b11000000;
            10'd41: row_data = 8'b11100000;
            10'd42: row_data = 8'b01111110;
            10'd43: row_data = 8'b00111110;
            10'd48: row_data = 8'b00000000;
            10'd49: row_data = 8'b00110000;
            10'd50: row_data = 8'b00111000;
            10'd51: row_data = 8'b00111000;
            10'd52: row_data = 8'b00110000;
            10'd53: row_data = 8'b00110000;
            10'd54: row_data = 8'b00110000;
            10'd55: row_data = 8'b00110000;
            10'd56: row_data = 8'b00110000;
            10'd57: row_data = 8'b00110000;
            10'd58: row_data = 8'b00110000;
            10'd59: row_data = 8'b00110000;
            10'd64: row_data = 8'b00000000;
            10'd65: row_data = 8'b11110000;
            10'd66: row_data = 8'b11110000;
            10'd67: row_data = 8'b00000010;
            10'd68: row_data = 8'b11110010;
            10'd69: row_data = 8'b11110010;
            10'd70: row_data = 8'b00000110;
            10'd71: row_data = 8'b00000100;
            10'd72: row_data = 8'b00001100;
            10'd73: row_data = 8'b00011100;
            10'd74: row_data = 8'b11111000;
            10'd75: row_data = 8'b11110000;
            10'd80: row_data = 8'b00000000;
            10'd81: row_data = 8'b00000000;
            10'd82: row_data = 8'b00000000;
            10'd83: row_data = 8'b01111100;
            10'd84: row_data = 8'b01111100;
            10'd85: row_data = 8'b00000000;
            10'd86: row_data = 8'b00000000;
            10'd87: row_data = 8'b01111100;
            10'd88: row_data = 8'b01111100;
            10'd89: row_data = 8'b00000000;
            10'd90: row_data = 8'b00000000;
            10'd91: row_data = 8'b00000000;
            10'd96: row_data = 8'b00000000;
            10'd97: row_data = 8'b10100110;
            10'd98: row_data = 8'b10100110;
            10'd99: row_data = 8'b10110110;
            10'd100: row_data = 8'b11010110;
            10'd101: row_data = 8'b01010110;
            10'd102: row_data = 8'b00000110;
            10'd103: row_data = 8'b00001100;
            10'd104: row_data = 8'b00001100;
            10'd105: row_data = 8'b00001100;
            10'd106: row_data = 8'b00011000;
            10'd107: row_data = 8'b01111000;
            10'd112: row_data = 8'b00000000;
            10'd113: row_data = 8'b01111100;
            10'd114: row_data = 8'b11000010;
            10'd115: row_data = 8'b11000000;
            10'd116: row_data = 8'b11000000;
            10'd117: row_data = 8'b11000000;
            10'd118: row_data = 8'b01100000;
            10'd119: row_data = 8'b00111000;
            10'd120: row_data = 8'b00110000;
            10'd121: row_data = 8'b01100000;
            10'd122: row_data = 8'b11000000;
            10'd123: row_data = 8'b11111110;
            10'd128: row_data = 8'b00000000;
            10'd129: row_data = 8'b00110000;
            10'd130: row_data = 8'b00110000;
            10'd131: row_data = 8'b11111110;
            10'd132: row_data = 8'b11000110;
            10'd133: row_data = 8'b11000110;
            10'd134: row_data = 8'b00000110;
            10'd135: row_data = 8'b00000110;
            10'd136: row_data = 8'b00000110;
            10'd137: row_data = 8'b00001100;
            10'd138: row_data = 8'b00011000;
            10'd139: row_data = 8'b01110000;
            10'd144: row_data = 8'b00000000;
            10'd145: row_data = 8'b00011000;
            10'd146: row_data = 8'b00011000;
            10'd147: row_data = 8'b11111110;
            10'd148: row_data = 8'b11111110;
            10'd149: row_data = 8'b00011000;
            10'd150: row_data = 8'b00011000;
            10'd151: row_data = 8'b00011000;
            10'd152: row_data = 8'b00111000;
            10'd153: row_data = 8'b01110000;
            10'd154: row_data = 8'b11000000;
            10'd155: row_data = 8'b00000000;
            10'd160: row_data = 8'b00000000;
            10'd161: row_data = 8'b11100000;
            10'd162: row_data = 8'b00111000;
            10'd163: row_data = 8'b00001110;
            10'd164: row_data = 8'b00000000;
            10'd165: row_data = 8'b11100000;
            10'd166: row_data = 8'b00111000;
            10'd167: row_data = 8'b00001110;
            10'd168: row_data = 8'b00000000;
            10'd169: row_data = 8'b11100000;
            10'd170: row_data = 8'b00111000;
            10'd171: row_data = 8'b00001110;
            10'd176: row_data = 8'b00000000;
            10'd177: row_data = 8'b01111100;
            10'd178: row_data = 8'b11000110;
            10'd179: row_data = 8'b11000110;
            10'd180: row_data = 8'b11000110;
            10'd181: row_data = 8'b11000110;
            10'd182: row_data = 8'b01111100;
            10'd183: row_data = 8'b11000110;
            10'd184: row_data = 8'b11000110;
            10'd185: row_data = 8'b11000110;
            10'd186: row_data = 8'b11000110;
            10'd187: row_data = 8'b01111100;
            10'd192: row_data = 8'b00000000;
            10'd193: row_data = 8'b11111110;
            10'd194: row_data = 8'b01100000;
            10'd195: row_data = 8'b01100000;
            10'd196: row_data = 8'b11111110;
            10'd197: row_data = 8'b01100000;
            10'd198: row_data = 8'b01100000;
            10'd199: row_data = 8'b01100000;
            10'd200: row_data = 8'b01100000;
            10'd201: row_data = 8'b01110000;
            10'd202: row_data = 8'b00111110;
            10'd203: row_data = 8'b00011110;
            10'd208: row_data = 8'b00000000;
            10'd209: row_data = 8'b00000000;
            10'd210: row_data = 8'b01101100;
            10'd211: row_data = 8'b01101100;
            10'd212: row_data = 8'b11111110;
            10'd213: row_data = 8'b11111110;
            10'd214: row_data = 8'b01101100;
            10'd215: row_data = 8'b01101100;
            10'd216: row_data = 8'b00001100;
            10'd217: row_data = 8'b00001100;
            10'd218: row_data = 8'b00011000;
            10'd219: row_data = 8'b01110000;
            10'd224: row_data = 8'b00000000;
            10'd225: row_data = 8'b00000000;
            10'd226: row_data = 8'b11111110;
            10'd227: row_data = 8'b11000110;
            10'd228: row_data = 8'b11000110;
            10'd229: row_data = 8'b00000110;
            10'd230: row_data = 8'b00000110;
            10'd231: row_data = 8'b00000110;
            10'd232: row_data = 8'b00000110;
            10'd233: row_data = 8'b00001100;
            10'd234: row_data = 8'b00011000;
            10'd235: row_data = 8'b01110000;
            10'd240: row_data = 8'b00000000;
            10'd241: row_data = 8'b00000000;
            10'd242: row_data = 8'b01100000;
            10'd243: row_data = 8'b00110000;
            10'd244: row_data = 8'b00011000;
            10'd245: row_data = 8'b00001100;
            10'd246: row_data = 8'b00001100;
            10'd247: row_data = 8'b00011000;
            10'd248: row_data = 8'b00110000;
            10'd249: row_data = 8'b01100000;
            10'd250: row_data = 8'b00000000;
            10'd251: row_data = 8'b00000000;
            10'd256: row_data = 8'b00000000;
            10'd257: row_data = 8'b00001100;
            10'd258: row_data = 8'b00001100;
            10'd259: row_data = 8'b11111110;
            10'd260: row_data = 8'b11111110;
            10'd261: row_data = 8'b00001100;
            10'd262: row_data = 8'b00011100;
            10'd263: row_data = 8'b00011100;
            10'd264: row_data = 8'b00111100;
            10'd265: row_data = 8'b00101100;
            10'd266: row_data = 8'b01101100;
            10'd267: row_data = 8'b01001100;
            10'd272: row_data = 8'b00000000;
            10'd273: row_data = 8'b00010000;
            10'd274: row_data = 8'b00010000;
            10'd275: row_data = 8'b00010000;
            10'd276: row_data = 8'b00010000;
            10'd277: row_data = 8'b00010000;
            10'd278: row_data = 8'b00010000;
            10'd279: row_data = 8'b00010000;
            10'd280: row_data = 8'b00010000;
            10'd281: row_data = 8'b00010000;
            10'd282: row_data = 8'b00010000;
            10'd283: row_data = 8'b00010000;
            10'd288: row_data = 8'b00000000;
            10'd289: row_data = 8'b00000000;
            10'd290: row_data = 8'b11000110;
            10'd291: row_data = 8'b11000110;
            10'd292: row_data = 8'b11000110;
            10'd293: row_data = 8'b11000110;
            10'd294: row_data = 8'b11000110;
            10'd295: row_data = 8'b00000110;
            10'd296: row_data = 8'b00000110;
            10'd297: row_data = 8'b00001100;
            10'd298: row_data = 8'b00011000;
            10'd299: row_data = 8'b01110000;
            10'd304: row_data = 8'b00000000;
            10'd305: row_data = 8'b11000000;
            10'd306: row_data = 8'b11100000;
            10'd307: row_data = 8'b11110000;
            10'd308: row_data = 8'b11011000;
            10'd309: row_data = 8'b11001100;
            10'd310: row_data = 8'b11000110;
            10'd311: row_data = 8'b11000110;
            10'd312: row_data = 8'b11111110;
            10'd313: row_data = 8'b11000000;
            10'd314: row_data = 8'b11000000;
            10'd315: row_data = 8'b11000000;
            10'd320: row_data = 8'b00000000;
            10'd321: row_data = 8'b00110000;
            10'd322: row_data = 8'b11111110;
            10'd323: row_data = 8'b11111110;
            10'd324: row_data = 8'b00110000;
            10'd325: row_data = 8'b00110000;
            10'd326: row_data = 8'b10110100;
            10'd327: row_data = 8'b10110100;
            10'd328: row_data = 8'b10110100;
            10'd329: row_data = 8'b10110110;
            10'd330: row_data = 8'b10110010;
            10'd331: row_data = 8'b00011000;
            10'd336: row_data = 8'b00000000;
            10'd337: row_data = 8'b11111110;
            10'd338: row_data = 8'b11000000;
            10'd339: row_data = 8'b11000000;
            10'd340: row_data = 8'b11111000;
            10'd341: row_data = 8'b11111100;
            10'd342: row_data = 8'b00001110;
            10'd343: row_data = 8'b00000110;
            10'd344: row_data = 8'b00000110;
            10'd345: row_data = 8'b00000110;
            10'd346: row_data = 8'b10000110;
            10'd347: row_data = 8'b01111100;
            10'd352: row_data = 8'b00000000;
            10'd353: row_data = 8'b00000000;
            10'd354: row_data = 8'b01111110;
            10'd355: row_data = 8'b00111100;
            10'd356: row_data = 8'b00000110;
            10'd357: row_data = 8'b00000110;
            10'd358: row_data = 8'b00110110;
            10'd359: row_data = 8'b00110110;
            10'd360: row_data = 8'b00111100;
            10'd361: row_data = 8'b00111000;
            10'd362: row_data = 8'b01100000;
            10'd363: row_data = 8'b01000000;
            10'd368: row_data = 8'b00000000;
            10'd369: row_data = 8'b11111110;
            10'd370: row_data = 8'b11000000;
            10'd371: row_data = 8'b11000000;
            10'd372: row_data = 8'b01100000;
            10'd373: row_data = 8'b01100000;
            10'd374: row_data = 8'b00110000;
            10'd375: row_data = 8'b00110000;
            10'd376: row_data = 8'b00011000;
            10'd377: row_data = 8'b00011000;
            10'd378: row_data = 8'b00011000;
            10'd379: row_data = 8'b00011000;
            10'd384: row_data = 8'b00000000;
            10'd385: row_data = 8'b00000000;
            10'd386: row_data = 8'b01100000;
            10'd387: row_data = 8'b11111110;
            10'd388: row_data = 8'b11111110;
            10'd389: row_data = 8'b00110000;
            10'd390: row_data = 8'b00110000;
            10'd391: row_data = 8'b11111110;
            10'd392: row_data = 8'b11111110;
            10'd393: row_data = 8'b00011000;
            10'd394: row_data = 8'b00011000;
            10'd395: row_data = 8'b00011000;
            10'd400: row_data = 8'b00000000;
            10'd401: row_data = 8'b00000000;
            10'd402: row_data = 8'b00000000;
            10'd403: row_data = 8'b00110000;
            10'd404: row_data = 8'b00110000;
            10'd405: row_data = 8'b00110000;
            10'd406: row_data = 8'b01101100;
            10'd407: row_data = 8'b01101100;
            10'd408: row_data = 8'b01100110;
            10'd409: row_data = 8'b11001110;
            10'd410: row_data = 8'b11011010;
            10'd411: row_data = 8'b11110010;
            10'd416: row_data = 8'b00000000;
            10'd417: row_data = 8'b00000000;
            10'd418: row_data = 8'b00000000;
            10'd419: row_data = 8'b00011000;
            10'd420: row_data = 8'b00011000;
            10'd421: row_data = 8'b00000000;
            10'd422: row_data = 8'b00000000;
            10'd423: row_data = 8'b00000000;
            10'd424: row_data = 8'b00000000;
            10'd425: row_data = 8'b00011000;
            10'd426: row_data = 8'b00011000;
            10'd427: row_data = 8'b00000000;
            10'd432: row_data = 8'b00000000;
            10'd433: row_data = 8'b00000000;
            10'd434: row_data = 8'b01111110;
            10'd435: row_data = 8'b00000000;
            10'd436: row_data = 8'b00000000;
            10'd437: row_data = 8'b01111110;
            10'd438: row_data = 8'b00011000;
            10'd439: row_data = 8'b00011000;
            10'd440: row_data = 8'b00011000;
            10'd441: row_data = 8'b00011000;
            10'd442: row_data = 8'b00110000;
            10'd443: row_data = 8'b01100000;
            10'd448: row_data = 8'b00000000;
            10'd449: row_data = 8'b00000000;
            10'd450: row_data = 8'b00010000;
            10'd451: row_data = 8'b00010000;
            10'd452: row_data = 8'b00010000;
            10'd453: row_data = 8'b11111110;
            10'd454: row_data = 8'b00010000;
            10'd455: row_data = 8'b00010000;
            10'd456: row_data = 8'b00010000;
            10'd457: row_data = 8'b00000000;
            10'd458: row_data = 8'b00000000;
            10'd459: row_data = 8'b00000000;
            10'd464: row_data = 8'b00000000;
            10'd465: row_data = 8'b00110000;
            10'd466: row_data = 8'b00110000;
            10'd467: row_data = 8'b01111110;
            10'd468: row_data = 8'b01111110;
            10'd469: row_data = 8'b11011000;
            10'd470: row_data = 8'b10011000;
            10'd471: row_data = 8'b00011000;
            10'd472: row_data = 8'b00011000;
            10'd473: row_data = 8'b00011000;
            10'd474: row_data = 8'b00110000;
            10'd475: row_data = 8'b11100000;
            10'd480: row_data = 8'b00000000;
            10'd481: row_data = 8'b01111100;
            10'd482: row_data = 8'b11000110;
            10'd483: row_data = 8'b11100110;
            10'd484: row_data = 8'b11100110;
            10'd485: row_data = 8'b11110110;
            10'd486: row_data = 8'b11010110;
            10'd487: row_data = 8'b11011110;
            10'd488: row_data = 8'b11001110;
            10'd489: row_data = 8'b11001110;
            10'd490: row_data = 8'b11000110;
            10'd491: row_data = 8'b01111100;
            10'd496: row_data = 8'b00000000;
            10'd497: row_data = 8'b00000000;
            10'd498: row_data = 8'b00001100;
            10'd499: row_data = 8'b00001100;
            10'd500: row_data = 8'b01001100;
            10'd501: row_data = 8'b01101100;
            10'd502: row_data = 8'b00111100;
            10'd503: row_data = 8'b00011100;
            10'd504: row_data = 8'b00011110;
            10'd505: row_data = 8'b00011010;
            10'd506: row_data = 8'b00110000;
            10'd507: row_data = 8'b01100000;
            10'd512: row_data = 8'b00000000;
            10'd513: row_data = 8'b00000000;
            10'd514: row_data = 8'b01100000;
            10'd515: row_data = 8'b11111110;
            10'd516: row_data = 8'b11111110;
            10'd517: row_data = 8'b01100110;
            10'd518: row_data = 8'b01100110;
            10'd519: row_data = 8'b01100110;
            10'd520: row_data = 8'b01100110;
            10'd521: row_data = 8'b01100110;
            10'd522: row_data = 8'b01000110;
            10'd523: row_data = 8'b10011100;
            10'd528: row_data = 8'b00000000;
            10'd529: row_data = 8'b01111100;
            10'd530: row_data = 8'b10001110;
            10'd531: row_data = 8'b00000110;
            10'd532: row_data = 8'b00000110;
            10'd533: row_data = 8'b00000110;
            10'd534: row_data = 8'b00001100;
            10'd535: row_data = 8'b00011000;
            10'd536: row_data = 8'b00110000;
            10'd537: row_data = 8'b01100000;
            10'd538: row_data = 8'b11000000;
            10'd539: row_data = 8'b11111110;
            10'd544: row_data = 8'b00000000;
            10'd545: row_data = 8'b00000000;
            10'd546: row_data = 8'b01111110;
            10'd547: row_data = 8'b01111110;
            10'd548: row_data = 8'b00000000;
            10'd549: row_data = 8'b11111110;
            10'd550: row_data = 8'b11111110;
            10'd551: row_data = 8'b00000110;
            10'd552: row_data = 8'b00000110;
            10'd553: row_data = 8'b00001110;
            10'd554: row_data = 8'b00011100;
            10'd555: row_data = 8'b01111000;
            10'd560: row_data = 8'b00000000;
            10'd561: row_data = 8'b00000000;
            10'd562: row_data = 8'b00010000;
            10'd563: row_data = 8'b11010110;
            10'd564: row_data = 8'b01111100;
            10'd565: row_data = 8'b00111000;
            10'd566: row_data = 8'b01111100;
            10'd567: row_data = 8'b11010110;
            10'd568: row_data = 8'b00010000;
            10'd569: row_data = 8'b00000000;
            10'd570: row_data = 8'b00000000;
            10'd571: row_data = 8'b00000000;
            10'd576: row_data = 8'b00000000;
            10'd577: row_data = 8'b01100000;
            10'd578: row_data = 8'b01100000;
            10'd579: row_data = 8'b11111110;
            10'd580: row_data = 8'b11111110;
            10'd581: row_data = 8'b01100110;
            10'd582: row_data = 8'b01100110;
            10'd583: row_data = 8'b01100110;
            10'd584: row_data = 8'b01101100;
            10'd585: row_data = 8'b01100000;
            10'd586: row_data = 8'b01111110;
            10'd587: row_data = 8'b00111110;
            10'd592: row_data = 8'b00000000;
            10'd593: row_data = 8'b00110000;
            10'd594: row_data = 8'b11111110;
            10'd595: row_data = 8'b11111110;
            10'd596: row_data = 8'b00000110;
            10'd597: row_data = 8'b00000110;
            10'd598: row_data = 8'b00000110;
            10'd599: row_data = 8'b00001100;
            10'd600: row_data = 8'b00111100;
            10'd601: row_data = 8'b11110110;
            10'd602: row_data = 8'b00110010;
            10'd603: row_data = 8'b00110000;
            10'd608: row_data = 8'b00000000;
            10'd609: row_data = 8'b01111100;
            10'd610: row_data = 8'b11000110;
            10'd611: row_data = 8'b11000110;
            10'd612: row_data = 8'b11000110;
            10'd613: row_data = 8'b11000110;
            10'd614: row_data = 8'b11001110;
            10'd615: row_data = 8'b01110110;
            10'd616: row_data = 8'b00000110;
            10'd617: row_data = 8'b00000110;
            10'd618: row_data = 8'b00001100;
            10'd619: row_data = 8'b01111000;
            10'd624: row_data = 8'b00000000;
            10'd625: row_data = 8'b00000000;
            10'd626: row_data = 8'b01111100;
            10'd627: row_data = 8'b01111100;
            10'd628: row_data = 8'b00001100;
            10'd629: row_data = 8'b00001100;
            10'd630: row_data = 8'b00011000;
            10'd631: row_data = 8'b00011000;
            10'd632: row_data = 8'b00110000;
            10'd633: row_data = 8'b00111000;
            10'd634: row_data = 8'b01101100;
            10'd635: row_data = 8'b11000110;
            10'd640: row_data = 8'b00000000;
            10'd641: row_data = 8'b01111110;
            10'd642: row_data = 8'b01111110;
            10'd643: row_data = 8'b01100110;
            10'd644: row_data = 8'b11000110;
            10'd645: row_data = 8'b10000110;
            10'd646: row_data = 8'b00100110;
            10'd647: row_data = 8'b00111110;
            10'd648: row_data = 8'b00011100;
            10'd649: row_data = 8'b00111000;
            10'd650: row_data = 8'b01110000;
            10'd651: row_data = 8'b11100000;
            10'd656: row_data = 8'b00000000;
            10'd657: row_data = 8'b00000000;
            10'd658: row_data = 8'b00000000;
            10'd659: row_data = 8'b00000000;
            10'd660: row_data = 8'b00000000;
            10'd661: row_data = 8'b00000000;
            10'd662: row_data = 8'b00000000;
            10'd663: row_data = 8'b00000000;
            10'd664: row_data = 8'b00000000;
            10'd665: row_data = 8'b00011000;
            10'd666: row_data = 8'b00011000;
            10'd667: row_data = 8'b00000000;
            10'd672: row_data = 8'b00000000;
            10'd673: row_data = 8'b11111110;
            10'd674: row_data = 8'b11111110;
            10'd675: row_data = 8'b00000110;
            10'd676: row_data = 8'b00000110;
            10'd677: row_data = 8'b01000110;
            10'd678: row_data = 8'b01101110;
            10'd679: row_data = 8'b00111100;
            10'd680: row_data = 8'b00011000;
            10'd681: row_data = 8'b00111100;
            10'd682: row_data = 8'b01100110;
            10'd683: row_data = 8'b11000000;
            10'd688: row_data = 8'b00000000;
            10'd689: row_data = 8'b00000000;
            10'd690: row_data = 8'b11111110;
            10'd691: row_data = 8'b11000000;
            10'd692: row_data = 8'b11000000;
            10'd693: row_data = 8'b01100000;
            10'd694: row_data = 8'b00110000;
            10'd695: row_data = 8'b00011000;
            10'd696: row_data = 8'b00001100;
            10'd697: row_data = 8'b00000110;
            10'd698: row_data = 8'b00000110;
            10'd699: row_data = 8'b11111110;
            10'd704: row_data = 8'b00000000;
            10'd705: row_data = 8'b00000000;
            10'd706: row_data = 8'b00000000;
            10'd707: row_data = 8'b11001100;
            10'd708: row_data = 8'b11001100;
            10'd709: row_data = 8'b11101110;
            10'd710: row_data = 8'b01100110;
            10'd711: row_data = 8'b01100110;
            10'd712: row_data = 8'b01100110;
            10'd713: row_data = 8'b00000000;
            10'd714: row_data = 8'b00000000;
            10'd715: row_data = 8'b00000000;
            10'd720: row_data = 8'b00000000;
            10'd721: row_data = 8'b00000000;
            10'd722: row_data = 8'b00001100;
            10'd723: row_data = 8'b00011000;
            10'd724: row_data = 8'b00110000;
            10'd725: row_data = 8'b01100000;
            10'd726: row_data = 8'b01100000;
            10'd727: row_data = 8'b00110000;
            10'd728: row_data = 8'b00011000;
            10'd729: row_data = 8'b00001100;
            10'd730: row_data = 8'b00000000;
            10'd731: row_data = 8'b00000000;
            10'd736: row_data = 8'b00000000;
            10'd737: row_data = 8'b10000000;
            10'd738: row_data = 8'b10000000;
            10'd739: row_data = 8'b10000000;
            10'd740: row_data = 8'b10000000;
            10'd741: row_data = 8'b00000000;
            10'd742: row_data = 8'b00000000;
            10'd743: row_data = 8'b10000000;
            10'd744: row_data = 8'b10000000;
            10'd745: row_data = 8'b10000000;
            10'd746: row_data = 8'b10000000;
            10'd747: row_data = 8'b10000000;
            10'd752: row_data = 8'b00000000;
            10'd753: row_data = 8'b00000000;
            10'd754: row_data = 8'b00000000;
            10'd755: row_data = 8'b00000000;
            10'd756: row_data = 8'b00000000;
            10'd757: row_data = 8'b00000000;
            10'd758: row_data = 8'b00000000;
            10'd759: row_data = 8'b00000000;
            10'd760: row_data = 8'b00000000;
            10'd761: row_data = 8'b00000000;
            10'd762: row_data = 8'b00000000;
            10'd763: row_data = 8'b00000000;
            default: row_data = 8'b00000000;
        endcase
    end

    // Extract pixel from row data
    always @(*) begin
        pixel = row_data[x];
    end

endmodule

// =============================================================================
// Module: sasic_top (Top-level wrapper for SASIC interface)
// Description: VGA Glyph Mode adapted for SASIC Structured ASIC
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
    // VGA Output Interface
    // ========================================================================
    // Using first 8 outputs for VGA signals:
    //   out_0: RGB[0] (bit 0 of red)
    //   out_1: RGB[1] (bit 0 of green)
    //   out_2: RGB[2] (bit 1 of red)
    //   out_3: RGB[3] (bit 1 of green)
    //   out_4: vsync
    //   out_5: RGB[4] (bit 2 of red)
    //   out_6: RGB[5] (bit 2 of green)
    //   out_7: hsync

    wire hsync, vsync;
    wire [5:0] RGB;

    // TinyVGA PMOD pinout: {hsync, RGB[0], RGB[2], RGB[4], vsync, RGB[1], RGB[3], RGB[5]}
    assign out_0 = RGB[0];
    assign out_1 = RGB[1];
    assign out_2 = RGB[2];
    assign out_3 = RGB[3];
    assign out_4 = vsync;
    assign out_5 = RGB[4];
    assign out_6 = RGB[5];
    assign out_7 = hsync;

    // Tie unused outputs to 0
    assign {out_39, out_38, out_37, out_36, out_35, out_34, out_33, out_32} = 32'b0;
    assign {out_31, out_30, out_29, out_28, out_27, out_26, out_25, out_24} = 32'b0;
    assign {out_23, out_22, out_21, out_20, out_19, out_18, out_17, out_16} = 32'b0;
    assign {out_15, out_14, out_13, out_12, out_11, out_10, out_9,  out_8}  = 32'b0;

    // Configure output enables: outputs 0-7 are active, rest are high-impedance
    assign {oeb_7, oeb_6, oeb_5, oeb_4, oeb_3, oeb_2, oeb_1, oeb_0} = 8'b00000000; // Active (low)
    assign {oeb_39, oeb_38, oeb_37, oeb_36, oeb_35, oeb_34, oeb_33, oeb_32} = 8'b11111111; // High-Z
    assign {oeb_31, oeb_30, oeb_29, oeb_28, oeb_27, oeb_26, oeb_25, oeb_24} = 8'b11111111;
    assign {oeb_23, oeb_22, oeb_21, oeb_20, oeb_19, oeb_18, oeb_17, oeb_16} = 8'b11111111;
    assign {oeb_15, oeb_14, oeb_13, oeb_12, oeb_11, oeb_10, oeb_9,  oeb_8}  = 8'b11111111;

    // ========================================================================
    // VGA Core Logic
    // ========================================================================

    wire video_active;
    wire [9:0] pix_x;
    wire [9:0] pix_y;

    wire [6:0] xb = pix_x[9:3];
    wire [6:0] x_mix = {xb[3], xb[1], xb[4], xb[1], xb[6], xb[0], xb[2]};
    wire [2:0] g_x = pix_x[2:0];
    wire [5:0] yb;
    wire [5:0] g_unused;
    wire [3:0] g_y;
    assign {g_unused, g_y} = pix_y - {yb, 3'b000} - {1'b0, yb, 2'b00};
    wire hl;

    // Use inputs for palette selection (in_0, in_1)
    wire [1:0] palette_select = {in_1, in_0};

    reg [9:0] counter;

    // VGA sync generator
    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    // Glyph ROM
    glyphs_rom glyphs(
        .c(glyph_index),
        .y(g_y),
        .x(g_x),
        .pixel(hl)
    );

    // Division by 3
    div3_rom div3(
        .in(pix_y[8:2]),
        .out(yb)
    );

    wire [5:0] r = x[6:1] >> 2;
    wire [5:0] glyph_index = {xb[2] ^ yb[0], xb[0] ^ yb[1], xb[1] ^ yb[2], xb[4] ^ yb[3], xb[3] ^ yb[4]}
        + {1'b0, xb[5] ^ yb[5], xb[6] ^ yb[0], xb[0] ^ yb[1], xb[1] ^ yb[2]}
        + r;

    wire [1:0] a = xb[1:0];
    wire [3:0] b = xb[5:2];
    wire [2:0] d = xb[3:2] + 2'd3;

    wire s = xb[0] ^ xb[1] ^ xb[2] ^ xb[3] ^ xb[4] ^ xb[5] ^ xb[6];
    wire n = xb[1] ^ xb[3] ^ xb[5];

    wire [6:0] v = (counter[9:3] << s) - yb - x_mix;
    wire [3:0] c = {2'b00, a} + d;
    wire [6:0] e = {3'b000, b} << c;
    wire [6:0] f = v[6:0] & e;
    wire [6:0] x = v[6:0] >> a;
    wire [2:0] y = x[2:0] ^ 3'b111;
    wire [5:0] black = 6'b000000;

    wire [5:0] z = (((v[2:0] & 3'b111) == 3'b000) & y == 7) ? 6'b111111 : palette[palette_select][y];

    wire [5:0] color = ((f != 7'd0) | n) ? black : z;

    assign RGB = (video_active & hl) ? color : black;

    always @(posedge vsync) begin
        if (~rst_n) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end

    // Color palettes (RRGGBB format)
    reg [5:0] palette[3:0][7:0];
    initial begin
        // Palette 0: Green (default)
        palette[0][0] = 6'b000000;
        palette[0][1] = 6'b000100;
        palette[0][2] = 6'b001000;
        palette[0][3] = 6'b001100;
        palette[0][4] = 6'b001101;
        palette[0][5] = 6'b011101;
        palette[0][6] = 6'b011110;
        palette[0][7] = 6'b101110;

        // Palette 1: Red
        palette[1][0] = 6'b000000;
        palette[1][1] = 6'b010000;
        palette[1][2] = 6'b100000;
        palette[1][3] = 6'b110000;
        palette[1][4] = 6'b110001;
        palette[1][5] = 6'b110101;
        palette[1][6] = 6'b110110;
        palette[1][7] = 6'b111010;

        // Palette 2: Blue
        palette[2][0] = 6'b000000;
        palette[2][1] = 6'b000001;
        palette[2][2] = 6'b000010;
        palette[2][3] = 6'b000011;
        palette[2][4] = 6'b000111;
        palette[2][5] = 6'b010111;
        palette[2][6] = 6'b011011;
        palette[2][7] = 6'b101011;

        // Palette 3: Pride
        palette[3][0] = 6'b000000;
        palette[3][1] = 6'b110000;
        palette[3][2] = 6'b111000;
        palette[3][3] = 6'b111100;
        palette[3][4] = 6'b001000;
        palette[3][5] = 6'b000111;
        palette[3][6] = 6'b100010;
        palette[3][7] = 6'b110011;
    end

endmodule

`default_nettype wire
