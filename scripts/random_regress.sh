#!/bin/sh
# Constrained-random regression: 24 runs of 32,768 windows with different seeds and
# stimulus statistics (basis bias, click probability, send probability, phase agreement).
# Compares RTL counters with the independent model. usage: scripts/random_regress.sh [rtl-file] [extra iverilog flags]
set -u
RTL=${1:-rtl/sifter.v}; FLAGS=${2:-}
W=build/rand; mkdir -p $W
iverilog -g2005 $FLAGS -o $W/tb $RTL tb/tb_sifter.v || exit 2
fail=0; n=0
for cfg in \
 "1 0.5 0.08 0.30 0.4"  "2 0.5 0.08 0.30 0.4"  "3 0.5 0.50 0.30 0.4"  "4 0.5 0.00 0.30 0.4" \
 "5 0.5 1.00 0.30 0.4"  "6 0.9 0.08 0.30 0.4"  "7 0.1 0.08 0.30 0.4"  "8 0.5 0.08 0.00 0.4" \
 "9 0.5 0.08 1.00 0.4"  "10 0.5 0.08 0.30 0.0" "11 0.5 0.08 0.30 1.0" "12 0.5 0.20 0.50 0.9" \
 "13 1.0 0.08 0.30 0.4" "14 0.0 0.08 0.30 0.4" "15 0.5 0.30 0.30 0.4" "16 0.7 0.40 0.10 0.6" \
 "17 0.3 0.02 0.80 0.2" "18 0.5 0.08 0.29 0.4" "19 0.6 0.15 0.45 0.7" "20 0.4 0.25 0.20 0.1" \
 "21 0.5 0.08 0.30 0.4" "22 0.8 0.35 0.60 0.95" "23 0.2 0.12 0.35 0.5" "24 0.5 0.05 0.25 0.35"; do
  set -- $cfg; n=$((n+1))
  python3 python/sifter_model.py random --seed $1 --n 32768 --pbasis $2 --pclick $3 --psend $4 --pphase $5 $W/stim.txt $W/expected.json
  vvp $W/tb +stim=$W/stim.txt +out=$W/rtl.json >/dev/null
  if python3 python/compare_counters.py $W/expected.json $W/rtl.json >/dev/null; then r=ok; else r=FAIL; fail=$((fail+1)); fi
  printf "  seed %-3s pbasis=%s pclick=%s psend=%s pphase=%s  %s\n" $1 $2 $3 $4 $5 $r
done
echo "random regression: $((n-fail)) / $n runs match"
[ $fail -eq 0 ]
