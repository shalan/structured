# SASIC Fabric Integration Guide

This document describes how to integrate a Verilog design with the SASIC (Structured ASIC) fabric.

## Standard Wrapper Interface

All designs must implement a `sasic_top` module with the following interface:

```verilog
module sasic_top (
    input  wire clk,
    input  wire rst_n,

    // 40 individual input pins
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

    // 40 individual output pins
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

    // 40 output enable pins
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
```

## Pin Direction Control (oeb)

The `oeb` (Output Enable Bar) signal controls the direction of each pin:

| oeb Value | Pin Direction | Description |
|-----------|---------------|-------------|
| `0` | **OUTPUT** | Pin is actively driven by `out_*` signal |
| `1` | **INPUT** | Pin is high-Z, read from `in_*` signal |

**Important:** The naming convention is inverted - `oeb = 0` enables output, `oeb = 1` disables it (high-Z for input).

## Integration Rules

### 1. Clock and Reset
- `clk`: System clock input
- `rst_n`: Active-LOW reset (invert with `~rst_n` for cores using active-HIGH reset)

### 2. Output Pin Configuration
For pins used as outputs:
```verilog
// Assign your signal to the output pin
assign out_0 = my_output_signal;

// Enable the output driver (oeb = 0)
assign oeb_0 = 1'b0;
```

### 3. Input Pin Configuration
For pins used as inputs:
```verilog
// Read from the input pin
wire my_input_signal = in_7;

// Disable the output driver for high-Z (oeb = 1)
assign oeb_7 = 1'b1;
```

### 4. Unused Pins
For pins not used:
```verilog
// Tie outputs to 0
assign out_8 = 1'b0;

// Set oeb to 1 (high-Z)
assign oeb_8 = 1'b1;
```

### 5. Grouping Pins into Buses
Use concatenation to group individual pins into buses:
```verilog
// Example: 16-bit address bus on pins 0-15
wire [15:0] address_bus;
assign {out_15, out_14, out_13, out_12, out_11, out_10, out_9, out_8,
       out_7,  out_6,  out_5,  out_4,  out_3,  out_2,  out_1, out_0} = address_bus;

// Set all as outputs
assign {oeb_15, oeb_14, oeb_13, oeb_12, oeb_11, oeb_10, oeb_9, oeb_8,
       oeb_7,  oeb_6,  oeb_5,  oeb_4,  oeb_3,  oeb_2,  oeb_1, oeb_0} = 16'h0000;
```

## Complete Example

```verilog
module sasic_top (
    input  wire clk,
    input  wire rst_n,
    input  wire in_0,  input  wire in_1,  ..., input  wire in_39,
    output wire out_0, output wire out_1, ..., output wire out_39,
    output wire oeb_0, output wire oeb_1, ..., output wire oeb_39
);

    // ================================================================
    // Signal Declarations
    // ================================================================

    // Input signals (oeb = 1 for high-Z)
    wire [7:0] data_in = {in_23, in_22, in_21, in_20, in_19, in_18, in_17, in_16};
    wire        irq = in_24;
    wire        nmi = in_25;

    // Output signals
    wire [15:0] address;
    wire [7:0]  data_out;
    wire        write_enable;

    // ================================================================
    // Core Instantiation
    // ================================================================

    my_core u_core (
        .clk(clk),
        .rst(~rst_n),      // Invert reset for active-HIGH core
        .addr(address),
        .din(data_in),
        .dout(data_out),
        .we(write_enable),
        .irq(irq),
        .nmi(nmi)
    );

    // ================================================================
    // Output Assignments
    // ================================================================

    // Address bus (pins 0-15, outputs)
    assign {out_15, out_14, out_13, out_12, out_11, out_10, out_9, out_8,
            out_7,  out_6,  out_5,  out_4,  out_3,  out_2,  out_1, out_0} = address;
    assign {oeb_15, oeb_14, oeb_13, oeb_12, oeb_11, oeb_10, oeb_9, oeb_8,
            oeb_7,  oeb_6,  oeb_5,  oeb_4,  oeb_3,  oeb_2,  oeb_1, oeb_0} = 16'h0000;

    // Data out (pins 24-31, outputs)
    assign {out_31, out_30, out_29, out_28, out_27, out_26, out_25, out_24} = data_out;
    assign {oeb_31, oeb_30, oeb_29, oeb_28, oeb_27, oeb_26, oeb_25, oeb_24} = 8'h00;

    // Write enable (pin 32, output)
    assign out_32 = write_enable;
    assign oeb_32 = 1'b0;

    // ================================================================
    // Input Pin Configuration (oeb = 1 for high-Z)
    // ================================================================

    // Data in pins (16-23)
    assign {oeb_23, oeb_22, oeb_21, oeb_20, oeb_19, oeb_18, oeb_17, oeb_16} = 8'hFF;

    // IRQ, NMI pins (24-25)
    assign oeb_24 = 1'b1;
    assign oeb_25 = 1'b1;

    // ================================================================
    // Unused Pins
    // ================================================================

    // Tie unused outputs to 0, set oeb to 1
    assign {out_39, out_38, out_37, out_36, out_35, out_34, out_33} = 7'b0;
    assign {oeb_39, oeb_38, oeb_37, oeb_36, oeb_35, oeb_34, oeb_33} = 7'b1111111;

endmodule
```

## Common Patterns from Existing Designs

### 6502 CPU (designs/src/6502.v)
| Pins | Direction | Signal |
|------|-----------|--------|
| 0-15 | OUTPUT | Address Bus [15:0] |
| 16-23 | INPUT | Data In [7:0] |
| 24-31 | OUTPUT | Data Out [7:0] |
| 32 | OUTPUT | Write Enable |
| 33 | INPUT | IRQ |
| 34 | INPUT | NMI |
| 35 | INPUT | RDY |
| 36-39 | Unused | - |

### VGA Glyph Demo (designs/src/vga_glyph_demo.v)
| Pins | Direction | Signal |
|------|-----------|--------|
| 0-6 | OUTPUT | RGB + Sync signals |
| 7-39 | Unused | - |
| 0-1 | INPUT | Palette select |

### UART to SPI Bridge (designs/src/uart_to_spi_bridge.v)
| Pins | Direction | Signal |
|------|-----------|--------|
| 0 | OUTPUT | UART TX |
| 1-6 | OUTPUT | SPI (SCK, MOSI, SS0-SS3) |
| 7 | INPUT | UART RX |
| 8 | INPUT | SPI MISO |
| 9-39 | Unused | - |

## Checklist for New Designs

- [ ] Module named `sasic_top`
- [ ] Has `clk` and `rst_n` inputs
- [ ] Has 40 `in_*` input pins (in_0 through in_39)
- [ ] Has 40 `out_*` output pins (out_0 through out_39)
- [ ] Has 40 `oeb_*` output pins (oeb_0 through oeb_39)
- [ ] All output pins have `oeb = 0`
- [ ] All input pins have `oeb = 1`
- [ ] Unused pins have `out = 0` and `oeb = 1`
- [ ] Reset polarity handled correctly (invert if core uses active-HIGH)

## Reference Designs

| File | Description | Status |
|------|-------------|--------|
| `6502.v` | 6502 CPU | Reference |
| `vga_glyph_demo.v` | VGA display | Reference |
| `z80.v` | Z80 CPU | Reference |
| `frv32_soc.v` | FRV32 SoC | Reference |
| `soc.v` | PicoSoC | Reference |
| `arith.v` | Arithmetic unit | Reference |
| `aes_128.v` | AES-128 encryption | Reference |
| `uart_to_spi_bridge.v` | UART-SPI bridge | Reference |
