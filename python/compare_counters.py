#!/usr/bin/env python3
"""Compare RTL counters against the Python golden model.

usage: python3 compare_counters.py golden.json rtl_counters.json
Exit code 0 if all 19 counters match, 1 otherwise.
"""
import json, sys

def main(argv):
    if len(argv) != 3:
        print(__doc__); return 2
    gold = json.load(open(argv[1])); rtl = json.load(open(argv[2]))
    bad = 0
    print(f"{'counter':<10}{'python':>10}{'rtl':>10}")
    for k in gold:
        ok = gold[k] == rtl.get(k)
        bad += not ok
        print(f"{k:<10}{gold[k]:>10}{str(rtl.get(k)):>10}{'' if ok else '   <-- MISMATCH'}")
    print("\nALL 19 COUNTERS MATCH" if not bad else f"\n{bad} MISMATCH(ES)")
    return 1 if bad else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
