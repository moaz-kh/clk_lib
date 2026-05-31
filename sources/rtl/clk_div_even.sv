//-----------------------------------------------------------------------------
// Module  : clk_div_even
// Purpose : Fixed divide-by-2^N. N is a compile-time parameter (N ≥ 1).
//           Division ratio = 2^N.
//           Output type is selected by the MODE parameter.
//
// Output types:
//   MODE=0 → C1: real clock, 50% duty cycle at f_clk / 2^N.
//              Implemented as count_r[N-1] — a direct flop bit, zero
//              combinational logic, 50% duty guaranteed by construction.
//   MODE=1 → C3: clock enable pulse, exactly 1 master-clock cycle wide,
//              fires once every 2^N master cycles.
//              Implemented as (count_r == '1) — combinational, LOW during
//              reset because count=0 makes the comparison FALSE.
//
// Usage warning: o_clk_out is intended to be used as a clock ENABLE
//   (if (o_clk_out) inside downstream always_ff), NOT as an actual clock
//   signal. Driving a clock port directly bypasses CTS on ASIC and requires
//   explicit BUFG insertion on FPGA. The user is responsible.
//
// Phase alignment (C1 mode): o_clk_out is count_r[N-1]. count_r resets to 0,
//   so the first HIGH is after 2^(N-1) clock cycles. Two instances with the
//   same N released from reset on the same edge are phase-aligned.
//   Tapping through a pipeline stage delays by 1 cycle and can invert phase.
//
// Reset behaviour:
//   Assert   (i_rst_n=0): count_r driven to 0 immediately (async).
//                         o_clk_out is LOW for both modes during reset.
//   Deassert (i_rst_n=1): counter begins counting on next posedge.
//
// Parameters:
//   N    ≥ 1   : division ratio = 2^N. N=1 degenerates to ÷2 (same as clk_div2).
//   MODE ∈ {0,1}: output type selection — resolved at elaboration, zero runtime cost.
//
// Author  : moaz khaled
// Date    : 2026-05-31
//-----------------------------------------------------------------------------
`default_nettype none

module clk_div_even #(
  parameter int unsigned N    = 2,  // division ratio = 2^N (N >= 1)
  parameter int unsigned MODE = 0   // 0 = C1 (50% duty), 1 = C3 (1-cycle pulse)
) (
  // Clock & Reset
  input  logic i_clk,
  input  logic i_rst_n,

  // Output
  output logic o_clk_out  // C1 or C3 — see MODE parameter
);

  logic [N-1:0] count_r;

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      count_r <= '0;
    end else begin
      count_r <= count_r + 1'b1;
    end
  end

  // MODE resolves at elaboration — synthesiser treats this as a constant mux.
  // C1: MSB of counter. C3: all-ones detect (LOW at reset since count_r=0).
  assign o_clk_out = (MODE == 0) ? count_r[N-1] : (count_r == '1);

endmodule

`default_nettype wire
