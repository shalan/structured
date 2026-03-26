# Wrapping Tiny Tapeout Projects for SASIC

## Overview

Tiny Tapeout (TT) projects use a standard interface with 8-bit buses and active-high output enables. The SASIC fabric uses 40 individual pins with active-low output enables (`oeb`). This guide explains how to write a `sasic_top` wrapper for any TT project.

## Interface Comparison

### TT Interface

```
module tt_um_<name>(
    input  wire [7:0] ui_in,     // 8 dedicated inputs
    output wire [7:0] uo_out,    // 8 dedicated outputs
    input  wire [7:0] uio_in,    // 8 bidirectional: input path
    output wire [7:0] uio_out,   // 8 bidirectional: output path
    output wire [7:0] uio_oe,    // 8 bidirectional: enable (active HIGH: 1=output)
    input  wire       ena,       // design enable
    input  wire       clk,
    input  wire       rst_n
);
```

### SASIC Interface

```
module sasic_top(
    input  wire clk,
    input  wire rst_n,
    input  wire in_0 .. in_39,    // 40 individual inputs
    output wire oeb_0 .. oeb_39,  // 40 output enables (active LOW: 0=output)
    output wire out_0 .. out_39   // 40 individual outputs
);
```

## Pin Mapping

| SASIC Pins    | TT Signal        | Notes                              |
|---------------|------------------|------------------------------------|
| `in_0..in_7`  | `ui_in[7:0]`    | Dedicated inputs                   |
| `in_8..in_15` | `uio_in[7:0]`   | Bidirectional input path           |
| `in_16..in_39`| —                | Unused; directly available to fabric as extra pins |
| `out_0..out_7`| `uo_out[7:0]`   | Dedicated outputs                  |
| `out_8..out_15`| `uio_out[7:0]` | Bidirectional output path          |
| `out_16..out_39`| —              | Unused; tie to `1'b0`             |
| `oeb_0..oeb_7`| `1'b1`          | Dedicated inputs: always tristate  |
| `oeb_8..oeb_15`| `~uio_oe[7:0]` | **Polarity inverted**             |
| `oeb_16..oeb_39`| `1'b1`        | Unused: tristate                   |
| `clk`         | `clk`            | Direct                             |
| `rst_n`       | `rst_n`          | Direct                             |
| —             | `ena`            | Tie to `1'b1`                     |

## Polarity Warning

TT `uio_oe` is **active HIGH** (1 = output), while SASIC `oeb` is **active LOW** (0 = output). You must invert:

```verilog
assign oeb_N = ~uio_oe[N-8];  // for N = 8..15
```

## Wrapper Template

Replace `tt_um_YOURDESIGN` with the actual module name. Append the TT project's Verilog source(s) before this wrapper in the same file.

```verilog
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

    // --- Bundle individual SASIC pins into TT buses ---
    wire [7:0] ui_in  = {in_7,  in_6,  in_5,  in_4,  in_3,  in_2,  in_1,  in_0};
    wire [7:0] uio_in = {in_15, in_14, in_13, in_12, in_11, in_10, in_9,  in_8};

    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // --- Instantiate TT project ---
    tt_um_YOURDESIGN tt_inst (
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (1'b1),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    // --- Dedicated outputs (uo_out -> out_0..out_7) ---
    assign {out_7, out_6, out_5, out_4, out_3, out_2, out_1, out_0} = uo_out;

    // --- Bidirectional outputs (uio_out -> out_8..out_15) ---
    assign {out_15, out_14, out_13, out_12, out_11, out_10, out_9, out_8} = uio_out;

    // --- Unused outputs: tie low ---
    assign {out_39, out_38, out_37, out_36, out_35, out_34, out_33, out_32,
            out_31, out_30, out_29, out_28, out_27, out_26, out_25, out_24,
            out_23, out_22, out_21, out_20, out_19, out_18, out_17, out_16} = 24'd0;

    // --- OEB: dedicated inputs are always tristate (oeb=1) ---
    assign {oeb_7, oeb_6, oeb_5, oeb_4, oeb_3, oeb_2, oeb_1, oeb_0} = 8'hFF;

    // --- OEB: bidirectional — INVERT TT polarity ---
    assign {oeb_15, oeb_14, oeb_13, oeb_12, oeb_11, oeb_10, oeb_9, oeb_8} = ~uio_oe;

    // --- OEB: unused pins are tristate (oeb=1) ---
    assign {oeb_39, oeb_38, oeb_37, oeb_36, oeb_35, oeb_34, oeb_33, oeb_32,
            oeb_31, oeb_30, oeb_29, oeb_28, oeb_27, oeb_26, oeb_25, oeb_24,
            oeb_23, oeb_22, oeb_21, oeb_20, oeb_19, oeb_18, oeb_17, oeb_16} = 24'hFFFFFF;

endmodule
```

## Synthesis

```bash
python3 tools/synth.py \
    -d designs/src/tt_um_YOURDESIGN.v \
    -t sasic_top \
    -l fabric/fabric_11x66.lib \
    -m tech/techmap_2.v \
    --fabric fabric/fabric_11x66.yaml \
    -o designs/synth/tt_um_YOURDESIGN_11x66 \
    --flatten -v
```

## Checklist

1. Concatenate the TT source files and the wrapper into a single `.v` file (or pass multiple `-d` arguments).
2. Ensure `sasic_top` is always the top module name (`-t sasic_top`).
3. Verify OEB polarity: `oeb = ~uio_oe`.
4. Tie `ena` to `1'b1`.
5. Tie unused `out_*` to `1'b0` and unused `oeb_*` to `1'b1`.
6. Check synthesis capacity report — TT projects using > ~13k gates may exceed fabric limits.
