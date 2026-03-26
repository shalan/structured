# Structured ASIC Design Flow

Complete guide for designing with the SASIC (Structured ASIC) platform using SkyWater 130nm PDK.

---

## Table of Contents

1. [Overview](#overview)
2. [Phase 1: Fabric Definition](#phase-1-fabric-definition)
3. [Phase 2: Design Preparation](#phase-2-design-preparation)
4. [Phase 3: Synthesis & Technology Mapping](#phase-3-synthesis--technology-mapping)
5. [Phase 4: Placement](#phase-4-placement)
6. [Phase 5: Verification & Export](#phase-5-verification--export)
7. [Complete Flow Example](#complete-flow-example)
8. [Troubleshooting](#troubleshooting)

---

## Overview

### What is a Structured ASIC?

A Structured ASIC uses a **pre-defined fabric** of standard cells with fixed placement. Unlike traditional standard-cell ASICs where cells can be placed anywhere, structured ASICs use:

- **Fixed tile grid**: Pre-placed cells in a repeating pattern
- **Pre-routed power**: Power and ground networks already in place
- **Predictable timing**: Pre-characterized interconnect delays
- **Faster turnaround**: Skip placement optimization, focus on assignment

### SASIC Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Die Area: 1003.6µm × 989.2µm                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Core Area: 993.6µm × 979.2µm                         │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Fabric: 36×90 tiles (3,240 total)              │  │  │
│  │  │                                                  │  │  │
│  │  │  Each tile: 27.6µm × 10.88µm                    │  │  │
│  │  │  - 13× NAND2 gates                              │  │  │
│  │  │  - 8× OR2 gates                                 │  │  │
│  │  │  - 4× Inverters                                 │  │  │
│  │  │  - 3× Buffers                                   │  │  │
│  │  │  - 2× D Flip-Flops (DFBBP)                      │  │  │
│  │  │  - 3× Constant cells (CONB)                     │  │  │
│  │  │  - 8× Well taps (TAP)                           │  │  │
│  │  │  - 6× Decoupling caps (DECAP)                   │  │  │
│  │  │                                                  │  │  │
│  │  │  Total functional cells: ~100,000               │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
│  I/O: 122 pins (40 tri-state groups + clk + rst_n)         │
└─────────────────────────────────────────────────────────────┘
```

### Design Flow Summary

```
┌──────────────────┐
│ 1. FABRIC        │  Define tile architecture
│    DEFINITION    │  → fabric.yaml
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ 2. FABRIC        │  Generate cell instances
│    GENERATION    │  → fabric_cells.yaml, pins.yaml
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ 3. DESIGN        │  Create Verilog with fixed interface
│    PREPARATION   │  → your_design.v
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ 4. SYNTHESIS &   │  Map logic to fabric cells
│    TECH MAP      │  → your_design_mapped.json
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ 5. PLACEMENT     │  Assign cells to fabric positions
│                  │  → your_design.def
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ 6. VERIFICATION  │  Check and visualize
│    & EXPORT      │  → Final DEF/GDS
└──────────────────┘
```

---

## Phase 1: Fabric Definition

### 1.1 Understanding the Fabric YAML

The fabric is defined in `structured/fabric/fabric.yaml`. This file specifies:

#### Fabric Information

```yaml
fabric_info:
  technology: "sky130"
  site_dimensions_um:
    width: 0.46    # Standard cell site width
    height: 2.72   # Standard cell site height
  units:
    database_units_per_micron: 1000
```

#### Fabric Layout

```yaml
fabric_layout:
  tiles_x: 36      # 36 tiles horizontally
  tiles_y: 90      # 90 tiles vertically
  # Total: 3,240 tiles
```

#### Cell Definitions

Each cell type has a defined width in sites:

```yaml
cell_definitions:
  sky130_fd_sc_hd__nand2_2:       { width_sites: 5 }
  sky130_fd_sc_hd__or2_2:         { width_sites: 5 }
  sky130_fd_sc_hd__and2_2:        { width_sites: 6 }
  sky130_fd_sc_hd__clkinv_2:      { width_sites: 4 }
  sky130_fd_sc_hd__clkbuf_4:      { width_sites: 6 }
  sky130_fd_sc_hd__dfbbp_1:       { width_sites: 26 }  # Flip-flop
  sky130_fd_sc_hd__tapvpwrvgnd_1: { width_sites: 1 }   # Well tap
  sky130_fd_sc_hd__decap_4:       { width_sites: 4 }   # Decoupling cap
  sky130_fd_sc_hd__decap_3:       { width_sites: 3 }
  sky130_fd_sc_hd__conb_1:        { width_sites: 3 }   # Tie high/low
  sky130_fd_sc_hd__fill_1:        { width_sites: 1 }   # Filler
```

#### Tile Definition

Each tile is 60 sites wide × 4 rows high:

```yaml
tile_definition:
  dimensions_sites:
    width: 60
    height: 4

  cells:
    # Row 0 (Y=0, Orientation: N)
    - { template_name: "R0_TAP_0",  cell_type: "sky130_fd_sc_hd__tapvpwrvgnd_1",
        origin_sites: { x: 0, y: 0 } }
    - { template_name: "R0_NAND_0", cell_type: "sky130_fd_sc_hd__nand2_2",
        origin_sites: { x: 1, y: 0 } }
    # ... more cells ...

    # Row 1 (Y=1, Orientation: FS/MX)
    - { template_name: "R1_TAP_0",  cell_type: "sky130_fd_sc_hd__tapvpwrvgnd_1",
        origin_sites: { x: 0, y: 1 } }
    # ... more cells ...

    # Row 2 (Y=2, Orientation: N)
    # Row 3 (Y=3, Orientation: FS/MX)
```

**Key Points:**
- Rows alternate orientation: N (normal) and FS (flipped)
- Each tile has ~60-70 cells total
- ~47 functional cells (NAND, OR, INV, BUF, DFBBP, CONB)
- ~20 non-functional cells (TAP, DECAP, FILL)

### 1.2 Modifying the Fabric (Advanced)

If you need to customize the fabric:

1. **Edit `fabric.yaml`** to change cell types or positions
2. **Regenerate fabric files** (see Phase 1.3)
3. **Update `fabric.lib`** to match available cells
4. **Re-characterize timing** if needed

**Warning:** Modifying the fabric requires re-running all generation steps and may affect timing closure.

### 1.3 Generating Fabric Files

Once the fabric is defined, generate the required files:

#### Generate Cell Instances

```bash
python3 tools/gen_fabric_cells_by_tile.py \
    --fabric structured/fabric/fabric.yaml \
    --out structured/fabric/fabric_cells.yaml \
    --die-margin-um 5.0
```

**Output:** `fabric_cells.yaml` (648,007 lines)
- Lists all 3,240 tiles
- Each tile contains 60-70 cell instances
- Total: ~220,000 cell instances
- Each cell has: name, orientation (N/FS), x/y coordinates

#### Generate Pin Placement

```bash
python3 tools/gen_pins_yaml.py \
    --fabric structured/fabric/fabric.yaml \
    --techlef structured/tech/sky130_fd_sc_hd.tlef \
    --out structured/fabric/pins.yaml \
    --die-margin-um 5.0 \
    --corner-keepout-um 5.0 \
    --pin-spacing-tracks 1
```

**Output:** `pins.yaml` (885 lines)
- 122 pins total
- 40 tri-state I/O groups (in_X, out_X, oeb_X)
- 1 clock pin (clk)
- 1 reset pin (rst_n)
- Pin coordinates aligned to routing tracks

**Pin Layout:**
```
        North (met2)
    in_20-29, out_20-29, oeb_20-29
    ┌─────────────────────────────┐
W   │                             │   E
e   │                             │   a
s   │      FABRIC CORE            │   s
t   │      (36×90 tiles)          │   t
    │                             │
(m   │                             │   (m
e   │                             │   e
t3) │                             │   t3)
    └─────────────────────────────┘
    in_0-9, out_0-9, oeb_0-9, clk, rst_n
        South (met2)
```

---

## Phase 2: Design Preparation

### 2.1 Fixed Interface Requirements

All designs **MUST** use the `sasic_top` module with this exact interface:

```verilog
module sasic_top (
    // Clock and Reset
    input  wire clk,              // Global clock
    input  wire rst_n,            // Active-low reset

    // 40 Input pins (10 per side)
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

    // 40 Output pins (10 per side)
    output wire out_0,  output wire out_1,  output wire out_2,  output wire out_3,
    output wire out_4,  output wire out_5,  output wire out_6,  output wire out_7,
    output wire out_8,  output wire out_9,  output wire out_10, output wire out_11,
    output wire out_12, output wire out_13, output wire out_14, output wire out_15,
    output wire out_16, output wire out_17, output wire out_18, output wire out_19,
    output wire out_20, output wire out_21, output wire out_22, output wire out_23,
    output wire out_24, output wire out_25, output wire out_26, output wire out_27,
    output wire out_28, output wire out_29, output wire out_30, output wire out_31,
    output wire out_32, output wire out_33, output wire out_34, output wire out_35,
    output wire out_36, output wire out_37, output wire out_38, output wire out_39,

    // 40 Output Enable pins (10 per side, active LOW)
    output wire oeb_0,  output wire oeb_1,  output wire oeb_2,  output wire oeb_3,
    output wire oeb_4,  output wire oeb_5,  output wire oeb_6,  output wire oeb_7,
    output wire oeb_8,  output wire oeb_9,  output wire oeb_10, output wire oeb_11,
    output wire oeb_12, output wire oeb_13, output wire oeb_14, output wire oeb_15,
    output wire oeb_16, output wire oeb_17, output wire oeb_18, output wire oeb_19,
    output wire oeb_20, output wire oeb_21, output wire oeb_22, output wire oeb_23,
    output wire oeb_24, output wire oeb_25, output wire oeb_26, output wire oeb_27,
    output wire oeb_28, output wire oeb_29, output wire oeb_30, output wire oeb_31,
    output wire oeb_32, output wire oeb_33, output wire oeb_34, output wire oeb_35,
    output wire oeb_36, output wire oeb_37, output wire oeb_38, output wire oeb_39
);
    // Your implementation here
endmodule
```

### 2.2 Understanding Tri-State I/O

Each I/O group consists of 3 pins:

| Pin | Direction | Purpose |
|-----|-----------|---------|
| `in_X` | Input to fabric | Receive external signal |
| `out_X` | Output from fabric | Drive external signal |
| `oeb_X` | Output from fabric | Output enable bar (active LOW) |

**Configuration:**

```verilog
// ========== Example 1: Pin as OUTPUT ==========
assign out_0 = my_output_signal;  // Drive this signal
assign oeb_0 = 1'b0;               // Enable output (LOW = enabled)

// ========== Example 2: Pin as INPUT ==========
wire external_input = in_0;       // Read this signal
assign out_0 = 1'b0;               // Don't care (output disabled)
assign oeb_0 = 1'b1;               // Disable output (HIGH = disabled)

// ========== Example 3: Bidirectional (with control) ==========
assign out_0 = tx_data;            // Transmit data
assign oeb_0 = ~tx_enable;         // Enable output when tx_enable=1
wire rx_data = in_0;               // Receive data (always readable)
```

### 2.3 Design Template

Use this template for your designs:

```verilog
`default_nettype none

// ========== YOUR SUBMODULES HERE ==========
module my_logic (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  data_in,
    output reg  [7:0]  data_out,
    // ... other ports
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_out <= 8'b0;
        else
            data_out <= data_in + 1;
    end
endmodule

// ========== TOP MODULE (REQUIRED) ==========
module sasic_top (
    input  wire clk,
    input  wire rst_n,
    input  wire in_0,  input  wire in_1,  ...,  input  wire in_39,
    output wire out_0, output wire out_1, ..., output wire out_39,
    output wire oeb_0, output wire oeb_1, ..., output wire oeb_39
);

    // ========== INSTANTIATE YOUR DESIGN ==========
    my_logic u_logic (
        .clk(clk),
        .rst_n(rst_n),
        .data_in({in_7, in_6, in_5, in_4, in_3, in_2, in_1, in_0}),
        .data_out({out_7, out_6, out_5, out_4, out_3, out_2, out_1, out_0})
    );

    // ========== CONFIGURE OUTPUT ENABLES ==========
    // Set oeb LOW for outputs, HIGH for inputs
    // This example: pins 0-7 are outputs, rest are inputs
    assign {oeb_39, oeb_38, oeb_37, oeb_36, oeb_35, oeb_34, oeb_33, oeb_32,
            oeb_31, oeb_30, oeb_29, oeb_28, oeb_27, oeb_26, oeb_25, oeb_24,
            oeb_23, oeb_22, oeb_21, oeb_20, oeb_19, oeb_18, oeb_17, oeb_16,
            oeb_15, oeb_14, oeb_13, oeb_12, oeb_11, oeb_10, oeb_9,  oeb_8,
            oeb_7,  oeb_6,  oeb_5,  oeb_4,  oeb_3,  oeb_2,  oeb_1,  oeb_0}
        = 40'hFFFFFF00;  // Lower 8 bits = outputs (oeb=0), rest = inputs (oeb=1)

    // ========== TIE UNUSED OUTPUTS ==========
    assign {out_39, out_38, out_37, out_36, out_35, out_34, out_33, out_32,
            out_31, out_30, out_29, out_28, out_27, out_26, out_25, out_24,
            out_23, out_22, out_21, out_20, out_19, out_18, out_17, out_16,
            out_15, out_14, out_13, out_12, out_11, out_10, out_9,  out_8}
        = 32'b0;

endmodule

`default_nettype wire
```

### 2.4 Design Guidelines

#### Do's ✅

- **Use behavioral arithmetic**: `+`, `-`, `*` operators map well to fabric cells
- **Use explicit flip-flops**: The fabric has DFBBP cells with set/reset
- **Keep utilization < 70%**: Target 50-70% for good routability
- **Pipeline long paths**: Break combinational chains with registers
- **Use clock and reset**: All flip-flops should use `clk` and `rst_n`

#### Don'ts ❌

- **Don't change port names**: Must match `sasic_top` interface exactly
- **Don't use latches**: Only D flip-flops are available
- **Don't exceed capacity**: Maximum ~70,000 functional cells
- **Don't use complex memory**: No block RAM in fabric (use registers)
- **Don't use analog cells**: Digital fabric only

#### Coding Style

```verilog
// ✅ GOOD: Behavioral arithmetic
assign sum = a + b;
assign diff = a - b;

// ✅ GOOD: Explicit flip-flop
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        count <= 8'b0;
    else if (enable)
        count <= count + 1;
end

// ❌ BAD: Latch inference
always @(*) begin
    if (enable)
        q <= d;  // Latch! Not supported
end

// ❌ BAD: Complex case with don't-cares
always @(*) begin
    case (sel)
        2'b00: y = a;
        2'b01: y = b;
        default: y = 1'bx;  // May infer $lut
    endcase
end
```

### 2.5 Example Designs

#### Example 1: Simple ALU

```verilog
module sasic_top (
    input  wire clk, rst_n,
    input  wire in_0,  ..., input  wire in_39,
    output wire out_0, ..., output wire out_39,
    output wire oeb_0, ..., output wire oeb_39
);

    wire [7:0] a = {in_7, in_6, in_5, in_4, in_3, in_2, in_1, in_0};
    wire [7:0] b = {in_15, in_14, in_13, in_12, in_11, in_10, in_9, in_8};
    wire [2:0] op = {in_18, in_17, in_16};

    reg [7:0] result;
    reg       carry;

    always @(*) begin
        case (op)
            3'b000: {carry, result} = a + b;      // ADD
            3'b001: {carry, result} = a - b;      // SUB
            3'b010: result = a & b;               // AND
            3'b011: result = a | b;               // OR
            3'b100: result = a ^ b;               // XOR
            3'b101: result = ~a;                  // NOT
            default: result = 8'b0;
        endcase
    end

    assign {out_7, out_6, out_5, out_4, out_3, out_2, out_1, out_0} = result;
    assign out_8 = carry;

    // Configure I/O
    assign {oeb_39, ..., oeb_0} = 40'hFFFFFE00;  // out_0-8 are outputs
    assign {out_39, ..., out_9} = 31'b0;

endmodule
```

#### Example 2: Counter with Parallel Load

```verilog
module sasic_top (
    input  wire clk, rst_n,
    input  wire in_0,  ..., input  wire in_39,
    output wire out_0, ..., output wire out_39,
    output wire oeb_0, ..., output wire oeb_39
);

    wire [15:0] load_data = {in_15, ..., in_0};
    wire        load_en   = in_16;
    wire        count_en  = in_17;

    reg [15:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            counter <= 16'b0;
        else if (load_en)
            counter <= load_data;
        else if (count_en)
            counter <= counter + 1;
    end

    assign {out_15, ..., out_0} = counter;

    assign {oeb_39, ..., oeb_0} = 40'hFFFF0000;  // out_0-15 are outputs
    assign {out_39, ..., out_16} = 24'b0;

endmodule
```

---

## Phase 3: Synthesis & Technology Mapping

### 3.1 Synthesis Overview

The synthesis phase:
1. Reads your Verilog design
2. Elaborates the hierarchy
3. Optimizes logic
4. Maps to fabric cells using technology mapping rules
5. Outputs a JSON netlist

### 3.2 Running Synthesis

#### Basic Command

```bash
python3 tools/synth.py \
    --design designs/your_design.v \
    --top sasic_top \
    --liberty structured/fabric/fabric.lib \
    --techmap structured/tech/techmap_2.v \
    --fabric structured/fabric/fabric.yaml \
    --output your_design
```

#### Full Command with Options

```bash
python3 tools/synth.py \
    --design designs/your_design.v \
    --top sasic_top \
    --liberty structured/fabric/fabric.lib \
    --techmap structured/tech/techmap_2.v \
    --fabric structured/fabric/fabric.yaml \
    --output your_design \
    --dff-liberty structured/tech/sasic.lib \
    --flatten \
    --abc-mode area_basic \
    --clock-period 10.0 \
    --verbose
```

### 3.3 Synthesis Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--design` | Yes | - | Input Verilog file(s) |
| `--top` | Yes | - | Top module name (`sasic_top`) |
| `--liberty` | Yes | - | Fabric library for ABC |
| `--techmap` | Yes | - | Technology mapping rules |
| `--fabric` | Recommended | - | Fabric YAML for capacity check |
| `--output` | No | `<top>` | Output basename |
| `--dff-liberty` | No | `--liberty` | Library for DFF mapping |
| `--flatten` | No | False | Flatten hierarchy |
| `--abc-mode` | No | `gate_default` | ABC optimization mode |
| `--clock-period` | No | - | Clock period in ns |
| `--delay` | No | 7500 | ABC delay in ps |
| `--verbose` | No | False | Enable verbose output |

### 3.4 ABC Optimization Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `gate_default` | No script, let ABC decide | General purpose |
| `area_basic` | Area optimization | High utilization designs |
| `area_min` | Aggressive area minimization | Maximum density |

### 3.5 Technology Mapping

The `techmap_2.v` file defines how high-level operations map to fabric cells:

#### Arithmetic Mapping (from `tech/techmap_2.v`)

```
Half Adder (HA):
  A ⊕ B (XOR)  → sky130_fd_sc_hd__ha_2.SUM
  A · B (AND)  → sky130_fd_sc_hd__ha_2.COUT

Full Adder (FA):
  2× HA + 1× OR2
  - HA1: sum1 = A ⊕ B, c1 = A · B
  - HA2: sum = sum1 ⊕ Cin, c2 = sum1 · Cin
  - OR2: Cout = c1 | c2

Adder Chain:
  - LSB: Half Adder (no carry in)
  - MSBs: Full Adders (ripple carry)

Subtraction:
  - A - B = A + (~B) + 1
  - Uses FA chain with inverted B
```

### 3.6 Output Files

After synthesis, you'll get:

```
your_design.json              # Mapped netlist (JSON format)
your_design.log               # Synthesis log
techmap_whitelist.v           # Filtered techmap rules
```

### 3.7 Checking the Output

#### Verify Netlist Format

```bash
python3 -c "
import json
with open('your_design.json') as f:
    data = json.load(f)
    print('Creator:', data['creator'])
    print('Modules:', list(data['modules'].keys()))
    module = data['modules']['sasic_top']
    print('Number of cells:', len(module['cells']))
    print('Number of ports:', len(module['ports']))
"
```

#### Check Utilization

The synthesis tool reports utilization:

```
Fabric capacity:  100000 site-widths
Design area:      45000 site-widths (45.0% utilization)
```

**Target: 50-70% utilization** for good routability

### 3.8 Common Synthesis Issues

#### Issue: Port Name Mismatch

```
ERROR: Port 'in_0' not found in module 'sasic_top'
```

**Solution:** Ensure your module has all 122 ports with exact names.

#### Issue: Unmapped Cells

```
ERROR: $lut cells remain after technology mapping
```

**Solution:**
- Avoid `case` statements with `x` or `z`
- Use explicit logic equations
- Add `--flatten` flag

#### Issue: High Utilization

```
WARNING: Design exceeds 80% utilization
```

**Solution:**
- Use `--abc-mode area_min`
- Simplify logic
- Add pipeline stages to reduce combinational cells

#### Issue: Latch Inference

```
WARNING: Inferred latch for signal 'q'
```

**Solution:**
- Always assign in `always @(posedge clk)` blocks
- Provide default assignments in all branches
- Use `(* latch_free *)` attribute

---

## Phase 4: Placement

### 4.1 Placement Overview

The placement phase:
1. Reads the mapped netlist (JSON)
2. Reads fabric cell positions (YAML)
3. Solves Quadratic Assignment Problem (QAP)
4. Assigns each netlist cell to a fabric cell
5. Outputs placement in DEF format

### 4.2 Running Placement

#### Basic Command

```bash
python3 tools/place.py \
    --netlist your_design.json \
    --fabric-cells structured/fabric/fabric_cells.yaml \
    --pins structured/fabric/pins.yaml \
    --output your_design.def
```

#### Full Command with Options

```bash
python3 tools/place.py \
    --netlist your_design.json \
    --fabric-cells structured/fabric/fabric_cells.yaml \
    --pins structured/fabric/pins.yaml \
    --output your_design.def \
    --verbose \
    --seed 42
```

### 4.3 Placement Algorithm

The placer uses a two-phase approach:

#### Phase 1: Initial Assignment (Hungarian Algorithm)

- Solves linear assignment problem
- Minimizes total connection distance
- Optimal for linear approximation
- Time: O(n³) where n = number of cells

#### Phase 2: Refinement (Simulated Annealing)

- Iteratively swaps cell assignments
- Accepts bad moves with decreasing probability
- Optimizes actual wirelength
- Temperature schedule: 1000 → 0.1

### 4.4 Placement Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `--netlist` | Yes | Mapped netlist (JSON) |
| `--fabric-cells` | Yes | Fabric cell positions (YAML) |
| `--pins` | Yes | I/O pin positions (YAML) |
| `--output` | Yes | Output DEF file |
| `--seed` | No | Random seed for reproducibility |
| `--verbose` | No | Enable verbose output |

### 4.5 Output Files

```
your_design.def          # Placement in DEF format
placement_stats.txt      # Wirelength and statistics
```

### 4.6 Understanding DEF Output

The DEF file contains:

```def
DESIGN sasic_top ;
UNITS DISTANCE MICRONS 1000 ;

DIEAREA ( 0 0 ) ( 1003600 989200 ) ;

COMPONENTS 45000 ;
 - cell_123 sky130_fd_sc_hd__nand2_2 + PLACED ( 5500 5000 ) N ;
 - cell_124 sky130_fd_sc_hd__dfbbp_1 + PLACED ( 9866400 9814800 ) FS ;
 ...
END COMPONENTS

PINS 122 ;
 - clk + NET clk + DIRECTION INPUT + PLACED ( 501630 0 ) met2 ;
 - in_0 + NET in_0 + DIRECTION INPUT + PLACED ( 4830 0 ) met2 ;
 ...
END PINS
END DESIGN
```

### 4.7 Placement Quality Metrics

The placer reports:

```
Initial wirelength:  1250000 µm
Final wirelength:    875000 µm
Improvement:         30.0%

Average cell distance: 15.2 µm
Maximum cell distance: 125.7 µm
```

**Good placement indicators:**
- Wirelength reduction > 20%
- Average distance < 20 µm
- No cells at maximum distance

---

## Phase 5: Verification & Export

### 5.1 Pin Overlap Check

Verify pins don't overlap with cells:

```bash
python3 tools/check_pin_overlap.py \
    --def your_design.def \
    --pins structured/fabric/pins.yaml
```

**Expected output:**
```
Checking 122 pins for overlaps...
✓ No overlaps detected
```

### 5.2 Track Alignment Check

Verify pins are on routing tracks:

```bash
python3 tools/check_pin_tracks.py \
    --def your_design.def \
    --techlef structured/tech/sky130_fd_sc_hd.tlef
```

**Expected output:**
```
Checking pin track alignment...
✓ All 122 pins aligned to routing tracks
  - met2 pins: 0.46 µm grid
  - met3 pins: 0.68 µm grid
```

### 5.3 Pin Spacing Check

Verify minimum pin spacing:

```bash
python3 tools/test_pin_spacings.py \
    --pins structured/fabric/pins.yaml
```

### 5.4 Placement Visualization

Generate a visual representation:

```bash
python3 tools/visualize_placement.py \
    --def your_design.def \
    --fabric structured/fabric/fabric.yaml \
    --output placement.png \
    --show-pins \
    --show-density
```

**Output:**
- `placement.png` - Visual representation of placement
- Color-coded by cell type
- Shows I/O pins
- Density heatmap overlay

### 5.5 Export to GDS (Optional)

If you have OpenROAD or similar tools:

```bash
# Convert DEF to GDS using your preferred tool
# Example with KLayout:
klayout -zz -r def_to_gds.rb your_design.def -o your_design.gds
```

---

## Complete Flow Example

### Example: 8-bit Processor Design

#### Step 1: Create Design

`designs/simple_cpu.v`:

```verilog
`default_nettype none

module simple_cpu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  instruction,
    input  wire [7:0]  data_in,
    output reg  [7:0]  data_out,
    output reg  [7:0]  pc,
    output wire        halt
);

    // Simple 8-bit CPU with 4 instructions
    // 00: NOP
    // 01: LOAD data_in
    // 10: ADD data_in
    // 11: HALT

    reg [7:0] accumulator;
    reg       halted;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= 8'b0;
            pc <= 8'b0;
            halted <= 1'b0;
            data_out <= 8'b0;
        end else if (!halted) begin
            case (instruction[7:6])
                2'b00: begin  // NOP
                    pc <= pc + 1;
                end
                2'b01: begin  // LOAD
                    accumulator <= data_in;
                    pc <= pc + 1;
                end
                2'b10: begin  // ADD
                    accumulator <= accumulator + data_in;
                    pc <= pc + 1;
                end
                2'b11: begin  // HALT
                    halted <= 1'b1;
                end
            endcase
            data_out <= accumulator;
        end
    end

    assign halt = halted;

endmodule

module sasic_top (
    input  wire clk, rst_n,
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

    // Wire inputs
    wire [7:0] instruction = {in_7, in_6, in_5, in_4, in_3, in_2, in_1, in_0};
    wire [7:0] data_in     = {in_15, in_14, in_13, in_12, in_11, in_10, in_9, in_8};

    // Wire outputs
    wire [7:0] data_out;
    wire [7:0] pc;
    wire       halt;

    // Instantiate CPU
    simple_cpu u_cpu (
        .clk(clk),
        .rst_n(rst_n),
        .instruction(instruction),
        .data_in(data_in),
        .data_out(data_out),
        .pc(pc),
        .halt(halt)
    );

    // Assign outputs
    assign {out_7, out_6, out_5, out_4, out_3, out_2, out_1, out_0} = data_out;
    assign {out_15, out_14, out_13, out_12, out_11, out_10, out_9, out_8} = pc;
    assign out_16 = halt;

    // Configure output enables
    assign {oeb_39, oeb_38, oeb_37, oeb_36, oeb_35, oeb_34, oeb_33, oeb_32,
            oeb_31, oeb_30, oeb_29, oeb_28, oeb_27, oeb_26, oeb_25, oeb_24,
            oeb_23, oeb_22, oeb_21, oeb_20, oeb_19, oeb_18, oeb_17, oeb_16,
            oeb_15, oeb_14, oeb_13, oeb_12, oeb_11, oeb_10, oeb_9,  oeb_8,
            oeb_7,  oeb_6,  oeb_5,  oeb_4,  oeb_3,  oeb_2,  oeb_1,  oeb_0}
        = 40'hFFFF0000;  // out_0-15 are outputs, rest are inputs

    // Tie unused outputs
    assign {out_39, out_38, out_37, out_36, out_35, out_34, out_33, out_32,
            out_31, out_30, out_29, out_28, out_27, out_26, out_25, out_24,
            out_23, out_22, out_21, out_20, out_19, out_18, out_17}
        = 23'b0;

endmodule

`default_nettype wire
```

#### Step 2: Synthesize

```bash
python3 tools/synth.py \
    --design designs/simple_cpu.v \
    --top sasic_top \
    --liberty structured/fabric/fabric.lib \
    --techmap structured/tech/techmap_2.v \
    --fabric structured/fabric/fabric.yaml \
    --output simple_cpu \
    --flatten \
    --abc-mode area_basic \
    --clock-period 10.0 \
    --verbose
```

**Expected output:**
```
Synthesizing sasic_top...
Flattening hierarchy...
Running ABC...
Mapping to fabric cells...

Fabric capacity:  100000 site-widths
Design area:      1250 site-widths (1.25% utilization)

Output: simple_cpu.json
```

#### Step 3: Place

```bash
python3 tools/place.py \
    --netlist simple_cpu.json \
    --fabric-cells structured/fabric/fabric_cells.yaml \
    --pins structured/fabric/pins.yaml \
    --output simple_cpu.def \
    --verbose
```

**Expected output:**
```
Loading netlist: 45 cells
Loading fabric: 3240 tiles, 220000 cells
Running placement...

Phase 1: Initial assignment (Hungarian algorithm)
  Initial wirelength: 15420 µm

Phase 2: Refinement (Simulated annealing)
  Final wirelength: 8750 µm
  Improvement: 43.3%

Output: simple_cpu.def
```

#### Step 4: Verify

```bash
# Check pin overlaps
python3 tools/check_pin_overlap.py \
    --def simple_cpu.def \
    --pins structured/fabric/pins.yaml

# Check track alignment
python3 tools/check_pin_tracks.py \
    --def simple_cpu.def \
    --techlef structured/tech/sky130_fd_sc_hd.tlef

# Visualize
python3 tools/visualize_placement.py \
    --def simple_cpu.def \
    --fabric structured/fabric/fabric.yaml \
    --output simple_cpu_placement.png
```

**Expected output:**
```
✓ No pin overlaps detected
✓ All pins aligned to routing tracks
✓ Visualization saved to simple_cpu_placement.png
```

---

## Troubleshooting

### Synthesis Issues

#### Problem: "Module 'sasic_top' not found"

**Cause:** Top module name mismatch

**Solution:**
```verilog
// Make sure your module is named exactly:
module sasic_top (...);
```

#### Problem: "Port count mismatch"

**Cause:** Missing or extra ports

**Solution:** Count your ports - must be exactly 122:
- 1 clk
- 1 rst_n
- 40 in_*
- 40 out_*
- 40 oeb_*

#### Problem: "Design exceeds fabric capacity"

**Cause:** Design too large

**Solution:**
1. Use `--abc-mode area_min`
2. Simplify logic
3. Reduce state bits
4. Add `--flatten` to remove hierarchy overhead

#### Problem: "$lut cells remain after mapping"

**Cause:** Complex logic not mappable

**Solution:**
```verilog
// Instead of:
case (sel)
    2'b00: y = a;
    2'b01: y = b;
    default: y = 1'bx;  // ❌ Don't use x
endcase

// Use:
case (sel)
    2'b00: y = a;
    2'b01: y = b;
    default: y = 1'b0;  // ✅ Use definite value
endcase
```

### Placement Issues

#### Problem: "No compatible cell found"

**Cause:** Netlist cell type not in fabric

**Solution:**
1. Check `fabric.lib` for available cells
2. Verify techmap rules in `techmap_2.v`
3. Use `--flatten` during synthesis

#### Problem: "High wirelength warning"

**Cause:** Poor placement quality

**Solution:**
1. Reduce design size
2. Use different random seed: `--seed 12345`
3. Check for high-fanout nets
4. Add pipeline registers

#### Problem: "Pin overlap detected"

**Cause:** Placement conflict

**Solution:**
1. Check fabric margin settings
2. Verify die area in pins.yaml
3. Reduce design utilization

### Verification Issues

#### Problem: "Pin not on track"

**Cause:** Pin coordinate misalignment

**Solution:**
1. Regenerate pins.yaml with correct tech LEF
2. Check met2/met3 track parameters
3. Verify database units

#### Problem: "Pin spacing violation"

**Cause:** Pins too close together

**Solution:**
1. Increase `--pin-spacing-tracks` in gen_pins_yaml.py
2. Check corner keepout settings
3. Verify track pitch from tech LEF

---

## Reference

### File Locations

```
sasic/
├── designs/                    # Your Verilog sources
│   ├── arith.v                # Example: arithmetic design
│   ├── 6502.v                 # Example: 6502 CPU
│   ├── z80.v                  # Example: Z80 CPU
│   └── soc.v                  # Example: SoC design
│
├── structured/                 # Structured ASIC files
│   ├── fabric/                # Fabric definition
│   │   ├── fabric.yaml        # Tile architecture
│   │   ├── fabric.lib         # Cell library
│   │   ├── pins.yaml          # I/O pin placement
│   │   └── fabric_cells.yaml  # All cell instances
│   │
│   ├── tech/                  # Technology files
│   │   ├── techmap_2.v        # Tech mapping rules
│   │   ├── sasic.lib          # Full timing library
│   │   ├── sky130_fd_sc_hd.lef
│   │   └── sky130_fd_sc_hd.tlef
│   │
│   └── designs/               # Synthesized designs
│       ├── arith_mapped.json
│       ├── 6502_mapped.json
│       ├── z80_mapped.json
│       └── soc_mapped.json
│
└── tools/                      # Python tools
    ├── synth.py               # Synthesis wrapper
    ├── place.py               # Placement engine
    ├── gen_fabric_cells_by_tile.py
    ├── gen_pins_yaml.py
    ├── check_pin_overlap.py
    ├── check_pin_tracks.py
    ├── visualize_placement.py
    └── draw-fp.py
```

### Quick Reference Commands

```bash
# Generate fabric files (one-time setup)
python3 tools/gen_fabric_cells_by_tile.py \
    --fabric structured/fabric/fabric.yaml \
    --out structured/fabric/fabric_cells.yaml

python3 tools/gen_pins_yaml.py \
    --fabric structured/fabric/fabric.yaml \
    --techlef structured/tech/sky130_fd_sc_hd.tlef \
    --out structured/fabric/pins.yaml

# Synthesize design
python3 tools/synth.py \
    --design designs/your_design.v \
    --top sasic_top \
    --liberty structured/fabric/fabric.lib \
    --techmap structured/tech/techmap_2.v \
    --fabric structured/fabric/fabric.yaml \
    --output your_design \
    --flatten \
    --verbose

# Place design
python3 tools/place.py \
    --netlist your_design.json \
    --fabric-cells structured/fabric/fabric_cells.yaml \
    --pins structured/fabric/pins.yaml \
    --output your_design.def \
    --verbose

# Verify
python3 tools/check_pin_overlap.py \
    --def your_design.def \
    --pins structured/fabric/pins.yaml

python3 tools/visualize_placement.py \
    --def your_design.def \
    --fabric structured/fabric/fabric.yaml \
    --output placement.png
```

### Fabric Specifications

| Parameter | Value |
|-----------|-------|
| Technology | SkyWater 130nm HD |
| Die Size | 1003.6µm × 989.2µm |
| Core Size | 993.6µm × 979.2µm |
| Tile Grid | 36 × 90 = 3,240 tiles |
| Tile Size | 27.6µm × 10.88µm |
| Site Size | 0.46µm × 2.72µm |
| Total Cells | ~220,000 |
| Functional Cells | ~100,000 |
| I/O Pins | 122 (40 tri-state groups + clk + rst_n) |
| Routing Layers | met2 (vertical), met3 (horizontal) |
| Maximum Design Size | ~70,000 cells (70% utilization) |
| Target Frequency | 50-200 MHz |

---

## Appendix: Tool Reference

### synth.py

**Purpose:** Yosys synthesis wrapper with techmap filtering

**Usage:**
```bash
python3 synth.py [OPTIONS]
```

**Key Options:**
- `--design`: Input Verilog file(s)
- `--top`: Top module name
- `--liberty`: Liberty library for ABC
- `--techmap`: Technology mapping file
- `--fabric`: Fabric YAML for capacity check
- `--output`: Output basename
- `--flatten`: Flatten hierarchy
- `--abc-mode`: ABC optimization mode
- `--clock-period`: Clock period in ns

### place.py

**Purpose:** Quadratic assignment problem solver for placement

**Usage:**
```bash
python3 place.py [OPTIONS]
```

**Key Options:**
- `--netlist`: Mapped netlist (JSON)
- `--fabric-cells`: Fabric cell positions (YAML)
- `--pins`: I/O pin positions (YAML)
- `--output`: Output DEF file
- `--seed`: Random seed
- `--verbose`: Verbose output

### gen_fabric_cells_by_tile.py

**Purpose:** Generate cell instances from fabric definition

**Usage:**
```bash
python3 gen_fabric_cells_by_tile.py \
    --fabric fabric.yaml \
    --out fabric_cells.yaml \
    --die-margin-um 5.0
```

### gen_pins_yaml.py

**Purpose:** Generate I/O pin placement

**Usage:**
```bash
python3 gen_pins_yaml.py \
    --fabric fabric.yaml \
    --techlef sky130_fd_sc_hd.tlef \
    --out pins.yaml \
    --die-margin-um 5.0 \
    --corner-keepout-um 5.0 \
    --pin-spacing-tracks 1
```

---

**Document Version:** 1.0
**Last Updated:** 2026-03-21
**Compatible with:** SASIC v7.2, SkyWater 130nm HD PDK
