#!/usr/bin/env python3
"""Per-window check of the RTL against the model for ALL 2**18 raw input combinations.

tb_sifter_exhaustive.v writes the 19 counters once per clock.  Window j's effect appears one
clock after window j-1's, so counter deltas between consecutive trace lines are compared with the
model's increments for each window.  Unlike an aggregate comparison, offsetting errors cannot hide.
usage: check_exhaustive.py build/exh_trace.txt
"""
import sys
sys.path.insert(0, __file__.rsplit("/", 2)[0] + "/python")
from sifter_model import KEYS, increments, exhaustive_rows

lines = [list(map(int, l.split())) for l in open(sys.argv[1]) if l.strip()]
k0 = next(i for i, l in enumerate(lines) if l[0] == 1)          # first line with n_total = 1
bad = 0
n = 0
for j, w in enumerate(exhaustive_rows()):
    prev, cur = lines[k0 + j - 1], lines[k0 + j]
    got = {k: cur[i] - prev[i] for i, k in enumerate(KEYS) if cur[i] != prev[i]}
    exp = increments(w)
    n += 1
    if got != exp:
        bad += 1
        if bad <= 10:
            print("MISMATCH window", j, w, "rtl", got, "model", exp)
final = lines[k0 + n - 1]
extra = lines[k0 + n:]                                          # after the last window: no further change
assert all(l == final for l in extra), "counters changed after the last window"
print(f"exhaustive: {n} windows checked, {bad} mismatches")
sys.exit(1 if bad else 0)
