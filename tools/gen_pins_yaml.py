#!/usr/bin/env python3
"""
gen_pins_yaml.py
Generate SASIC pin placement YAML (and optional pre-placement DEF PINS)
from a fabric YAML and a Sky130 tech LEF.

Requirements from spec:
- Pins on DIE edges (not core edges).
- South/North on met2 (vertical preferred) -> snap X to met2 tracks.
- West/East on met3 (horizontal preferred) -> snap Y to met3 tracks.
- 5 µm margin between core and die (derived from fabric) — informational.
- 5 µm corner keepout: no pins within 5 µm of any die corner.
- 40 groups for each bus: in_*, out_*, oeb_* (10 groups per side, equal spacing).
- clk and rst_n on bottom (south) center, snapped to met2 X tracks.
- YAML only contains pin placement (NO fabric cells dump).

Optional: emit a small DEF with PINS only (and DIEAREA).

Usage:
  python gen_pins_yaml.py \
    --fabric fabric.yaml \
    --techlef sky130_fd_sc_hd.tlef \
    --out pins.yaml \
    --out-def pins.def \
    [--die-margin-um 5.0] [--corner-keepout-um 5.0] [--pin-spacing-tracks 1]

Pin Spacing:
  --pin-spacing-tracks: Number of tracks between pins within a group (default: 1)
    Each I/O group (in_X, out_X, oeb_X) has pins placed on adjacent routing tracks.
    - South/North sides (met2): pins spread horizontally (X-axis) by 0.46 µm per track
    - East/West sides (met3): pins spread vertically (Y-axis) by 0.68 µm per track
    - All pins are guaranteed to be on-track for optimal routing

If you do not have a tech LEF, you may use manual grids:
  --met2-start-um 0.23 --met2-step-um 0.46 \
  --met3-start-um 0.34 --met3-step-um 0.68
"""

import argparse
import re
from typing import Dict, Tuple, Any, List
import yaml
from pathlib import Path


# ------------------------------
# TLef parsing (robust to multi-line UNITS; derives grids from LAYER PITCH/OFFSET)
# ------------------------------

def parse_techlef_tracks(path: str) -> Tuple[int, Dict[str, Dict[str, Tuple[float, float]]]]:
    """
    Returns: (dbu_per_micron, tracks_map)
      tracks_map[layer][axis] = (start_um, step_um), axis in {"X","Y"}
    Prefers TRACKS statements if present; otherwise derives from LAYER block:
      DIRECTION VERTICAL  -> axis 'X' uses OFFSET/PITCH
      DIRECTION HORIZONTAL-> axis 'Y' uses OFFSET/PITCH
    """
    dbu = None
    tracks_map: Dict[str, Dict[str, Tuple[float, float]]] = {}

    in_units = False
    in_layer = False
    cur_layer = None
    cur_dir = None
    cur_pitch = None
    cur_offset = None

    tracks_re = re.compile(
        r"^\s*TRACKS\s+(X|Y)\s+([0-9.+\-Ee]+)\s+DO\s+(\d+)\s+STEP\s+([0-9.+\-Ee]+)\s+LAYER\s+(.+?);"
    )

    with open(path, "r") as f:
        for raw in f:
            line = raw.strip()

            # UNITS block
            if line.startswith("UNITS"):
                in_units = True
                continue
            if in_units:
                m_db = re.search(r"DATABASE\s+MICRONS\s+(\d+)", line)
                if m_db:
                    dbu = int(m_db.group(1))
                if line.startswith("END UNITS"):
                    in_units = False
                # fallthrough

            # TRACKS
            m = tracks_re.match(raw)
            if m:
                axis = m.group(1)
                start = float(m.group(2))
                step  = float(m.group(4))
                layers = re.split(r"\s+", m.group(5).strip())
                for L in layers:
                    L = L.strip()
                    if not L:
                        continue
                    tracks_map.setdefault(L, {})[axis] = (start, step)
                continue

            # LAYER PITCH/OFFSET fallback
            if line.startswith("LAYER "):
                in_layer = True
                cur_layer = line.split()[1]
                cur_dir = None
                cur_pitch = None
                cur_offset = None
                continue

            if in_layer:
                if line.startswith("DIRECTION "):
                    cur_dir = line.split()[1].strip(";").upper()
                elif line.startswith("PITCH "):
                    vals = line[len("PITCH "):].strip(" ;").split()
                    cur_pitch = float(vals[0])
                elif line.startswith("OFFSET "):
                    vals = line[len("OFFSET "):].strip(" ;").split()
                    cur_offset = float(vals[0])
                elif line.startswith("END "):
                    end_name = line.split()[1]
                    if end_name == cur_layer and cur_layer and cur_dir and cur_pitch is not None and cur_offset is not None:
                        axis = "X" if cur_dir == "VERTICAL" else "Y"
                        tracks_map.setdefault(cur_layer, {})[axis] = (cur_offset, cur_pitch)
                    in_layer = False
                    cur_layer = None
                    cur_dir = None
                    cur_pitch = None
                    cur_offset = None

    if dbu is None:
        # Last resort scan
        with open(path, "r") as f2:
            for raw in f2:
                m = re.search(r"DATABASE\s+MICRONS\s+(\d+)", raw)
                if m:
                    dbu = int(m.group(1)); break
    if dbu is None:
        raise ValueError("Could not find 'DATABASE MICRONS <N>' in TLef.")

    # Convert any TRACKS entries that were in DBU to microns if necessary.
    # (Most TLefs specify TRACKS in microns already. We assume microns here.)
    return dbu, tracks_map


# ------------------------------
# Helpers
# ------------------------------

def snap_to_track(val: float, start: float, step: float, lo: float, hi: float) -> float:
    """Snap val to nearest track start + k*step, then clamp to [lo,hi]."""
    if step <= 0:
        return max(lo, min(hi, val))
    k = round((val - start) / step)
    snapped = start + k * step
    if snapped < lo:
        # move inward in multiples of step
        k = int((lo - start + step - 1e-12) // step)
        snapped = start + k * step
        if snapped < lo:
            snapped += step
    if snapped > hi:
        k = int((hi - start) // step)
        snapped = start + k * step
        if snapped > hi:
            snapped -= step
    return max(lo, min(hi, snapped))


def unique_with_step(positions: List[float], step: float, lo: float, hi: float) -> List[float]:
    """Ensure uniqueness by nudging duplicates by ±step inward."""
    used = set()
    out = []
    for x in positions:
        xi = x
        tries = 0
        while round(xi, 6) in used and tries < 20:
            # try one step inward
            cand1 = xi + step
            cand2 = xi - step
            if lo <= cand1 <= hi and round(cand1, 6) not in used:
                xi = cand1
            elif lo <= cand2 <= hi and round(cand2, 6) not in used:
                xi = cand2
            else:
                xi = max(lo, min(hi, xi))
            tries += 1
        used.add(round(xi, 6))
        out.append(xi)
    return out


# ------------------------------
# Main pin generation
# ------------------------------

def main():
    ap = argparse.ArgumentParser(description="Generate SASIC pins YAML (die-edge, snapped to tracks).")
    ap.add_argument("--fabric", required=True, help="fabric.yaml")
    ap.add_argument("--out", required=True, help="pins.yaml output path")
    ap.add_argument("--out-def", help="Optional DEF output with PINS only")
    ap.add_argument("--techlef", help="Sky130 technology LEF (.tlef)")
    ap.add_argument("--met2-start-um", type=float, help="Manual met2 X-track start (um)")
    ap.add_argument("--met2-step-um", type=float, help="Manual met2 X-track step (um)")
    ap.add_argument("--met3-start-um", type=float, help="Manual met3 Y-track start (um)")
    ap.add_argument("--met3-step-um", type=float, help="Manual met3 Y-track step (um)")
    ap.add_argument("--die-margin-um", type=float, default=5.0, help="core-to-die margin (um)")
    ap.add_argument("--corner-keepout-um", type=float, default=5.0, help="die-corner keepout (um)")
    ap.add_argument("--pin-spacing-tracks", type=int, default=1, help="number of tracks between pins within a group (default: 1)")
    ap.add_argument("--site-name", default="unithd", help="DEF site name (if emitting ROWS later)")
    ap.add_argument("--design-name", default="sasic_block", help="DEF DESIGN name")
    args = ap.parse_args()

    fab = yaml.safe_load(open(args.fabric, "r"))
    sx = float(fab["fabric_info"]["site_dimensions_um"]["width"])
    sy = float(fab["fabric_info"]["site_dimensions_um"]["height"])
    Wx = int(fab["tile_definition"]["dimensions_sites"]["width"])
    Wy = int(fab["tile_definition"]["dimensions_sites"]["height"])
    TX = int(fab["fabric_layout"]["tiles_x"])
    TY = int(fab["fabric_layout"]["tiles_y"])
    dbu = int(fab["fabric_info"]["units"])

    tile_w_um = Wx * sx
    tile_h_um = Wy * sy
    core_w_um = TX * tile_w_um
    core_h_um = TY * tile_h_um
    die_margin = float(args.die_margin_um)
    die_w_um = core_w_um + 2 * die_margin
    die_h_um = core_h_um + 2 * die_margin

    # Tracks for met2.X and met3.Y
    met2_start = args.met2_start_um
    met2_step  = args.met2_step_um
    met3_start = args.met3_start_um
    met3_step  = args.met3_step_um

    if args.techlef:
        dbu_lef, tracks = parse_techlef_tracks(args.techlef)
        # Use TLef DBU only if different? (pins YAML uses microns; DEF uses fab dbu)
        # Pull met2 X, met3 Y
        if met2_start is None or met2_step is None:
            if "met2" in tracks and "X" in tracks["met2"]:
                met2_start, met2_step = tracks["met2"]["X"]
        if met3_start is None or met3_step is None:
            if "met3" in tracks and "Y" in tracks["met3"]:
                met3_start, met3_step = tracks["met3"]["Y"]

    # Default to Sky130 HD if not provided
    if met2_start is None: met2_start = 0.23
    if met2_step  is None: met2_step  = 0.46
    if met3_start is None: met3_start = 0.34
    if met3_step  is None: met3_step  = 0.68

    # Side & layer mapping
    side_to_layer = {"south": "met2", "north": "met2", "west": "met3", "east": "met3"}

    # 5 µm corner keepout on DIE edges
    ck = float(args.corner_keepout_um)

    # Build equal-spacing anchor points per side (10 anchors each), snapped to tracks
    def anchors_for_side(side: str) -> List[float]:
        if side in ("south", "north"):
            L = die_w_um
            start, step = met2_start, met2_step  # X tracks
        else:
            L = die_h_um
            start, step = met3_start, met3_step  # Y tracks

        n = 10
        lo = ck
        hi = L - ck
        if hi <= lo:
            raise ValueError("Die too small for corner keepout. Reduce keepout or enlarge die.")

        raw = [lo + i * (hi - lo) / (n - 1) for i in range(n)]  # inclusive endpoints
        snapped = [snap_to_track(v, start, step, lo, hi) for v in raw]
        snapped = unique_with_step(snapped, step, lo, hi)
        return snapped

    south_xs = anchors_for_side("south")
    north_xs = anchors_for_side("north")
    west_ys  = anchors_for_side("west")
    east_ys  = anchors_for_side("east")

    # Place clk / rst_n at bottom center, snapped to met2 X tracks, ensure not colliding with anchors
    center_x = die_w_um * 0.5
    clk_x = snap_to_track(center_x, met2_start, met2_step, ck, die_w_um - ck)
    # rst_n one track to the right if possible, else left
    k_clk = round((clk_x - met2_start) / met2_step)
    rst_x = clk_x + met2_step
    if rst_x > die_w_um - ck:
        rst_x = clk_x - met2_step
    # If these collide with south_xs, nudge anchors outward by one step if equal
    def nudge_away(xs: List[float], forb: List[float], step: float, lo: float, hi: float) -> List[float]:
        out = []
        used = set(round(f,6) for f in forb)
        for x in xs:
            xi = x
            tries = 0
            while round(xi,6) in used and tries < 10:
                cand = xi - step if xi > (lo + hi)/2 else xi + step
                if lo <= cand <= hi:
                    xi = cand
                tries += 1
            out.append(xi)
        return out

    south_xs = nudge_away(south_xs, [clk_x, rst_x], met2_step, ck, die_w_um - ck)

    # Get pin spacing parameter (in tracks)
    track_spacing = int(args.pin_spacing_tracks)

    # Helper to append pins
    pins: List[Dict[str, Any]] = []

    def add_pin(name: str, side: str, x: float, y: float, layer: str, direction: str):
        pins.append({
            "name": name,
            "side": side,
            "layer": layer,
            "x_um": round(x, 6),
            "y_um": round(y, 6),
            "direction": direction.upper(),
            "status": "FIXED"
        })

    # Assign groups by side: 0-9 south, 10-19 east, 20-29 north, 30-39 west
    # Each group has 3 pins (in, out, oeb) placed on adjacent tracks
    for i in range(40):
        if i < 10:
            side = "south"; layer = side_to_layer[side]
            x_center = south_xs[i]; y = 0.0
            # South side: spread horizontally on met2 tracks
            add_pin(f"in_{i}",  side, x_center - track_spacing * met2_step, y, layer, "INPUT")
            add_pin(f"out_{i}", side, x_center, y, layer, "OUTPUT")
            add_pin(f"oeb_{i}", side, x_center + track_spacing * met2_step, y, layer, "INPUT")
        elif i < 20:
            side = "east"; layer = side_to_layer[side]
            x = die_w_um; y_center = east_ys[i - 10]
            # East side: spread vertically on met3 tracks
            add_pin(f"in_{i}",  side, x, y_center - track_spacing * met3_step, layer, "INPUT")
            add_pin(f"out_{i}", side, x, y_center, layer, "OUTPUT")
            add_pin(f"oeb_{i}", side, x, y_center + track_spacing * met3_step, layer, "INPUT")
        elif i < 30:
            side = "north"; layer = side_to_layer[side]
            x_center = north_xs[i - 20]; y = die_h_um
            # North side: spread horizontally on met2 tracks
            add_pin(f"in_{i}",  side, x_center - track_spacing * met2_step, y, layer, "INPUT")
            add_pin(f"out_{i}", side, x_center, y, layer, "OUTPUT")
            add_pin(f"oeb_{i}", side, x_center + track_spacing * met2_step, y, layer, "INPUT")
        else:
            side = "west"; layer = side_to_layer[side]
            x = 0.0; y_center = west_ys[i - 30]
            # West side: spread vertically on met3 tracks
            add_pin(f"in_{i}",  side, x, y_center - track_spacing * met3_step, layer, "INPUT")
            add_pin(f"out_{i}", side, x, y_center, layer, "OUTPUT")
            add_pin(f"oeb_{i}", side, x, y_center + track_spacing * met3_step, layer, "INPUT")

    # clk / rst_n at bottom center
    add_pin("clk",   "south", clk_x, 0.0,       "met2", "INPUT")
    add_pin("rst_n", "south", rst_x, 0.0,       "met2", "INPUT")

    pin_yaml = {
        "pin_placement": {
            "version": "2.1",
            "units": {"coords": "microns", "dbu_per_micron": dbu},
            "layers": {"south": "met2", "north": "met2", "west": "met3", "east": "met3"},
            "tracks": {
                "met2": {"start_um": met2_start, "step_um": met2_step},
                "met3": {"start_um": met3_start, "step_um": met3_step}
            },
            "die": {"width_um": round(die_w_um, 6), "height_um": round(die_h_um, 6),
                    "core_margin_um": round(die_margin, 6), "corner_keepout_um": round(ck, 6)},
            "core": {"width_um": round(core_w_um, 6), "height_um": round(core_h_um, 6)},
            "groups_per_side": 10,
            "pin_spacing_tracks": track_spacing,
            "pin_spacing_um": {
                "met2": round(track_spacing * met2_step, 6),
                "met3": round(track_spacing * met3_step, 6)
            },
            "pins": pins
        }
    }

    with open(args.out, "w") as f:
        yaml.safe_dump(pin_yaml, f, sort_keys=False)
    print(f"Wrote {args.out}")

    # Optional: DEF with PINS only
    if args.out_def:
        die_w = int(round(die_w_um * dbu))
        die_h = int(round(die_h_um * dbu))
        eps = 1  # tiny rect inside boundary
        lines = []
        lines.append("VERSION 5.8 ;")
        lines.append("NAMESCASESENSITIVE ON ;")
        lines.append('DIVIDERCHAR "/" ;')
        lines.append('BUSBITCHARS "[]" ;')
        lines.append(f"DESIGN {args.design_name} ;")
        lines.append(f"UNITS DISTANCE MICRONS {dbu} ;")
        lines.append(f"DIEAREA ( 0 0 ) ( {die_w} {die_h} ) ;")
        # PINS
        lines.append(f"PINS {len(pins)} ;")
        for p in pins:
            name = p["name"]
            layer = p["layer"]
            side  = p["side"]
            x = int(round(p["x_um"] * dbu))
            y = int(round(p["y_um"] * dbu))
            if side == "south":
                x1, y1 = x, 0
                x2, y2 = min(die_w, x + eps), eps
            elif side == "north":
                x1, y1 = x, max(0, die_h - eps)
                x2, y2 = min(die_w, x + eps), die_h
            elif side == "west":
                x1, y1 = 0, y
                x2, y2 = eps, min(die_h, y + eps)
            else: # east
                x1, y1 = max(0, die_w - eps), y
                x2, y2 = die_w, min(die_h, y + eps)
            lines.append(f"- {name}")
            lines.append(f"  + DIRECTION {p['direction']}")
            lines.append(f"  + USE SIGNAL")
            lines.append(f"  + PORT")
            lines.append(f"    + LAYER {layer} ( {x1} {y1} ) ( {x2} {y2} )")
            lines.append(f"    + PLACED ( {x} {y} ) N")
            lines.append(f"  + FIXED ( {x} {y} ) N")
            lines.append("  ;")
        lines.append("END PINS")
        lines.append("END DESIGN")
        Path(args.out_def).write_text("\n".join(lines))
        print(f"Wrote {args.out_def}")
        
if __name__ == "__main__":
    main()
