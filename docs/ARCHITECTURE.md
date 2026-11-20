# Sifter core architecture

`rtl/sifter.v` implements the counting half of the post-processing pipeline (report Chapter 4).
It takes **one window per clock** and keeps 19 counters. Ratios, Wilson intervals, binary entropies
and the key rate R stay in software.

## Interface (`module sifter #(parameter CW = 32)`)

| Port | Width | Meaning |
| --- | --- | --- |
| `clk`, `rst` | 1 | Clock, synchronous reset (clears `v` and all counters) |
| `valid` | 1 | Window present this cycle |
| `a_basis`, `b_basis` | 1 | Basis choice, 1 = Z, 0 = X |
| `a_int`, `b_int` | 2 | Intensity code: 0 vacuum, 1 decoy 1, 2 decoy 2 |
| `a_ph`, `b_ph` | 4 | Phase slice (M = 16) |
| `a_send`, `b_send` | 1 | Z-window send decisions |
| `click1`, `click2` | 1 | Charlie's two detectors |
| 19 outputs | CW | Counters, listed below |

## Three stages

1. **Stage 0:** register the inputs (valid, 2 basis, 2 send, 2 click, 4 intensity, 8 phase = 19 bits).
2. **Stage 1 (combinational):** basis match; X windows (`xm`) and Z windows (`zm`); equal intensity;
   accepted window (`acc` = equal intensity, non-vacuum, equal phase slice); effective click
   (`click1 ^ click2`); wrong bit from the sign of cos(delta x 2pi/16), where delta = `b_ph - a_ph`;
   Z category from `{a_send, b_send}`.
3. **Stage 2:** update the 19 counters.

**Note on the wrong-bit rule.** Wrong-bit detection uses the sign of cos(delta x 2pi/16), but a window
is only *accepted* when the two phase slices are equal, so delta is always 0 for every window that can reach
`n_xerr`, and the cosine is always positive there. In the current design the rule therefore reduces to
"wrong bit = `click2`". The cosine branch is harmless and would matter only if the acceptance rule were relaxed
to allow unequal slices. Mutation testing confirms it: changing the cosine bounds changes no counter
(see `docs/TESTING.md`).

**Input contract.** Intensity codes 0 to 2 are legal. Code 3 is outside the contract: such an X window is counted
in `n_xint` and `n_xacc` but in no per-intensity bin (pinned by a directed test).

Latency: a window presented in cycle *k* reaches the counters in cycle *k + 1*.
A 32,768-window run takes about 32,770 cycles.

## Counters (report Table 4.1)

| Counter | Counts |
| --- | --- |
| `n_total` | All valid windows |
| `n_xm` / `n_zm` | Windows where both chose X / both chose Z |
| `n_xint` | X windows with equal intensity |
| `n_xacc` | Equal intensity, non-vacuum, equal phase slice (accepted) |
| `n_xeff` | Accepted windows with exactly one detector click |
| `n_xerr` | Effective accepted windows with the wrong bit (E_X numerator) |
| `n_int0`, `n_int1`, `n_int2` | Intensity-matched X windows at vacuum / decoy 1 / decoy 2 |
| `c_int0`, `c_int1`, `c_int2` | Of those, windows with an effective click |
| `n_zcat0` .. `n_zcat3` | Z windows: A only / B only / both sent / neither sent |
| `n_zeff` | Z windows with an effective click |
| `n_zerr` | Effective Z clicks in the both-sent or neither-sent categories |

## Hardware / software split (target: PYNQ-Z2 class Zynq-7000, xc7z020)

Python on the processing system packs windows, the core counts them in programmable logic, and
Python reads the counters back (over AXI-Lite, not yet implemented) to compute rates, Wilson
intervals, entropies and R. The core is meant for offline processing of logged windows, not for the
live 10 Gbit/s stream (a 100 ps window is far shorter than any fabric clock period).
