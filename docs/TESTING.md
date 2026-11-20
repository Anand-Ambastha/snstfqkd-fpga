# Testing

`make regress` runs everything below (about 3 minutes). `make test` is the 10-second smoke test.
`make mutate` adds the slow mutation test. CI runs `make regress` and the CXXRTL / synthesis check on every push.

Last full run (Icarus Verilog 12, Verilator 5.054, Yosys 0.71, Python 3.12): all of the following passed.

| # | Test | What it proves | Result |
| - | --- | --- | --- |
| 1 | Lint: Verilator `-Wall`, Yosys `check -assert` | No width, latch, driver or hierarchy problems | clean, 0 warnings |
| 2 | `tests/test_python.py` (unittest) | Independent model matches `golden_model.py` and report Table 4.2; Table 4.3 trace; counter invariants; `compare_counters.py` exit codes | 5 / 5 |
| 3 | `make sim`: report-style random run, RTL vs `golden.json` | Aggregate counters equal on 32,768 windows | 19 / 19 |
| 4 | `make ten`: report Table 4.3 trace | Cycle-by-cycle behaviour, self-checking | PASS |
| 5 | `make directed`: corner cases | valid gaps with garbage data, reset, reset with windows in flight, no X on outputs, counter wrap-around at CW = 4 (exactly 15 / 16 / 40 windows), out-of-contract intensity code 3 | PASS |
| 6 | `make exh`: **exhaustive** | All 2^18 = 262,144 raw input combinations, checked **per window** (counter delta of every window vs the model, so offsetting errors cannot hide) | 0 mismatches |
| 6b | `make gaps`: **model-based, random valid gaps, garbage data and random resets** | Cycle-accurate model of the two-stage pipeline (a reset drops the window in stage 0 and the one being presented); 20 runs x 20,000 cycles | 20 / 20 (RTL and gate-level) |
| 7 | `make random`: constrained random | 24 runs x 32,768 windows, varied seeds and statistics (basis bias 0 to 1, click probability 0 to 1, send probability 0 to 1, phase agreement 0 to 1) | 24 / 24 |
| 8 | `make gate`: **gate-level** | Yosys generic gate netlist (627 flip-flops, no vendor cells) passes the same exhaustive and random tests | 0 mismatches, 24 / 24 |
| 9 | `make cxxrtl`: CXXRTL C++ model | The report's own flow gives the same counters | 19 / 19 |
| 10 | `make synth` | 24 LUT, 627 FF, 152 CARRY4, 0 BRAM, 0 DSP (matches report Table 4.4) | match |
| 10b | `make ovf`: overflow-flag variant (`rtl/variants/sifter_ovf.v`) | `ovf` is low until the first counter wraps, then sticky until reset; the variant also passes the exhaustive, directed and gaps tests | PASS |
| 11 | Fresh `git clone` | `make test`, `make cxxrtl`, `make synth` work from a clean checkout and leave `git status` clean | pass |

## Independence of the references

The RTL is checked against two Python models: `golden_model.py` (the report's Appendix B) and
`sifter_model.py` (written separately: different structure, per-window increments, wrong-bit rule via
`math.cos`). They agree with each other and with the RTL.

## Mutation test (`make mutate`)

23 single faults are injected into `rtl/sifter.v` (inverted comparisons, swapped categories, wrong click rules,
reset not clearing a counter, truncated phase compare, stuck input, ...). **21 of 23 are caught.** The two survivors
change only the cosine-sign range in the wrong-bit rule. They are *equivalent mutants*: a window can only be
accepted when both phase slices are equal, so the slice difference is always 0 there and the cosine branch never
changes a counter (see the note in `docs/ARCHITECTURE.md`).

## Bugs found while testing the repository

* `build/` was git-ignored, so a fresh clone had no `build/` directory and `make` failed. Fixed (`build/.gitkeep`
  is now tracked and the Makefile creates the directory).
* **Test gap (found in a critic review, now closed):** a reset bug (reset lets the window presented in the same cycle
  into stage 0) passed the exhaustive and random tests, because they never reset or leave gaps. The new model-based
  `make gaps` test catches it (16 of 20 runs fail on that mutant).
* No functional bug was found in `rtl/sifter.v`.

## Not covered

* The real OptiSystem CSVs have not been run through the RTL (future work in the report).
* Timing closure, power, place-and-route and on-board behaviour are not tested (Vivado / PYNQ not available).
* Yosys numbers are synthesis estimates for the xc7 family; Vivado may differ slightly.
* The Python key-rate pipeline (`python/pipeline/`) is not part of this repository yet, so it has no tests here.
* The GitHub Actions workflow runs the same commands, but it has not been executed on GitHub yet.

## What the tests do not establish (critic's note)

The tests prove that the RTL implements the specification in `golden_model.py` / `sifter_model.py`.
They do not prove that the specification itself (the wrong-bit rule, the Z-error definition, the acceptance rule) is
the right physics: both models follow the report's Chapter 3 rules. The strongest remaining check is to run the real
OptiSystem CSVs through both the Python pipeline and the RTL and compare Q_X, E_X, Q_Z and QBER.
See also `docs/OPTIMISATION.md`.
