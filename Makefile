TECHLEF      = tech/sky130_fd_sc_hd.tlef
SRC_DIR      = designs/src
SYNTH_DIR    = designs/synth

.PHONY: all synth clean gen-pins gen-cells gen-tile-images

all: synth

synth:
	./tools/synthesize_all.sh

# Generate pin placement YAML for a given fabric
# Usage: make gen-pins FABRIC=fabric/fabric_11x66.yaml
gen-pins:
	@test -n "$(FABRIC)" || (echo "Usage: make gen-pins FABRIC=fabric/<name>.yaml" && exit 1)
	python3 tools/gen_pins_yaml.py \
		--fabric $(FABRIC) \
		--techlef $(TECHLEF) \
		--out $(dir $(FABRIC))pins_$(notdir $(basename $(FABRIC))).yaml

# Generate tile-organized cell positions YAML for a given fabric
# Usage: make gen-cells FABRIC=fabric/fabric_11x66.yaml
gen-cells:
	@test -n "$(FABRIC)" || (echo "Usage: make gen-cells FABRIC=fabric/<name>.yaml" && exit 1)
	python3 tools/gen_fabric_cells_by_tile.py \
		--fabric $(FABRIC) \
		--out $(dir $(FABRIC))cells_$(notdir $(basename $(FABRIC))).yaml

# Generate tile layout images for all fabric definitions
gen-tile-images:
	python3 tools/draw-tile.py fabric/fabric_11x66.yaml -o docs/tile_11x66.png
	python3 tools/draw-tile.py fabric/nand2_11x66.yaml -o docs/tile_nand2_11x66.png

clean:
	rm -rf $(SYNTH_DIR) *.log techmap_whitelist.v __pycache__ tools/__pycache__
