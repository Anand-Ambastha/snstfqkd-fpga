// VARIANT of rtl/sifter.v with a sticky counter-overflow flag `ovf`; everything else is identical.
// Every counter increments at most once per valid window, so no counter can wrap before n_total does:
// watching n_total alone is enough (cost: 1 flip-flop and a few LUTs).
// SNS-TF-QKD per-window sifting & counting engine (one window per clock)
// Mirrors the Python pipeline: basis match, X-intensity/phase post-selection,
// X-click/error counting, per-intensity click stats, Z-basis SNS categories.
module sifter #(parameter CW = 32) (
  input  wire clk, rst, valid,
  input  wire a_basis, b_basis,          // 1 = Z, 0 = X
  input  wire [1:0] a_int, b_int,        // 0 vacuum, 1 decoy1, 2 decoy2
  input  wire [3:0] a_ph, b_ph,          // phase slice, M = 16
  input  wire a_send, b_send,            // Z-window send decisions
  input  wire click1, click2,            // Charlie detectors
  output reg  ovf,                       // sticky: a counter has wrapped (cleared by rst)
  output reg [CW-1:0] n_total, n_xm, n_zm, n_xint, n_xacc, n_xeff, n_xerr,
  output reg [CW-1:0] n_int0, n_int1, n_int2, c_int0, c_int1, c_int2,
  output reg [CW-1:0] n_zcat0, n_zcat1, n_zcat2, n_zcat3, n_zeff, n_zerr
);
  // stage 0: register inputs
  reg v; reg ab, bb, as, bs, c1, c2; reg [1:0] ai, bi; reg [3:0] ap, bp;
  always @(posedge clk) begin
    if (rst) v <= 1'b0;
    else begin
      v <= valid; ab <= a_basis; bb <= b_basis; as <= a_send; bs <= b_send;
      c1 <= click1; c2 <= click2; ai <= a_int; bi <= b_int; ap <= a_ph; bp <= b_ph;
    end
  end
  // stage 1: combinational decisions
  wire bmatch  = (ab == bb);
  wire xm      = v & bmatch & ~ab;
  wire zm      = v & bmatch &  ab;
  wire imatch  = (ai == bi);
  wire xint    = xm & imatch;
  wire acc     = xint & (ai != 2'd0) & (ap == bp);
  wire eff     = c1 ^ c2;
  wire [3:0] d = bp - ap;                       // slice difference
  wire cosneg  = (d >= 4'd5) && (d <= 4'd11);   // cos(d*2pi/16) < 0
  wire wrong   = (c1 & cosneg) | (c2 & ~cosneg);
  wire [1:0] zcat = {as, bs};                   // 01 B-only,10 A-only,11 both,00 none
  wire zbad    = zm & eff & (zcat == 2'b11 || zcat == 2'b00);
  // stage 2: counters
  always @(posedge clk) begin
    if (rst) begin
      n_total<=0; n_xm<=0; n_zm<=0; n_xint<=0; n_xacc<=0; n_xeff<=0; n_xerr<=0;
      n_int0<=0; n_int1<=0; n_int2<=0; c_int0<=0; c_int1<=0; c_int2<=0;
      n_zcat0<=0; n_zcat1<=0; n_zcat2<=0; n_zcat3<=0; n_zeff<=0; n_zerr<=0;
      ovf<=1'b0;
    end else begin
      if (v && (&n_total)) ovf <= 1'b1;
      if (v)    n_total <= n_total + 1;
      if (xm)   n_xm    <= n_xm + 1;
      if (zm)   n_zm    <= n_zm + 1;
      if (xint) n_xint  <= n_xint + 1;
      if (acc)  n_xacc  <= n_xacc + 1;
      if (acc & eff)         n_xeff <= n_xeff + 1;
      if (acc & eff & wrong) n_xerr <= n_xerr + 1;
      if (xint && ai==2'd0) begin n_int0 <= n_int0+1; if (eff) c_int0 <= c_int0+1; end
      if (xint && ai==2'd1) begin n_int1 <= n_int1+1; if (eff) c_int1 <= c_int1+1; end
      if (xint && ai==2'd2) begin n_int2 <= n_int2+1; if (eff) c_int2 <= c_int2+1; end
      if (zm && zcat==2'b10) n_zcat0 <= n_zcat0+1;
      if (zm && zcat==2'b01) n_zcat1 <= n_zcat1+1;
      if (zm && zcat==2'b11) n_zcat2 <= n_zcat2+1;
      if (zm && zcat==2'b00) n_zcat3 <= n_zcat3+1;
      if (zm & eff)  n_zeff <= n_zeff + 1;
      if (zbad)      n_zerr <= n_zerr + 1;
    end
  end
endmodule
