# SNS-TF-QKD sifter core: simulation, verification and synthesis
#
#   make test      quick check: golden model + Icarus testbench + counter comparison + ten-window trace
#   make regress   full regression: lint, python tests, test, directed, exhaustive (2**18 windows),
#                  24 constrained-random runs, 20 gap/reset runs, gate-level netlist, overflow-flag variant
#   make mutate    mutation test: inject 23 RTL faults, confirm the regression catches them (slow)
#   make cxxrtl    same comparison through a Yosys CXXRTL C++ model (the report's flow)
#   make synth     Yosys synth_xilinx resource estimate (xc7 family)
#   make clean
#
# Tools: python3, iverilog/vvp (Icarus Verilog), yosys + g++ (for cxxrtl, synth).
# Using the pip package yowasp-yosys instead of a native yosys:
#   make cxxrtl synth YOSYS=yowasp-yosys \
#        YOSYS_INC=$$(python3 -c "import yowasp_yosys,os;print(os.path.dirname(yowasp_yosys.__file__))")/share/include/backends/cxxrtl/runtime

PY       ?= python3
IVERILOG ?= iverilog
VVP      ?= vvp
YOSYS    ?= yosys
CXX      ?= g++
YOSYS_INC ?= $(shell $(YOSYS)-config --datdir 2>/dev/null)/include/backends/cxxrtl/runtime

$(shell mkdir -p build)
RTL   = rtl/sifter.v
STIM  = python/stim.txt
GOLD  = python/golden.json

.PHONY: test regress golden sim ten directed gaps ovf exh random gate lint pytest mutate cxxrtl synth clean
test: sim ten

regress: lint pytest test directed gaps exh random gate ovf

golden: $(GOLD)
$(GOLD) $(STIM): python/golden_model.py
	cd python && $(PY) golden_model.py

build/tb_sifter: $(RTL) tb/tb_sifter.v
	$(IVERILOG) -g2005 -o $@ $(RTL) tb/tb_sifter.v

sim: build/tb_sifter $(STIM) $(GOLD)
	$(VVP) build/tb_sifter +stim=$(STIM) +out=build/rtl_counters.json
	$(PY) python/compare_counters.py $(GOLD) build/rtl_counters.json

build/tb_ten: $(RTL) tb/tb_sifter_ten.v
	$(IVERILOG) -g2005 -o $@ $(RTL) tb/tb_sifter_ten.v

ten: build/tb_ten
	$(VVP) build/tb_ten | tee build/ten_window.log
	@grep -q "^PASS" build/ten_window.log

directed: $(RTL) tb/tb_sifter_directed.v
	$(IVERILOG) -g2005 -o build/tb_dir $(RTL) tb/tb_sifter_directed.v
	$(VVP) build/tb_dir | tee build/directed.log
	@grep -q "^PASS" build/directed.log

gaps: $(RTL) tb/tb_sifter_gaps.v
	./scripts/gaps_regress.sh $(RTL)

# optional variant with a sticky counter-overflow flag (see docs/OPTIMISATION.md)
ovf: rtl/variants/sifter_ovf.v tb/tb_sifter_ovf.v
	$(IVERILOG) -g2005 -o build/tb_ovf rtl/variants/sifter_ovf.v tb/tb_sifter_ovf.v
	$(VVP) build/tb_ovf | tee build/ovf.log
	@grep -q "^PASS" build/ovf.log

exh: $(RTL) tb/tb_sifter_exhaustive.v
	$(IVERILOG) -g2005 -o build/tb_exh $(RTL) tb/tb_sifter_exhaustive.v
	$(VVP) build/tb_exh > /dev/null
	$(PY) tests/check_exhaustive.py build/exh_trace.txt

random: $(RTL) tb/tb_sifter.v
	./scripts/random_regress.sh $(RTL)

# gate-level: generic gate netlist from Yosys (no vendor cells), same exhaustive and random tests
build/sifter_gate.v: $(RTL)
	$(YOSYS) -q -p "read_verilog $(RTL); synth -top sifter -flatten; abc -g AND,NAND,OR,NOR,XOR,XNOR,ANDNOT,ORNOT,MUX; opt_clean; write_verilog -noattr build/sifter_gate.v"

gate: build/sifter_gate.v
	$(IVERILOG) -g2005 -DGATE -o build/tb_gate_exh build/sifter_gate.v tb/tb_sifter_exhaustive.v
	$(VVP) build/tb_gate_exh > /dev/null
	$(PY) tests/check_exhaustive.py build/exh_trace.txt
	./scripts/random_regress.sh build/sifter_gate.v -DGATE
	./scripts/gaps_regress.sh build/sifter_gate.v -DGATE

# lint: Verilator -Wall (if installed) and Yosys structural checks
lint:
	@if command -v verilator >/dev/null 2>&1; then verilator --lint-only -Wall --top-module sifter $(RTL) && echo "verilator lint: clean"; else echo "verilator not installed, skipping"; fi
	$(YOSYS) -q -p "read_verilog -sv $(RTL); proc; check -assert; hierarchy -check -top sifter" && echo "yosys check: clean"

pytest:
	$(PY) tests/test_python.py

mutate:
	./scripts/mutation_test.sh

build/sifter.cc: $(RTL)
	$(YOSYS) -q -p "read_verilog $(RTL); write_cxxrtl -header build/sifter.cc"

build/tb_cxxrtl: build/sifter.cc tb/tb_cxxrtl.cc
	@test -f "$(YOSYS_INC)/cxxrtl/cxxrtl.h" || { echo "cxxrtl.h not found in '$(YOSYS_INC)': set YOSYS_INC (see top of Makefile)"; exit 1; }
	$(CXX) -std=c++14 -O2 -I build -I "$(YOSYS_INC)" tb/tb_cxxrtl.cc -o $@

cxxrtl: build/tb_cxxrtl $(STIM) $(GOLD)
	./build/tb_cxxrtl $(STIM) build/rtl_counters_cxxrtl.json
	$(PY) python/compare_counters.py $(GOLD) build/rtl_counters_cxxrtl.json

synth:
	$(YOSYS) -q -p "read_verilog $(RTL); synth_xilinx -top sifter; tee -o build/synth_stat.txt stat"
	@grep -E "CARRY4|FDRE|LUT|DSP|RAM" build/synth_stat.txt

clean:
	rm -rf build/* python/stim.txt python/golden.json
	touch build/.gitkeep
