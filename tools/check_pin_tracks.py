#!/usr/bin/env python3
"""
Check if pins are aligned with routing tracks (met2 and met3).

Usage:
  python check_pin_tracks.py <pins.yaml>
  python check_pin_tracks.py <pins.yaml> --met2-start 0.23 --met2-step 0.46
  python check_pin_tracks.py <pins.yaml> --techlef <sky130.tlef>
"""

import yaml
import sys
import argparse
import re


def parse_track_info_from_techlef(techlef_path):
    """Extract met2/met3 track start and step from a tech LEF file."""
    met2_start = met2_step = met3_start = met3_step = None

    with open(techlef_path, 'r') as f:
        content = f.read()

    # Parse LAYER blocks for met2 and met3
    for layer_name, prefix in [('met2', 'met2'), ('met3', 'met3')]:
        # Look for LAYER met2 ... END met2 blocks
        layer_pat = re.compile(
            rf'LAYER\s+{layer_name}\s*;(.*?)END\s+{layer_name}',
            re.DOTALL | re.IGNORECASE
        )
        m = layer_pat.search(content)
        if not m:
            continue
        block = m.group(1)

        # Extract PITCH and OFFSET
        pitch_m = re.search(r'PITCH\s+([\d.]+)', block)
        offset_m = re.search(r'OFFSET\s+([\d.]+)', block)
        if pitch_m:
            step = float(pitch_m.group(1))
            start = float(offset_m.group(1)) if offset_m else step / 2.0
            if layer_name == 'met2':
                met2_start, met2_step = start, step
            else:
                met3_start, met3_step = start, step

    return met2_start, met2_step, met3_start, met3_step


def check_track_alignment(yaml_file, met2_start, met2_step, met3_start, met3_step):
    """Verify that pins are placed on routing tracks."""
    with open(yaml_file, 'r') as f:
        data = yaml.safe_load(f)

    pins = data['pin_placement']['pins']

    def is_on_track(value, start, step, tolerance=0.001):
        offset = value - start
        track_num = round(offset / step)
        expected = start + track_num * step
        error = abs(value - expected)
        return error < tolerance, expected, error

    print("=" * 80)
    print("PIN TRACK ALIGNMENT ANALYSIS")
    print("=" * 80)
    print(f"met2 (X-axis): start={met2_start} um, step={met2_step} um")
    print(f"met3 (Y-axis): start={met3_start} um, step={met3_step} um")
    print("=" * 80)

    total_pins = len(pins)
    on_track = 0
    off_track = 0
    max_error = 0.0
    off_track_pins = []

    for pin in pins:
        side = pin['side']
        name = pin['name']

        if side in ['south', 'north']:
            x = pin['x_um']
            aligned, expected, error = is_on_track(x, met2_start, met2_step)
        else:
            y = pin['y_um']
            aligned, expected, error = is_on_track(y, met3_start, met3_step)

        if aligned:
            on_track += 1
        else:
            off_track += 1
            max_error = max(max_error, error)
            coord = pin['x_um'] if side in ['south', 'north'] else pin['y_um']
            off_track_pins.append((name, side, coord, expected, error))

    print(f"\nSTATISTICS:")
    print(f"  Total pins:        {total_pins}")
    print(f"  On track:          {on_track} ({100*on_track/total_pins:.1f}%)")
    print(f"  Off track:         {off_track} ({100*off_track/total_pins:.1f}%)")
    print(f"  Max error:         {max_error:.6f} um")

    if off_track > 0:
        print(f"\n{'Pin Name':<12} {'Side':<8} {'Actual (um)':<12} {'Track (um)':<12} {'Error (um)'}")
        print("-" * 60)
        for name, side, actual, expected, error in off_track_pins[:20]:
            print(f"{name:<12} {side:<8} {actual:<12.6f} {expected:<12.6f} {error:.6f}")
        if len(off_track_pins) > 20:
            print(f"... and {len(off_track_pins) - 20} more off-track pins")
    else:
        print("\nAll pins are properly aligned with routing tracks.")

    print("=" * 80)
    return off_track == 0


def main():
    parser = argparse.ArgumentParser(
        description='Check pin alignment with routing tracks')
    parser.add_argument('pins_yaml', help='Pin placement YAML file')
    parser.add_argument('--techlef', help='Tech LEF file (auto-extract track info)')
    parser.add_argument('--met2-start', type=float, default=0.23,
                        help='met2 track start offset in um (default: 0.23, Sky130 HD)')
    parser.add_argument('--met2-step', type=float, default=0.46,
                        help='met2 track pitch in um (default: 0.46, Sky130 HD)')
    parser.add_argument('--met3-start', type=float, default=0.34,
                        help='met3 track start offset in um (default: 0.34, Sky130 HD)')
    parser.add_argument('--met3-step', type=float, default=0.68,
                        help='met3 track pitch in um (default: 0.68, Sky130 HD)')

    args = parser.parse_args()

    met2_start, met2_step = args.met2_start, args.met2_step
    met3_start, met3_step = args.met3_start, args.met3_step

    if args.techlef:
        t2s, t2p, t3s, t3p = parse_track_info_from_techlef(args.techlef)
        if t2s is not None: met2_start, met2_step = t2s, t2p
        if t3s is not None: met3_start, met3_step = t3s, t3p
        print(f"Loaded track info from {args.techlef}")

    success = check_track_alignment(
        args.pins_yaml, met2_start, met2_step, met3_start, met3_step)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
