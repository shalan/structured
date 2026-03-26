# Fabric Resource Usage Report

Generated: 2026-03-24

## Executive Summary

Analysis of 15 synthesized designs across 3 SASIC fabric definitions targeting SkyWater SKY130 HD.

---

## Fabric Specifications

### fabric_11x66 (default)

- **Tile**: 66 x 11 sites (30.4 x 29.9 um)
- **Grid**: 32 x 32 = 1,024 tiles
- **Functional capacity**: 333,824 site-widths
- **Target utilization**: 50-70% for optimal routability

| Cell | Width (sites) | Per Tile | Total Capacity |
|------|-------------:|--------:|--------------:|
| nand2_2 | 5 | 51 | 52,224 |
| nor2_2 | 5 | 21 | 21,504 |
| nand3_2 | 8 | 10 | 10,240 |
| inv_2 | 3 | 13 | 13,312 |
| buf_2 | 4 | 9 | 9,216 |
| dfbbp_1 | 26 | 4 | 4,096 |

### nand2_11x66 (NAND2-only, balanced v16.1)

- **Tile**: 66 x 11 sites (30.4 x 29.9 um)
- **Grid**: 32 x 32 = 1,024 tiles
- **Functional capacity**: 235,520 site-widths
- **Target utilization**: 50-70% for optimal routability

| Cell | Width (sites) | Per Tile | Total Capacity |
|------|-------------:|--------:|--------------:|
| nand2_2 | 5 | 66 | 67,584 |
| inv_2 | 3 | 19 | 19,456 |
| buf_2 | 4 | 5 | 5,120 |
| dfbbp_1 | 26 | 8 | 8,192 |

Changes from v16.0: +2 DFBBP, +5 INV, -3 BUF, -11 NAND2 per tile. Rebalanced to match observed NAND2:INV demand ratio (~3:1 vs previous 5.5:1).

### fabric (60x4)

- **Tile**: 60 x 4 sites (27.6 x 10.9 um)
- **Grid**: 36 x 90 = 3,240 tiles
- **Functional capacity**: ~100,000 site-widths
- **Target utilization**: 50-70% for optimal routability

| Cell | Width (sites) | Per Tile | Total Capacity |
|------|-------------:|--------:|--------------:|
| nand2_2 | 5 | 15 | 48,600 |
| or2_2 | 5 | 8 | 25,920 |
| clkinv_2 | 3 | 4 | 12,960 |
| clkbuf_4 | 6 | 3 | 9,720 |
| dfbbp_1 | 26 | 2 | 6,480 |
| conb_1 | 3 | 3 | 9,720 |

---

## Design Results — fabric_11x66

| Design | BUF | DFBBP | INV | NAND2 | NAND3 | NOR2 | Total | Area (sw) | Util% | Status |
|--------|----:|------:|----:|------:|------:|-----:|------:|----------:|------:|--------|
| arith | 67 | 11 | 53 | 115 | 54 | 115 | 415 | 2,304 | 0.7% | OK |
| tt_bit_serial_cpu | 130 | 111 | 125 | 606 | 151 | 302 | 1,425 | 9,538 | 2.9% | OK |
| vga_glyph_demo | 203 | 32 | 183 | 862 | 277 | 574 | 2,131 | 11,598 | 3.5% | OK |
| tt_spi_pwm | 335 | 146 | 113 | 653 | 139 | 401 | 1,787 | 11,866 | 3.6% | OK |
| uart_to_spi_bridge | 85 | 164 | 185 | 690 | 174 | 459 | 1,757 | 12,305 | 3.7% | OK |
| 6502 | 322 | 143 | 220 | 1,072 | 302 | 622 | 2,681 | 16,561 | 5.0% | OK |
| z80 | 78 | 160 | 539 | 2,965 | 1,197 | 3,155 | 8,094 | 46,274 | 13.9% | OK |
| tt_tiny_nn | 73 | 479 | 1,301 | 6,041 | 1,122 | 3,064 | 12,080 | 71,159 | 21.3% | OK |
| tt_uart_rv32i | 283 | 1,778 | 1,109 | 6,614 | 1,893 | 3,630 | 15,307 | 117,060 | 35.1% | OK |
| tt_sha256 | 223 | 1,621 | 2,220 | 11,478 | 4,120 | 5,527 | 25,189 | 167,692 | 50.2% | OK |
| frv32_soc | 474 | 5,812 | 1,428 | 28,810 | 2,391 | 8,046 | 46,961 | 360,709 | 108.1% | Over |
| soc | 798 | 6,375 | 4,281 | 25,711 | 6,360 | 22,320 | 65,845 | 472,829 | 141.6% | Over |
| aes_128 | 4,523 | 5,018 | 12,837 | 50,693 | 14,581 | 27,746 | 115,398 | 695,926 | 208.5% | Over |

**10 of 13 designs fit** within a single fabric_11x66 tile array.

### Utilization Visualization

```
Capacity: 333,824 site-widths (fabric_11x66)

arith             [#                                              ]   0.7%
tt_bit_serial_cpu [##                                             ]   2.9%
vga_glyph_demo    [##                                             ]   3.5%
tt_spi_pwm        [##                                             ]   3.6%
uart_to_spi_bridge[##                                             ]   3.7%
6502              [###                                            ]   5.0%
z80               [#######                                        ]  13.9%
tt_tiny_nn        [###########                                    ]  21.3%
tt_uart_rv32i     [##################                             ]  35.1%
tt_sha256         [#########################                      ]  50.2%
frv32_soc         [##################################################] 108.1% OVER
soc               [##################################################] 141.6% OVER
aes_128           [##################################################] 208.5% OVER
```

---

## Design Results — nand2_11x66 (v16.2)

Per-cell utilization showing how each design maps onto the NAND2-only fabric.

Capacity: NAND2=67,584 | INV=19,456 | BUF=5,120 | DFBBP=8,192

| Design | NAND2 | %cap | INV | %cap | BUF | %cap | DFBBP | %cap | Total | Util% | Status |
|--------|------:|-----:|----:|-----:|----:|-----:|------:|-----:|------:|------:|--------|
| arith | 308 | 0% | 163 | 1% | 67 | 1% | 11 | 0% | 549 | 0.4% | OK |
| tt_bit_serial_cpu | 1,178 | 2% | 407 | 2% | 130 | 3% | 111 | 1% | 1,826 | 1.7% | OK |
| tt_spi_pwm | 1,251 | 2% | 502 | 3% | 335 | 7% | 146 | 2% | 2,234 | 2.0% | OK |
| uart_to_spi_bridge | 1,437 | 2% | 774 | 4% | 85 | 2% | 164 | 2% | 2,460 | 2.2% | OK |
| vga_glyph_demo | 1,852 | 3% | 602 | 3% | 203 | 4% | 32 | 0% | 2,689 | 2.0% | OK |
| 6502 | 2,109 | 3% | 940 | 5% | 322 | 6% | 143 | 2% | 3,514 | 2.9% | OK |
| tt_warp | 6,461 | 10% | 2,700 | 14% | 717 | 14% | 261 | 3% | 10,139 | 8.0% | OK |
| z80 | 7,425 | 11% | 4,942 | 25% | 78 | 2% | 160 | 2% | 12,605 | 9.0% | OK |
| tt_tiny_nn | 10,470 | 15% | 3,797 | 20% | 73 | 1% | 479 | 6% | 14,819 | 12.1% | OK |
| tt_uart_rv32i | 13,833 | 20% | 5,483 | 28% | 283 | 6% | 1,778 | 22% | 21,377 | 21.1% | OK |
| tt_sha256 | 24,152 | 36% | 8,442 | 43% | 223 | 4% | 1,621 | 20% | 34,438 | 30.0% | OK |
| tt_kianv_rv32ima | 26,400 | 39% | 7,788 | 40% | 762 | 15% | 2,475 | 30% | 37,425 | 35.4% | OK |
| frv32_soc | 40,229 | 60% | 7,366 | 38% | 474 | 9% | 5,812 | 71% | 53,881 | 59.7% | OK |
| soc | 56,619 | 84% | 14,577 | 75% | 798 | 16% | 6,375 | 78% | 78,369 | 78.7% | OK |
| aes_128 | 92,715 | 137% | 19,569 | 101% | 4,523 | 88% | 5,018 | 61% | 121,825 | 106.5% | Over |

**14 of 15 designs fit.** Only aes_128 exceeds capacity (NAND2 at 137%).

### Design Descriptions

| Design | Description | FFs | Bottleneck |
|--------|-------------|----:|------------|
| arith | Arithmetic operations test | 11 | BUF 1% |
| tt_bit_serial_cpu | 8-bit bit-serial CPU | 111 | BUF 3% |
| tt_spi_pwm | SPI-controlled PWM generator | 146 | BUF 7% |
| uart_to_spi_bridge | UART-to-SPI bridge | 164 | INV 4% |
| vga_glyph_demo | VGA glyph renderer | 32 | BUF 4% |
| 6502 | 6502 8-bit microprocessor | 143 | BUF 6% |
| tt_warp | Demoscene VGA tunnel + music | 261 | BUF 14% |
| z80 | Z80 8-bit microprocessor | 160 | INV 25% |
| tt_tiny_nn | Tiny neural network inference | 479 | INV 20% |
| tt_uart_rv32i | UART-programmable RV32I RISC-V | 1,778 | INV 28% |
| tt_sha256 | SHA-256 hash processor | 1,621 | INV 43% |
| tt_kianv_rv32ima | KianV RV32IMA uLinux SoC | 2,475 | INV 40% |
| frv32_soc | FemtoRV32 SoC | 5,812 | DFBBP 71% |
| soc | System-on-Chip | 6,375 | NAND2 84% |
| aes_128 | AES-128 encryption core | 5,018 | NAND2 137% |

---

## Design Details

### Designs That Fit

**arith** (0.7%) — Arithmetic operations test. Minimal resource usage, excellent candidate for validation.

**tt_bit_serial_cpu** (2.9%) — 8-bit bit-serial CPU with shift-register ALU. Very compact sequential design.

**vga_glyph_demo** (3.5%) — VGA glyph renderer. Mostly combinational with small register file.

**tt_spi_pwm** (3.6%) — SPI-controlled PWM generator from Tiny Tapeout.

**uart_to_spi_bridge** (3.7%) — UART-to-SPI bridge. Balanced mix of control logic and shift registers.

**6502** (5.0%) — Classic 6502 8-bit microprocessor. Well-characterized, good benchmark.

**z80** (13.9%) — Z80 8-bit microprocessor. Larger than 6502, heavy NOR2 usage (3,155 cells). Monitor routing congestion.

**tt_tiny_nn** (21.3%) — Tiny neural network inference engine. High NAND2 (6,041) and NOR2 (3,064) usage for arithmetic.

**tt_uart_rv32i** (35.1%) — UART-programmable RV32I RISC-V core. 1,778 flip-flops for register file and pipeline.

**tt_warp** (8.0%) — Demoscene VGA tunnel effect with music synthesizer (Silice-generated). 261 flip-flops, CORDIC pipeline. Notable BUF usage (14%) from deep pipeline stages.

**tt_kianv_rv32ima** (35.4%) — Full RV32IMA core running uLinux with UART, QQSPI, CLINT, CSR, multiplier and divider. 2,475 flip-flops. Well-balanced utilization across all cell types (30-40%).

**tt_sha256** (30.0% on nand2_11x66, 45.0% on fabric_11x66) — SHA-256 hash processor. 1,621 flip-flops. Fits both fabrics.

**frv32_soc** (59.7% on nand2_11x66, Over on fabric_11x66) — RISC-V SoC. 5,812 flip-flops. Fits nand2_11x66 thanks to the additional DFBBP rows; does not fit fabric_11x66.

**soc** (78.7% on nand2_11x66, Over on fabric_11x66) — Larger SoC design. 6,375 flip-flops. Fits nand2_11x66 at 84% NAND2; does not fit fabric_11x66.

### Designs That Exceed All Fabric Capacities

**aes_128** (106.5% on nand2_11x66, 186.7% on fabric_11x66) — AES-128 encryption. NAND2 at 137% and INV at 101%. Would need bit-serial or time-multiplexed architecture to fit.

---

## Cell Type Distribution (All Designs)

| Cell Type | Total Count | % of All Cells |
|-----------|------------|---------------|
| NAND2 | 135,310 | 37.1% |
| NOR2 | 72,461 | 19.9% |
| NAND3 | 33,064 | 9.1% |
| INV | 24,493 | 6.7% |
| DFBBP (FF) | 21,850 | 6.0% |
| BUF | 7,594 | 2.1% |
| CONB | ~40 | <0.1% |

### Observations

1. **NAND2 dominance** (37.1%): Expected for NAND-mapped synthesis flows
2. **NOR2 prominence** (19.9%): fabric_11x66 benefits from dedicated NOR2 cells (absent in the 60x4 fabric)
3. **NAND3 usage** (9.1%): Reduces gate count for 3-input functions vs two NAND2 stages
4. **Sequential ratio**: ~6% DFBBP across all designs; ranges from 2.4% (arith) to 11.6% (tt_uart_rv32i)
5. **Buffer usage**: Low (2.1%), indicating good logic depth management by ABC

---

## Regenerating This Report

```bash
# Synthesize all designs
make synth

# Results are in designs/synth/*_mapped.json
# Cell counts can be extracted with:
python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
counts = {}
for m in d['modules'].values():
    for c in m['cells'].values():
        t = c['type']
        counts[t] = counts.get(t, 0) + 1
for k, v in sorted(counts.items(), key=lambda x: -x[1]):
    print(f'{k:40s} {v:6d}')
" designs/synth/<design>_11x66_mapped.json
```

---

**Fabric definitions:** `fabric/fabric_11x66.yaml`, `fabric/nand2_11x66.yaml`, `fabric/fabric.yaml`
**Designs analyzed:** 15
**Designs fitting fabric_11x66:** 10/13 | **Designs fitting nand2_11x66:** 14/15
