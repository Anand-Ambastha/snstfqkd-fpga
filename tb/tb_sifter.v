// Self-contained testbench: drives python/stim.txt through the sifter core
// (one window per clock) and writes the 19 final counters to rtl_counters.json,
// in the same key order as python/golden.json.
//
//   iverilog -g2005 -o build/tb_sifter rtl/sifter.v tb/tb_sifter.v
//   vvp build/tb_sifter +stim=python/stim.txt +out=build/rtl_counters.json
//
// stim.txt line format (written by python/golden_model.py):
//   a_basis b_basis a_int b_int a_ph b_ph a_send b_send click1 click2
`timescale 1ns/1ps
module tb_sifter;
  parameter CW = 32;
  reg clk = 0, rst = 1, valid = 0;
  reg a_basis = 0, b_basis = 0, a_send = 0, b_send = 0, click1 = 0, click2 = 0;
  reg [1:0] a_int = 0, b_int = 0;
  reg [3:0] a_ph = 0, b_ph = 0;

  wire [CW-1:0] n_total, n_xm, n_zm, n_xint, n_xacc, n_xeff, n_xerr;
  wire [CW-1:0] n_int0, n_int1, n_int2, c_int0, c_int1, c_int2;
  wire [CW-1:0] n_zcat0, n_zcat1, n_zcat2, n_zcat3, n_zeff, n_zerr;

`ifdef GATE
  sifter dut (
`else
  sifter #(.CW(CW)) dut (
`endif
    .clk(clk), .rst(rst), .valid(valid),
    .a_basis(a_basis), .b_basis(b_basis), .a_int(a_int), .b_int(b_int),
    .a_ph(a_ph), .b_ph(b_ph), .a_send(a_send), .b_send(b_send),
    .click1(click1), .click2(click2),
    .n_total(n_total), .n_xm(n_xm), .n_zm(n_zm), .n_xint(n_xint), .n_xacc(n_xacc),
    .n_xeff(n_xeff), .n_xerr(n_xerr),
    .n_int0(n_int0), .n_int1(n_int1), .n_int2(n_int2),
    .c_int0(c_int0), .c_int1(c_int1), .c_int2(c_int2),
    .n_zcat0(n_zcat0), .n_zcat1(n_zcat1), .n_zcat2(n_zcat2), .n_zcat3(n_zcat3),
    .n_zeff(n_zeff), .n_zerr(n_zerr));

  always #5 clk = ~clk;   // 100 MHz, illustrative only

  reg [1023:0] stim_name, out_name;
  integer fin, fout, rc, n;
  integer ab, bb, ai, bi, ap, bp, sa, sb, c1, c2;

  initial begin
    if (!$value$plusargs("stim=%s", stim_name)) stim_name = "python/stim.txt";
    if (!$value$plusargs("out=%s",  out_name))  out_name  = "build/rtl_counters.json";
    fin = $fopen(stim_name, "r");
    if (fin == 0) begin $display("ERROR: cannot open stimulus file"); $finish; end

    repeat (3) @(posedge clk);
    rst <= 0;
    n = 0;
    rc = $fscanf(fin, "%d %d %d %d %d %d %d %d %d %d\n", ab, bb, ai, bi, ap, bp, sa, sb, c1, c2);
    while (rc == 10) begin
      @(posedge clk);                     // present one window per clock
      valid <= 1; a_basis <= ab; b_basis <= bb; a_int <= ai; b_int <= bi;
      a_ph <= ap; b_ph <= bp; a_send <= sa; b_send <= sb; click1 <= c1; click2 <= c2;
      n = n + 1;
      rc = $fscanf(fin, "%d %d %d %d %d %d %d %d %d %d\n", ab, bb, ai, bi, ap, bp, sa, sb, c1, c2);
    end
    @(posedge clk); valid <= 0;
    repeat (4) @(posedge clk);            // flush: input register, then counters
    $fclose(fin);

    fout = $fopen(out_name, "w");
    $fwrite(fout, "{\"n_total\": %0d, \"n_xm\": %0d, \"n_zm\": %0d, \"n_xint\": %0d, \"n_xacc\": %0d, ", n_total, n_xm, n_zm, n_xint, n_xacc);
    $fwrite(fout, "\"n_xeff\": %0d, \"n_xerr\": %0d, \"n_int0\": %0d, \"n_int1\": %0d, \"n_int2\": %0d, ", n_xeff, n_xerr, n_int0, n_int1, n_int2);
    $fwrite(fout, "\"c_int0\": %0d, \"c_int1\": %0d, \"c_int2\": %0d, ", c_int0, c_int1, c_int2);
    $fwrite(fout, "\"n_zcat0\": %0d, \"n_zcat1\": %0d, \"n_zcat2\": %0d, \"n_zcat3\": %0d, \"n_zeff\": %0d, \"n_zerr\": %0d}\n", n_zcat0, n_zcat1, n_zcat2, n_zcat3, n_zeff, n_zerr);
    $fclose(fout);
    $display("tb_sifter: %0d windows driven, counters written to %0s", n, out_name);
    $finish;
  end
endmodule
