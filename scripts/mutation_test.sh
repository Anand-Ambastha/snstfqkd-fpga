#!/bin/sh
# Mutation test: inject one fault at a time into rtl/sifter.v and confirm the regression catches it.
# A surviving mutant means either a test gap or logic that cannot affect the counters.
# usage: scripts/mutation_test.sh   (needs iverilog, vvp, python3; run from the repo root)
set -u
RTL=rtl/sifter.v; W=build/mut; mkdir -p $W
[ -f python/stim.txt ] || (cd python && python3 golden_model.py)
killed=0; total=0
mut() {  # name, sed-expression
  name=$1; expr=$2; total=$((total+1))
  sed "$expr" $RTL > $W/m.v
  if cmp -s $RTL $W/m.v; then echo "  ! $name: sed expression did not change the file"; return; fi
  status=SURVIVED
  # exhaustive per-window check
  if iverilog -g2005 -o $W/m_exh $W/m.v tb/tb_sifter_exhaustive.v 2>/dev/null && vvp $W/m_exh >/dev/null 2>&1; then
    python3 tests/check_exhaustive.py build/exh_trace.txt >/dev/null 2>&1 || status=KILLED
  else status=KILLED; fi
  # directed tests
  if [ $status = SURVIVED ]; then
    iverilog -g2005 -o $W/m_dir $W/m.v tb/tb_sifter_directed.v 2>/dev/null
    vvp $W/m_dir 2>/dev/null | grep -q "^PASS" || status=KILLED
  fi
  # model-based gaps / reset test (3 seeds)
  if [ $status = SURVIVED ]; then
    SEEDS="1 2 3" ./scripts/gaps_regress.sh $W/m.v >/dev/null 2>&1 || status=KILLED
  fi
  [ $status = KILLED ] && killed=$((killed+1))
  printf "  %-8s %s\n" "$status" "$name"
}
mut "n_total counts without valid"     's/if (v)    n_total/if (1)    n_total/'
mut "X match ignores basis"            's/wire xm      = v \& bmatch \& ~ab;/wire xm      = v \& bmatch;/'
mut "Z match counts X windows"         's/wire zm      = v \& bmatch \&  ab;/wire zm      = v \& bmatch \& ~ab;/'
mut "intensity compare inverted"       's/wire imatch  = (ai == bi);/wire imatch  = (ai != bi);/'
mut "vacuum accepted"                  "s/(ai != 2'd0) \& (ap == bp)/(ap == bp)/"
mut "phase mismatch accepted"          "s/(ai != 2'd0) \& (ap == bp)/(ai != 2'd0)/"
mut "effective click = OR"             's/wire eff     = c1 ^ c2;/wire eff     = c1 | c2;/'
mut "effective click = AND"            's/wire eff     = c1 ^ c2;/wire eff     = c1 \& c2;/'
mut "wrong bit uses click1 only"       's/wire wrong   = (c1 \& cosneg) | (c2 \& ~cosneg);/wire wrong   = c1;/'
mut "wrong bit inverted"               's/wire wrong   = (c1 \& cosneg) | (c2 \& ~cosneg);/wire wrong   = (c2 \& cosneg) | (c1 \& ~cosneg);/'
mut "zcat A-only and B-only swapped"   "s/zm \&\& zcat==2'b10) n_zcat0/zm \&\& zcat==2'b01) n_zcat0/"
mut "Z error includes single sender"   "s/(zcat == 2'b11 || zcat == 2'b00)/(zcat == 2'b11 || zcat == 2'b00 || zcat == 2'b10)/"
mut "Z error misses both-sent"         "s/(zcat == 2'b11 || zcat == 2'b00)/(zcat == 2'b00)/"
mut "n_zeff counts non-effective"      's/if (zm \& eff)  n_zeff/if (zm)  n_zeff/'
mut "c_int1 counted on any click"      "s/n_int1 <= n_int1+1; if (eff) c_int1/n_int1 <= n_int1+1; if (c1) c_int1/"
mut "n_int2 bin uses code 1"           "s/if (xint \&\& ai==2'd2) begin n_int2/if (xint \&\& ai==2'd1) begin n_int2/"
mut "reset does not clear n_zerr"      's/n_zcat3<=0; n_zeff<=0; n_zerr<=0;/n_zcat3<=0; n_zeff<=0;/'
mut "phase compare 3 bits only"        "s/(ap == bp)/(ap[2:0] == bp[2:0])/"
mut "reset lets presented window in"   "s/if (rst) v <= 1.b0;/if (rst) v <= valid;/"
mut "input register skips valid"       's/v <= valid; ab <= a_basis;/v <= 1; ab <= a_basis;/'
mut "stage-0 click2 stuck"             's/c1 <= click1; c2 <= click2;/c1 <= click1; c2 <= 1;/'
# cosneg bounds: for accepted windows ap==bp so d is always 0 -> these are expected to survive
mut "cosneg lower bound 5->6 (equiv?)" "s/(d >= 4'd5)/(d >= 4'd6)/"
mut "cosneg always false (equiv?)"     's/wire cosneg  = (d >= 4.d5) \&\& (d <= 4.d11);/wire cosneg  = 1'"'"'b0;/'
echo "mutation score: $killed / $total killed"
