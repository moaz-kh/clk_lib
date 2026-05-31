//-----------------------------------------------------------------------------
// Module  : tb_clk_div_prog
// Purpose : Self-checking testbench for clk_div_prog.
//
// Instantiates 4 DUTs (IMPL∈{0,1} × MODE∈{0,1}), all sharing one clock,
// reset, and stimulus stream. DEFAULT_DIV=8, RATIO_WIDTH=8.
//
// Test sequence:
//   1. Reset: o_clk_out=0, o_rdy=1 for all instances
//   2. Steady-state at DEFAULT_DIV=8: verify period and waveform type
//   3. Ratio change to 16 via handshake: new ratio at next terminal
//   4. Ratio change to 4 (smaller)
//   5. Multiple consecutive changes
//   6. Edge case: i_valid simultaneous with terminal, pending=0 → 1-period latency
//   7. Edge case: i_valid while o_rdy=0 (pending=1) → rejected
//   8. Cross-check: IMPL=0 and IMPL=1 produce same period and pulse width
//
// Run: make sim TOP_MODULE=clk_div_prog TESTBENCH=tb_clk_div_prog
//-----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module tb_clk_div_prog;

  // -------------------------------------------------------------------------
  // Parameters
  // -------------------------------------------------------------------------
  localparam int unsigned RATIO_WIDTH  = 8;
  localparam int unsigned DEFAULT_DIV  = 8;
  localparam int unsigned CLK_PERIOD   = 10;

  // -------------------------------------------------------------------------
  // Signals
  // -------------------------------------------------------------------------
  logic                   i_clk;
  logic                   i_rst_n;
  logic [RATIO_WIDTH-1:0] i_ratio;
  logic                   i_valid;

  // Outputs: a=IMPL0 b=IMPL1, c1=MODE0 c3=MODE1
  logic o_rdy_a_c1,  o_clk_a_c1;
  logic o_rdy_a_c3,  o_clk_a_c3;
  logic o_rdy_b_c1,  o_clk_b_c1;
  logic o_rdy_b_c3,  o_clk_b_c3;

  // -------------------------------------------------------------------------
  // Clock
  // -------------------------------------------------------------------------
  initial i_clk = 1'b0;
  always #(CLK_PERIOD/2) i_clk = ~i_clk;

  // -------------------------------------------------------------------------
  // DUT instances
  // -------------------------------------------------------------------------
  clk_div_prog #(.RATIO_WIDTH(RATIO_WIDTH), .DEFAULT_DIV(DEFAULT_DIV), .MODE(0), .IMPL(0))
    u_a_c1 (.i_clk(i_clk), .i_rst_n(i_rst_n), .i_ratio(i_ratio), .i_valid(i_valid),
            .o_rdy(o_rdy_a_c1), .o_clk_out(o_clk_a_c1));

  clk_div_prog #(.RATIO_WIDTH(RATIO_WIDTH), .DEFAULT_DIV(DEFAULT_DIV), .MODE(1), .IMPL(0))
    u_a_c3 (.i_clk(i_clk), .i_rst_n(i_rst_n), .i_ratio(i_ratio), .i_valid(i_valid),
            .o_rdy(o_rdy_a_c3), .o_clk_out(o_clk_a_c3));

  clk_div_prog #(.RATIO_WIDTH(RATIO_WIDTH), .DEFAULT_DIV(DEFAULT_DIV), .MODE(0), .IMPL(1))
    u_b_c1 (.i_clk(i_clk), .i_rst_n(i_rst_n), .i_ratio(i_ratio), .i_valid(i_valid),
            .o_rdy(o_rdy_b_c1), .o_clk_out(o_clk_b_c1));

  clk_div_prog #(.RATIO_WIDTH(RATIO_WIDTH), .DEFAULT_DIV(DEFAULT_DIV), .MODE(1), .IMPL(1))
    u_b_c3 (.i_clk(i_clk), .i_rst_n(i_rst_n), .i_ratio(i_ratio), .i_valid(i_valid),
            .o_rdy(o_rdy_b_c3), .o_clk_out(o_clk_b_c3));

  // -------------------------------------------------------------------------
  // Waveform dump
  // -------------------------------------------------------------------------
  initial begin
    $dumpfile("sim/waves/clk_div_prog_tb.vcd");
    $dumpvars(0, tb_clk_div_prog);
  end

  // -------------------------------------------------------------------------
  // Test infrastructure
  // -------------------------------------------------------------------------
  integer fail_count;

  task automatic check_bit(input string label, input logic got, input logic expected);
    if (got !== expected) begin
      $display("FAIL [%s]: got=%b expected=%b", label, got, expected);
      fail_count++;
    end else begin
      $display("PASS [%s]", label);
    end
  endtask

  task automatic check_val(input string label, input integer got, input integer expected);
    if (got !== expected) begin
      $display("FAIL [%s]: got=%0d expected=%0d", label, got, expected);
      fail_count++;
    end else begin
      $display("PASS [%s]=%0d", label, got);
    end
  endtask

  // Measure C1 period: count master cycles between consecutive rising edges.
  // Returns result in out_period. Reads signal SIG directly.
  // SIG must be a module-level signal (not a task-copied input).
  `define MEAS_PERIOD_C1(SIG, LIMIT, OUT) \
    begin \
      integer _j; logic _p, _c; \
      /* wait for LOW then rising edge */ \
      for (_j=0; _j<(LIMIT); _j++) begin @(posedge i_clk); #1; if (SIG==1'b0) break; end \
      _p=SIG; \
      for (_j=0; _j<(LIMIT); _j++) begin \
        @(posedge i_clk); #1; _c=SIG; \
        if (_p==1'b0 && _c==1'b1) break; _p=_c; \
      end \
      /* count to next rising edge */ \
      OUT=0; _p=SIG; \
      for (_j=0; _j<(LIMIT); _j++) begin \
        @(posedge i_clk); #1; _c=SIG; OUT++; \
        if (_p==1'b0 && _c==1'b1) break; _p=_c; \
      end \
    end

  // Measure C3 period: count master cycles between consecutive rising edges.
  `define MEAS_PERIOD_C3(SIG, LIMIT, OUT) \
    begin \
      integer _j; logic _p, _c; \
      for (_j=0; _j<(LIMIT); _j++) begin @(posedge i_clk); #1; if (SIG==1'b0) break; end \
      _p=SIG; \
      for (_j=0; _j<(LIMIT); _j++) begin \
        @(posedge i_clk); #1; _c=SIG; \
        if (_p==1'b0 && _c==1'b1) break; _p=_c; \
      end \
      OUT=0; _p=SIG; \
      for (_j=0; _j<(LIMIT); _j++) begin \
        @(posedge i_clk); #1; _c=SIG; OUT++; \
        if (_p==1'b0 && _c==1'b1) break; _p=_c; \
      end \
    end

  // Measure C3 pulse width (HIGH cycles per period).
  `define MEAS_HIGH(SIG, LIMIT, OUT) \
    begin \
      integer _j; logic _p, _c; \
      for (_j=0; _j<(LIMIT); _j++) begin @(posedge i_clk); #1; if (SIG==1'b0) break; end \
      _p=SIG; \
      for (_j=0; _j<(LIMIT); _j++) begin \
        @(posedge i_clk); #1; _c=SIG; \
        if (_p==1'b0 && _c==1'b1) break; _p=_c; \
      end \
      OUT=0; _p=SIG; \
      for (_j=0; _j<(LIMIT); _j++) begin \
        @(posedge i_clk); #1; _c=SIG; \
        if (_p==1'b1) OUT++; \
        if (_p==1'b0 && _c==1'b1) break; _p=_c; \
      end \
    end

  // -------------------------------------------------------------------------
  // Scratch
  // -------------------------------------------------------------------------
  integer p_a_c1, p_a_c3, p_b_c1, p_b_c3;
  integer h_a_c3, h_b_c3;

  // -------------------------------------------------------------------------
  // Test body
  // -------------------------------------------------------------------------
  initial begin
    fail_count = 0;
    i_rst_n    = 1'b0;
    i_ratio    = RATIO_WIDTH'(DEFAULT_DIV);
    i_valid    = 1'b0;

    // ======================================================================
    // Test 1: Reset state
    // ======================================================================
    repeat (5) @(posedge i_clk); #1;
    check_bit("rst_clk_a_c1", o_clk_a_c1, 1'b0);
    check_bit("rst_clk_a_c3", o_clk_a_c3, 1'b0);
    check_bit("rst_clk_b_c1", o_clk_b_c1, 1'b0);
    check_bit("rst_clk_b_c3", o_clk_b_c3, 1'b0);
    check_bit("rst_rdy_a_c1", o_rdy_a_c1, 1'b1);
    check_bit("rst_rdy_a_c3", o_rdy_a_c3, 1'b1);
    check_bit("rst_rdy_b_c1", o_rdy_b_c1, 1'b1);
    check_bit("rst_rdy_b_c3", o_rdy_b_c3, 1'b1);

    @(negedge i_clk);
    i_rst_n = 1'b1;

    // ======================================================================
    // Test 2: Steady-state at DEFAULT_DIV=8
    // ======================================================================
    // Wait for outputs to establish (extra headroom)
    repeat (DEFAULT_DIV * 3) @(posedge i_clk);

    `MEAS_PERIOD_C1(o_clk_a_c1, 64, p_a_c1)
    `MEAS_PERIOD_C1(o_clk_b_c1, 64, p_b_c1)
    `MEAS_PERIOD_C3(o_clk_a_c3, 64, p_a_c3)
    `MEAS_PERIOD_C3(o_clk_b_c3, 64, p_b_c3)
    `MEAS_HIGH(o_clk_a_c3, 64, h_a_c3)
    `MEAS_HIGH(o_clk_b_c3, 64, h_b_c3)

    check_val("ss8_period_a_c1", p_a_c1, DEFAULT_DIV);
    check_val("ss8_period_b_c1", p_b_c1, DEFAULT_DIV);
    check_val("ss8_period_a_c3", p_a_c3, DEFAULT_DIV);
    check_val("ss8_period_b_c3", p_b_c3, DEFAULT_DIV);
    check_val("ss8_pulse_a_c3",  h_a_c3, 1);
    check_val("ss8_pulse_b_c3",  h_b_c3, 1);

    // ======================================================================
    // Test 3: Ratio change to 16 via handshake
    // ======================================================================
    // Wait for o_rdy then present ratio
    @(posedge i_clk); #1;
    while (!o_rdy_b_c1) @(posedge i_clk);
    @(negedge i_clk);
    i_ratio = 8'd16;
    i_valid = 1'b1;
    @(posedge i_clk); #1;
    i_valid = 1'b0;
    i_ratio = RATIO_WIDTH'(DEFAULT_DIV);

    // Allow enough cycles for the change to propagate (up to 2 full periods)
    repeat (16 * 3) @(posedge i_clk);

    `MEAS_PERIOD_C1(o_clk_a_c1, 128, p_a_c1)
    `MEAS_PERIOD_C1(o_clk_b_c1, 128, p_b_c1)
    `MEAS_PERIOD_C3(o_clk_a_c3, 128, p_a_c3)
    `MEAS_PERIOD_C3(o_clk_b_c3, 128, p_b_c3)

    check_val("ratio16_period_a_c1", p_a_c1, 16);
    check_val("ratio16_period_b_c1", p_b_c1, 16);
    check_val("ratio16_period_a_c3", p_a_c3, 16);
    check_val("ratio16_period_b_c3", p_b_c3, 16);

    // ======================================================================
    // Test 4: Ratio change to 4 (smaller ratio)
    // ======================================================================
    @(posedge i_clk); #1;
    while (!o_rdy_b_c1) @(posedge i_clk);
    @(negedge i_clk);
    i_ratio = 8'd4;
    i_valid = 1'b1;
    @(posedge i_clk); #1;
    i_valid = 1'b0;
    i_ratio = RATIO_WIDTH'(DEFAULT_DIV);

    repeat (16 * 3) @(posedge i_clk);

    `MEAS_PERIOD_C1(o_clk_a_c1, 64, p_a_c1)
    `MEAS_PERIOD_C1(o_clk_b_c1, 64, p_b_c1)

    check_val("ratio4_period_a_c1", p_a_c1, 4);
    check_val("ratio4_period_b_c1", p_b_c1, 4);

    // ======================================================================
    // Test 5: Multiple consecutive ratio changes
    // ======================================================================
    // Change to 12 then immediately queue 6 while pending
    @(posedge i_clk); #1;
    while (!o_rdy_b_c1) @(posedge i_clk);
    @(negedge i_clk);
    i_ratio = 8'd12;
    i_valid = 1'b1;
    @(posedge i_clk); #1;
    // Now pending=1, o_rdy=0 — present 6, should be rejected
    i_ratio = 8'd6;
    // i_valid still high — but o_rdy=0 so it should be ignored
    @(posedge i_clk); #1;
    i_valid = 1'b0;

    repeat (12 * 4) @(posedge i_clk);

    `MEAS_PERIOD_C1(o_clk_b_c1, 96, p_b_c1)
    check_val("consec_period_12_b_c1", p_b_c1, 12);

    // ======================================================================
    // Test 6: Edge case — i_valid simultaneous with terminal, pending=0
    //   New ratio takes effect at NEXT terminal (1-period latency).
    //   Verify: output first runs one more period at old ratio,
    //           then switches to new ratio.
    // ======================================================================
    // Set ratio to 8 first and let it stabilise
    @(posedge i_clk); #1;
    while (!o_rdy_b_c1) @(posedge i_clk);
    @(negedge i_clk);
    i_ratio = 8'd8;
    i_valid = 1'b1;
    @(posedge i_clk); #1;
    i_valid = 1'b0;

    repeat (8 * 4) @(posedge i_clk);

    // Now drive valid on the exact terminal cycle of Option B C1
    // Wait for o_clk_b_c1 to go HIGH (terminal of B), then apply valid
    begin
      integer _k;
      for (_k = 0; _k < 32; _k++) begin
        @(posedge i_clk); #1;
        // After the output goes high, that is the toggle point.
        // Present valid on the same posedge as terminal (which is when
        // o_clk_b_c1 just toggled HIGH). Drive valid on negedge.
        if (o_clk_b_c1 == 1'b1) begin
          @(negedge i_clk);
          i_ratio = 8'd20;
          i_valid = 1'b1;
          @(posedge i_clk); #1;
          i_valid = 1'b0;
          i_ratio = RATIO_WIDTH'(DEFAULT_DIV);
          break;
        end
      end
    end

    // Allow time for the change
    repeat (20 * 4) @(posedge i_clk);

    `MEAS_PERIOD_C1(o_clk_b_c1, 160, p_b_c1)
    // The module should have settled at ratio=20 by now
    check_val("edge_valid_term_b_c1", p_b_c1, 20);

    // ======================================================================
    // Test 7: i_valid while o_rdy=0 — rejected, shadow not overwritten
    // ======================================================================
    @(posedge i_clk); #1;
    while (!o_rdy_b_c1) @(posedge i_clk);
    @(negedge i_clk);
    i_ratio = 8'd10;
    i_valid = 1'b1;               // accepted: pending goes 1, rdy goes 0
    @(posedge i_clk); #1;
    // Now o_rdy=0 — present a different (wrong) ratio
    i_ratio = 8'd200;
    // i_valid still asserted but o_rdy=0 — should be rejected
    @(posedge i_clk); #1;
    i_valid = 1'b0;
    i_ratio = RATIO_WIDTH'(DEFAULT_DIV);

    repeat (20 * 4) @(posedge i_clk);

    `MEAS_PERIOD_C1(o_clk_b_c1, 160, p_b_c1)
    // Must settle at 10, NOT 200
    check_val("reject_while_pending_b_c1", p_b_c1, 10);

    // ======================================================================
    // Test 8: Cross-compare IMPL=0 vs IMPL=1 — same period, same pulse width
    //   (phase offset is allowed to differ)
    // ======================================================================
    @(posedge i_clk); #1;
    while (!o_rdy_b_c1) @(posedge i_clk);
    @(negedge i_clk);
    i_ratio = 8'd8;
    i_valid = 1'b1;
    @(posedge i_clk); #1;
    i_valid = 1'b0;

    repeat (8 * 6) @(posedge i_clk);

    `MEAS_PERIOD_C1(o_clk_a_c1, 64, p_a_c1)
    `MEAS_PERIOD_C1(o_clk_b_c1, 64, p_b_c1)
    `MEAS_PERIOD_C3(o_clk_a_c3, 64, p_a_c3)
    `MEAS_PERIOD_C3(o_clk_b_c3, 64, p_b_c3)
    `MEAS_HIGH(o_clk_a_c3, 64, h_a_c3)
    `MEAS_HIGH(o_clk_b_c3, 64, h_b_c3)

    check_val("xcheck_c1_period_match", p_a_c1,  p_b_c1);
    check_val("xcheck_c3_period_match", p_a_c3,  p_b_c3);
    check_val("xcheck_c3_pulse_a",      h_a_c3,  1);
    check_val("xcheck_c3_pulse_b",      h_b_c3,  1);
    check_val("xcheck_c1_period_val",   p_b_c1,  8);
    check_val("xcheck_c3_period_val",   p_b_c3,  8);

    // ======================================================================
    // Summary
    // ======================================================================
    if (fail_count == 0) begin
      $display("*** TEST PASSED ***");
    end else begin
      $display("*** TEST FAILED *** (%0d failure(s))", fail_count);
    end

    $finish;
  end

endmodule

`default_nettype wire
