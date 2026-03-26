#!/usr/bin/env python3

import yaml
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import argparse
import sys
from matplotlib.lines import Line2D
from matplotlib.backend_bases import MouseButton

class InteractiveFloorplan:
    """
    Interactive floorplan viewer with zoom and pan capabilities.
    """
    def __init__(self, ax, die_width, die_height, padding):
        self.ax = ax
        self.die_width = die_width
        self.die_height = die_height
        self.padding = padding
        self.press = None
        self.cur_xlim = None
        self.cur_ylim = None

        # Connect events
        self.cidpress = ax.figure.canvas.mpl_connect('button_press_event', self.on_press)
        self.cidrelease = ax.figure.canvas.mpl_connect('button_release_event', self.on_release)
        self.cidmotion = ax.figure.canvas.mpl_connect('motion_notify_event', self.on_motion)
        self.cidscroll = ax.figure.canvas.mpl_connect('scroll_event', self.on_scroll)
        self.cidkey = ax.figure.canvas.mpl_connect('key_press_event', self.on_key)

    def on_press(self, event):
        """Store initial position for panning."""
        if event.inaxes != self.ax:
            return
        if event.button == MouseButton.LEFT:
            self.cur_xlim = self.ax.get_xlim()
            self.cur_ylim = self.ax.get_ylim()
            self.press = event.xdata, event.ydata

    def on_release(self, event):
        """Reset press position."""
        self.press = None
        self.ax.figure.canvas.draw()

    def on_motion(self, event):
        """Handle panning with mouse drag."""
        if self.press is None:
            return
        if event.inaxes != self.ax:
            return
        if event.button == MouseButton.LEFT:
            dx = event.xdata - self.press[0]
            dy = event.ydata - self.press[1]

            self.ax.set_xlim(self.cur_xlim[0] - dx, self.cur_xlim[1] - dx)
            self.ax.set_ylim(self.cur_ylim[0] - dy, self.cur_ylim[1] - dy)
            self.ax.figure.canvas.draw()

    def on_scroll(self, event):
        """Handle zooming with mouse scroll."""
        if event.inaxes != self.ax:
            return

        cur_xlim = self.ax.get_xlim()
        cur_ylim = self.ax.get_ylim()

        xdata = event.xdata
        ydata = event.ydata

        # Zoom factor
        base_scale = 1.2
        if event.button == 'up':
            # Zoom in
            scale_factor = 1 / base_scale
        elif event.button == 'down':
            # Zoom out
            scale_factor = base_scale
        else:
            scale_factor = 1

        # Calculate new limits
        new_width = (cur_xlim[1] - cur_xlim[0]) * scale_factor
        new_height = (cur_ylim[1] - cur_ylim[0]) * scale_factor

        relx = (cur_xlim[1] - xdata) / (cur_xlim[1] - cur_xlim[0])
        rely = (cur_ylim[1] - ydata) / (cur_ylim[1] - cur_ylim[0])

        self.ax.set_xlim([xdata - new_width * (1 - relx), xdata + new_width * relx])
        self.ax.set_ylim([ydata - new_height * (1 - rely), ydata + new_height * rely])

        self.ax.figure.canvas.draw()

    def on_key(self, event):
        """Handle keyboard shortcuts."""
        if event.key == 'r':
            # Reset view
            self.ax.set_xlim(-self.padding, self.die_width + self.padding)
            self.ax.set_ylim(-self.padding, self.die_height + self.padding)
            self.ax.figure.canvas.draw()
        elif event.key == 'h':
            # Show help
            print("\n" + "="*60)
            print("Interactive Floorplan Viewer - Keyboard Shortcuts")
            print("="*60)
            print("  Mouse Scroll      : Zoom in/out at cursor position")
            print("  Left Click + Drag : Pan the view")
            print("  'r' key           : Reset view to original")
            print("  'h' key           : Show this help message")
            print("  'q' key           : Quit/close the viewer")
            print("="*60 + "\n")

def draw_floorplan_viewer(yaml_file_path, output_path=None):
    """
    Parses a floorplan YAML file and generates an interactive visual representation
    of the die, core, and pin placements using matplotlib with zoom and pan support.

    Args:
        yaml_file_path: Path to the pin placement YAML file
        output_path: Optional path to save PNG file. If None, displays interactively.
    """
    # --- 1. Read and Parse the YAML File ---
    try:
        with open(yaml_file_path, 'r') as f:
            content = f.read()
            data = yaml.safe_load(content)
    except FileNotFoundError:
        print(f"Error: The file '{yaml_file_path}' was not found.", file=sys.stderr)
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"Error parsing YAML file '{yaml_file_path}': {e}", file=sys.stderr)
        sys.exit(1)

    # Extract the main data structure
    try:
        plan = data['pin_placement']
        die_info = plan['die']
        pins = plan['pins']
    except KeyError as e:
        print(f"Error: YAML file is missing expected key: {e}", file=sys.stderr)
        sys.exit(1)
        
    # --- 2. Setup Matplotlib Figure ---
    die_width = die_info['width_um']
    die_height = die_info['height_um']
    
    # Add some padding for labels
    padding = max(die_width, die_height) * 0.05 
    
    fig, ax = plt.subplots(figsize=(12, 12))
    ax.set_aspect('equal')
    ax.set_xlim(-padding, die_width + padding)
    ax.set_ylim(-padding, die_height + padding)
    ax.set_title("ASIC Floorplan Viewer", fontsize=16)
    ax.set_xlabel("X-coordinate ($\mu$m)")
    ax.set_ylabel("Y-coordinate ($\mu$m)")
    ax.grid(True, linestyle='--', alpha=0.6)

    # --- 3. Draw Die and Core Areas ---
    # Draw Die Area
    die_area = patches.Rectangle(
        (0, 0), die_width, die_height,
        linewidth=2, edgecolor='black', facecolor='#f0f0f0', label='Die Area'
    )
    ax.add_patch(die_area)

    # Draw Core Area
    core_margin = die_info.get('core_margin_um', 0)
    core_width = plan.get('core', {}).get('width_um', die_width - 2 * core_margin)
    core_height = plan.get('core', {}).get('height_um', die_height - 2 * core_margin)
    
    core_area = patches.Rectangle(
        (core_margin, core_margin), core_width, core_height,
        linewidth=1.5, edgecolor='darkblue', linestyle='--', facecolor='none', label='Core Area'
    )
    ax.add_patch(core_area)
    
    # --- 4. Define Pin Styles and Draw Pins ---
    pin_style_map = {
        'input': {'color': 'blue', 'marker': 'o'},
        'output': {'color': 'red', 'marker': 'o'},
        'oeb': {'color': 'green', 'marker': 'o'},
        'clk': {'color': 'purple', 'marker': 's'},
        'rst_n': {'color': 'orange', 'marker': 's'},
        'default': {'color': 'gray', 'marker': 'x'}
    }
    
    side_marker_map = {
        'south': '^', # Pointing up into the core
        'north': 'v', # Pointing down into the core
        'east': '<',  # Pointing left into the core
        'west': '>'   # Pointing right into the core
    }

    for pin in pins:
        x, y = pin['x_um'], pin['y_um']
        name = pin['name']
        direction = pin['direction']
        side = pin['side']

        # Determine color
        pin_type = 'default'
        if name.startswith('oeb'):
            pin_type = 'oeb'
        elif name == 'clk':
            pin_type = 'clk'
        elif name == 'rst_n':
            pin_type = 'rst_n'
        elif direction in pin_style_map:
            pin_type = direction
        
        style = pin_style_map[pin_type]
        marker = side_marker_map.get(side, style['marker'])
        
        # Plot pin marker
        ax.plot(x, y, marker=marker, color=style['color'], markersize=6, markeredgecolor='black')

        # Add pin labels with adjusted positions for readability
        offset = padding * 0.15
        rotation = 0
        ha, va = 'center', 'center'

        if side == 'south':
            y -= offset
            va = 'top'
        elif side == 'north':
            y += offset
            va = 'bottom'
        elif side == 'west':
            x -= offset
            ha = 'right'
            rotation = 90
        elif side == 'east':
            x += offset
            ha = 'left'
            rotation = 90
        
        ax.text(x, y, name, fontsize=7, ha=ha, va=va, rotation=rotation, color=style['color'])

    # --- 5. Create and Display Legend ---
    legend_elements = [
        patches.Patch(facecolor='#f0f0f0', edgecolor='black', label='Die Area'),
        patches.Patch(facecolor='none', edgecolor='darkblue', linestyle='--', label='Core Area')
    ]
    # Add pin types to legend
    seen_types = set()
    for pin in pins:
        pin_type = 'default'
        if pin['name'].startswith('oeb'): pin_type = 'oeb'
        elif pin['name'] == 'clk': pin_type = 'clk'
        elif pin['name'] == 'rst_n': pin_type = 'rst_n'
        elif pin['direction'] in pin_style_map: pin_type = pin['direction']
        
        if pin_type not in seen_types:
            style = pin_style_map[pin_type]
            legend_elements.append(
                Line2D([0], [0], marker=style['marker'], color='w', label=f'Pin ({pin_type.capitalize()})',
                       markerfacecolor=style['color'], markersize=8)
            )
            seen_types.add(pin_type)

    ax.legend(handles=legend_elements, loc='upper right', bbox_to_anchor=(1.25, 1.02))

    plt.tight_layout(rect=[0, 0, 0.85, 1])

    # Save to file or show interactively
    if output_path:
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        print(f"Floorplan visualization saved to: {output_path}")
    else:
        # Initialize interactive controls
        interactive = InteractiveFloorplan(ax, die_width, die_height, padding)

        # Add help text to the title
        ax.set_title("ASIC Floorplan Viewer (Press 'h' for help)", fontsize=16)

        # Display initial help message
        print("\n" + "="*60)
        print("Interactive Floorplan Viewer")
        print("="*60)
        print("Controls:")
        print("  Mouse Scroll      : Zoom in/out at cursor position")
        print("  Left Click + Drag : Pan the view")
        print("  'r' key           : Reset view to original")
        print("  'h' key           : Show help message")
        print("  'q' key           : Quit/close the viewer")
        print("="*60 + "\n")

        plt.show()

# --- Main execution block ---
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Visualize an ASIC floorplan from a YAML definition file."
    )
    parser.add_argument(
        "yaml_file",
        type=str,
        help="Path to the input floorplan YAML file."
    )
    parser.add_argument(
        "-o", "--output",
        type=str,
        default=None,
        help="Output PNG file path. If not specified, displays interactively."
    )
    args = parser.parse_args()

    draw_floorplan_viewer(args.yaml_file, output_path=args.output)
