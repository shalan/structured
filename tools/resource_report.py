#!/usr/bin/env python3
"""
Fabric Resource Usage Report Generator

Analyzes synthesized designs and reports fabric resource utilization.
Loads all capacity/width data from the fabric YAML — no hard-coded values.

Usage:
  python tools/resource_report.py --fabric fabric/fabric_11x66.yaml --designs designs/synth/
  python tools/resource_report.py --fabric fabric/nand2_11x66.yaml --designs designs/synth/ --suffix nand2_11x66
"""

import json
import sys
import argparse
from pathlib import Path
from collections import defaultdict

import yaml

# Infrastructure cell types excluded from functional capacity
INFRA_PREFIXES = ('tapvpwrvgnd', 'decap', 'fill', 'conb', 'clkbuf', 'and2')


def load_fabric_capacity(fabric_yaml_path):
    """
    Load cell widths and compute per-type capacity from fabric YAML.

    Returns:
        cell_widths: Dict[cell_type -> width_in_sites]
        capacity:    Dict[cell_type -> total_count_in_fabric]
        total_func_sites: int  (total functional site-widths)
    """
    with open(fabric_yaml_path) as f:
        fab = yaml.safe_load(f)

    cell_defs = fab.get('cell_definitions', {})
    cell_widths = {ct: int(info['width_sites']) for ct, info in cell_defs.items()}

    tiles_x = int(fab['fabric_layout']['tiles_x'])
    tiles_y = int(fab['fabric_layout']['tiles_y'])
    n_tiles = tiles_x * tiles_y

    # Count cells per type per tile
    tile_counts = defaultdict(int)
    for entry in fab['tile_definition']['cells']:
        ct = entry['cell_type']
        repeat = int(entry.get('repeat', 1))
        tile_counts[ct] += repeat

    capacity = {ct: count * n_tiles for ct, count in tile_counts.items()}

    # Total functional site-widths
    total_func_sites = 0
    for ct, count in capacity.items():
        short = ct.split('__')[-1] if '__' in ct else ct
        if not any(short.startswith(p) for p in INFRA_PREFIXES):
            total_func_sites += count * cell_widths.get(ct, 0)

    return cell_widths, capacity, total_func_sites, n_tiles


def is_functional(cell_type):
    """Check if a cell type is functional (not infrastructure)."""
    short = cell_type.split('__')[-1] if '__' in cell_type else cell_type
    return not any(short.startswith(p) for p in INFRA_PREFIXES)


def analyze_design(json_path, cell_widths):
    """Analyze a synthesized design JSON file."""
    try:
        with open(json_path) as f:
            data = json.load(f)

        # Find top module (try sasic_top, then first with cells)
        module = data['modules'].get('sasic_top')
        if module is None:
            module = next((m for m in data['modules'].values() if m.get('cells')), {})

        cells = module.get('cells', {})
        cell_counts = defaultdict(int)
        for cell_data in cells.values():
            cell_counts[cell_data.get('type', 'unknown')] += 1

        func_cells = {ct: n for ct, n in cell_counts.items() if is_functional(ct)}
        func_area = sum(cell_widths.get(ct, 5) * n for ct, n in func_cells.items())

        return {
            'cell_counts': dict(cell_counts),
            'functional_cells': func_cells,
            'functional_area_sites': func_area,
        }
    except Exception as e:
        return {'error': str(e)}


def print_report(designs_data, cell_widths, capacity, total_func_sites, n_tiles, fabric_name):
    """Print formatted resource usage report."""
    print("=" * 100)
    print(f"STRUCTURED ASIC FABRIC RESOURCE REPORT — {fabric_name}")
    print(f"Fabric: {n_tiles} tiles, {total_func_sites:,} functional site-widths")
    print("=" * 100)

    # Summary table
    print(f"\n{'Design':<25} {'Cells':>7} {'Area (sw)':>10} {'Util%':>7}  Status")
    print("-" * 65)

    for name, data in sorted(designs_data.items(), key=lambda x: x[1].get('functional_area_sites', 0)):
        if 'error' in data:
            print(f"{name:<25} ERROR: {data['error']}")
            continue

        area = data['functional_area_sites']
        n_cells = sum(data['functional_cells'].values())
        util = area / total_func_sites * 100 if total_func_sites else 0

        # Check per-cell overflow
        overflow = any(
            data['functional_cells'].get(ct, 0) > capacity.get(ct, 0)
            for ct in data['functional_cells']
        )
        if overflow:
            status = "OVER"
        elif util < 50:
            status = "OK"
        elif util < 80:
            status = "High"
        else:
            status = "Full"

        print(f"{name:<25} {n_cells:>7,} {area:>10,} {util:>6.1f}%  {status}")

    print("-" * 65)

    # Per-cell breakdown for each design
    print(f"\nPER-CELL UTILIZATION (count / capacity)")
    print("-" * 100)

    # Collect all functional cell types
    func_types = sorted(set(
        ct for d in designs_data.values() if 'error' not in d
        for ct in d['functional_cells']
    ))
    short_names = {ct: ct.split('__')[-1] if '__' in ct else ct for ct in func_types}

    # Header
    header = f"{'Design':<20}"
    for ct in func_types:
        header += f" {short_names[ct]:>12}"
    header += f" {'Area%':>7}"
    print(header)
    print("-" * len(header))

    for name, data in sorted(designs_data.items(), key=lambda x: x[1].get('functional_area_sites', 0)):
        if 'error' in data:
            continue
        line = f"{name:<20}"
        for ct in func_types:
            used = data['functional_cells'].get(ct, 0)
            cap = capacity.get(ct, 0)
            pct = used / cap * 100 if cap else 0
            line += f" {used:>5}/{cap:<5} " if pct < 80 else f" {used:>5}/{cap:<5}!"
        area = data['functional_area_sites']
        util = area / total_func_sites * 100 if total_func_sites else 0
        line += f" {util:>6.1f}%"
        print(line)

    print("-" * len(header))
    print()


def main():
    parser = argparse.ArgumentParser(description='Fabric Resource Usage Report')
    parser.add_argument('--fabric', required=True, help='Fabric definition YAML')
    parser.add_argument('--designs', default='designs/synth/',
                        help='Directory containing *_mapped.json files (default: designs/synth/)')
    parser.add_argument('--suffix', default=None,
                        help='Only include JSON files matching *_{suffix}_mapped.json')
    args = parser.parse_args()

    fabric_name = Path(args.fabric).stem
    cell_widths, capacity, total_func_sites, n_tiles = load_fabric_capacity(args.fabric)

    # Discover designs
    designs_dir = Path(args.designs)
    all_json = sorted(designs_dir.glob("*_mapped.json"))

    if args.suffix:
        # Match files whose stem ends with exactly _{suffix}_mapped
        import re
        pat = re.compile(r'^(.+)_' + re.escape(args.suffix) + r'_mapped$')
        design_files = [f for f in all_json if pat.match(f.stem)]
    else:
        design_files = all_json

    if not design_files:
        suffix_info = f" with suffix '{args.suffix}'" if args.suffix else ""
        print(f"ERROR: No designs found in {designs_dir}{suffix_info}")
        sys.exit(1)

    print(f"Found {len(design_files)} designs\n")

    designs_data = {}
    for json_file in design_files:
        name = json_file.stem.replace('_mapped', '')
        if args.suffix:
            name = name.replace(f'_{args.suffix}', '')
        designs_data[name] = analyze_design(json_file, cell_widths)

    print_report(designs_data, cell_widths, capacity, total_func_sites, n_tiles, fabric_name)


if __name__ == '__main__':
    main()
