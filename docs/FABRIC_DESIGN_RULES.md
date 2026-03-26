# Fabric Design Rules and Creation Guidelines

**Document Version:** 1.0
**Date:** 2026-03-21
**Fabric Version:** 7.2 (Physically Corrected)

---

## Executive Summary

This document extracts the **mandatory design rules** for creating new structured ASIC fabrics using the SkyWater 130nm HD process. Understanding these rules is critical for:

1. **Modifying existing fabrics** to better match design requirements
2. **Creating new fabrics** with different cell compositions
3. **Ensuring DRC compliance** with Sky130 physical design rules

---

## Critical Constraints

### 🔒 **FIXED - Cannot Be Changed**

These elements are **mandatory** and cannot be altered due to physical design rules:

| Element | Constraint | Reason |
|---------|------------|--------|
| **TAP cells** | 2 per row (x=0 and x=30) | Latch-up prevention (Sky130 DRC) |
| **TAP spacing** | ≤ 30 sites (13.8 µm) | Maximum well tap distance rule |
| **Row orientation** | Alternating N/FS | Power rail sharing, abutment |
| **Tile width** | 60 sites (27.6 µm) | Fixed fabric architecture |
| **Tile height** | 4 rows (10.88 µm) | Fixed fabric architecture |

### ✅ **FLEXIBLE - Can Be Modified**

These elements can be **redesigned** to match design requirements:

| Element | Constraint | Notes |
|---------|------------|-------|
| **NAND2 cells** | Any count | Primary logic gate |
| **OR2 cells** | Any count | Secondary logic/arithmetic |
| **INV cells** | Any count | Signal inversion |
| **BUF cells** | Any count | Signal buffering |
| **DFBBP cells** | Any count | Flip-flops (state elements) |
| **DECAP cells** | Fill gaps | Power integrity |
| **CONB cells** | Fill gaps | Tie-high/low generation |
| **FILL cells** | Fill gaps | Density maintenance |

---

## Detailed Design Rules

### Rule 1: TAP Cell Placement (MANDATORY)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  TAP cells are FIXED due to Sky130 design rules - CANNOT BE MODIFIED         ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

**Requirement:**
- **Position 1:** Every row MUST have a TAP cell at x=0 (start of row)
- **Position 2:** Every row MUST have a TAP cell at x=30 (middle of row)
- **Spacing:** Maximum 30 sites between TAP cells

**Cell Type:** `sky130_fd_sc_hd__tapvpwrvgnd_1` (width: 1 site)

**Physical Reason:**
- Well tap connections prevent latch-up in CMOS circuits
- Sky130 design rules specify maximum distance between substrate/well contacts
- 30 sites = 13.8 µm, which satisfies the design rule

**Impact on Fabric:**
```
Per Row:  2 TAP cells (at x=0 and x=30)
Per Tile: 8 TAP cells (2 per row × 4 rows)
Total:    25,920 TAP cells in fabric (8 × 3,240 tiles)
```

**Example (Row 0):**
```
x:  0  1  2  3  4  5  6  7  8  9 10 11 ... 29 30 31 32 33 34 35 ... 59
    T  └────────────────────────────────────┘  T  └────────────────────┘
    ^                                       ^
    TAP at x=0                          TAP at x=30
```

---

### Rule 2: Row Orientation Pattern (MANDATORY)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  Alternating row orientation enables power rail sharing and cell abutment   ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

**Pattern:**
- **Row 0:** N (normal) orientation
- **Row 1:** FS (flip-vertical, mirror-X) orientation
- **Row 2:** N (normal) orientation
- **Row 3:** FS (flip-vertical, mirror-X) orientation

**DEF Orientation Codes:**
- `N` = North (normal, 0° rotation)
- `FS` = Flipped-vertical (South, 180° rotation, also called MX in some tools)

**Physical Reason:**
- Adjacent rows share power rails (VDD and VSS)
- Enables standard cell abutment without gaps
- Reduces overall fabric height
- Improves power distribution

**Visual Representation:**
```
Row 0 (N):  [VDD] ┌─────────────────────┐ [VDD]
                  │  Cells face UP      │
            [VSS] └─────────────────────┘ [VSS]
                         ↓ Shared rail
Row 1 (FS): [VSS] ┌─────────────────────┐ [VSS]
                  │  Cells face DOWN    │
            [VDD] └─────────────────────┘ [VDD]
                         ↓ Shared rail
Row 2 (N):  [VDD] ┌─────────────────────┐ [VDD]
                  │  Cells face UP      │
            [VSS] └─────────────────────┘ [VSS]
                         ↓ Shared rail
Row 3 (FS): [VSS] ┌─────────────────────┐ [VSS]
                  │  Cells face DOWN    │
            [VDD] └─────────────────────┘ [VDD]
```

---

### Rule 3: Tile Width Constraint (MANDATORY)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  All rows MUST sum to exactly 60 sites - no gaps, no overflow               ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

**Constraint:**
- **Tile width:** 60 sites (fixed)
- **Physical width:** 60 × 0.46 µm = 27.6 µm
- **Requirement:** Sum of all cell widths in a row = 60 sites

**Verification Formula:**
```
For each row:
  Σ (cell_width_i) = 60 sites

where cell_width_i is the width of cell i in sites
```

**Cell Widths (in sites):**
| Cell Type | Width (sites) | Width (µm) |
|-----------|---------------|------------|
| TAP | 1 | 0.46 |
| FILL | 1 | 0.46 |
| DECAP_3 | 3 | 1.38 |
| CONB | 3 | 1.38 |
| INV | 4 | 1.84 |
| DECAP_4 | 4 | 1.84 |
| NAND2 | 5 | 2.30 |
| OR2 | 5 | 2.30 |
| BUF | 6 | 2.76 |
| AND2 | 6 | 2.76 |
| DFBBP | 26 | 11.96 |

**Example Calculation (Row 0):**
```
TAP(1) + NAND(5) + NAND(5) + NAND(5) + INV(4) + BUF(6) + DECAP(4) +
TAP(1) + NAND(5) + NAND(5) + OR(5) + OR(5) + OR(5) + DECAP(4)
= 1+5+5+5+4+6+4+1+5+5+5+5+5+4 = 60 ✓
```

---

### Rule 4: Fill Cell Strategy (FLEXIBLE)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  Fill cells (DECAP, CONB, FILL) fill remaining space after functional cells  ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

**Fill Cell Types (Priority Order):**

| Priority | Cell Type | Width | Purpose | When to Use |
|----------|-----------|-------|---------|-------------|
| **1 (Highest)** | **DECAP_4** | 4 sites | Decoupling capacitor | **ALWAYS preferred** for gaps ≥ 4 |
| **2** | **DECAP_3** | 3 sites | Decoupling capacitor | **ALWAYS preferred** for gaps ≥ 3 |
| **3** | **CONB** | 3 sites | Tie-high/low generator | Only when DECAP not needed |
| **4 (Lowest)** | **FILL** | 1 site | Density maintenance | **ONLY as last resort** |

**⚠️ CRITICAL RULE: DECAP cells have HIGHER priority than FILL cells!**

- **DECAP cells provide decoupling capacitance** which is essential for power integrity
- **FILL cells only maintain density** and should be avoided whenever possible
- **Always use DECAP cells to fill gaps** unless the gap is too small (1 site)

**Placement Strategy:**

1. **Start with functional cells** (NAND, OR, INV, BUF, DFBBP)
2. **Calculate remaining space:** `gap = 60 - Σ(functional_cell_widths) - 2` (for TAPs)
3. **Fill gaps with DECAP cells FIRST (MANDATORY PRIORITY):**
   - Gap ≥ 4 → Use DECAP_4 (REQUIRED - do not use FILL)
   - Gap = 3 → Use DECAP_3 (REQUIRED - do not use FILL)
   - Gap = 2 → Use DECAP_3 + FILL (DECAP prioritized even if overfills slightly)
   - Gap = 1 → Use FILL (only case where FILL is acceptable)

**Key Rule:** **DECAP cells are MANDATORY for power integrity.** DECAP cells provide decoupling capacitance which improves power supply stability and reduces noise. FILL cells only maintain density and should **ONLY be used when DECAP doesn't fit** (gap = 1 site).

**Example:**
```
Functional cells use: 50 sites
TAP cells use: 2 sites
Remaining gap: 60 - 50 - 2 = 8 sites

Fill options (in priority order):
  ✓ REQUIRED: DECAP_4 + DECAP_4 (4+4=8) - Maximum decoupling
  ✓ ACCEPTABLE: DECAP_4 + DECAP_3 + FILL (4+3+1=8) - High decoupling
  ✗ AVOID: DECAP_3 + DECAP_3 + FILL + FILL (3+3+1+1=8) - Less decoupling
  ✗ PROHIBITED: FILL × 8 (1×8=8) - No decoupling, violates DECAP priority rule
```

---

### Rule 5: Functional Cell Placement (FLEXIBLE)

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  Functional cells can be placed freely within row, avoiding TAP positions   ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

**Constraints:**
- Cannot place functional cells at x=0 (TAP position)
- Cannot place functional cells at x=30 (TAP position)
- Must fit within 60-site width

**Available Space Per Row:**
```
Total width:     60 sites
TAP cells:       2 sites (at x=0 and x=30)
Available:       58 sites for functional + fill cells
```

**Two Regions Per Row:**
```
Region 1: x=1 to x=29  (29 sites)
Region 2: x=31 to x=59 (29 sites)
Total available: 58 sites
```

**Placement Guidelines:**

1. **Distribute cells evenly** across both regions
2. **Group related cells** (e.g., keep arithmetic cells together)
3. **Consider routing** - avoid creating routing congestion
4. **Respect cell widths** - don't split multi-site cells across regions

---

## Fabric Creation Workflow

### Step 1: Define Design Requirements

Analyze your target designs to determine cell ratios:

```bash
python3 tools/cell_usage_analysis.py
```

Example output:
```
Required cell ratios:
  NAND2:  57% of functional cells
  OR2:    24% of functional cells
  INV:     8% of functional cells
  DFBBP:   7% of functional cells
  BUF:     4% of functional cells
```

### Step 2: Calculate Cells Per Tile

**Total functional cells per tile:** Target based on utilization

```
Example: 40 functional cells per tile
  NAND2:  40 × 0.57 = 23 cells
  OR2:    40 × 0.24 = 10 cells
  INV:    40 × 0.08 = 3 cells
  DFBBP:  40 × 0.07 = 3 cells
  BUF:    40 × 0.04 = 2 cells
```

### Step 3: Distribute Cells Across Rows

**Available space per tile:** 58 sites × 4 rows = 232 sites

**Cell width calculation:**
```
NAND2:  23 × 5 = 115 sites
OR2:    10 × 5 = 50 sites
INV:     3 × 4 = 12 sites
DFBBP:   3 × 26 = 78 sites
BUF:     2 × 6 = 12 sites
Total:  267 sites
```

**Problem:** 267 sites > 232 sites available!

**Solution:** Reduce cell count or use larger tile

### Step 4: Adjust and Iterate

Option 1: **Reduce cell count**
```
Target: 35 functional cells per tile
  NAND2:  35 × 0.57 = 20 cells (100 sites)
  OR2:    35 × 0.24 = 8 cells  (40 sites)
  INV:    35 × 0.08 = 3 cells  (12 sites)
  DFBBP:  35 × 0.07 = 2 cells  (52 sites)
  BUF:    35 × 0.04 = 2 cells  (12 sites)
  Total: 216 sites ✓ (fits in 232)
```

Option 2: **Increase tile width** (requires new fabric architecture)
```
New tile width: 70 sites (instead of 60)
Available space: 68 × 4 = 272 sites
```

### Step 5: Assign Cells to Rows

**Strategy:**
- **Rows 0, 2 (N orientation):** Combinational logic (NAND, OR, INV, BUF)
- **Rows 1, 3 (FS orientation):** Sequential logic (NAND + DFBBP)

**Example Distribution:**
```
Row 0 (N):   6× NAND + 4× OR + 2× INV + 1× BUF = 30+20+8+6 = 64 sites ❌
  Adjust:    5× NAND + 3× OR + 2× INV + 1× BUF = 25+15+8+6 = 54 sites ✓
  Fill:      54 + 2(TAP) = 56, Gap = 4 → DECAP_4

Row 1 (FS):  5× NAND + 1× DFBBP = 25+26 = 51 sites ✓
  Fill:      51 + 2(TAP) = 53, Gap = 7 → DECAP_4 + DECAP_3

Row 2 (N):   5× NAND + 5× OR + 1× INV = 25+25+4 = 54 sites ✓
  Fill:      54 + 2(TAP) = 56, Gap = 4 → DECAP_4

Row 3 (FS):  5× NAND + 1× DFBBP = 25+26 = 51 sites ✓
  Fill:      51 + 2(TAP) = 53, Gap = 7 → DECAP_4 + DECAP_3
```

### Step 6: Create fabric.yaml

```yaml
fabric_info:
  technology: "sky130"
  site_dimensions_um: { width: 0.46, height: 2.72 }
  units:
    database_units_per_micron: 1000

fabric_layout:
  tiles_x: 36
  tiles_y: 90

cell_definitions:
  sky130_fd_sc_hd__nand2_2:      { width_sites: 5 }
  sky130_fd_sc_hd__or2_2:        { width_sites: 5 }
  sky130_fd_sc_hd__clkinv_2:     { width_sites: 4 }
  sky130_fd_sc_hd__clkbuf_4:     { width_sites: 6 }
  sky130_fd_sc_hd__dfbbp_1:      { width_sites: 26 }
  sky130_fd_sc_hd__tapvpwrvgnd_1:{ width_sites: 1 }
  sky130_fd_sc_hd__decap_4:      { width_sites: 4 }
  sky130_fd_sc_hd__decap_3:      { width_sites: 3 }
  sky130_fd_sc_hd__conb_1:       { width_sites: 3 }
  sky130_fd_sc_hd__fill_1:       { width_sites: 1 }

tile_definition:
  dimensions_sites: { width: 60, height: 4 }

  cells:
    # Row 0 (N orientation)
    - { template_name: "R0_TAP_0",  cell_type: "sky130_fd_sc_hd__tapvpwrvgnd_1", origin_sites: { x: 0, y: 0 } }
    - { template_name: "R0_NAND_0", cell_type: "sky130_fd_sc_hd__nand2_2", origin_sites: { x: 1, y: 0 } }
    # ... more cells ...
    - { template_name: "R0_DECAP_0",cell_type: "sky130_fd_sc_hd__decap_4", origin_sites: { x: 56, y: 0 } }

    # Row 1 (FS orientation)
    - { template_name: "R1_TAP_0",  cell_type: "sky130_fd_sc_hd__tapvpwrvgnd_1", origin_sites: { x: 0, y: 1 } }
    # ... more cells ...

    # Row 2 (N orientation)
    # Row 3 (FS orientation)
```

### Step 7: Validate Fabric

```bash
# Generate fabric cells
python3 tools/gen_fabric_cells_by_tile.py \
    --fabric fabric.yaml \
    --out fabric_cells.yaml

# Verify width constraints
python3 -c "
import yaml
with open('fabric.yaml') as f:
    fab = yaml.safe_load(f)
widths = {
    'sky130_fd_sc_hd__nand2_2': 5,
    'sky130_fd_sc_hd__or2_2': 5,
    'sky130_fd_sc_hd__clkinv_2': 4,
    'sky130_fd_sc_hd__clkbuf_4': 6,
    'sky130_fd_sc_hd__dfbbp_1': 26,
    'sky130_fd_sc_hd__tapvpwrvgnd_1': 1,
    'sky130_fd_sc_hd__decap_4': 4,
    'sky130_fd_sc_hd__decap_3': 3,
    'sky130_fd_sc_hd__conb_1': 3,
    'sky130_fd_sc_hd__fill_1': 1,
}
for row in range(4):
    cells = [c for c in fab['tile_definition']['cells'] if c['origin_sites']['y'] == row]
    total = sum(widths.get(c['cell_type'], 0) for c in cells)
    print(f'Row {row}: {total} sites', '✓' if total == 60 else '❌')
"
```

---

## Common Mistakes to Avoid

### ❌ Mistake 1: Moving TAP Cells

**Wrong:**
```yaml
- { template_name: "R0_TAP_0", cell_type: "sky130_fd_sc_hd__tapvpwrvgnd_1", origin_sites: { x: 2, y: 0 } }
```

**Correct:**
```yaml
- { template_name: "R0_TAP_0", cell_type: "sky130_fd_sc_hd__tapvpwrvgnd_1", origin_sites: { x: 0, y: 0 } }
```

**Reason:** TAP cells must be at x=0 and x=30 to satisfy Sky130 design rules.

---

### ❌ Mistake 2: Row Width Mismatch

**Wrong:**
```
Row 0: 1+5+5+5+4+6+4+1+5+5+5+5+5 = 56 sites (gap of 4)
```

**Correct:**
```
Row 0: 1+5+5+5+4+6+4+1+5+5+5+5+5+4 = 60 sites (add DECAP_4)
```

**Reason:** All rows must sum to exactly 60 sites.

---

### ❌ Mistake 3: Wrong Orientation Pattern

**Wrong:**
```yaml
# All rows N orientation
Row 0: N
Row 1: N
Row 2: N
Row 3: N
```

**Correct:**
```yaml
# Alternating N/FS
Row 0: N
Row 1: FS
Row 2: N
Row 3: FS
```

**Reason:** Alternating orientation enables power rail sharing.

---

### ❌ Mistake 4: Overlapping Cells

**Wrong:**
```yaml
- { template_name: "R0_NAND_0", cell_type: "sky130_fd_sc_hd__nand2_2", origin_sites: { x: 29, y: 0 } }
- { template_name: "R0_TAP_1",  cell_type: "sky130_fd_sc_hd__tapvpwrvgnd_1", origin_sites: { x: 30, y: 0 } }
```

**Problem:** NAND2 at x=29 ends at x=34, overlaps TAP at x=30

**Correct:**
```yaml
- { template_name: "R0_NAND_0", cell_type: "sky130_fd_sc_hd__nand2_2", origin_sites: { x: 24, y: 0 } }
- { template_name: "R0_TAP_1",  cell_type: "sky130_fd_sc_hd__tapvpwrvgnd_1", origin_sites: { x: 30, y: 0 } }
```

---

### ❌ Mistake 5: Using FILL Instead of DECAP (Priority Violation)

**Wrong:**
```
Row 0: Functional cells = 52 sites, TAPs = 2 sites
Remaining gap: 60 - 52 - 2 = 6 sites
Fill with: FILL × 6 (1×6=6)
```

**Problem:** Violates DECAP priority rule - FILL cells used when DECAP fits

**Correct:**
```
Row 0: Functional cells = 52 sites, TAPs = 2 sites
Remaining gap: 60 - 52 - 2 = 6 sites
Fill with: DECAP_4 + DECAP_3 (4+3=7, slight overfill acceptable) OR
           DECAP_3 + DECAP_3 (3+3=6, perfect fit)
```

**Reason:** DECAP cells provide essential decoupling capacitance for power integrity. FILL cells should ONLY be used for 1-site gaps where DECAP cannot fit.

---

## Quick Reference

### Mandatory Elements (Cannot Change)

| Element | Value | Reason |
|---------|-------|--------|
| TAP positions | x=0, x=30 | Sky130 DRC |
| Row orientations | N, FS, N, FS | Power rail sharing |
| Tile width | 60 sites | Fabric architecture |
| Tile height | 4 rows | Fabric architecture |

### Flexible Elements (Can Change)

| Element | Constraint | Width | Priority |
|---------|------------|-------|----------|
| NAND2 | Any count | 5 sites | - |
| OR2 | Any count | 5 sites | - |
| INV | Any count | 4 sites | - |
| BUF | Any count | 6 sites | - |
| DFBBP | Any count | 26 sites | - |
| **DECAP_4** | Fill gaps | 4 sites | **1 (HIGHEST - MANDATORY)** |
| **DECAP_3** | Fill gaps | 3 sites | **2 (HIGH - MANDATORY)** |
| CONB | Fill gaps | 3 sites | 3 (Medium) |
| FILL | Fill gaps | 1 site | **4 (LOWEST - Last resort only)** |

**⚠️ DECAP Priority Rule:** DECAP cells MUST be used to fill gaps whenever possible (gap ≥ 3). FILL cells should ONLY be used for 1-site gaps.

### Space Calculation

```
Per row:  60 sites total
          2 sites for TAPs (fixed)
          58 sites available

Per tile: 60 × 4 = 240 sites total
          2 × 4 = 8 sites for TAPs (fixed)
          232 sites available for functional + fill cells
```

---

## Tools

### Analyze Current Fabric
```bash
python3 tools/cell_usage_analysis.py
```

### Generate Fabric Files
```bash
python3 tools/gen_fabric_cells_by_tile.py --fabric fabric.yaml --out fabric_cells.yaml
python3 tools/gen_pins_yaml.py --fabric fabric.yaml --techlef tech/sky130_fd_sc_hd.tlef --out pins.yaml
```

### Validate Fabric
```bash
# Check row widths
python3 -c "
import yaml
with open('structured/fabric/fabric.yaml') as f:
    fab = yaml.safe_load(f)
# ... validation code ...
"
```

---

**End of Document**
