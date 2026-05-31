//-----------------------------------------------------------------------------
// Module  : clk_div2
// Purpose : Fixed divide-by-2. Produces a C1 output (real clock, 50% duty
//           cycle) at half the input frequency.
//
// Output type: C1 — continuous waveform, HIGH for one master cycle, LOW for
//              one master cycle. Period = 2 master clock cycles.
//
// Usage warning: o_clk_out is intended to be used as a clock ENABLE
//   (if (o_clk_out) inside downstream always_ff), NOT as an actual clock
//   signal. Driving a clock port directly bypasses CTS on ASIC and requires
//   explicit BUFG insertion on FPGA. The user is responsible.
//
// Phase alignment: o_clk_out asserts HIGH on the first posedge after
//   i_rst_n deasserts. Two clk_div2 instances released from reset on the
//   same edge are phase-aligned. Tapping o_clk_out through a pipeline stage
//   delays the enable by 1 cycle, which INVERTS the phase. All consumers
//   must tap at the same pipeline depth.
//
// Reset behaviour:
//   Assert   (i_rst_n=0): o_clk_out driven LOW immediately (async).
//   Deassert (i_rst_n=1): o_clk_out goes HIGH on the first posedge of i_clk.
//
// Parameters: none — single-purpose module. For 2^N division use clk_div_even.
//
// Author  : moaz khaled
// Date    : 2026-05-31
//-----------------------------------------------------------------------------
`default_nettype none

module clk_div2 (
  // Clock & Reset
  input  logic i_clk,
  input  logic i_rst_n,

  // Output
  output logic o_clk_out   // C1: 50% duty cycle at f_clk/2
);

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      o_clk_out <= 1'b0;
    end else begin
      o_clk_out <= ~o_clk_out;
    end
  end

endmodule

`default_nettype wire
