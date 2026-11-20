# Optimisation review

Measured with Yosys `synth_xilinx` (xc7 family) on the validated core (`rtl/sifter.v`, CW = 32).
All numbers are synthesis estimates; Vivado may differ slightly.

| Variant | LUT | FF | CARRY4 | Verdict |
| --- | --- | --- | --- | --- |
| Baseline (as in the report) | 24 | 627 | 152 | reference |
| Remove the cos(delta) logic (wrong bit = `click2`) | 24 | 627 | 152 | no gain: Yosys already removes it, because accepted windows always have delta = 0. Source-level cleanup only |
| Remove the stage-0 input register | 24 | 608 | 152 | -19 FF, but loses registered inputs (timing and I/O robustness). Not recommended |
| Drop `n_zm` and `n_xint` (host computes them: n_zm = sum of `n_zcat0..3`, n_xint = sum of `n_int0..2`) | 22 | 563 | 136 | -10%. Changes the 19-counter interface of the report, so not shipped. Keep `n_total`: it is the overflow sentinel (below) |
| CW = 16 (enough for up to 65,535 windows) | 24 | 323 | 76 | **-48% FF and CARRY4**, the biggest lever. Needs overflow protection |
| CW = 17 (up to 131,071 windows) | 24 | 342 | 95 | -45% |
| Add sticky overflow flag `ovf` (`rtl/variants/sifter_ovf.v`) | 33 | 628 | 152 | +1 FF, +9 LUT. Shipped as an optional variant, tested |

## Why the overflow flag only watches `n_total`

Every counter increments at most once per valid window, and every increment condition includes `valid`, so no counter
can wrap before `n_total` does. One sticky flag on `n_total` therefore protects all 19 counters. This is also why
`n_total` is the one "redundant" counter worth keeping. Without it, a too-small CW wraps silently.

## Critic's conclusions

1. **Area is not the problem.** The whole core uses under 1.2% of any resource on the xc7z020. Squeezing LUTs and
   flip-flops further has no practical value on this device. If you want savings, choose CW from the run length
   (CW = 16 for 32,768 windows) and pair it with the overflow flag.
2. **Not worth doing:** time-multiplexing the counters (cannot sustain one window per clock) and pipelining the counters
   (the 32-bit carry chains are short at 100 MHz; but Fmax has not been measured, because that needs Vivado).
3. **Worth doing next, in this order:**
   1. Run the real OptiSystem CSVs through the RTL and the Python pipeline and compare Q_X, E_X, Q_Z, QBER. This is the
      only test that checks the specification itself and not just the implementation.
   2. Build the AXI-Lite wrapper with an atomic counter read (snapshot or stop-then-read). Reading 19 free-running
      counters one by one while windows stream in would give inconsistent values.
   3. Place and route in Vivado to get real timing, power and utilisation.
   4. Adopt the overflow flag (or a CW matched to the run length) in the integrated design.
4. **Cosmetic:** the cos(delta) wrong-bit logic is unreachable for accepted windows (see `docs/ARCHITECTURE.md`). It is
   harmless, and keeping it matches the report. Mention it if an examiner asks why the logic has no effect.
