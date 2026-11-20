# Verification

The three checks below reproduce the report. The complete test matrix (exhaustive, random, gate-level, mutation) is in `docs/TESTING.md`. These were run for this repository (Icarus Verilog 12, Yosys 0.71 / CXXRTL, Python 3.12).

| Check | Command | Result |
| --- | --- | --- |
| RTL (Icarus) vs Python golden model, 32,768 random windows | `make sim` | all 19 counters match |
| RTL (Yosys CXXRTL C++ model) vs Python golden model | `make cxxrtl` | all 19 counters match |
| Ten-window hand-written trace (report Table 4.3) | `make ten` | PASS |

`make test` runs the first and third; `make cxxrtl` needs Yosys and a C++ compiler.

## Random stimulus

`python/golden_model.py` (seed 7) writes `python/stim.txt`, one window per line:

```
a_basis b_basis a_int b_int a_ph b_ph a_send b_send click1 click2
```

The stimulus uses 50% basis choice, 40% phase-slice agreement and an 8% click probability per
detector, which exercises every branch of the decision logic. It then writes the expected 19 counters
to `python/golden.json`. `tb/tb_sifter.v` (Verilog) and `tb/tb_cxxrtl.cc` (C++) drive the same file
through the core and `python/compare_counters.py` compares the results.

Expected counters (match report Table 4.2): n_total 32,768; n_xm 8,164; n_zm 8,182; n_xint 2,935;
n_xacc 1,154; n_xeff 176; n_xerr 97; n_int0/1/2 313 / 1,331 / 1,291; c_int0/1/2 45 / 203 / 207;
n_zcat0..3 1,669 / 1,748 / 683 / 4,082; n_zeff 1,268; n_zerr 755.

## Ten-window trace

`tb/tb_sifter_ten.v` drives Table 4.3 and prints the counters after every clock. Final values:
n_total 10, n_xm 6, n_zm 3, n_xint 5, n_xacc 3, n_xeff 2, n_xerr 1, n_zeff 2, n_zerr 1.
Window 9 shows why n_xacc and n_xeff differ: both detectors clicked, so the window is accepted but
not an effective single click. Add `+vcd` to the `vvp` command to write `build/tb_ten.vcd` for a
waveform viewer.

## Scope

This is a check against random stimulus. It does not run the real OptiSystem CSVs through the RTL,
so it does not reproduce the Chapter 3 numbers. That test is listed under future work.
