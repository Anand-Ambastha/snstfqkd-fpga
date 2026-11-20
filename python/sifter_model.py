#!/usr/bin/env python3
"""Independent reference model of the sifter core, plus a stimulus generator.

Written separately from golden_model.py (different structure, and the wrong-bit rule uses
math.cos instead of a lookup range) so that the two Python models and the RTL can be
cross-checked against each other.

Window tuple: (a_basis, b_basis, a_int, b_int, a_ph, b_ph, a_send, b_send, click1, click2)
basis 1 = Z, 0 = X.  Intensity codes 0..2 are legal; code 3 is outside the contract.

CLI:  python3 sifter_model.py random  --seed S --n N [--pbasis P --pclick P --psend P --pphase P] STIM EXPECTED
      python3 sifter_model.py exhaustive STIM            (all 2**18 raw input combinations)
      python3 sifter_model.py gaps --seed S --n N STIM EXPECTED   (random valid gaps, garbage data, random resets;
                                                                    12 columns: window, valid, rst)
"""
import json, math, random, sys

KEYS = ("n_total n_xm n_zm n_xint n_xacc n_xeff n_xerr n_int0 n_int1 n_int2 "
        "c_int0 c_int1 c_int2 n_zcat0 n_zcat1 n_zcat2 n_zcat3 n_zeff n_zerr").split()


def increments(w):
    """Counter increments caused by one window (dict of only the non-zero ones)."""
    ab, bb, ai, bi, ap, bp, sa, sb, c1, c2 = w
    inc = {"n_total": 1}
    if ab != bb:
        return inc
    eff = (c1 + c2) == 1
    if ab == 1:                                   # Z window
        inc["n_zm"] = 1
        cat = {(1, 0): 0, (0, 1): 1, (1, 1): 2, (0, 0): 3}[(sa, sb)]
        inc["n_zcat%d" % cat] = 1
        if eff:
            inc["n_zeff"] = 1
            if cat in (2, 3):
                inc["n_zerr"] = 1
        return inc
    inc["n_xm"] = 1                               # X window
    if ai != bi:
        return inc
    inc["n_xint"] = 1
    if ai in (0, 1, 2):
        inc["n_int%d" % ai] = 1
        if eff:
            inc["c_int%d" % ai] = 1
    if ai != 0 and ap == bp:
        inc["n_xacc"] = 1
        if eff:
            inc["n_xeff"] = 1
            d = (bp - ap) % 16
            cosneg = math.cos(2 * math.pi * d / 16) < -1e-9
            if (c1 and cosneg) or (c2 and not cosneg):
                inc["n_xerr"] = 1
    return inc


def count(rows, cw=32):
    c = dict.fromkeys(KEYS, 0)
    for w in rows:
        for k, v in increments(w).items():
            c[k] += v
    return {k: v % (1 << cw) for k, v in c.items()}


def gen_random(seed, n, pbasis=0.5, pclick=0.08, psend=0.3, pphase=0.4):
    r = random.Random(seed)
    rows = []
    for _ in range(n):
        ap = r.randrange(16)
        rows.append((int(r.random() < pbasis), int(r.random() < pbasis),
                     r.choice((0, 1, 1, 2, 2)), r.choice((0, 1, 1, 2, 2)),
                     ap, ap if r.random() < pphase else r.randrange(16),
                     int(r.random() < psend), int(r.random() < psend),
                     int(r.random() < pclick), int(r.random() < pclick)))
    return rows


def exhaustive_rows():
    """bit layout: [17]ab [16]bb [15:14]ai [13:12]bi [11:8]ap [7:4]bp [3]sa [2]sb [1]c1 [0]c2"""
    for i in range(1 << 18):
        yield ((i >> 17) & 1, (i >> 16) & 1, (i >> 14) & 3, (i >> 12) & 3,
               (i >> 8) & 15, (i >> 4) & 15, (i >> 3) & 1, (i >> 2) & 1, (i >> 1) & 1, i & 1)


def count_cycles(cycles, cw=32):
    """Cycle-accurate model with valid gaps and synchronous reset.
    Per clock edge: rst clears the counters and drops the window in stage 0 and the one being presented;
    otherwise the window in stage 0 (if any) is counted and the presented window moves into stage 0 if valid.
    cycles: iterable of (window, valid, rst).  A final idle cycle drains stage 0."""
    c = dict.fromkeys(KEYS, 0); pending = None
    for w, valid, rst in list(cycles) + [((0,) * 10, 0, 0)]:
        if rst:
            c = dict.fromkeys(KEYS, 0); pending = None
        else:
            if pending is not None:
                for k, v in increments(pending).items():
                    c[k] += v
            pending = w if valid else None
    return {k: v % (1 << cw) for k, v in c.items()}


def gen_gaps(seed, n, pvalid=0.7, prst=0.01):
    r = random.Random(seed)
    base = gen_random(seed + 1000, n, pclick=0.3)
    cyc = []
    for w in base:
        if r.random() < 0.02:                       # occasional long idle stretch with garbage on the pins
            for _ in range(r.randrange(2, 12)):
                cyc.append((tuple(r.randrange(m) for m in (2, 2, 4, 4, 16, 16, 2, 2, 2, 2)), 0, 0))
        cyc.append((w, int(r.random() < pvalid), int(r.random() < prst)))
    return cyc


def write_stim(path, rows):
    with open(path, "w") as f:
        for w in rows:
            f.write(" ".join(map(str, w)) + "\n")


def main(a):
    if len(a) >= 2 and a[1] == "exhaustive" and len(a) == 3:
        write_stim(a[2], exhaustive_rows()); return 0
    if len(a) >= 2 and a[1] == "random":
        import argparse
        p = argparse.ArgumentParser(); p.add_argument("mode")
        p.add_argument("--seed", type=int, default=1); p.add_argument("--n", type=int, default=32768)
        p.add_argument("--pbasis", type=float, default=0.5); p.add_argument("--pclick", type=float, default=0.08)
        p.add_argument("--psend", type=float, default=0.3); p.add_argument("--pphase", type=float, default=0.4)
        p.add_argument("stim"); p.add_argument("expected")
        x = p.parse_args(a[1:])
        rows = gen_random(x.seed, x.n, x.pbasis, x.pclick, x.psend, x.pphase)
        write_stim(x.stim, rows); json.dump(count(rows), open(x.expected, "w")); return 0
    if len(a) >= 2 and a[1] == "gaps":
        import argparse
        p = argparse.ArgumentParser(); p.add_argument("mode")
        p.add_argument("--seed", type=int, default=1); p.add_argument("--n", type=int, default=20000)
        p.add_argument("stim"); p.add_argument("expected")
        x = p.parse_args(a[1:])
        cyc = gen_gaps(x.seed, x.n)
        write_stim(x.stim, [tuple(w) + (v, r) for w, v, r in cyc])
        json.dump(count_cycles(cyc), open(x.expected, "w")); return 0
    print(__doc__); return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
