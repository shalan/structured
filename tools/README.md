# SASIC Tools

Tool suite for the Sky130 Structured ASIC flow: synthesis, placement, pin generation, visualization, and validation.

## Flow Overview

```
fabric.yaml ─┬─► gen_fabric_cells_by_tile.py ──► fabric_cells.yaml ──┐
             ├─► gen_pins_yaml.py ──────────────► pins.yaml ─────────┤
             └─► draw-tile.py ──────────────────► tile.png           │
                                                                     │
design.v ────► synth.py ──► mapped.json ──► place.py ──► placement.yaml
                                                │
                                                ├──► visualize_placement.py
                                                └──► placement.def
```

## Core Tools

### synth.py — Yosys Synthesis Wrapper

Maps RTL to the fabric cell library using Yosys + ABC, then checks resource capacity.

```bash
python3 tools/synth.py \
  -d designs/src/arith.v \
  -t sasic_top \
  -l fabric/fabric_11x66.lib \
  -m tech/techmap_2.v \
  --fabric fabric/fabric_11x66.yaml \
  -o designs/synth/arith_11x66 \
  --flatten -v

# SystemVerilog designs
python3 tools/synth.py -d designs/src/tt_warp.sv ... --sv
```

**Key flags:**
| Flag | Description |
|------|-------------|
| `-d/--design` | Input Verilog/SV file(s) |
| `-t/--top` | Top module name |
| `-l/--liberty` | Fabric liberty file for ABC |
| `-m/--techmap` | Yosys techmap file |
| `--fabric` | Fabric YAML (for capacity checking) |
| `-o/--output` | Output base path |
| `--flatten` | Flatten hierarchy before synthesis |
| `--sv` | Enable SystemVerilog parsing |
| `--abc-mode` | `gate_default`, `area_basic`, `area_min` |
| `-D/--delay` | Target delay in ps |

**Outputs:** `{output}_mapped.json`, `{output}_mapped.v`, `{output}_mapped.blif`

**Exit codes:** 0 = success, 2 = capacity overflow, 3 = $lut detected (ABC failure)

---

### synthesize_all.sh — Batch Synthesis

Auto-discovers all `.v` and `.sv` designs in `designs/src/` and synthesizes each.

```bash
# Default fabric
./tools/synthesize_all.sh fabric_11x66

# NAND2-only fabric
./tools/synthesize_all.sh nand2_11x66
```

Per-design flags (e.g., `--sv` for SystemVerilog) are configured via the `DESIGN_FLAGS` associative array at the top of the script.

---

### place.py — Cell Placement (Greedy + Simulated Annealing)

Assigns synthesized netlist cells to pre-placed fabric cell positions, minimizing HPWL wirelength.

```bash
python3 tools/place.py \
  --netlist designs/synth/arith_11x66_mapped.json \
  --fabric-cells output/fabric_cells.yaml \
  --fabric-yaml fabric/fabric_11x66.yaml \
  --pins output/pins.yaml \
  --out-yaml output/arith/placement.yaml
```

**Algorithm:** Greedy initial assignment (I/O-connected cells first, then by connectivity), refined by Simulated Annealing with cell-cell and cell-empty swaps.

**Key flags:**
| Flag | Description |
|------|-------------|
| `--fabric-yaml` | Fabric definition YAML (for cell type resolution) |
| `--sa-iterations` | SA iterations (default: 10000) |
| `--tile-radius` | Swap radius in tiles (default: 3) |

---

### gen_pins_yaml.py — Pin Placement Generator

Generates die-edge pin positions snapped to met2/met3 routing tracks.

```bash
python3 tools/gen_pins_yaml.py \
  --fabric fabric/fabric_11x66.yaml \
  --out output/pins.yaml \
  --out-def output/pins.def \
  --techlef tech/sky130_fd_sc_hd.tlef
```

---

### gen_fabric_cells_by_tile.py — Fabric Cell Position Generator

Converts the fabric tile definition into die-absolute cell positions.

```bash
python3 tools/gen_fabric_cells_by_tile.py \
  --fabric fabric/fabric_11x66.yaml \
  --out output/fabric_cells.yaml \
  --die-margin-um 5.0
```

---

## Visualization Tools

### draw-tile.py — Tile Layout Visualization

Renders a single tile from the fabric YAML as a color-coded PNG.

```bash
python3 tools/draw-tile.py fabric/fabric_11x66.yaml -o docs/tile_11x66.png
```

### draw-fp.py — Interactive Floorplan Viewer

Interactive viewer for pin placement with zoom/pan (mouse scroll, drag). Keyboard: `r` reset, `h` help, `q` quit.

```bash
python3 tools/draw-fp.py output/pins.yaml -o docs/floorplan.png
```

### visualize_placement.py — Placement Visualization

Shows placed cells on the fabric grid, color-coded by type.

```bash
python3 tools/visualize_placement.py \
  --placement output/arith/placement.yaml \
  --pins output/pins.yaml \
  --fabric fabric/fabric_11x66.yaml \
  --output docs/arith_placed.png
```

---

## Validation Tools

### check_pin_tracks.py — Pin Track Alignment Check

Verifies all pins are aligned with routing tracks. Supports tech LEF or manual track values.

```bash
# Using Sky130 defaults
python3 tools/check_pin_tracks.py output/pins.yaml

# Using tech LEF
python3 tools/check_pin_tracks.py output/pins.yaml --techlef tech/sky130_fd_sc_hd.tlef

# Manual track values
python3 tools/check_pin_tracks.py output/pins.yaml --met2-start 0.23 --met2-step 0.46
```

### check_pin_overlap.py — Pin Overlap Detection

Detects coordinate collisions in pin placement. Distinguishes intentional triads (in/out/oeb groups) from errors.

```bash
python3 tools/check_pin_overlap.py output/pins.yaml
```

---

## Reporting Tools

### resource_report.py — Fabric Resource Report

Analyzes synthesized designs against fabric capacity. Loads all data from the fabric YAML.

```bash
# Report for a specific fabric
python3 tools/resource_report.py \
  --fabric fabric/fabric_11x66.yaml \
  --designs designs/synth/ \
  --suffix nand2_11x66

# Report for all designs (no suffix filter)
python3 tools/resource_report.py --fabric fabric/fabric_11x66.yaml
```

