#!/usr/bin/env python3
"""
Structured ASIC Assignment Solver
==================================
Assigns design netlist cells to pre-placed fabric cells to minimize wirelength.

This is a Quadratic Assignment Problem (QAP) solved using:
1. Hungarian algorithm for fast initial assignment (optimal for linear approximation)
2. Simulated Annealing for refinement (optimizes actual wirelength)

Author: Claude
Date: 2025-10-18
"""

import json
import yaml
import argparse
import sys
import time
import re
from pathlib import Path
from typing import Dict, List, Tuple, Set
from collections import defaultdict
import random
import math

try:
    import numpy as np
    from scipy.optimize import linear_sum_assignment
except ImportError:
    print("ERROR: Required packages not installed!")
    print("Please run: pip install numpy scipy")
    sys.exit(1)

# =============================================================================
# Data Structures
# =============================================================================

class Position:
    """2D position in microns"""
    def __init__(self, x: float, y: float):
        self.x = x
        self.y = y

    def __repr__(self):
        return f"({self.x:.3f}, {self.y:.3f})"

    def distance(self, other: 'Position') -> float:
        """Manhattan distance"""
        return abs(self.x - other.x) + abs(self.y - other.y)


class DesignCell:
    """A cell from the design netlist"""
    def __init__(self, name: str, cell_type: str):
        self.name = name
        self.cell_type = cell_type
        self.nets = []  # List of net IDs this cell connects to

    def __repr__(self):
        return f"DesignCell({self.name}, {self.cell_type})"


class FabricCell:
    """A pre-placed cell in the fabric"""
    def __init__(self, name: str, cell_type: str, position: Position, tile: str, row: str):
        self.name = name
        self.cell_type = cell_type
        self.position = position
        self.tile = tile
        self.row = row
        self.assigned = False  # Track if this slot is used

    def __repr__(self):
        return f"FabricCell({self.name}, {self.cell_type}, {self.position})"


class IOPin:
    """A fixed I/O pin on the die edge"""
    def __init__(self, name: str, position: Position, direction: str):
        self.name = name
        self.position = position
        self.direction = direction

    def __repr__(self):
        return f"IOPin({self.name}, {self.position})"


class Net:
    """A net connecting design cells and I/O pins"""
    def __init__(self, net_id: int, name: str = ""):
        self.net_id = net_id
        self.name = name
        self.design_cells = []  # List of DesignCell objects
        self.io_pins = []  # List of IOPin objects

    def __repr__(self):
        return f"Net({self.net_id}, {len(self.design_cells)} cells, {len(self.io_pins)} pins)"


# =============================================================================
# Input Parsing
# =============================================================================

def parse_netlist(json_path: str) -> Tuple[Dict[str, DesignCell], Dict[int, Net]]:
    """
    Parse design netlist from JSON.

    Returns:
        design_cells: Dict[cell_name -> DesignCell]
        nets: Dict[net_id -> Net]
    """
    print(f"==> Parsing netlist: {json_path}")

    with open(json_path, 'r') as f:
        data = json.load(f)

    # Get top module — try explicit name first, then fall back to first non-empty module
    if 'sasic_top' in data['modules']:
        top_module = data['modules']['sasic_top']
    else:
        # Use first module with cells (skip empty wrapper modules)
        top_module = None
        for mod_name, mod_data in data['modules'].items():
            if mod_data.get('cells'):
                top_module = mod_data
                print(f"    Using module: {mod_name}")
                break
        if top_module is None:
            print("ERROR: No module with cells found in netlist JSON")
            sys.exit(1)

    # Parse design cells
    design_cells = {}
    for cell_name, cell_data in top_module['cells'].items():
        cell_type = cell_data['type']
        design_cells[cell_name] = DesignCell(cell_name, cell_type)

    # Parse nets
    nets = {}
    net_to_cells = defaultdict(list)

    # Build connectivity: net_id -> list of (cell_name, port)
    for cell_name, cell_data in top_module['cells'].items():
        for port, net_ids in cell_data['connections'].items():
            for net_id in net_ids:
                net_to_cells[net_id].append(cell_name)

    # Create Net objects
    for net_id, cell_names in net_to_cells.items():
        net = Net(net_id)
        for cell_name in set(cell_names):  # Remove duplicates
            if cell_name in design_cells:
                net.design_cells.append(design_cells[cell_name])
                design_cells[cell_name].nets.append(net_id)
        nets[net_id] = net

    print(f"    Found {len(design_cells)} design cells")
    print(f"    Found {len(nets)} nets")

    # Print cell type statistics
    type_counts = defaultdict(int)
    for cell in design_cells.values():
        type_counts[cell.cell_type] += 1

    print("    Design cell types:")
    for cell_type, count in sorted(type_counts.items()):
        print(f"      {cell_type}: {count}")

    return design_cells, nets


def parse_fabric_cells(yaml_path: str, fabric_yaml_path: str = None) -> Dict[str, List[FabricCell]]:
    """
    Parse fabric cells from YAML.

    Args:
        yaml_path: Path to fabric_cells_by_tile YAML (from gen_fabric_cells_by_tile.py)
        fabric_yaml_path: Path to fabric definition YAML (for cell type resolution).
                          If None, falls back to substring-based inference.

    Returns:
        fabric_by_type: Dict[cell_type -> List[FabricCell]]
    """
    print(f"==> Parsing fabric cells: {yaml_path}")

    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)

    # Build template->type map from fabric YAML if available
    tmpl_map = {}
    if fabric_yaml_path:
        tmpl_map = build_template_type_map(fabric_yaml_path)
        print(f"    Loaded {len(tmpl_map)} template->type mappings from {fabric_yaml_path}")

    fabric_cells = []
    tiles = data['fabric_cells_by_tile']['tiles']

    for tile_name, tile_data in tiles.items():
        for cell_data in tile_data['cells']:
            cell_name = cell_data['name']
            position = Position(cell_data['x'], cell_data['y'])

            # Resolve cell type from YAML template map
            cell_type = resolve_cell_type(cell_name, tmpl_map)

            # Extract row (R0, R1, R2, ...)
            parts = cell_name.split('__')
            row = parts[1].split('_')[0] if len(parts) > 1 else "R0"

            fabric_cell = FabricCell(cell_name, cell_type, position, tile_name, row)
            fabric_cells.append(fabric_cell)

    # Group by type
    fabric_by_type = defaultdict(list)
    for cell in fabric_cells:
        if cell.cell_type:  # Skip infrastructure cells
            fabric_by_type[cell.cell_type].append(cell)

    print(f"    Found {len(fabric_cells)} total fabric cells")
    print("    Fabric cell types (available for placement):")
    for cell_type, cells in sorted(fabric_by_type.items()):
        print(f"      {cell_type}: {len(cells)}")

    return fabric_by_type


def build_template_type_map(fabric_yaml_path: str) -> Dict[str, str]:
    """
    Build a mapping from template_name -> cell_type by reading the fabric YAML.
    This replaces fragile substring-based cell type inference.

    Returns:
        Dict[template_prefix -> sky130 cell type]
        e.g. {"R0_N2L": "sky130_fd_sc_hd__nand2_2", ...}
    """
    with open(fabric_yaml_path, 'r') as f:
        fab = yaml.safe_load(f)

    tmpl_map = {}
    for entry in fab['tile_definition']['cells']:
        tmpl = entry['template_name']
        cell_type = entry['cell_type']
        repeat = int(entry.get('repeat', 1))
        if repeat > 1:
            for i in range(repeat):
                tmpl_map[f"{tmpl}_{i}"] = cell_type
        else:
            tmpl_map[tmpl] = cell_type
    return tmpl_map


# Infrastructure cell types that are not available for placement
INFRA_TYPES = {
    'sky130_fd_sc_hd__tapvpwrvgnd_1',
    'sky130_fd_sc_hd__decap_3',
    'sky130_fd_sc_hd__decap_4',
    'sky130_fd_sc_hd__fill_1',
    'sky130_fd_sc_hd__clkbuf_4',
    'sky130_fd_sc_hd__and2_1',
    'sky130_fd_sc_hd__conb_1',
}


def resolve_cell_type(fabric_cell_name: str, tmpl_map: Dict[str, str]) -> str:
    """
    Resolve cell type from a fabric cell name using the template map.

    fabric_cell_name format: T{x}Y{y}__{template_name}
    Returns: sky130 cell type or None for infrastructure cells.
    """
    # Extract template portion: everything after "__"
    if '__' not in fabric_cell_name:
        return None
    tmpl_part = fabric_cell_name.split('__', 1)[1]

    cell_type = tmpl_map.get(tmpl_part)
    if cell_type is None:
        return None
    if cell_type in INFRA_TYPES:
        return None
    return cell_type


def parse_io_pins(yaml_path: str) -> Dict[str, IOPin]:
    """
    Parse I/O pins from YAML.

    Returns:
        io_pins: Dict[pin_name -> IOPin]
    """
    print(f"==> Parsing I/O pins: {yaml_path}")

    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)

    io_pins = {}
    pins_data = data['pin_placement']['pins']

    for pin_data in pins_data:
        name = pin_data['name']
        position = Position(pin_data['x_um'], pin_data['y_um'])
        direction = pin_data['direction']
        io_pins[name] = IOPin(name, position, direction)

    print(f"    Found {len(io_pins)} I/O pins")

    return io_pins


def link_nets_to_io_pins(nets: Dict[int, Net], io_pins: Dict[str, IOPin],
                         netlist_json: dict):
    """
    Link nets to I/O pins by analyzing top-level connections.
    """
    print("==> Linking nets to I/O pins...")

    # Find top module — try sasic_top, then first module with cells
    if 'sasic_top' in netlist_json['modules']:
        top_module = netlist_json['modules']['sasic_top']
    else:
        top_module = next(
            (m for m in netlist_json['modules'].values() if m.get('cells')),
            None
        )
        if top_module is None:
            print("ERROR: No module with cells found"); sys.exit(1)

    # Get port connections (maps port name to net ID)
    port_connections = {}
    if 'ports' in top_module:
        for port_name, port_data in top_module['ports'].items():
            if 'bits' in port_data:
                port_connections[port_name] = port_data['bits'][0]

    # Also check netnames
    if 'netnames' in top_module:
        for net_name, net_data in top_module['netnames'].items():
            if 'bits' in net_data and net_name in io_pins:
                net_id = net_data['bits'][0]
                if net_id in nets:
                    nets[net_id].io_pins.append(io_pins[net_name])
                    nets[net_id].name = net_name

    io_net_count = sum(1 for net in nets.values() if net.io_pins)
    print(f"    Linked {io_net_count} nets to I/O pins")




# =============================================================================
# Wirelength Computation (HPWL)
# =============================================================================

def compute_wirelength(assignment: Dict[str, FabricCell], nets: Dict[int, Net]) -> float:
    """
    Compute total wirelength (HPWL) for an assignment.
    Pure bounding-box metric without any weighting.
    
    Args:
        assignment: Dict[design_cell_name -> FabricCell]
        nets: Dict[net_id -> Net]
    
    Returns:
        Total wirelength in microns
    """
    total_wl = 0.0
    
    for net in nets.values():
        if len(net.design_cells) + len(net.io_pins) < 2:
            continue  # Skip single-pin nets
        
        positions = []
        
        # Add positions of assigned design cells
        for design_cell in net.design_cells:
            if design_cell.name in assignment:
                fabric_cell = assignment[design_cell.name]
                positions.append(fabric_cell.position)
        
        # Add positions of I/O pins (FIXED)
        for io_pin in net.io_pins:
            positions.append(io_pin.position)
        
        if len(positions) < 2:
            continue
        
        # Compute HPWL
        x_coords = [p.x for p in positions]
        y_coords = [p.y for p in positions]
        hpwl = (max(x_coords) - min(x_coords)) + (max(y_coords) - min(y_coords))
        total_wl += hpwl
    
    return total_wl


# =============================================================================
# Greedy Initial Assignment
# =============================================================================

def greedy_assignment(design_cells: Dict[str, DesignCell],
                     fabric_by_type: Dict[str, List[FabricCell]],
                     nets: Dict[int, Net],
                     io_pins: Dict[str, IOPin]) -> Dict[str, FabricCell]:
    """
    Greedy initial assignment with hybrid strategy:
    1. I/O-connected cells first (closest to I/O pins)
    2. Remaining cells by connectivity (incremental HPWL)
    
    Returns:
        assignment: Dict[design_cell_name -> FabricCell]
    """
    print("\n==> Computing initial assignment (Greedy algorithm)...")
    
    assignment = {}
    
    # Track used fabric cells per type
    used_fabric = {cell_type: set() for cell_type in fabric_by_type.keys()}
    
    # Build net connectivity: cell -> [other_cells_on_same_net]
    cell_connectivity = defaultdict(set)
    for net in nets.values():
        cells_in_net = [dc.name for dc in net.design_cells]
        for cell_name in cells_in_net:
            cell_connectivity[cell_name].update(cells_in_net)
            cell_connectivity[cell_name].discard(cell_name)  # Remove self
    
    # Classify cells: I/O-connected vs internal
    io_connected_cells = []
    internal_cells = []
    
    for cell in design_cells.values():
        has_io_connection = False
        for net_id in cell.nets:
            if len(nets[net_id].io_pins) > 0:
                has_io_connection = True
                break
        
        if has_io_connection:
            io_connected_cells.append(cell)
        else:
            internal_cells.append(cell)
    
    # Sort I/O-connected cells by number of I/O connections (descending)
    def count_io_connections(cell):
        count = 0
        for net_id in cell.nets:
            count += len(nets[net_id].io_pins)
        return count
    
    io_connected_cells.sort(key=count_io_connections, reverse=True)
    
    # Sort internal cells by connectivity (most connected first)
    internal_cells.sort(key=lambda c: len(cell_connectivity[c.name]), reverse=True)
    
    # Processing order: I/O-connected first, then internal
    ordered_cells = io_connected_cells + internal_cells
    
    print(f"    I/O-connected cells: {len(io_connected_cells)}")
    print(f"    Internal cells: {len(internal_cells)}")
    
    # Assign cells in order
    for idx, design_cell in enumerate(ordered_cells):
        cell_type = design_cell.cell_type
        
        if cell_type not in fabric_by_type:
            print(f"    WARNING: No fabric cells of type {cell_type}")
            continue
        
        # Get available fabric cells of this type
        available_fabric = [fc for fc in fabric_by_type[cell_type] 
                           if fc.name not in used_fabric[cell_type]]
        
        if not available_fabric:
            print(f"    ERROR: No available fabric cells for {cell_type}")
            sys.exit(1)
        
        # Find best fabric cell for this design cell
        best_fabric = None
        best_cost = float('inf')
        
        if design_cell in io_connected_cells:
            # Strategy: Minimize distance to connected I/O pins
            for fabric_cell in available_fabric:
                cost = 0.0
                for net_id in design_cell.nets:
                    net = nets[net_id]
                    for io_pin in net.io_pins:
                        distance = fabric_cell.position.distance(io_pin.position)
                        cost += distance
                
                if cost < best_cost:
                    best_cost = cost
                    best_fabric = fabric_cell
        else:
            # Strategy: Minimize incremental HPWL
            for fabric_cell in available_fabric:
                # Temporarily assign and compute incremental cost
                temp_assignment = assignment.copy()
                temp_assignment[design_cell.name] = fabric_cell
                
                # Compute wirelength of affected nets only
                cost = 0.0
                for net_id in design_cell.nets:
                    net = nets[net_id]
                    
                    positions = []
                    for dc in net.design_cells:
                        if dc.name in temp_assignment:
                            positions.append(temp_assignment[dc.name].position)
                    for io_pin in net.io_pins:
                        positions.append(io_pin.position)
                    
                    if len(positions) >= 2:
                        x_coords = [p.x for p in positions]
                        y_coords = [p.y for p in positions]
                        hpwl = (max(x_coords) - min(x_coords)) + (max(y_coords) - min(y_coords))
                        cost += hpwl
                
                if cost < best_cost:
                    best_cost = cost
                    best_fabric = fabric_cell
        
        # Assign
        assignment[design_cell.name] = best_fabric
        used_fabric[cell_type].add(best_fabric.name)
        
        # Progress report
        if (idx + 1) % 500 == 0:
            print(f"    Assigned {idx + 1}/{len(ordered_cells)} cells...")
    
    initial_wl = compute_wirelength(assignment, nets)
    print(f"    Initial wirelength: {initial_wl:.2f} µm")
    
    return assignment


# =============================================================================
# Simulated Annealing with Cell-Cell and Cell-Empty Swaps
# =============================================================================

def get_tile_from_fabric_cell(fabric_cell: FabricCell) -> Tuple[int, int]:
    """Extract tile coordinates from fabric cell name like 'T0Y89__R2_NAND_0'"""
    tile = fabric_cell.tile  # e.g., 'T0Y89'
    # Parse 'T{x}Y{y}'
    parts = tile.replace('T', '').split('Y')
    return (int(parts[0]), int(parts[1]))


def simulated_annealing_with_empty_moves(
        initial_assignment: Dict[str, FabricCell],
        design_cells: Dict[str, DesignCell],
        fabric_by_type: Dict[str, List[FabricCell]],
        nets: Dict[int, Net],
        max_iterations: int = 10000,
        t_init: float = None,
        t_final: float = 0.01,
        cooling_rate: float = 0.95,
        tile_radius: int = 3) -> Dict[str, FabricCell]:
    """
    Refine assignment using Simulated Annealing with two move types:
    1. Cell-cell swap (same type)
    2. Cell-empty swap (within tile radius, same type)
    """
    print("\n==> Refining assignment (Simulated Annealing)...")
    print(f"    Max iterations: {max_iterations}")
    print(f"    Tile radius for empty swaps: {tile_radius}")
    
    # Build reverse mapping: fabric_cell_name -> design_cell_name
    fabric_to_design = {v.name: k for k, v in initial_assignment.items()}
    
    # Track used fabric cells per type
    used_fabric = {cell_type: set() for cell_type in fabric_by_type.keys()}
    for fabric_cell in initial_assignment.values():
        used_fabric[fabric_cell.cell_type].add(fabric_cell.name)
    
    # Auto-estimate initial temperature if not provided
    if t_init is None:
        # Sample some moves to estimate scale
        sample_deltas = []
        temp_assignment = initial_assignment.copy()
        for _ in range(100):
            wl_before = compute_wirelength(temp_assignment, nets)
            # Random cell-cell swap
            cell_type = random.choice(list(used_fabric.keys()))
            cells_of_type = [c for c in design_cells.values() if c.cell_type == cell_type]
            if len(cells_of_type) >= 2:
                ca, cb = random.sample(cells_of_type, 2)
                fa, fb = temp_assignment[ca.name], temp_assignment[cb.name]
                temp_assignment[ca.name], temp_assignment[cb.name] = fb, fa
                wl_after = compute_wirelength(temp_assignment, nets)
                sample_deltas.append(abs(wl_after - wl_before))
                # Revert
                temp_assignment[ca.name], temp_assignment[cb.name] = fa, fb
        
        avg_delta = sum(sample_deltas) / len(sample_deltas) if sample_deltas else 1000
        t_init = -avg_delta / math.log(0.85)
        print(f"    Estimated T_init: {t_init:.2f} (avg_delta={avg_delta:.2f})")
    
    print(f"    Temperature: {t_init:.1f} → {t_final:.3f}")
    print(f"    Cooling rate: {cooling_rate}")
    
    current_assignment = initial_assignment.copy()
    best_assignment = current_assignment.copy()
    
    current_wl = compute_wirelength(current_assignment, nets)
    best_wl = current_wl
    
    # Group design cells by type
    cells_by_type = defaultdict(list)
    for cell in design_cells.values():
        cells_by_type[cell.cell_type].append(cell)
    
    T = t_init
    iteration = 0
    accepts = 0
    rejects = 0
    cell_cell_swaps = 0
    cell_empty_swaps = 0
    
    start_time = time.time()
    
    while T > t_final and iteration < max_iterations:
        # Multiple moves per temperature
        moves_per_temp = max(10, len(design_cells) // 10)
        
        for _ in range(moves_per_temp):
            iteration += 1
            
            # Choose move type: 50% cell-cell, 50% cell-empty
            if random.random() < 0.5:
                # MOVE TYPE 1: Cell-cell swap
                cell_type = random.choice(list(cells_by_type.keys()))
                cells_of_type = cells_by_type[cell_type]
                
                if len(cells_of_type) < 2:
                    continue
                
                cell_a, cell_b = random.sample(cells_of_type, 2)
                fabric_a = current_assignment[cell_a.name]
                fabric_b = current_assignment[cell_b.name]
                
                # Swap
                current_assignment[cell_a.name] = fabric_b
                current_assignment[cell_b.name] = fabric_a
                
                # Compute delta
                new_wl = compute_wirelength(current_assignment, nets)
                delta_wl = new_wl - current_wl
                
                # Accept or reject
                if delta_wl < 0 or random.random() < math.exp(-delta_wl / T):
                    current_wl = new_wl
                    accepts += 1
                    cell_cell_swaps += 1
                    if current_wl < best_wl:
                        best_wl = current_wl
                        best_assignment = current_assignment.copy()
                else:
                    # Reject - undo
                    current_assignment[cell_a.name] = fabric_a
                    current_assignment[cell_b.name] = fabric_b
                    rejects += 1
            else:
                # MOVE TYPE 2: Cell-empty swap (within tile radius)
                cell_type = random.choice(list(cells_by_type.keys()))
                cells_of_type = cells_by_type[cell_type]
                
                if not cells_of_type:
                    continue
                
                design_cell = random.choice(cells_of_type)
                current_fabric = current_assignment[design_cell.name]
                current_tile = get_tile_from_fabric_cell(current_fabric)
                
                # Find empty fabric cells of same type within tile radius
                available_empty = []
                for fabric_cell in fabric_by_type[cell_type]:
                    if fabric_cell.name in used_fabric[cell_type]:
                        continue  # Already used
                    
                    tile = get_tile_from_fabric_cell(fabric_cell)
                    manhattan_dist = abs(tile[0] - current_tile[0]) + abs(tile[1] - current_tile[1])
                    if manhattan_dist <= tile_radius:
                        available_empty.append(fabric_cell)
                
                if not available_empty:
                    continue  # No empty slots nearby
                
                new_fabric = random.choice(available_empty)
                
                # Swap
                current_assignment[design_cell.name] = new_fabric
                used_fabric[cell_type].remove(current_fabric.name)
                used_fabric[cell_type].add(new_fabric.name)
                
                # Compute delta
                new_wl = compute_wirelength(current_assignment, nets)
                delta_wl = new_wl - current_wl
                
                # Accept or reject
                if delta_wl < 0 or random.random() < math.exp(-delta_wl / T):
                    current_wl = new_wl
                    accepts += 1
                    cell_empty_swaps += 1
                    if current_wl < best_wl:
                        best_wl = current_wl
                        best_assignment = current_assignment.copy()
                else:
                    # Reject - undo
                    current_assignment[design_cell.name] = current_fabric
                    used_fabric[cell_type].remove(new_fabric.name)
                    used_fabric[cell_type].add(current_fabric.name)
                    rejects += 1
        
        # Cool down
        T *= cooling_rate
        
        # Progress report
        if iteration % 1000 == 0:
            elapsed = time.time() - start_time
            accept_rate = accepts / (accepts + rejects) if (accepts + rejects) > 0 else 0
            print(f"    Iter {iteration}: WL={current_wl:.2f}, Best={best_wl:.2f}, "
                  f"T={T:.3f}, Accept={accept_rate:.1%}, Time={elapsed:.1f}s")
    
    elapsed = time.time() - start_time
    initial_wl = compute_wirelength(initial_assignment, nets)
    improvement = ((initial_wl - best_wl) / initial_wl * 100) if initial_wl > 0 else 0
    
    print(f"    Final wirelength: {best_wl:.2f} µm")
    print(f"    Improvement: {improvement:.1f}%")
    print(f"    Runtime: {elapsed:.1f} seconds")
    print(f"    Accepts: {accepts} (cell-cell: {cell_cell_swaps}, cell-empty: {cell_empty_swaps})")
    print(f"    Rejects: {rejects}")
    
    return best_assignment


def write_yaml_output(assignment: Dict[str, FabricCell],
                     design_cells: Dict[str, DesignCell],
                     output_path: str):
    """Write assignment to YAML file"""
    print(f"\n==> Writing YAML output: {output_path}")

    placement_data = {
        'placement': {
            'version': '1.0',
            'num_cells': len(assignment),
            'cells': []
        }
    }

    for design_name in sorted(assignment.keys()):
        design_cell = design_cells[design_name]
        fabric_cell = assignment[design_name]

        cell_data = {
            'design_cell': design_name,
            'cell_type': design_cell.cell_type,
            'fabric_cell': fabric_cell.name,
            'tile': fabric_cell.tile,
            'row': fabric_cell.row,
            'position': {
                'x_um': round(fabric_cell.position.x, 6),
                'y_um': round(fabric_cell.position.y, 6)
            }
        }
        placement_data['placement']['cells'].append(cell_data)

    with open(output_path, 'w') as f:
        yaml.dump(placement_data, f, default_flow_style=False, sort_keys=False)

    print(f"    Wrote {len(assignment)} cell placements")


def write_def_output(assignment: Dict[str, FabricCell],
                    design_cells: Dict[str, DesignCell],
                    fabric_yaml_path: str,
                    output_path: str,
                    design_name: str = "sasic_top"):
    """Write assignment to DEF file."""
    print(f"\n==> Writing DEF output: {output_path}")

    # Read fabric info for die area computation
    with open(fabric_yaml_path, 'r') as f:
        fabric_data = yaml.safe_load(f)

    site_w = fabric_data['fabric_info']['site_dimensions_um']['width']
    site_h = fabric_data['fabric_info']['site_dimensions_um']['height']
    tiles_x = int(fabric_data['fabric_layout']['tiles_x'])
    tiles_y = int(fabric_data['fabric_layout']['tiles_y'])
    tile_w = int(fabric_data['tile_definition']['dimensions_sites']['width'])
    tile_h = int(fabric_data['tile_definition']['dimensions_sites']['height'])
    margin = 5.0  # µm
    die_width = int((tiles_x * tile_w * site_w + 2 * margin) * 1000)
    die_height = int((tiles_y * tile_h * site_h + 2 * margin) * 1000)

    with open(output_path, 'w') as f:
        f.write("VERSION 5.8 ;\n")
        f.write("DIVIDERCHAR \"/\" ;\n")
        f.write("BUSBITCHARS \"[]\" ;\n")
        f.write(f"DESIGN {design_name} ;\n")
        f.write("UNITS DISTANCE MICRONS 1000 ;\n\n")

        f.write(f"DIEAREA ( 0 0 ) ( {die_width} {die_height} ) ;\n\n")

        f.write(f"COMPONENTS {len(assignment)} ;\n")
        for cell_name in sorted(assignment.keys()):
            fabric_cell = assignment[cell_name]
            design_cell = design_cells[cell_name]

            # Convert to DBU
            x_dbu = int(fabric_cell.position.x * 1000)
            y_dbu = int(fabric_cell.position.y * 1000)

            # Determine orientation: odd rows are flipped (FS)
            row_match = re.search(r'_R(\d+)', fabric_cell.name)
            if row_match:
                orient = "FS" if int(row_match.group(1)) % 2 else "N"
            else:
                orient = "N"

            f.write(f"- {cell_name} {design_cell.cell_type}\n")
            f.write(f"  + PLACED ( {x_dbu} {y_dbu} ) {orient} ;\n")

        f.write("END COMPONENTS\n\n")
        f.write("END DESIGN\n")

    print(f"    Wrote {len(assignment)} components")




# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Structured ASIC Assignment Solver (Greedy + SA)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Place design with default parameters
  python tools/place.py --netlist output/arith/arith_mapped.json \
                        --fabric-cells output/fabric_2/fabric_cells.yaml \
                        --pins output/fabric_2/pins.yaml \
                        --out-yaml output/arith/placement.yaml \
                        --out-def output/arith/placement.def

  # Adjust SA parameters
  python tools/place.py --netlist output/aes_128/aes_128_mapped.json \
                        --fabric-cells output/fabric_2/fabric_cells.yaml \
                        --pins output/fabric_2/pins.yaml \
                        --out-yaml output/aes_128/placement.yaml \
                        --sa-iterations 20000 \
                        --tile-radius 5
        """
    )

    parser.add_argument('--netlist', required=True, help='Input netlist JSON file')
    parser.add_argument('--fabric-cells', required=True, help='Fabric cells YAML file')
    parser.add_argument('--fabric-yaml', help='Fabric definition YAML (for cell type resolution)')
    parser.add_argument('--pins', required=True, help='I/O pins YAML file')
    parser.add_argument('--out-yaml', required=True, help='Output placement YAML file')
    parser.add_argument('--out-def', help='Output placement DEF file (optional)')
    parser.add_argument('--top', default='sasic_top', help='Top module name for DEF output (default: sasic_top)')

    # Algorithm parameters
    parser.add_argument('--sa-iterations', type=int, default=10000,
                       help='SA iterations (default: 10000)')
    parser.add_argument('--sa-temp-init', type=float, default=None,
                       help='SA initial temperature (default: auto-estimate)')
    parser.add_argument('--sa-temp-final', type=float, default=0.01,
                       help='SA final temperature (default: 0.01)')
    parser.add_argument('--sa-cooling', type=float, default=0.95,
                       help='SA cooling rate (default: 0.95)')
    parser.add_argument('--tile-radius', type=int, default=3,
                       help='Tile radius for cell-empty swaps (default: 3)')

    args = parser.parse_args()

    print("=" * 80)
    print("Structured ASIC Assignment Solver (Greedy + SA)")
    print("=" * 80)

    start_time = time.time()

    # Parse inputs
    design_cells, nets = parse_netlist(args.netlist)
    fabric_by_type = parse_fabric_cells(args.fabric_cells, args.fabric_yaml)
    io_pins = parse_io_pins(args.pins)

    # Link nets to I/O pins
    with open(args.netlist, 'r') as f:
        netlist_json = json.load(f)
    link_nets_to_io_pins(nets, io_pins, netlist_json)

    # Check fabric resources
    print("\n==> Checking fabric resources...")
    for cell_type, design_cells_list in sorted({ct: [c for c in design_cells.values() if c.cell_type == ct] 
                                                for ct in set(c.cell_type for c in design_cells.values())}.items()):
        n_design = len(design_cells_list)
        n_fabric = len(fabric_by_type.get(cell_type, []))
        utilization = n_design / n_fabric * 100 if n_fabric > 0 else 0
        status = "OK" if n_design <= n_fabric else "ERROR"
        print(f"    {cell_type}: {n_design}/{n_fabric} ({utilization:.1f}%) [{status}]")

        if n_design > n_fabric:
            print(f"\nERROR: Not enough fabric resources for {cell_type}!")
            sys.exit(1)

    # Compute initial assignment (GREEDY)
    assignment = greedy_assignment(design_cells, fabric_by_type, nets, io_pins)

    # Refine with SA (always enabled)
    assignment = simulated_annealing_with_empty_moves(
        assignment, design_cells, fabric_by_type, nets,
        max_iterations=args.sa_iterations,
        t_init=args.sa_temp_init,
        t_final=args.sa_temp_final,
        cooling_rate=args.sa_cooling,
        tile_radius=args.tile_radius
    )

    # Write outputs
    write_yaml_output(assignment, design_cells, args.out_yaml)

    if args.out_def:
        write_def_output(assignment, design_cells, args.fabric_cells, args.out_def,
                         design_name=args.top)

    # Final statistics
    final_wl = compute_wirelength(assignment, nets)
    elapsed = time.time() - start_time

    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print(f"Design cells assigned: {len(assignment)}")
    print(f"Total wirelength: {final_wl:.2f} µm")
    print(f"Total runtime: {elapsed:.1f} seconds")
    print("=" * 80)

    print("\n✅ Assignment complete!")


if __name__ == '__main__':
    main()
