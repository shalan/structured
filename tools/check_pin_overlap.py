#!/usr/bin/env python3
"""
Check for overlapping pins in pin placement YAML file.
"""

import yaml
import sys
from collections import defaultdict

def check_pin_overlaps(yaml_file):
    """
    Analyze pin placement YAML and report any overlapping pin coordinates.
    """
    # Load YAML
    with open(yaml_file, 'r') as f:
        data = yaml.safe_load(f)

    pins = data['pin_placement']['pins']

    # Group pins by (x, y, side) coordinates
    coord_map = defaultdict(list)

    for pin in pins:
        key = (pin['x_um'], pin['y_um'], pin['side'])
        coord_map[key].append(pin['name'])

    # Find overlaps
    overlaps = {coord: names for coord, names in coord_map.items() if len(names) > 1}

    # Report results
    print("="*80)
    print("Pin Overlap Analysis")
    print("="*80)
    print(f"Total pins: {len(pins)}")
    print(f"Unique locations: {len(coord_map)}")
    print(f"Overlapping locations: {len(overlaps)}")
    print("="*80)

    if overlaps:
        print("\nOVERLAPPING PINS DETECTED:")
        print("-"*80)

        # Group by side for better organization
        by_side = defaultdict(list)
        for (x, y, side), names in sorted(overlaps.items()):
            by_side[side].append((x, y, names))

        for side in ['south', 'east', 'north', 'west']:
            if side in by_side:
                print(f"\n{side.upper()} side ({len(by_side[side])} overlapping locations):")
                print("-"*80)
                for x, y, names in by_side[side]:
                    print(f"  Location ({x:.2f} µm, {y:.2f} µm): {len(names)} pins")
                    for name in names:
                        print(f"    - {name}")

        # Summary statistics
        print("\n" + "="*80)
        print("SUMMARY:")
        print("-"*80)
        max_overlap = max(len(names) for names in overlaps.values())
        print(f"  Maximum pins at one location: {max_overlap}")

        # Count by overlap degree
        overlap_counts = defaultdict(int)
        for names in overlaps.values():
            overlap_counts[len(names)] += 1

        print(f"  Overlap distribution:")
        for count in sorted(overlap_counts.keys()):
            print(f"    {count} pins at same location: {overlap_counts[count]} locations")

        # Analyze overlap patterns
        print("\n  Overlap patterns:")
        group_pattern = all(
            len(names) == 3 and
            any(n.startswith('in_') for n in names) and
            any(n.startswith('out_') for n in names) and
            any(n.startswith('oeb_') for n in names)
            for names in overlaps.values()
        )

        if group_pattern:
            print("    ✓ All overlaps are in/out/oeb triads (intentional grouping)")
            num_groups = len(overlaps)
            print(f"    ✓ {num_groups} I/O groups detected")
        else:
            print("    ⚠ Non-uniform overlap pattern detected")

        # Check for clk/rst_n overlaps
        clk_pins = [names for names in overlaps.values() if 'clk' in names or 'rst_n' in names]
        if clk_pins:
            print("\n  ⚠ WARNING: Clock/reset pins overlap with other signals!")
            for names in clk_pins:
                print(f"    - {', '.join(names)}")

        return len(overlaps)
    else:
        print("\n✓ No overlapping pins detected - all pins have unique locations")
        return 0

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python check_pin_overlap.py <pins.yaml>")
        sys.exit(1)

    yaml_file = sys.argv[1]
    num_overlaps = check_pin_overlaps(yaml_file)

    print("\n" + "="*80)
    if num_overlaps > 0:
        print("⚠ Pin overlaps detected. Review placement strategy.")
    else:
        print("✓ Pin placement validation passed.")
    print("="*80 + "\n")
