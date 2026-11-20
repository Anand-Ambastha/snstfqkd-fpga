# Synthesis results

Open-source Yosys flow, `synth_xilinx` (7-series family), target Zynq-7000 xc7z020 (PYNQ-Z2 class).
Reproduce with `make synth`. I/O buffers that Yosys reports (IBUF/OBUF/BUFG) are left out of the
table: in a real design the counters are read through AXI-Lite registers, not through pins.

## CW = 32 (default)

| Resource | Used | Available (xc7z020) | Utilisation |
| --- | --- | --- | --- |
| LUTs (LUT2 to LUT6) | 24 | 53,200 | 0.05% |
| Flip-flops (FDRE) | 627 | 106,400 | 0.59% |
| Carry cells (CARRY4) | 152 | 13,300 | 1.14% |
| Block RAM / DSP | 0 / 0 | 140 / 220 | 0% |

The 627 flip-flops are 608 counter bits (19 x 32) plus 19 input-register bits. The 152 carry cells
are 19 x 32 / 4.

## Against counter width

| CW (bits) | LUTs | Flip-flops | CARRY4 |
| --- | --- | --- | --- |
| 8 | 24 | 171 | 38 |
| 16 | 24 | 323 | 76 |
| 24 | 24 | 475 | 114 |
| 32 | 24 | 627 | 152 |
| 48 | 22 | 931 | 228 |
| 64 | 24 | 1,235 | 304 |

Flip-flops follow 19 x CW + 19, carry cells 19 x CW / 4, and the LUT count stays near 24.
A 17-bit counter already covers 131,071 windows.

## Caveats

Yosys numbers are synthesis estimates; Vivado may map the same logic slightly differently.
The 0.33 ms run time for 32,768 windows assumes a 100 MHz clock and is not a timing-closure result.
Place-and-route, timing, power, AXI-Lite wrapper, bitstream and a board run are not done yet.
