// Exhaustive test: every one of the 2**18 raw input combinations is driven as one window,
// back to back, and the 19 counters are written to build/exh_trace.txt once per clock.
// tests/check_exhaustive.py then checks the per-window counter deltas against the model.
//   iverilog -g2005 -o build/tb_exh rtl/sifter.v tb/tb_sifter_exhaustive.v && vvp build/tb_exh
`timescale 1ns/1ps
module tb_sifter_exhaustive;
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
    .a_ph(a_ph), .b_ph(b_ph), .a_send(a_send), .b_send(b_send), .click1(click1), .click2(click2),
    .n_total(n_total), .n_xm(n_xm), .n_zm(n_zm), .n_xint(n_xint), .n_xacc(n_xacc), .n_xeff(n_xeff), .n_xerr(n_xerr),
    .n_int0(n_int0), .n_int1(n_int1), .n_int2(n_int2), .c_int0(c_int0), .c_int1(c_int1), .c_int2(c_int2),
    .n_zcat0(n_zcat0), .n_zcat1(n_zcat1), .n_zcat2(n_zcat2), .n_zcat3(n_zcat3), .n_zeff(n_zeff), .n_zerr(n_zerr));
  always #5 clk = ~clk;
  integer f, i;
  reg tracing = 0;
  always @(posedge clk) if (tracing)
    $fwrite(f, "%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d\n",
      n_total, n_xm, n_zm, n_xint, n_xacc, n_xeff, n_xerr, n_int0, n_int1, n_int2, c_int0, c_int1, c_int2,
      n_zcat0, n_zcat1, n_zcat2, n_zcat3, n_zeff, n_zerr);
  initial begin
    f = $fopen("build/exh_trace.txt", "w");
    repeat (3) @(posedge clk); rst <= 0; @(posedge clk); tracing = 1;
    for (i = 0; i < (1 << 18); i = i + 1) begin
      valid <= 1;
      a_basis <= i[17]; b_basis <= i[16]; a_int <= i[15:14]; b_int <= i[13:12];
      a_ph <= i[11:8]; b_ph <= i[7:4]; a_send <= i[3]; b_send <= i[2]; click1 <= i[1]; click2 <= i[0];
      @(posedge clk);
    end
    valid <= 0;
    repeat (6) @(posedge clk);
    $fclose(f);
    $display("tb_sifter_exhaustive: %0d windows driven", 1 << 18);
    $finish;
  end
endmodule
