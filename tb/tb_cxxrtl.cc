// CXXRTL (Yosys) C++ testbench: the flow used for the report's Table 4.2.
// Reads a stimulus file (default python/stim.txt), drives one window per clock and
// writes the 19 final counters as JSON (same key order as python/golden.json).
//
//   yosys -p "read_verilog rtl/sifter.v; write_cxxrtl -header build/sifter.cc"
//   g++ -std=c++14 -O2 -I build -I <yosys-share>/include/backends/cxxrtl/runtime \
//       tb/tb_cxxrtl.cc -o build/tb_cxxrtl
//   build/tb_cxxrtl python/stim.txt build/rtl_counters_cxxrtl.json
#include <cstdio>
#include <cstdlib>
#include "sifter.cc"

int main(int argc, char **argv) {
    const char *stim = argc > 1 ? argv[1] : "python/stim.txt";
    const char *out  = argc > 2 ? argv[2] : "build/rtl_counters_cxxrtl.json";
    FILE *f = fopen(stim, "r");
    if (!f) { fprintf(stderr, "cannot open %s\n", stim); return 2; }

    cxxrtl_design::p_sifter top;
    auto tick = [&]() {
        top.p_clk.set<bool>(false); top.step();
        top.p_clk.set<bool>(true);  top.step();
    };

    top.p_rst.set<bool>(true);
    top.p_valid.set<bool>(false);
    for (int i = 0; i < 3; i++) tick();
    top.p_rst.set<bool>(false);

    int ab, bb, ai, bi, ap, bp, sa, sb, c1, c2, n = 0;
    while (fscanf(f, "%d %d %d %d %d %d %d %d %d %d", &ab, &bb, &ai, &bi, &ap, &bp, &sa, &sb, &c1, &c2) == 10) {
        top.p_a__basis.set<uint32_t>(ab); top.p_b__basis.set<uint32_t>(bb);
        top.p_a__int.set<uint32_t>(ai);   top.p_b__int.set<uint32_t>(bi);
        top.p_a__ph.set<uint32_t>(ap);    top.p_b__ph.set<uint32_t>(bp);
        top.p_a__send.set<uint32_t>(sa);  top.p_b__send.set<uint32_t>(sb);
        top.p_click1.set<uint32_t>(c1);   top.p_click2.set<uint32_t>(c2);
        top.p_valid.set<bool>(true);
        tick(); n++;
    }
    fclose(f);
    top.p_valid.set<bool>(false);
    for (int i = 0; i < 4; i++) tick();   // flush input register and counters

    FILE *o = fopen(out, "w");
    if (!o) { fprintf(stderr, "cannot write %s\n", out); return 2; }
    fprintf(o, "{");
#define C(key, member, last) fprintf(o, "\"" key "\": %u%s", top.p_##member.get<uint32_t>(), last ? "}\n" : ", ")
    C("n_total", n__total, 0);
    C("n_xm", n__xm, 0);
    C("n_zm", n__zm, 0);
    C("n_xint", n__xint, 0);
    C("n_xacc", n__xacc, 0);
    C("n_xeff", n__xeff, 0);
    C("n_xerr", n__xerr, 0);
    C("n_int0", n__int0, 0);
    C("n_int1", n__int1, 0);
    C("n_int2", n__int2, 0);
    C("c_int0", c__int0, 0);
    C("c_int1", c__int1, 0);
    C("c_int2", c__int2, 0);
    C("n_zcat0", n__zcat0, 0);
    C("n_zcat1", n__zcat1, 0);
    C("n_zcat2", n__zcat2, 0);
    C("n_zcat3", n__zcat3, 0);
    C("n_zeff", n__zeff, 0);
    C("n_zerr", n__zerr, 1);
#undef C
    fclose(o);
    printf("tb_cxxrtl: %d windows driven, counters written to %s\n", n, out);
    return 0;
}
