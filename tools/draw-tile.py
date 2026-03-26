#!/usr/bin/env python3

import yaml
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import numpy as np
import argparse  # Import argparse for command-line arguments
import sys       # Import sys for exit

def draw_tile_layout(yaml_content, output_path=None):
    """
    Parses the fabric YAML string and draws a scaled representation of the tile
    layout using matplotlib.

    Args:
        yaml_content: YAML content string
        output_path: Optional path to save PNG file. If None, displays interactively.
    """
    
    # --- 1. Define Constants and Styling ---
    
    # Site dimensions from the prompt
    SITE_HEIGHT_UM = 2.72
    SITE_WIDTH_UM = 0.46
    
    # Color and Label mapping for each cell type.
    # As requested, decap_3 and decap_4 share a color and label.
    STYLE_MAP = {
        "sky130_fd_sc_hd__nand2_2":      {"color": "skyblue",    "label": "NAND2"},
        "sky130_fd_sc_hd__nand3_2":      {"color": "steelblue",  "label": "NAND3"},
        "sky130_fd_sc_hd__nor2_2":       {"color": "lightgreen", "label": "NOR2"},
        "sky130_fd_sc_hd__or2_2":        {"color": "mediumseagreen", "label": "OR2"},
        "sky130_fd_sc_hd__inv_2":        {"color": "khaki",      "label": "INV"},
        "sky130_fd_sc_hd__buf_2":        {"color": "lightsalmon", "label": "BUF"},
        "sky130_fd_sc_hd__and2_1":       {"color": "salmon",     "label": "AND2"},
        "sky130_fd_sc_hd__and2_2":       {"color": "salmon",     "label": "AND2"},
        "sky130_fd_sc_hd__clkinv_2":     {"color": "khaki",      "label": "CLKINV"},
        "sky130_fd_sc_hd__clkbuf_4":     {"color": "plum",       "label": "CLKBUF"},
        "sky130_fd_sc_hd__dfbbp_1":      {"color": "orange",     "label": "DFBBP (Flip-Flop)"},
        "sky130_fd_sc_hd__tapvpwrvgnd_1":{"color": "dimgray",    "label": "TAP (Well Tap)"},
        "sky130_fd_sc_hd__decap_4":      {"color": "lightcoral", "label": "DECAP (Decoupling)"},
        "sky130_fd_sc_hd__decap_3":      {"color": "lightcoral", "label": "DECAP (Decoupling)"},
        "sky130_fd_sc_hd__conb_1":       {"color": "lightpink",  "label": "CONB (Tie Cell)"},
        "sky130_fd_sc_hd__fill_1":       {"color": "whitesmoke", "label": "FILL"},
    }
    DEFAULT_STYLE = {"color": "silver", "label": "Unknown"}
    
    # --- 2. Parse YAML Data ---
    
    try:
        data = yaml.safe_load(yaml_content)
    except yaml.YAMLError as e:
        print(f"Error parsing YAML: {e}")
        return

    # Basic validation of loaded data
    if 'cell_definitions' not in data or 'tile_definition' not in data:
        print("Error: YAML is missing 'cell_definitions' or 'tile_definition' key.", file=sys.stderr)
        return
        
    cell_defs = data['cell_definitions']
    tile_cells = data['tile_definition']['cells']
    tile_dims_sites = data['tile_definition']['dimensions_sites']
    
    tile_width_sites = tile_dims_sites['width']
    tile_height_sites = tile_dims_sites['height']
    
    # Calculate total physical dimensions
    total_width_um = tile_width_sites * SITE_WIDTH_UM
    total_height_um = tile_height_sites * SITE_HEIGHT_UM
    
    # --- 3. Setup Matplotlib Figure ---
    
    # Adjust figsize to be proportional to the tile dimensions for a good default view
    fig_width = 15
    fig_height = (total_height_um / total_width_um) * fig_width * 1.5 # Extra factor for aesthetics
    
    fig, ax = plt.subplots(figsize=(fig_width, fig_height))
    ax.set_aspect('equal') # Critical for correct physical scaling
    
    # Set plot limits. Row 0 is at the bottom (y=0).
    ax.set_xlim(0, total_width_um)
    ax.set_ylim(0, total_height_um)
    
    ax.set_title(f"Sky130 Structured ASIC Tile (V{data.get('fabric_info', {}).get('version', 'N/A')})", fontsize=16)
    ax.set_xlabel("Width ($\mu$m)")
    ax.set_ylabel("Height ($\mu$m)")

    legend_patches = {} # To store unique patches for the legend
    
    # --- 4. Draw Each Cell ---

    for cell in tile_cells:
        cell_type = cell['cell_type']
        template_name = cell['template_name']

        # Get origin in sites
        origin_x_site = cell['origin_sites']['x']
        origin_y_site = cell['origin_sites']['y']

        # Get dimensions in sites
        if cell_type not in cell_defs:
            print(f"Warning: Cell type '{cell_type}' not in definitions. Skipping.", file=sys.stderr)
            continue

        width_sites = cell_defs[cell_type]['width_sites']
        height_sites = 1 # All standard cells are 1 row high

        # Handle repeat and spacing
        repeat_count = cell.get('repeat', 1)
        spacing_sites = cell.get('spacing', width_sites)

        for rep_idx in range(repeat_count):
            cur_x_site = origin_x_site + rep_idx * spacing_sites

            # Convert to physical coordinates (microns)
            x_coord_um = cur_x_site * SITE_WIDTH_UM
            y_coord_um = origin_y_site * SITE_HEIGHT_UM
            width_um = width_sites * SITE_WIDTH_UM
            height_um = height_sites * SITE_HEIGHT_UM

            # Get cell style
            style = STYLE_MAP.get(cell_type, DEFAULT_STYLE)
            color = style["color"]
            label = style["label"]

            # Draw the cell rectangle
            rect = patches.Rectangle(
                (x_coord_um, y_coord_um),
                width_um,
                height_um,
                linewidth=1,
                edgecolor='black',
                facecolor=color
            )
            ax.add_patch(rect)

            # Add text label
            # Simplify the type name for display (e.g., "nand2_2")
            simple_type = cell_type.split('__')[-1]
            if repeat_count > 1:
                text_label = f"{template_name}[{rep_idx}]\n({simple_type})"
            else:
                text_label = f"{template_name}\n({simple_type})"

            # Adjust font size and rotation for narrow cells
            if width_um < 1.0: # e.g., tap cells
                font_size = 6
                rotation = 90
            elif width_um < 3.0: # e.g., conb, decap_3
                font_size = 7
                rotation = 0
            else:
                font_size = 8
                rotation = 0

            ax.text(
                x_coord_um + width_um / 2,
                y_coord_um + height_um / 2,
                text_label,
                ha='center',
                va='center',
                fontsize=font_size,
                rotation=rotation,
                color='black'
            )

            # Add a patch to the legend (only one per type)
            if label not in legend_patches:
                legend_patches[label] = patches.Patch(color=color, label=label)

    # --- 5. Finalize Plot (Grid and Legend) ---
    
    # Add minor grid for site boundaries
    ax.set_xticks(np.arange(0, total_width_um + SITE_WIDTH_UM, SITE_WIDTH_UM), minor=True)
    ax.set_yticks(np.arange(0, total_height_um + SITE_HEIGHT_UM, SITE_HEIGHT_UM), minor=True)
    ax.grid(which='minor', linestyle=':', linewidth=0.5, color='#aaaaaa')
    
    # Add major grid for row labels
    ax.set_yticks(
        np.arange(0, total_height_um, SITE_HEIGHT_UM) + (SITE_HEIGHT_UM / 2),
        labels=[f"Row {i}" for i in range(tile_height_sites)]
    )
    # Clear minor y-tick labels, keep major row labels
    ax.tick_params(axis='y', which='minor', length=0)
    
    # Add legend outside the plot area
    ax.legend(
        handles=legend_patches.values(),
        bbox_to_anchor=(1.02, 1), # Position to the top-right outside
        loc='upper left',
        borderaxespad=0.
    )
    
    # Adjust layout to prevent legend from being cut off
    plt.tight_layout(rect=[0, 0, 0.85, 1]) # Make room on the right

    # Save to file or show interactively
    if output_path:
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        print(f"Tile visualization saved to: {output_path}")
    else:
        # Show the plot interactively
        plt.show()

# --- Main execution ---
if __name__ == "__main__":
    # Setup command-line argument parser
    parser = argparse.ArgumentParser(
        description="Draw an ASIC tile layout from a YAML fabric definition file."
    )
    parser.add_argument(
        "yaml_file",
        type=str,
        help="Path to the input YAML file."
    )
    parser.add_argument(
        "-o", "--output",
        type=str,
        default=None,
        help="Output PNG file path. If not specified, displays interactively."
    )

    args = parser.parse_args()
    
    # Read the YAML file content
    try:
        with open(args.yaml_file, 'r') as f:
            yaml_content_string = f.read()
    except FileNotFoundError:
        print(f"Error: The file '{args.yaml_file}' was not found.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading file: {e}", file=sys.stderr)
        sys.exit(1)

    # Call the drawing function with the file content
    draw_tile_layout(yaml_content_string, output_path=args.output)