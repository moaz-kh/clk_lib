//-----------------------------------------------------------------------------
// Module  : clk_div_prog
// Purpose : Runtime-programmable even clock divider.
//           Division ratio is set via a valid/ready handshake and takes
//           effect at the next terminal count — no glitches on o_clk_out.
//
// Output types (selected by MODE parameter):
//   MODE=0 → C1: real clock, 50% duty cycle at f_clk / ratio.
//   MODE=1 → C3: clock enable pulse, 1 master-clock cycle wide, fires
//              once every `ratio` master cycles.
//
// Implementation variants (selected by IMPL parameter):
//   IMPL=0 → Option A: up-counter (0 → ratio-1). Terminal detected by
//              full comparator (count == active-1). Midpoint detected for
//              C1 toggle. Uses RATIO_WIDTH-bit counter and comparators.
//   IMPL=1 → Option B (default): down-counter (ratio/2-1 → 0). Terminal
//              detected as NOR of all bits (~|count) — no comparator.
//              Shadow/active store ratio/2. C3 uses a skip flop to suppress
//              every other terminal (giving one pulse per full period).
//
// Valid/ready handshake:
//   IDLE    (o_rdy=1, pending=0): a new ratio is accepted on i_valid & o_rdy.
//   PENDING (o_rdy=0, pending=1): ratio is in shadow; applied at next terminal.
//   Transitions are mutually exclusive by construction — no arbitration logic.
//
//   Edge case: if i_valid fires on the same cycle as terminal with pending=0,
//   the shadow captures the new ratio but the active register does not update
//   (terminal & pending is FALSE that cycle). The new ratio applies at the
//   NEXT terminal. This 1-period latency is documented behaviour, not a bug.
//
// Usage warning: o_clk_out is intended to be used as a clock ENABLE
//   (if (o_clk_out) inside downstream always_ff), NOT as an actual clock
//   signal. The user is responsible for correct downstream usage.
//
// Parameters:
//   RATIO_WIDTH : bit width of i_ratio port.
//   DEFAULT_DIV : reset-state division ratio. Must be even and ≥ 2.
//                 RATIO_WIDTH must be ≥ $clog2(DEFAULT_DIV)+1.
//   MODE        : 0 = C1, 1 = C3.
//   IMPL        : 0 = Option A, 1 = Option B (default).
//
// Constraints:
//   - i_ratio must be even and ≥ 2. Odd values are silently truncated.
//   - i_ratio = 0 or 1 causes degenerate counter behaviour.
//   - i_ratio must be synchronous to i_clk. Use fpga_cdc_lib for CDC.
//   - DEFAULT_DIV must be even and ≥ 2.
//
// Author  : moaz khaled
// Date    : 2026-05-31
//-----------------------------------------------------------------------------
`default_nettype none

module clk_div_prog #(
  parameter int unsigned RATIO_WIDTH = 8,  // bit width of i_ratio
  parameter int unsigned DEFAULT_DIV = 8,  // reset-state ratio (even, ≥2)
  parameter int unsigned MODE        = 0,  // 0=C1, 1=C3
  parameter int unsigned IMPL        = 1   // 0=Option A, 1=Option B (default)
) (
  // Clock & Reset
  input  logic                   i_clk,
  input  logic                   i_rst_n,

  // Control
  input  logic [RATIO_WIDTH-1:0] i_ratio,  // requested ratio (even, ≥2, sync to i_clk)
  input  logic                   i_valid,  // handshake: new ratio presented
  output logic                   o_rdy,    // handshake: ready to accept (= ~pending)

  // Output
  output logic                   o_clk_out // C1 or C3 — see MODE
);

  // =========================================================================
  // Option A — up-counter, full-ratio comparator
  // =========================================================================
  if (IMPL == 0) begin : gen_option_a

    logic [RATIO_WIDTH-1:0] shadow_a;
    logic [RATIO_WIDTH-1:0] active_a;
    logic [RATIO_WIDTH-1:0] count_a;
    logic                   pending_a;
    logic                   terminal_a;
    logic                   midpoint_a;
    logic                   clk_c1_a;

    assign terminal_a = (count_a == active_a - 1'b1);
    assign midpoint_a = (count_a == (active_a >> 1) - 1'b1);

    // Shadow register: latches new ratio when accepted
    always_ff @(posedge i_clk or negedge i_rst_n) begin
      if (!i_rst_n) begin
        shadow_a <= RATIO_WIDTH'(DEFAULT_DIV);
      end else if (i_valid && !pending_a) begin
        shadow_a <= i_ratio;
      end
    end

    // Pending flag: set on accept, cleared on load
    always_ff @(posedge i_clk or negedge i_rst_n) begin
      if (!i_rst_n) begin
        pending_a <= 1'b0;
      end else if (i_valid && !pending_a) begin
        pending_a <= 1'b1;
      end else if (terminal_a && pending_a) begin
        pending_a <= 1'b0;
      end
    end

    // Active register: updated at terminal when pending
    always_ff @(posedge i_clk or negedge i_rst_n) begin
      if (!i_rst_n) begin
        active_a <= RATIO_WIDTH'(DEFAULT_DIV);
      end else if (terminal_a && pending_a) begin
        active_a <= shadow_a;
      end
    end

    // Up-counter: wraps at terminal
    always_ff @(posedge i_clk or negedge i_rst_n) begin
      if (!i_rst_n) begin
        count_a <= '0;
      end else if (terminal_a) begin
        count_a <= '0;
      end else begin
        count_a <= count_a + 1'b1;
      end
    end

    // C1 toggle: flips at terminal and midpoint for 50% duty cycle
    always_ff @(posedge i_clk or negedge i_rst_n) begin
      if (!i_rst_n) begin
        clk_c1_a <= 1'b0;
      end else if (terminal_a) begin
        clk_c1_a <= ~clk_c1_a;
      end else if (midpoint_a) begin
        clk_c1_a <= ~clk_c1_a;
      end
    end

    assign o_rdy     = ~pending_a;
    assign o_clk_out = (MODE == 0) ? clk_c1_a : terminal_a;

  // =========================================================================
  // Option B — down-counter, NOR terminal (default)
  // =========================================================================
  end else begin : gen_option_b

    // Internal width is RATIO_WIDTH-1 since shadow/active store ratio/2
    logic [RATIO_WIDTH-2:0] shadow_b;
    logic [RATIO_WIDTH-2:0] active_b;
    logic [RATIO_WIDTH-2:0] count_b;
    logic                   pending_b;
    logic                   terminal_b;
    logic                   clk_c1_b;
    logic                   skip_b;

    // Terminal when counter reaches 0 — NOR of all bits, no comparator
    assign terminal_b = ~|count_b;

    // Shadow register: stores ratio/2
    always_ff @(posedge i_clk or negedge i_rst_n) begin
      if (!i_rst_n) begin
        shadow_b <= (RATIO_WIDTH-1)'(DEFAULT_DIV >> 1);
      end else if (i_valid && !pending_b) begin
        shadow_b <= i_ratio[RATIO_WIDTH-1:1];  // i_ratio >> 1
      end
    end

    // Pending flag
    always_ff @(posedge i_clk or negedge i_rst_n) begin
      if (!i_rst_n) begin
        pending_b <= 1'b0;
      end else if (i_valid && !pending_b) begin
        pending_b <= 1'b1;
      end else if (terminal_b && pending_b) begin
        pending_b <= 1'b0;
      end
    end

    // Active register: stores ratio/2; updated at terminal when pending
    always_ff @(posedge i_clk or negedge i_rst_n) begin
      if (!i_rst_n) begin
        active_b <= (RATIO_WIDTH-1)'(DEFAULT_DIV >> 1);
      end else if (terminal_b && pending_b) begin
        active_b <= shadow_b;
      end
    end

    // Down-counter: loaded with (active-1) at each terminal
    always_ff @(posedge i_clk or negedge i_rst_n) begin
      if (!i_rst_n) begin
        count_b <= (RATIO_WIDTH-1)'((DEFAULT_DIV >> 1) - 1);
      end else if (terminal_b) begin
        count_b <= active_b - 1'b1;
      end else begin
        count_b <= count_b - 1'b1;
      end
    end

    // C1 toggle: flips every terminal → period = 2*(ratio/2) = ratio
    always_ff @(posedge i_clk or negedge i_rst_n) begin
      if (!i_rst_n) begin
        clk_c1_b <= 1'b0;
      end else if (terminal_b) begin
        clk_c1_b <= ~clk_c1_b;
      end
    end

    // Skip flop: suppresses every other terminal for C3 (one pulse per ratio cycles)
    always_ff @(posedge i_clk or negedge i_rst_n) begin
      if (!i_rst_n) begin
        skip_b <= 1'b0;
      end else if (terminal_b) begin
        skip_b <= ~skip_b;
      end
    end

    assign o_rdy     = ~pending_b;
    assign o_clk_out = (MODE == 0) ? clk_c1_b : (terminal_b & skip_b);

  end

endmodule

`default_nettype wire
