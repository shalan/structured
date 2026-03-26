#!/bin/bash
# Synthesize all SASIC designs for a given fabric
# Usage: ./tools/synthesize_all.sh [fabric_name]
#   fabric_name: base name under fabric/ (default: nand2_11x66)
#   Example: ./tools/synthesize_all.sh fabric_11x66

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

FABRIC_NAME="${1:-nand2_11x66}"
FABRIC_LIB="fabric/${FABRIC_NAME}.lib"
FABRIC_YAML="fabric/${FABRIC_NAME}.yaml"
TECHMAP="tech/techmap_2.v"
DESIGN_DIR="designs/src"
OUTPUT_DIR="designs/synth"

# Validate fabric files exist
if [ ! -f "$FABRIC_LIB" ]; then
    echo "ERROR: Liberty file not found: $FABRIC_LIB" >&2; exit 1
fi
if [ ! -f "$FABRIC_YAML" ]; then
    echo "ERROR: Fabric YAML not found: $FABRIC_YAML" >&2; exit 1
fi

# Per-design extra flags (associative array)
# Add entries here for designs that need special flags (e.g., --sv for SystemVerilog)
declare -A DESIGN_FLAGS
DESIGN_FLAGS["tt_warp.sv"]="--sv"
DESIGN_FLAGS["tt_mult_uart_spi.sv"]="--sv"

# Auto-discover designs: all .v and .sv files in DESIGN_DIR
DESIGNS=()
for f in "$DESIGN_DIR"/*.v "$DESIGN_DIR"/*.sv; do
    [ -f "$f" ] && DESIGNS+=("$(basename "$f")")
done

# Sort for deterministic order
IFS=$'\n' DESIGNS=($(sort <<<"${DESIGNS[*]}")); unset IFS

if [ ${#DESIGNS[@]} -eq 0 ]; then
    echo "ERROR: No design files found in $DESIGN_DIR/" >&2; exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "SASIC Design Synthesis — ${FABRIC_NAME}"
echo "========================================"
echo "Fabric LIB:  $FABRIC_LIB"
echo "Fabric YAML: $FABRIC_YAML"
echo "Techmap:     $TECHMAP"
echo "Designs:     ${#DESIGNS[@]} found in $DESIGN_DIR/"
echo "Output:      $OUTPUT_DIR"
echo "========================================"

RESULTS=()
PASS=0
FAIL=0

for design in "${DESIGNS[@]}"; do
    flags="${DESIGN_FLAGS[$design]:-}"
    ext="${design##*.}"
    name=$(basename "$design" ".$ext")
    out_tag="${name}_${FABRIC_NAME}"

    echo ""
    echo "========================================"
    echo "Synthesizing: $name ${flags:+($flags)}"
    echo "========================================"

    START_TIME=$(date +%s)

    if python3 tools/synth.py \
        -d "$DESIGN_DIR/$design" \
        -t sasic_top \
        -l "$FABRIC_LIB" \
        -m "$TECHMAP" \
        --fabric "$FABRIC_YAML" \
        -o "$OUTPUT_DIR/${out_tag}" \
        --flatten $flags \
        -v 2>&1 | tail -50; then
        EXIT_CODE=${PIPESTATUS[0]}
    else
        EXIT_CODE=$?
    fi

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    if [ $EXIT_CODE -eq 0 ]; then
        echo ""
        echo "OK $name: SUCCESS (${DURATION}s)"
        RESULTS+=("OK  $name (${DURATION}s)")
        PASS=$((PASS + 1))
    else
        echo ""
        echo "FAIL $name: FAILED (${DURATION}s)"
        RESULTS+=("FAIL $name (${DURATION}s)")
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "========================================"
echo "Synthesis Summary [${FABRIC_NAME}]: ${PASS} passed, ${FAIL} failed / ${#DESIGNS[@]} total"
echo "========================================"
for result in "${RESULTS[@]}"; do
    echo "  $result"
done
echo "========================================"
