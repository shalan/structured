#!/usr/bin/env python3
"""
synth.py — Yosys wrapper for structured ASIC flows

- Techmap whitelist written to CWD: ./techmap_whitelist.v
- ABC defaults to NO -script (matches your known-good bash flow). Use --abc-mode/--abc-script* to change.
- Optional flatten.
- Capacity & functional area (site-widths) from YAML; excludes tap/fill/decap and optionally conb.
- Fails if $lut appears after mapping.

Examples
--------
python synth.py -d test.v -t arithmetic_test_top -l fabric.lib -m arithmetic_fabric.v \
  --enable-only-generic "$_XOR_" --flatten --fabric fabric.yaml -v
"""

import argparse, os, shutil, subprocess, sys, tempfile, json, re
from pathlib import Path
from typing import Optional, List, Set, Tuple, Dict, Any

try:
    import yaml
except Exception:
    yaml = None

# ---------------- ABC presets (no rewrite/refactor/resub/ifraig) ----------------
ABC_BUILTINS = {
    "gate_default": None,  # -> NO -script
    "area_basic":   "strash; dch -f; dc2; balance; map -a; topo; stime;",
    "area_min":     "strash; dc2; map -a; topo; stime;",
}
ADVANCED_CMDS = re.compile(r"\b(rewrite|refactor|resub|ifraig)\b", re.IGNORECASE)

# ---------------- Regex helpers for techmap filtering ----------------
ATTR_PREFIX       = r'(?:\s*\(\*.*?\*\)\s*)*'
MODULE_RE         = re.compile(rf"(?ms)^\s*({ATTR_PREFIX}module\s+([A-Za-z_$][\w$]*)\b.*?endmodule)\s*")
TECHMAP_ATTR_FULL_RE = re.compile(
    r'\(\*\s*techmap_celltype\s*=\s*(["\'])([^"\']+)\1\s*\*\)', re.IGNORECASE
)

def canon_generic(name: str) -> str:
    return name.strip().lower().replace("$","").replace("_","").replace(" ","")

def split_attr_tokens(s: str) -> List[str]:
    return [t for t in re.split(r'[,\s]+', s.strip()) if t]

def extract_all_generics(text: str) -> Set[str]:
    gens: Set[str] = set()
    for m in TECHMAP_ATTR_FULL_RE.finditer(text):
        for tok in split_attr_tokens(m.group(2)):
            gens.add(canon_generic(tok))
    return gens

def rebuild_attr(attr_match: re.Match, enabled_norm: Set[str]) -> str:
    quote = attr_match.group(1)
    inner = attr_match.group(2)
    kept  = [t for t in split_attr_tokens(inner) if canon_generic(t) in enabled_norm]
    if not kept:
        return f'(* techmap_celltype = {quote}__EMPTY__{quote} *)'
    return f'(* techmap_celltype = {quote}{" ".join(kept)}{quote} *)'

# ---------------- CLI ----------------
def parse_csv_list(value: Optional[str]) -> List[str]:
    if not value: return []
    return [tok.strip() for tok in value.split(",") if tok.strip()]

def parse_args():
    env_liberty = os.getenv("LIBERTY_FILE", "fabric.lib")
    env_design  = os.getenv("DESIGN_FILES", "test.v")
    env_top     = os.getenv("TOP_MODULE", "arithmetic_test_top")
    env_techmap = os.getenv("TECHMAP_FILE", "arithmetic_fabric.v")
    env_output  = os.getenv("OUTPUT_NAME", "")

    p = argparse.ArgumentParser(
        formatter_class=argparse.RawTextHelpFormatter,
        description="Yosys synthesis wrapper with techmap whitelist gating and YAML-based capacity/area reporting."
    )
    # Core IO
    p.add_argument("-l","--liberty", default=env_liberty, help="Liberty for ABC mapping (not used for areas)")
    p.add_argument("-d","--design", nargs="+", default=env_design.split(), help="Design files")
    p.add_argument("-t","--top", default=env_top, help="Top module")
    p.add_argument("-m","--techmap", default=env_techmap, help="Techmap file (e.g., arithmetic_fabric.v)")
    p.add_argument("-o","--output", default=env_output, help="Output base (default: <top>)")
    p.add_argument("--dff-liberty", default=None, help="Liberty for dfflibmap (default: --liberty)")

    # ABC timing
    p.add_argument("--clock-period", type=float, default=None,
                   help="Clock period in ns; converted to ABC -D in ps (overrides --delay)")
    p.add_argument("-D","--delay", type=int, default=7500,
                   help="ABC -D value in ps (default 7500)")

    # ABC selection
    p.add_argument("--abc-noscript", action="store_true",
                   help="Force ABC with no -script (overrides --abc-mode/--abc-script*)")
    p.add_argument("--abc-mode", choices=list(ABC_BUILTINS.keys()), default="gate_default",
                   help="ABC preset (default 'gate_default' → NO -script)")
    p.add_argument("--abc-script-file", default=None, help="Path to an ABC script")
    p.add_argument("--abc-script", default=None, help="Inline ABC script string")
    p.add_argument("--allow-abc-advanced", action="store_true",
                   help="Allow rewrite/refactor/resub/ifraig in custom scripts")

    # Techmap gating (GENERICS)
    p.add_argument("--disable-generic", action="append", default=[],
                   help='Disable mapping for generic ops (repeat/CSV), e.g. "$add,$_XOR_"')
    p.add_argument("--enable-only-generic", default=None,
                   help='Allow ONLY these generic ops (CSV); others disabled; e.g. "$add,$_FA_"')
    p.add_argument("--disable-cell", action="append", default=[],
                   help="Skip mapping modules that instantiate these stdcells (repeat/CSV)")
    p.add_argument("--whitelist-out", default="techmap_whitelist.v",
                   help="Write the generated whitelist techmap here (default: ./techmap_whitelist.v)")

    # Reporting / filtering
    p.add_argument("--exclude-pattern", action="append",
                   default=["__tap", "__fill", "__decap"],
                   help="Substring patterns of cell types to EXCLUDE from stats & checks (repeatable). Default: __tap,__fill,__decap")
    p.add_argument("--count-conb-as-functional", action="store_true",
                   help="If set, conb cells ARE counted as functional area (default: excluded).")

    # Fabric YAML (required for capacity/area)
    p.add_argument("--fabric", dest="fabric_yaml", default=None,
                   help="Fabric YAML for capacity and site-width area calculations")

    # Buffer insertion
    p.add_argument("--insbuf-cell", default="sky130_fd_sc_hd__buf_2",
                   help="Cell for insbuf (default: sky130_fd_sc_hd__buf_2)")
    p.add_argument("--insbuf-in", default="A", help="Input pin name for insbuf cell (default: A)")
    p.add_argument("--insbuf-out", default="X", help="Output pin name for insbuf cell (default: X)")

    # Flow toggles
    p.add_argument("--flatten", action="store_true", help="Add explicit 'flatten'")
    p.add_argument("--no-techmap-filter", action="store_true",
                   help="Do NOT filter/whitelist the techmap file (debug)")
    p.add_argument("--sv", action="store_true", help="Enable SystemVerilog mode (read_verilog -sv)")
    p.add_argument("--echo-ys", action="store_true", help="Print generated Yosys script")
    p.add_argument("--keep-ys", action="store_true", help="Keep the temp .ys file")
    p.add_argument("--verbose", "-v", action="store_true", help="Verbose logging")
    return p.parse_args()

# ---------------- System helpers ----------------
def ensure_tools():
    if shutil.which("yosys") is None:
        print("ERROR: yosys not found in PATH", file=sys.stderr)
        sys.exit(1)

def load_text(p: Path) -> str:
    try:
        return p.read_text()
    except Exception as e:
        print(f"ERROR: cannot read file '{p}': {e}", file=sys.stderr); sys.exit(1)

def sanitize_script(script: Optional[str], allow_advanced: bool) -> Optional[str]:
    if not script: return script
    return script.strip().strip(";") if allow_advanced else ADVANCED_CMDS.sub("# \\g<1>", script).strip().strip(";")

def choose_abc_script(args) -> Optional[str]:
    if args.abc_noscript:
        return None
    if args.abc_script_file:
        return sanitize_script(load_text(Path(args.abc_script_file)), args.allow_abc_advanced)
    if args.abc_script:
        return sanitize_script(args.abc_script, args.allow_abc_advanced)
    builtin = ABC_BUILTINS.get(args.abc_mode)
    return sanitize_script(builtin, args.allow_abc_advanced) if builtin else None

# ---------------- Whitelist builder ----------------
def build_whitelist_techmap(techmap_path: Path,
                            enabled_generics_norm: Set[str],
                            disabled_stdcells: Set[str],
                            out_path: Path) -> Tuple[Path, List[str], List[str]]:
    """
    Create a techmap at out_path with:
      - helper modules (no techmap_celltype) kept intact,
      - mapping modules with techmap_celltype rewritten to only enabled tokens,
      - dropped if no enabled tokens remain,
      - excluding any module that instantiates a disabled stdcell token.
    """
    src = techmap_path.read_text()
    included: List[str] = []
    skipped: List[str] = []
    kept_blocks: List[str] = []

    for m in MODULE_RE.finditer(src):
        block   = m.group(1)
        modname = m.group(2)

        # Ban modules that instantiate forbidden stdcells (simple substring)
        if disabled_stdcells and any(cell in block for cell in disabled_stdcells):
            skipped.append(f"{modname} [contains disabled stdcell]")
            continue

        attrs = list(TECHMAP_ATTR_FULL_RE.finditer(block))
        if not attrs:
            kept_blocks.append(block if block.endswith("\n") else block + "\n")
            included.append(f"{modname} [helper/no_techmap_celltype]")
            continue

        new_block = block
        empty_after = True
        for am in reversed(attrs):
            rewritten = rebuild_attr(am, enabled_generics_norm)
            if "__EMPTY__" not in rewritten:
                empty_after = False
            s, e = am.span()
            new_block = new_block[:s] + rewritten + new_block[e:]

        if empty_after:
            skipped.append(f"{modname} [no enabled generics]")
            continue

        kept_blocks.append(new_block if new_block.endswith("\n") else new_block + "\n")
        first = TECHMAP_ATTR_FULL_RE.search(new_block)
        kept_tokens = split_attr_tokens(first.group(2)) if first else []
        included.append(f"{modname} [generics={','.join(kept_tokens)}]")

    out_path = out_path.resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if not kept_blocks:
        raise SystemExit("ERROR: Whitelist produced an empty techmap. Check enabled generics.")
    out_path.write_text("// Whitelist techmap generated by synth.py\n" + "".join(kept_blocks))
    return out_path, included, skipped

# ---------------- YAML capacity + site-width “areas” ----------------
def _coerce_width_sites(val: Any) -> Optional[int]:
    """Accept dict{'width_sites': N} | int | float | '5' | 'width_sites: 5' -> int or None."""
    if isinstance(val, dict):
        w = val.get("width_sites")
        if isinstance(w, (int, float)): return int(round(w))
        return None
    if isinstance(val, (int, float)):
        return int(round(val))
    if isinstance(val, str):
        # Try to extract the first integer-like number in the string
        m = re.search(r'[-+]?\d+(\.\d+)?', val)
        if m:
            f = float(m.group(0))
            return int(round(f))
    return None

def load_fabric_from_yaml(yaml_path: Path) -> Tuple[Dict[str,int], Dict[str,int]]:
    """Return (capacity_counts, cell_site_widths) from YAML."""
    if yaml is None:
        print("ERROR: PyYAML is required for --fabric (pip install pyyaml)", file=sys.stderr)
        sys.exit(1)
    fab = yaml.safe_load(yaml_path.read_text())
    tiles_x = int(fab["fabric_layout"]["tiles_x"])
    tiles_y = int(fab["fabric_layout"]["tiles_y"])
    total_tiles = tiles_x * tiles_y

    # Per-tile counts → capacity
    per_tile: Dict[str,int] = {}
    for cell in fab["tile_definition"]["cells"]:
        ctype = cell["cell_type"]
        repeat = int(cell.get("repeat", 1))
        per_tile[ctype] = per_tile.get(ctype, 0) + repeat
    capacity = {k: v * total_tiles for k, v in per_tile.items()}

    # Site-widths from fabric_info.cell_definitions (robust coercion)
    site_widths: Dict[str,int] = {}
    #defs = (fab.get("fabric_info", {}) or {}).get("cell_definitions", {}) or {}
    defs = fab.get("cell_definitions", {}) or {}
    bad: List[str] = []
    for ctype, info in defs.items():
        w = _coerce_width_sites(info)
        if w is None:
            bad.append(ctype)
        else:
            site_widths[ctype] = w
    if bad:
        print(f"Note: {len(bad)} cell types in YAML had no usable width_sites; "
              f"skipping in area totals (e.g., {', '.join(bad[:5])}{'...' if len(bad)>5 else ''})")
    return capacity, site_widths

def is_excluded(cell_type: str, exclude_patterns: List[str], count_conb_as_functional: bool) -> bool:
    lc = cell_type.lower()
    if not count_conb_as_functional and "conb" in lc:
        return True  # treat conb as non-functional unless opted-in
    return any(pat.lower() in lc for pat in exclude_patterns)

def print_usage_with_capacity_yaml(usage: Dict[str,int],
                                   capacity: Dict[str,int],
                                   site_widths: Dict[str,int],
                                   exclude_patterns: List[str],
                                   count_conb_as_functional: bool):
    print("\nResources vs Capacity (excluding non-functional classes):")
    keys = sorted(k for k in (set(usage) | set(capacity))
                  if not is_excluded(k, exclude_patterns, count_conb_as_functional))

    over = False
    for k in keys:
        used = usage.get(k, 0); total = capacity.get(k, 0)
        if total > 0:
            pct = int(round(used / total * 100))
            line = f"{k:32s} : {used}/{total} ({pct}%)"
        else:
            line = f"{k:32s} : {used}/0 (n/a)"
        if total and used > total:
            line += "  **OVER**"; over = True
        print("  " + line)

    # Functional area utilization (in site-width units)
    used_sw = 0
    cap_sw  = 0
    missing: List[str] = []
    for k in keys:
        w = site_widths.get(k)
        if w is None:
            missing.append(k)
            continue
        used_sw += usage.get(k, 0) * w
        cap_sw  += capacity.get(k, 0) * w

    if cap_sw > 0:
        pct_area = used_sw / cap_sw * 100.0
        print(f"\nFunctional area utilization (site-widths): {used_sw}/{cap_sw} ({pct_area:.1f}%)")
    else:
        print("\nFunctional area utilization: capacity area = 0 (check YAML).")

    if missing:
        missing.sort()
        print(f"Note: {len(missing)} cell types missing width_sites in YAML; skipped in area totals.")
        print(missing)

    if over:
        print("\nERROR: Fabric capacity violations detected.")
    else:
        print("\nCapacity check: OK ✅")

# ---------------- Yosys script builder & runner ----------------
def build_yosys_script(designs: List[str], top: str, techmap: str, liberty: str, dff_liberty: str,
                       delay_ps: int, flatten: bool, outbase: str,
                       abc_script: Optional[str],
                       insbuf_cell: str = "sky130_fd_sc_hd__buf_2",
                       insbuf_in: str = "A", insbuf_out: str = "X",
                       sv: bool = False) -> str:
    sv_flag = " -sv" if sv else ""
    reads = "\n".join(f'read_verilog{sv_flag} "{f}"' for f in designs)
    flatten_block = "flatten\nopt_clean -purge\nopt\n" if flatten else ""

    if abc_script:
        esc = abc_script.replace('"','\\"')
        abc_line = f'abc -liberty "{liberty}" -D {delay_ps} -script "{esc}"'
    else:
        abc_line = f'abc -liberty "{liberty}" -D {delay_ps}'

    return f"""\
# Auto-generated Yosys synthesis script (techmap whitelist)

log =========================================================================
log Arithmetic-Optimized Synthesis for Structured ASIC
log =========================================================================

# Read design files
{reads}

# Elaborate
hierarchy -check -top {top}

log
log Statistics before synthesis:
stat

# High-level synthesis
proc; opt
fsm; opt
memory; opt

# Arithmetic extraction
log =========================================================================
log Arithmetic Extraction - Identifying Addition Patterns
log =========================================================================
alumacc
opt

log
log After arithmetic extraction:
stat

# Technology-independent mapping
techmap
opt

# Read liberty for DFF context
read_liberty -lib "{dff_liberty}"

# Arithmetic technology mapping
log =========================================================================
log Arithmetic Technology Mapping
log =========================================================================
log Using techmap file: {techmap}
techmap -map "{techmap}"
opt

# Optional flatten
{flatten_block}\
# Constant mapping
hilomap -singleton \\
  -hicell sky130_fd_sc_hd__conb_1 HI \\
  -locell sky130_fd_sc_hd__conb_1 LO

# Checks + flop mapping
check -assert

opt
opt_clean -purge
wreduce

stat -tech cmos
log Mapping flip-flops...
dfflibmap -liberty "{dff_liberty}"
opt

# ABC (no -script by default)
log =========================================================================
log Combinational Logic Mapping ABC
log =========================================================================
{abc_line}

# Cleanup
opt_clean -purge
opt
opt_expr
opt
opt_clean -purge
#splitnets -ports
opt_clean -purge
opt -full
opt_clean -purge

insbuf -buf {insbuf_cell} {insbuf_in} {insbuf_out}

hilomap -singleton \\
  -hicell sky130_fd_sc_hd__conb_1 HI \\
  -locell sky130_fd_sc_hd__conb_1 LO

# Final stats
log =========================================================================
log Final Cell Usage Analysis
log =========================================================================
stat -liberty "{liberty}"

# Outputs
write_verilog -noattr -noexpr -nohex "{outbase}_mapped.v"
write_blif "{outbase}_mapped.blif"
write_json "{outbase}_mapped.json"
"""

def run_yosys(ys_text: str, echo_ys: bool, keep_ys: bool) -> int:
    temp = None
    try:
        with tempfile.NamedTemporaryFile("w", delete=False, suffix=".ys") as tf:
            temp = tf.name
            tf.write(ys_text)
        if echo_ys:
            print("\n===== BEGIN YOSYS SCRIPT =====\n" + ys_text + "\n=====  END YOSYS SCRIPT  =====\n")
        print(f"Running Yosys with script: {temp}\n")
        with open("synthesis.log", "w") as logf:
            proc = subprocess.Popen(["yosys", temp],
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    text=True, bufsize=1)
            assert proc.stdout
            for line in proc.stdout:
                sys.stdout.write(line)
                logf.write(line)
            return proc.wait()
    finally:
        if temp and Path(temp).exists() and not keep_ys:
            try: Path(temp).unlink()
            except Exception: pass

# ---------------- Usage & capacity ----------------
def count_cells_from_json(json_path: Path) -> Tuple[Dict[str,int], int]:
    data = json.loads(json_path.read_text())
    counts: Dict[str,int] = {}
    modules = data.get("modules") or {}
    for m in modules.values():
        for c in (m.get("cells") or {}).values():
            t = c.get("type")
            if t: counts[t] = counts.get(t, 0) + 1
    return counts, len(modules)

# ---------------- Main ----------------
def main():
    args = parse_args()
    ensure_tools()

    liberty     = Path(args.liberty)
    dff_lib     = Path(args.dff_liberty) if args.dff_liberty else liberty
    techmap     = Path(args.techmap)
    designs     = [Path(f) for f in args.design]
    top         = args.top
    outbase     = args.output or top
    fabric_yaml = Path(args.fabric_yaml) if args.fabric_yaml else None

    for f in designs:
        if not f.is_file(): print(f"ERROR: missing design: {f}", file=sys.stderr); sys.exit(1)
    if not liberty.is_file(): print(f"ERROR: missing liberty: {liberty}", file=sys.stderr); sys.exit(1)
    if not techmap.is_file(): print(f"ERROR: missing techmap: {techmap}", file=sys.stderr); sys.exit(1)
    if not dff_lib.is_file(): print(f"ERROR: missing dff liberty: {dff_lib}", file=sys.stderr); sys.exit(1)
    if not fabric_yaml or not fabric_yaml.is_file():
        print("ERROR: --fabric YAML is required for capacity/area reporting.", file=sys.stderr); sys.exit(1)

    delay_ps = args.delay if args.clock_period is None else int(round(args.clock_period * 1000.0))

    # Generic gating inputs
    disable_generic_raw: Set[str] = set()
    for entry in args.disable_generic:
        disable_generic_raw.update(parse_csv_list(entry))
    enable_only_raw: Set[str] = set(parse_csv_list(args.enable_only_generic)) if args.enable_only_generic else set()

    disable_generic_norm: Set[str] = {canon_generic(x) for x in disable_generic_raw}
    enable_only_norm: Set[str]     = {canon_generic(x) for x in enable_only_raw}

    # Optional stdcell gating
    disabled_stdcells: Set[str] = set()
    for entry in args.disable_cell:
        disabled_stdcells.update(parse_csv_list(entry))

    # ABC script (None => no -script)
    abc_script = choose_abc_script(args)

    # Build whitelist techmap if requested
    filtered_techmap = techmap
    included_info: List[str] = []
    skipped_info: List[str] = []
    if not args.no_techmap_filter:
        src_text = load_text(techmap)
        all_generics = extract_all_generics(src_text)
        need_whitelist = False
        enabled_norm: Set[str] = set()

        if enable_only_norm:
            enabled_norm = set(enable_only_norm)
            need_whitelist = True
        elif disable_generic_norm:
            enabled_norm = set(all_generics) - set(disable_generic_norm)
            need_whitelist = True

        if need_whitelist:
            whitelist_path = Path(args.whitelist_out)
            filtered_techmap, included_info, skipped_info = build_whitelist_techmap(
                techmap_path=techmap,
                enabled_generics_norm=enabled_norm,
                disabled_stdcells=disabled_stdcells,
                out_path=whitelist_path
            )
            print(f"[info] Using techmap whitelist: {filtered_techmap}")
            if included_info:
                print("[info] Included techmap modules:")
                for s in included_info: print("  +", s)
            if skipped_info:
                print("[info] Skipped techmap modules:")
                for s in skipped_info: print("  -", s)

    if args.verbose:
        print("="*72)
        print("Arithmetic-Optimized Synthesis (Python)")
        print("="*72)
        print(f"Liberty File (ABC):     {liberty}")
        print(f"DFF Liberty:            {dff_lib}")
        print(f"Techmap File:           {techmap}")
        if filtered_techmap != techmap:
            print(f"Techmap Whitelist:      {filtered_techmap}")
        print(f"Design Files:           {' '.join(str(p) for p in designs)}")
        print(f"Top Module:             {top}")
        print(f"Output Base:            {outbase}")
        print(f"ABC:                    {'NO -script' if not abc_script else 'custom -script'}  |  -D {delay_ps} ps")
        if enable_only_raw:
            print(f"Enable-only generic:    {', '.join(sorted(enable_only_raw))}")
        if disable_generic_raw:
            print(f"Disabled generic:       {', '.join(sorted(disable_generic_raw))}")
        if disabled_stdcells:
            print(f"Disabled stdcells:      {', '.join(sorted(disabled_stdcells))}")
        print(f"Flatten:                {'ON' if args.flatten else 'OFF (match Bash)'}")
        print(f"Fabric YAML:            {fabric_yaml}")
        print(f"Exclude patterns:       {', '.join(args.exclude_pattern)} "
              f"(conb {'IN' if args.count_conb_as_functional else 'OUT'})")
        print("="*72+"\n")

    # Build & run Yosys
    ys_text = build_yosys_script(
        designs=[str(p) for p in designs],
        top=top, techmap=str(filtered_techmap),
        liberty=str(liberty), dff_liberty=str(dff_lib),
        delay_ps=delay_ps, flatten=args.flatten, outbase=outbase,
        abc_script=abc_script,
        insbuf_cell=args.insbuf_cell, insbuf_in=args.insbuf_in, insbuf_out=args.insbuf_out,
        sv=args.sv
    )
    ret = run_yosys(ys_text, echo_ys=args.echo_ys, keep_ys=args.keep_ys)
    if ret != 0:
        print("\nERROR: Synthesis failed. See synthesis.log", file=sys.stderr); sys.exit(ret)

    # Usage & capacity
    json_path = Path(f"{outbase}_mapped.json")
    if not json_path.is_file():
        print("WARNING: JSON netlist not found; skipping capacity/area check.", file=sys.stderr)
        return
    usage, modcnt = count_cells_from_json(json_path)
    print(f"\nModules in JSON: {modcnt}")

    if any(k.startswith("$lut") or k == "$lut" for k in usage):
        print("\nERROR: Detected $lut in result.", file=sys.stderr)
        print("ABC likely failed to load/match liberty or a LUT-oriented script was used.", file=sys.stderr)
        sys.exit(3)

    print("\nMapped cell usage (by type):")
    for c, n in sorted(usage.items()):
        print(f"  {c:32s} : {n}")

    capacity, site_widths = load_fabric_from_yaml(fabric_yaml)
    print_usage_with_capacity_yaml(
        usage=usage,
        capacity=capacity,
        site_widths=site_widths,
        exclude_patterns=args.exclude_pattern,
        count_conb_as_functional=args.count_conb_as_functional
    )
    # Violation exit code (ignoring excluded classes)
    def not_excluded(k: str) -> bool:
        return not is_excluded(k, args.exclude_pattern, args.count_conb_as_functional)
    if any(usage.get(k,0) > capacity.get(k,0) for k in usage if not_excluded(k)):
        sys.exit(2)

    print("\nSUCCESS: Synthesis and checks completed.")

if __name__ == "__main__":
    main()
