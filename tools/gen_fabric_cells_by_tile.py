#!/usr/bin/env python3
"""
gen_fabric_cells_by_tile.py
Generate a tile-organized YAML of cell names, orientations, and die-absolute positions
from a Structured ASIC fabric YAML (Sky130).

Output format (approved by user):
fabric_cells_by_tile:
  version: 1.0
  units: { coords: microns }
  position_semantics: "die-absolute, DEF PLACED origin (lower-left), orient in {N, FS}"
  tiles:
    T0Y0:
      x: 0
      y: 0
      cells:
        - { name: "T0Y0__R0_NAND_0", orient: "N",  x: 5.46, y: 5.00 }
        - { name: "T0Y0__R0_NAND_1", orient: "N",  x: 7.76, y: 5.00 }
    T1Y0:
      x: 1
      y: 0
      cells:
        - { name: "T1Y0__R1_BUF_0",  orient: "FS", x: 33.62, y: 7.72 }

Usage:
  python gen_fabric_cells_by_tile.py --fabric fabric.yaml --out cells_by_tile.yaml
  # Optional: margin (µm) between core and die (default 5.0)
  python gen_fabric_cells_by_tile.py --fabric fabric.yaml --out cells_by_tile.yaml --die-margin-um 5.0
"""

import argparse
from typing import Dict, Any
import yaml

def load_yaml(path: str) -> Dict[str, Any]:
    with open(path, "r") as f:
        return yaml.safe_load(f)

def main():
    ap = argparse.ArgumentParser(description="Generate tile-organized cell positions YAML from fabric YAML.")
    ap.add_argument("--fabric", required=True, help="Path to fabric YAML")
    ap.add_argument("--out", required=True, help="Output YAML path")
    ap.add_argument("--die-margin-um", type=float, default=5.0, help="Margin between core and die (µm), default 5.0")
    args = ap.parse_args()

    fab = load_yaml(args.fabric)

    # Geometry from fabric
    sx = float(fab["fabric_info"]["site_dimensions_um"]["width"])
    sy = float(fab["fabric_info"]["site_dimensions_um"]["height"])
    Wx = int(fab["tile_definition"]["dimensions_sites"]["width"])
    Wy = int(fab["tile_definition"]["dimensions_sites"]["height"])
    TX = int(fab["fabric_layout"]["tiles_x"])
    TY = int(fab["fabric_layout"]["tiles_y"])

    tile_w_um = Wx * sx
    tile_h_um = Wy * sy
    margin = float(args.die_margin_um)

    # Build tiles mapping
    tiles: Dict[str, Any] = {}
    tmpl_cells = fab["tile_definition"]["cells"]

    # Deterministic order: ty -> tx
    for ty in range(TY):
        for tx in range(TX):
            key = f"T{tx}Y{ty}"
            tile_entry = {"x": tx, "y": ty, "cells": []}

            tile_x0_um = margin + tx * tile_w_um
            tile_y0_um = margin + ty * tile_h_um

            # Deterministic cell order: row (oy) then site_x (ox)
            sorted_cells = sorted(
                tmpl_cells,
                key=lambda e: (int(e["origin_sites"]["y"]), int(e["origin_sites"]["x"]))
            )

            for entry in sorted_cells:
                tmpl = entry["template_name"]
                ox = int(entry["origin_sites"]["x"])
                oy = int(entry["origin_sites"]["y"])

                orient = "N" if (oy % 2 == 0) else "FS"
                x_um = tile_x0_um + ox * sx
                y_um = tile_y0_um + oy * sy

                tile_entry["cells"].append({
                    "name": f"{key}__{tmpl}",
                    "orient": orient,
                    "x": round(x_um, 6),
                    "y": round(y_um, 6),
                })

            tiles[key] = tile_entry

    out_yaml = {
        "fabric_cells_by_tile": {
            "version": "1.0",
            "units": { "coords": "microns" },
            "position_semantics": "die-absolute, DEF PLACED origin (lower-left), orient in {N, FS}",
            "tiles": tiles,
        }
    }

    with open(args.out, "w") as f:
        yaml.safe_dump(out_yaml, f, sort_keys=False)

    print(f"Wrote {args.out}")

if __name__ == "__main__":
    main()
