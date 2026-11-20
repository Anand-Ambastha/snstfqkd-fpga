#!/bin/sh
# Model-based test with random valid gaps, garbage data and random resets (default 20 seeds; SEEDS="1 2" to override).
# usage: scripts/gaps_regress.sh [rtl-file] [extra iverilog flags]
set -u
RTL=${1:-rtl/sifter.v}; FLAGS=${2:-}
W=build/gaps; mkdir -p $W
iverilog -g2005 $FLAGS -o $W/tb $RTL tb/tb_sifter_gaps.v || exit 2
SEEDS=${SEEDS:-1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20}
fail=0; n=0
for seed in $SEEDS; do
  n=$((n+1))
  python3 python/sifter_model.py gaps --seed $seed --n 20000 $W/stim.txt $W/expected.json
  vvp $W/tb +stim=$W/stim.txt +out=$W/rtl.json >/dev/null
  python3 python/compare_counters.py $W/expected.json $W/rtl.json >/dev/null || { fail=$((fail+1)); echo "  seed $seed FAIL"; }
done
echo "gaps/reset regression: $((n-fail)) / $n runs match"
[ $fail -eq 0 ]
