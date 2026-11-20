// Test for rtl/variants/sifter_ovf.v: ovf is low until the first counter wraps, then sticky until reset.
//   iverilog -g2005 -o build/tb_ovf rtl/variants/sifter_ovf.v tb/tb_sifter_ovf.v && vvp build/tb_ovf
`timescale 1ns/1ps
module tb_sifter_ovf;
  reg clk = 0, rst = 1, valid = 0, c1 = 1;
  wire ovf4, ovf32; wire [3:0] t4; wire [31:0] t32;
  // CW = 4 and CW = 32 instances, X/X accepted effective windows
  sifter #(.CW(4)) d4 (.clk(clk), .rst(rst), .valid(valid), .a_basis(1'b0), .b_basis(1'b0), .a_int(2'd1), .b_int(2'd1),
    .a_ph(4'd3), .b_ph(4'd3), .a_send(1'b0), .b_send(1'b0), .click1(c1), .click2(1'b0), .ovf(ovf4), .n_total(t4));
  sifter #(.CW(32)) d32 (.clk(clk), .rst(rst), .valid(valid), .a_basis(1'b0), .b_basis(1'b0), .a_int(2'd1), .b_int(2'd1),
    .a_ph(4'd3), .b_ph(4'd3), .a_send(1'b0), .b_send(1'b0), .click1(c1), .click2(1'b0), .ovf(ovf32), .n_total(t32));
  always #5 clk = ~clk;
  integer i, errors = 0;
  task step(input v); begin valid <= v; @(posedge clk); end endtask
  task chk(input [255:0] n, input got, input exp); begin if (got !== exp) begin errors = errors + 1; $display("FAIL %0s: got %b exp %b", n, got, exp); end end endtask
  initial begin
    repeat (3) @(posedge clk); rst <= 0; @(posedge clk);
    chk("ovf4 after reset", ovf4, 1'b0);
    for (i = 0; i < 15; i = i + 1) step(1); step(0); repeat (3) @(posedge clk);
    chk("ovf4 after 15 windows", ovf4, 1'b0);                   // 15 = 2^4 - 1: no wrap yet
    step(1); step(0); repeat (3) @(posedge clk);
    chk("ovf4 after 16 windows", ovf4, 1'b1);                   // 16th window wraps n_total
    for (i = 0; i < 5; i = i + 1) step(0);
    chk("ovf4 sticky", ovf4, 1'b1); chk("ovf32 never", ovf32, 1'b0);
    rst <= 1; repeat (2) @(posedge clk); rst <= 0; @(posedge clk);
    chk("ovf4 cleared by reset", ovf4, 1'b0);
    if (errors == 0) $display("PASS: overflow flag"); else $display("FAIL: %0d errors", errors);
    $finish;
  end
endmodule
