// Ten-window hand-written stimulus (report Table 4.3) with a per-cycle counter log
// and a self-checking summary.  Window 0 is presented in cycle 0; its effect reaches
// the counters one clock later, and the final values appear at cycle 10.
//
//   iverilog -g2005 -o build/tb_ten rtl/sifter.v tb/tb_sifter_ten.v && vvp build/tb_ten
//   (add  +vcd  to also write build/tb_ten.vcd)
`timescale 1ns/1ps
module tb_sifter_ten;
  parameter CW = 32;
  reg clk = 0, rst = 1, valid = 0;
  reg a_basis = 0, b_basis = 0, a_send = 0, b_send = 0, click1 = 0, click2 = 0;
  reg [1:0] a_int = 0, b_int = 0;
  reg [3:0] a_ph = 0, b_ph = 0;

  wire [CW-1:0] n_total, n_xm, n_zm, n_xint, n_xacc, n_xeff, n_xerr;
  wire [CW-1:0] n_int0, n_int1, n_int2, c_int0, c_int1, c_int2;
  wire [CW-1:0] n_zcat0, n_zcat1, n_zcat2, n_zcat3, n_zeff, n_zerr;

  sifter #(.CW(CW)) dut (
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

  always #5 clk = ~clk;

  // basis: 1 = Z, 0 = X.  Z-window fields not used by X logic are driven as 0.
  task win(input ab, input bb, input [1:0] ai, input [1:0] bi, input [3:0] ap, input [3:0] bp,
           input sa, input sb, input c1, input c2);
    begin
      a_basis <= ab; b_basis <= bb; a_int <= ai; b_int <= bi; a_ph <= ap; b_ph <= bp;
      a_send <= sa; b_send <= sb; click1 <= c1; click2 <= c2; valid <= 1;
      @(posedge clk);
    end
  endtask

  integer cyc = 0, errors = 0;
  always @(posedge clk) if (!rst) begin
    $display("cyc %2d | total=%0d xm=%0d zm=%0d xint=%0d xacc=%0d xeff=%0d xerr=%0d zeff=%0d zerr=%0d",
             cyc, n_total, n_xm, n_zm, n_xint, n_xacc, n_xeff, n_xerr, n_zeff, n_zerr);
    cyc = cyc + 1;
  end

  task check(input [255:0] name, input integer got, input integer exp);
    begin
      if (got !== exp) begin errors = errors + 1; $display("MISMATCH %0s: got %0d, expected %0d", name, got, exp); end
    end
  endtask

  initial begin
    if ($test$plusargs("vcd")) begin $dumpfile("build/tb_ten.vcd"); $dumpvars(0, tb_sifter_ten); end
    repeat (3) @(posedge clk);
    rst <= 0;
    @(posedge clk);
    //   ab bb  ai  bi  ap  bp  sa sb c1 c2
    win(0, 0, 1, 1, 3, 3, 0, 0, 1, 0);   // 0 accepted, effective, correct bit
    win(0, 0, 2, 2, 5, 5, 0, 0, 0, 1);   // 1 accepted, effective, wrong bit
    win(1, 1, 0, 0, 0, 0, 1, 0, 1, 0);   // 2 Z, A only sent, effective
    win(1, 0, 0, 0, 0, 0, 0, 0, 0, 0);   // 3 basis mismatch: only n_total
    win(0, 0, 1, 2, 2, 6, 0, 0, 0, 1);   // 4 intensity mismatch: only n_xm
    win(1, 1, 0, 0, 0, 0, 1, 1, 1, 1);   // 5 Z, both sent, both click: not effective
    win(0, 0, 0, 0, 0, 0, 0, 0, 0, 0);   // 6 vacuum, intensity-matched, not accepted
    win(0, 0, 1, 1, 4, 9, 0, 0, 1, 0);   // 7 intensity match, phase mismatch
    win(1, 1, 0, 0, 0, 0, 0, 0, 1, 0);   // 8 Z, neither sent, effective: Z error
    win(0, 0, 2, 2, 7, 7, 0, 0, 1, 1);   // 9 accepted, both click: not effective
    valid <= 0;
    repeat (4) @(posedge clk);

    check("n_total", n_total, 10); check("n_xm", n_xm, 6);   check("n_zm", n_zm, 3);
    check("n_xint", n_xint, 5);    check("n_xacc", n_xacc, 3); check("n_xeff", n_xeff, 2);
    check("n_xerr", n_xerr, 1);    check("n_zeff", n_zeff, 2); check("n_zerr", n_zerr, 1);
    check("n_zcat0", n_zcat0, 1);  check("n_zcat2", n_zcat2, 1); check("n_zcat3", n_zcat3, 1);
    if (errors == 0) $display("PASS: ten-window trace matches the by-hand expectation");
    else             $display("FAIL: %0d mismatches", errors);
    $finish;
  end
endmodule
