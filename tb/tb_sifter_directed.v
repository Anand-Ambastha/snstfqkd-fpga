// Directed corner-case tests: idle/valid gaps, reset behaviour, X-free outputs after reset,
// counter wrap-around at CW = 4, and the documented behaviour for out-of-contract intensity code 3.
//   iverilog -g2005 -o build/tb_dir rtl/sifter.v tb/tb_sifter_directed.v && vvp build/tb_dir
`timescale 1ns/1ps
module tb_sifter_directed;
  reg clk = 0, rst = 1, valid = 0;
  reg a_basis = 0, b_basis = 0, a_send = 0, b_send = 0, click1 = 0, click2 = 0;
  reg [1:0] a_int = 0, b_int = 0;
  reg [3:0] a_ph = 0, b_ph = 0;

  // CW = 32 instance
  wire [31:0] n_total, n_xm, n_zm, n_xint, n_xacc, n_xeff, n_xerr, n_int0, n_int1, n_int2;
  wire [31:0] c_int0, c_int1, c_int2, n_zcat0, n_zcat1, n_zcat2, n_zcat3, n_zeff, n_zerr;
  sifter #(.CW(32)) dut (.clk(clk), .rst(rst), .valid(valid),
    .a_basis(a_basis), .b_basis(b_basis), .a_int(a_int), .b_int(b_int), .a_ph(a_ph), .b_ph(b_ph),
    .a_send(a_send), .b_send(b_send), .click1(click1), .click2(click2),
    .n_total(n_total), .n_xm(n_xm), .n_zm(n_zm), .n_xint(n_xint), .n_xacc(n_xacc), .n_xeff(n_xeff), .n_xerr(n_xerr),
    .n_int0(n_int0), .n_int1(n_int1), .n_int2(n_int2), .c_int0(c_int0), .c_int1(c_int1), .c_int2(c_int2),
    .n_zcat0(n_zcat0), .n_zcat1(n_zcat1), .n_zcat2(n_zcat2), .n_zcat3(n_zcat3), .n_zeff(n_zeff), .n_zerr(n_zerr));
  // CW = 4 instance (wrap-around), same inputs
  wire [3:0] w_total, w_xm, w_zm, w_xint, w_xacc, w_xeff, w_xerr, w_int0, w_int1, w_int2;
  wire [3:0] w_cint0, w_cint1, w_cint2, w_zc0, w_zc1, w_zc2, w_zc3, w_zeff, w_zerr;
  sifter #(.CW(4)) dut4 (.clk(clk), .rst(rst), .valid(valid),
    .a_basis(a_basis), .b_basis(b_basis), .a_int(a_int), .b_int(b_int), .a_ph(a_ph), .b_ph(b_ph),
    .a_send(a_send), .b_send(b_send), .click1(click1), .click2(click2),
    .n_total(w_total), .n_xm(w_xm), .n_zm(w_zm), .n_xint(w_xint), .n_xacc(w_xacc), .n_xeff(w_xeff), .n_xerr(w_xerr),
    .n_int0(w_int0), .n_int1(w_int1), .n_int2(w_int2), .c_int0(w_cint0), .c_int1(w_cint1), .c_int2(w_cint2),
    .n_zcat0(w_zc0), .n_zcat1(w_zc1), .n_zcat2(w_zc2), .n_zcat3(w_zc3), .n_zeff(w_zeff), .n_zerr(w_zerr));

  always #5 clk = ~clk;
  integer errors = 0, i;

  task expect(input [255:0] name, input integer got, input integer exp);
    begin if (got !== exp) begin errors = errors + 1; $display("FAIL %0s: got %0d expected %0d", name, got, exp); end end
  endtask
  task win(input ab, input bb, input [1:0] ai, input [1:0] bi, input [3:0] ap, input [3:0] bp,
           input sa, input sb, input c1, input c2, input v);
    begin
      a_basis <= ab; b_basis <= bb; a_int <= ai; b_int <= bi; a_ph <= ap; b_ph <= bp;
      a_send <= sa; b_send <= sb; click1 <= c1; click2 <= c2; valid <= v; @(posedge clk);
    end
  endtask
  task flush; begin valid <= 0; repeat (4) @(posedge clk); end endtask
  task do_reset; begin rst <= 1; valid <= 0; repeat (3) @(posedge clk); rst <= 0; @(posedge clk); end endtask
  function allzero; input dummy; begin
    allzero = (n_total|n_xm|n_zm|n_xint|n_xacc|n_xeff|n_xerr|n_int0|n_int1|n_int2|c_int0|c_int1|c_int2|
               n_zcat0|n_zcat1|n_zcat2|n_zcat3|n_zeff|n_zerr) == 0; end endfunction
  function hasx; input dummy; begin
    hasx = ^{n_total,n_xm,n_zm,n_xint,n_xacc,n_xeff,n_xerr,n_int0,n_int1,n_int2,c_int0,c_int1,c_int2,
             n_zcat0,n_zcat1,n_zcat2,n_zcat3,n_zeff,n_zerr} === 1'bx; end endfunction

  initial begin
    // 1. outputs are never X after reset, and are all zero
    do_reset;
    if (hasx(0)) begin errors = errors + 1; $display("FAIL: X on outputs after reset"); end
    if (!allzero(0)) begin errors = errors + 1; $display("FAIL: counters not zero after reset"); end

    // 2. idle cycles with garbage on the data pins and valid = 0 never count
    for (i = 0; i < 100; i = i + 1)
      win($random, $random, $random, $random, $random, $random, $random, $random, $random, $random, 1'b0);
    flush;
    if (!allzero(0)) begin errors = errors + 1; $display("FAIL: counted while valid was low"); end

    // 3. valid windows interleaved with invalid garbage windows: only valid ones count
    for (i = 0; i < 8; i = i + 1) begin
      win(1,1,0,0,0,0,1,1,1,1, 1'b0);                     // would hit n_zm / n_zcat2 if counted
      win(0,0,1,1,3,3,0,0,1,0, 1'b1);                     // accepted, effective, correct
    end
    flush;
    expect("gap n_total", n_total, 8); expect("gap n_zm", n_zm, 0);
    expect("gap n_xacc", n_xacc, 8);   expect("gap n_xeff", n_xeff, 8); expect("gap n_xerr", n_xerr, 0);

    // 4. synchronous reset clears everything
    do_reset;
    if (!allzero(0)) begin errors = errors + 1; $display("FAIL: reset did not clear counters"); end

    // 5. reset with windows in flight: a window in stage 0 and one presented during reset are dropped,
    //    a window presented after reset is counted
    win(0,0,1,1,3,3,0,0,1,0, 1'b1);                         // W1, reaches stage 0
    rst <= 1; win(0,0,2,2,5,5,0,0,0,1, 1'b1);               // W2 presented while rst = 1 (W1 reset in stage 0)
    rst <= 0; win(0,0,1,1,6,6,0,0,1,0, 1'b1);               // W3 counted
    flush;
    expect("inflight n_total", n_total, 1); expect("inflight n_xacc", n_xacc, 1); expect("inflight n_int1", n_int1, 1);

    // 6. wrap-around: CW=4 counts modulo 16 while CW=32 keeps counting
    do_reset;
    for (i = 0; i < 40; i = i + 1) win(0,0,1,1,3,3,0,0,1,0, 1'b1);
    flush;
    expect("cw32 n_total", n_total, 40); expect("cw4 n_total (40 mod 16)", w_total, 8);
    expect("cw4 n_xacc", w_xacc, 8);     expect("cw4 n_xeff", w_xeff, 8);   expect("cw4 c_int1", w_cint1, 8);
    do_reset;
    for (i = 0; i < 16; i = i + 1) win(0,0,1,1,3,3,0,0,1,0, 1'b1);
    flush; expect("cw4 n_total after exactly 16", w_total, 0); expect("cw32 after 16", n_total, 16);
    do_reset;
    for (i = 0; i < 15; i = i + 1) win(0,0,1,1,3,3,0,0,1,0, 1'b1);
    flush; expect("cw4 n_total after 15", w_total, 15);

    // 7. out-of-contract intensity code 3 (documented): counted in n_xint / n_xacc, but in no per-intensity bin
    do_reset;
    win(0,0,3,3,2,2,0,0,1,0, 1'b1); flush;
    expect("code3 n_xint", n_xint, 1); expect("code3 n_xacc", n_xacc, 1);
    expect("code3 n_int0", n_int0, 0); expect("code3 n_int1", n_int1, 0); expect("code3 n_int2", n_int2, 0);

    // 8. no X reaches the outputs after a long random run
    do_reset;
    for (i = 0; i < 2000; i = i + 1)
      win($random, $random, $random, $random, $random, $random, $random, $random, $random, $random, 1'b1);
    flush;
    if (hasx(0)) begin errors = errors + 1; $display("FAIL: X on outputs after random run"); end

    if (errors == 0) $display("PASS: all directed tests");
    else             $display("FAIL: %0d directed-test errors", errors);
    $finish;
  end
endmodule
