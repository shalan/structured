#!/usr/bin/env python3
"""
Placement Visualization Tool
=============================
Visualizes cell assignment on the structured ASIC fabric.

Shows:
- Assigned fabric cells (colored by type)
- I/O pins on die edges
- Tile boundaries
- Design cell names

Author: Claude
Date: 2025-10-18
"""

import yaml
import argparse
import sys
from pathlib import Path

try:
    import matplotlib.pyplot as plt
    import matplotlib.patches as patches
    from matplotlib.collections import PatchCollection
except ImportError:
    print("ERROR: matplotlib not installed!")
    print("Please run: pip install matplotlib")
    sys.exit(1)


def load_placement(yaml_path: str):
    """Load placement data from YAML"""
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    return data['placement']['cells']


def load_pins(yaml_path: str):
    """Load I/O pin data from YAML"""
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    return data['pin_placement']['pins']


def load_fabric_info(yaml_path: str):
    """Load fabric info from fabric YAML"""
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)

    fabric_info = data['fabric_info']
    fabric_layout = data['fabric_layout']
    tile_def = data['tile_definition']

    site_w = fabric_info['site_dimensions_um']['width']
    site_h = fabric_info['site_dimensions_um']['height']

    tile_w_sites = tile_def['dimensions_sites']['width']
    tile_h_sites = tile_def['dimensions_sites']['height']

    tile_w_um = tile_w_sites * site_w
    tile_h_um = tile_h_sites * site_h

    tiles_x = fabric_layout['tiles_x']
    tiles_y = fabric_layout['tiles_y']

    fabric_w = tiles_x * tile_w_um
    fabric_h = tiles_y * tile_h_um

    return {
        'site_width': site_w,
        'site_height': site_h,
        'tile_width': tile_w_um,
        'tile_height': tile_h_um,
        'tiles_x': tiles_x,
        'tiles_y': tiles_y,
        'fabric_width': fabric_w,
        'fabric_height': fabric_h
    }


def get_cell_type_color(cell_type: str):
    """Get color for each cell type"""
    colors = {
        'sky130_fd_sc_hd__nand2_2': '#3498db',    # Blue
        'sky130_fd_sc_hd__or2_2': '#e74c3c',      # Red
        'sky130_fd_sc_hd__clkinv_2': '#2ecc71',   # Green
        'sky130_fd_sc_hd__clkbuf_4': '#f39c12',   # Orange
        'sky130_fd_sc_hd__dfbbp_1': '#9b59b6',    # Purple
        'sky130_fd_sc_hd__conb_1': '#95a5a6',     # Gray
    }
    return colors.get(cell_type, '#34495e')


def visualize_placement(placement_cells, pins, fabric_info, output_path=None,
                       show_tile_grid=True, show_labels=False):
    """
    Create placement visualization.

    Args:
        placement_cells: List of placed cells
        pins: List of I/O pins
        fabric_info: Fabric dimensions and parameters
        output_path: Output PNG file path (None = show interactively)
        show_tile_grid: Show tile boundaries
        show_labels: Show cell names (warning: cluttered for large designs)
    """
    print("==> Creating placement visualization...")

    # Create figure
    fig, ax = plt.subplots(figsize=(16, 12))

    fabric_w = fabric_info['fabric_width']
    fabric_h = fabric_info['fabric_height']

    # Set axis limits with margin
    margin = 20  # µm
    ax.set_xlim(-margin, fabric_w + margin)
    ax.set_ylim(-margin, fabric_h + margin)
    ax.set_aspect('equal')

    # Draw fabric boundary
    fabric_rect = patches.Rectangle(
        (0, 0), fabric_w, fabric_h,
        linewidth=2, edgecolor='black', facecolor='none', linestyle='--'
    )
    ax.add_patch(fabric_rect)

    # Draw tile grid
    if show_tile_grid:
        tile_w = fabric_info['tile_width']
        tile_h = fabric_info['tile_height']
        tiles_x = fabric_info['tiles_x']
        tiles_y = fabric_info['tiles_y']

        for i in range(tiles_x + 1):
            x = i * tile_w
            ax.plot([x, x], [0, fabric_h], 'k-', linewidth=0.3, alpha=0.3)

        for j in range(tiles_y + 1):
            y = j * tile_h
            ax.plot([0, fabric_w], [y, y], 'k-', linewidth=0.3, alpha=0.3)

    # Draw placed cells
    cell_markers = []
    cell_colors = []
    cell_labels = []

    for cell in placement_cells:
        x = cell['position']['x_um']
        y = cell['position']['y_um']
        cell_type = cell['cell_type']

        cell_markers.append((x, y))
        cell_colors.append(get_cell_type_color(cell_type))
        cell_labels.append(cell['design_cell'])

    # Plot cells as scatter
    xs = [m[0] for m in cell_markers]
    ys = [m[1] for m in cell_markers]
    ax.scatter(xs, ys, c=cell_colors, s=20, alpha=0.7, edgecolors='black', linewidths=0.5, zorder=3)

    # Optionally show labels (warning: very cluttered!)
    if show_labels and len(cell_markers) < 100:
        for i, label in enumerate(cell_labels):
            ax.annotate(label, (xs[i], ys[i]), fontsize=4, alpha=0.5)

    # Draw I/O pins
    pin_xs = []
    pin_ys = []
    pin_colors = []
    pin_labels = []

    for pin in pins:
        x = pin['x_um']
        y = pin['y_um']
        name = pin['name']
        direction = pin['direction']

        pin_xs.append(x)
        pin_ys.append(y)

        # Color by direction
        if direction == 'INPUT':
            pin_colors.append('#27ae60')  # Green
        elif direction == 'OUTPUT':
            pin_colors.append('#e67e22')  # Orange
        else:
            pin_colors.append('#95a5a6')  # Gray

        pin_labels.append(name)

    # Plot pins as stars
    ax.scatter(pin_xs, pin_ys, c=pin_colors, s=100, marker='*',
              edgecolors='black', linewidths=1, zorder=5, label='I/O Pins')

    # Create legend
    from matplotlib.lines import Line2D
    legend_elements = [
        Line2D([0], [0], marker='o', color='w', label='NAND2',
               markerfacecolor=get_cell_type_color('sky130_fd_sc_hd__nand2_2'), markersize=8),
        Line2D([0], [0], marker='o', color='w', label='OR2',
               markerfacecolor=get_cell_type_color('sky130_fd_sc_hd__or2_2'), markersize=8),
        Line2D([0], [0], marker='o', color='w', label='INV',
               markerfacecolor=get_cell_type_color('sky130_fd_sc_hd__clkinv_2'), markersize=8),
        Line2D([0], [0], marker='o', color='w', label='BUF',
               markerfacecolor=get_cell_type_color('sky130_fd_sc_hd__clkbuf_4'), markersize=8),
        Line2D([0], [0], marker='o', color='w', label='DFF',
               markerfacecolor=get_cell_type_color('sky130_fd_sc_hd__dfbbp_1'), markersize=8),
        Line2D([0], [0], marker='o', color='w', label='CONB',
               markerfacecolor=get_cell_type_color('sky130_fd_sc_hd__conb_1'), markersize=8),
        Line2D([0], [0], marker='*', color='w', label='I/O Pins',
               markerfacecolor='#27ae60', markersize=12),
    ]
    ax.legend(handles=legend_elements, loc='upper right', fontsize=10)

    # Labels and title
    ax.set_xlabel('X (µm)', fontsize=12)
    ax.set_ylabel('Y (µm)', fontsize=12)
    ax.set_title(f'Structured ASIC Placement ({len(placement_cells)} cells, {len(pins)} I/O pins)',
                fontsize=14, fontweight='bold')

    # Grid
    ax.grid(True, alpha=0.2)

    # Statistics text
    stats_text = f"Fabric: {fabric_w:.1f} × {fabric_h:.1f} µm\n"
    stats_text += f"Tiles: {fabric_info['tiles_x']} × {fabric_info['tiles_y']}\n"
    stats_text += f"Cells: {len(placement_cells)}"

    ax.text(0.02, 0.98, stats_text, transform=ax.transAxes,
           fontsize=10, verticalalignment='top',
           bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))

    plt.tight_layout()

    # Save or show
    if output_path:
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        print(f"    Saved visualization: {output_path}")
    else:
        plt.show()

    plt.close()


def main():
    parser = argparse.ArgumentParser(
        description='Visualize structured ASIC placement',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Visualize placement
  python tools/visualize_placement.py \\
    --placement output/arith/placement.yaml \\
    --pins output/fabric_2/pins.yaml \\
    --fabric fabric_2.yaml \\
    --output output/arith/placement.png

  # Show interactively (no --output)
  python tools/visualize_placement.py \\
    --placement output/arith/placement.yaml \\
    --pins output/fabric_2/pins.yaml \\
    --fabric fabric_2.yaml

  # Show with tile grid
  python tools/visualize_placement.py \\
    --placement output/arith/placement.yaml \\
    --pins output/fabric_2/pins.yaml \\
    --fabric fabric_2.yaml \\
    --output output/arith/placement.png \\
    --tile-grid
        """
    )

    parser.add_argument('--placement', required=True, help='Placement YAML file')
    parser.add_argument('--pins', required=True, help='I/O pins YAML file')
    parser.add_argument('--fabric', required=True, help='Fabric definition YAML file')
    parser.add_argument('--output', help='Output PNG file (if not specified, show interactively)')
    parser.add_argument('--tile-grid', action='store_true', help='Show tile boundaries')
    parser.add_argument('--labels', action='store_true', help='Show cell labels (cluttered for >100 cells)')

    args = parser.parse_args()

    print("=" * 80)
    print("Placement Visualization")
    print("=" * 80)

    # Load data
    print(f"==> Loading placement: {args.placement}")
    placement_cells = load_placement(args.placement)

    print(f"==> Loading pins: {args.pins}")
    pins = load_pins(args.pins)

    print(f"==> Loading fabric info: {args.fabric}")
    fabric_info = load_fabric_info(args.fabric)

    # Create visualization
    visualize_placement(
        placement_cells, pins, fabric_info,
        output_path=args.output,
        show_tile_grid=args.tile_grid,
        show_labels=args.labels
    )

    print("=" * 80)
    print("✅ Visualization complete!")


if __name__ == '__main__':
    main()
