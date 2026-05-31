//-----------------------------------------------------------------------------
// Module  : tb_clk_div_even
// Purpose : Self-checking testbench for clk_div_even.
//
// Tests N ∈ {1,2,3,4} × MODE ∈ {0,1} — 8 DUT instances, all driven by
// the same clock and reset. For each configuration:
//   - output is LOW during reset
//   - output period = 2^N master clock cycles
//   - MODE=0: HIGH for exactly 2^(N-1) cycles per period (50% duty)
//   - MODE=1: HIGH for exactly 1 cycle per 2^N master cycles
//
// Run: make sim TOP_MODULE=clk_div_even TESTBENCH=tb_clk_div_even
//-----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module tb_clk_div_even;

  // -------------------------------------------------------------------------
  // Clock
  // -------------------------------------------------------------------------
  logic i_clk;
  logic i_rst_n;

  localparam CLK_PERIOD = 10;
  initial i_clk = 1'b0;
  always #(CLK_PERIOD/2) i_clk = ~i_clk;

  // -------------------------------------------------------------------------
  // DUT instances — 8 configurations
  // -------------------------------------------------------------------------
  logic o_n1_m0, o_n1_m1;
  logic o_n2_m0, o_n2_m1;
  logic o_n3_m0, o_n3_m1;
  logic o_n4_m0, o_n4_m1;

  clk_div_even #(.N(1), .MODE(0)) u_n1_m0 (.i_clk(i_clk), .i_rst_n(i_rst_n), .o_clk_out(o_n1_m0));
  clk_div_even #(.N(1), .MODE(1)) u_n1_m1 (.i_clk(i_clk), .i_rst_n(i_rst_n), .o_clk_out(o_n1_m1));
  clk_div_even #(.N(2), .MODE(0)) u_n2_m0 (.i_clk(i_clk), .i_rst_n(i_rst_n), .o_clk_out(o_n2_m0));
  clk_div_even #(.N(2), .MODE(1)) u_n2_m1 (.i_clk(i_clk), .i_rst_n(i_rst_n), .o_clk_out(o_n2_m1));
  clk_div_even #(.N(3), .MODE(0)) u_n3_m0 (.i_clk(i_clk), .i_rst_n(i_rst_n), .o_clk_out(o_n3_m0));
  clk_div_even #(.N(3), .MODE(1)) u_n3_m1 (.i_clk(i_clk), .i_rst_n(i_rst_n), .o_clk_out(o_n3_m1));
  clk_div_even #(.N(4), .MODE(0)) u_n4_m0 (.i_clk(i_clk), .i_rst_n(i_rst_n), .o_clk_out(o_n4_m0));
  clk_div_even #(.N(4), .MODE(1)) u_n4_m1 (.i_clk(i_clk), .i_rst_n(i_rst_n), .o_clk_out(o_n4_m1));

  // -------------------------------------------------------------------------
  // Waveform dump
  // -------------------------------------------------------------------------
  initial begin
    $dumpfile("sim/waves/clk_div_even_tb.vcd");
    $dumpvars(0, tb_clk_div_even);
  end

  // -------------------------------------------------------------------------
  // Checker — accessed directly (no task signal-passing to avoid copy-on-call)
  //
  // Macro-style: for each output, after reset, collect samples for
  // 4 * exp_period cycles and verify period and duty cycle.
  //
  // measure_c1(sig, label, exp_period, exp_high):
  //   Waits for a rising edge of sig, then counts cycles to the next
  //   rising edge (= period) and HIGH cycles in between (= duty).
  //
  // We use a generate approach to keep the code DRY while referencing
  // each signal directly by name.
  // -------------------------------------------------------------------------
  integer fail_count;

  // Measure period and high-time of a C1 signal directly.
  // SIG is a module-level signal name, accessed by value each cycle.
  // Because we cannot pass live signal refs through task inputs in iverilog,
  // each measurement block is written inline per instance below.

  // Shared scratch registers used by each inline measurement block:
  integer meas_period, meas_high;
  logic   meas_prev, meas_cur;

  // Helper: print pass/fail for a value comparison
  task automatic check_val(
    input string  label,
    input integer got,
    input integer expected
  );
    if (got !== expected) begin
      $display("FAIL [%s]: got=%0d expected=%0d", label, got, expected);
      fail_count++;
    end else begin
      $display("PASS [%s]=%0d", label, got);
    end
  endtask

  // -------------------------------------------------------------------------
  // Measure helpers — inline macros via `define to read signal directly
  // -------------------------------------------------------------------------
  // Usage: `MEASURE_C1(sig, exp_period)
  //   After call: meas_period and meas_high contain the measured values.
  `define MEASURE(SIG, EXP_P) \
    begin \
      integer _i; \
      /* wait until SIG is LOW */ \
      for (_i = 0; _i < (EXP_P)*4; _i++) begin \
        @(posedge i_clk); #1; \
        if (SIG == 1'b0) break; \
      end \
      /* wait for rising edge */ \
      meas_prev = SIG; \
      for (_i = 0; _i < (EXP_P)*4; _i++) begin \
        @(posedge i_clk); #1; \
        meas_cur = SIG; \
        if (meas_prev == 1'b0 && meas_cur == 1'b1) break; \
        meas_prev = meas_cur; \
      end \
      /* count to next rising edge */ \
      meas_period = 0; meas_high = 0; \
      meas_prev = SIG; \
      for (_i = 0; _i < (EXP_P)*4; _i++) begin \
        @(posedge i_clk); #1; \
        meas_cur = SIG; \
        meas_period++; \
        if (meas_prev == 1'b1) meas_high++; \
        if (meas_prev == 1'b0 && meas_cur == 1'b1) break; \
        meas_prev = meas_cur; \
      end \
    end

  // -------------------------------------------------------------------------
  // Test body
  // -------------------------------------------------------------------------
  initial begin
    fail_count = 0;
    i_rst_n    = 1'b0;

    // ------------------------------------------------------------------
    // Reset check — all outputs must be LOW during reset
    // ------------------------------------------------------------------
    repeat (5) @(posedge i_clk); #1;
    if (o_n1_m0 !== 1'b0) begin $display("FAIL [reset_n1_m0]"); fail_count++; end
    else $display("PASS [reset_n1_m0]");
    if (o_n1_m1 !== 1'b0) begin $display("FAIL [reset_n1_m1]"); fail_count++; end
    else $display("PASS [reset_n1_m1]");
    if (o_n2_m0 !== 1'b0) begin $display("FAIL [reset_n2_m0]"); fail_count++; end
    else $display("PASS [reset_n2_m0]");
    if (o_n2_m1 !== 1'b0) begin $display("FAIL [reset_n2_m1]"); fail_count++; end
    else $display("PASS [reset_n2_m1]");
    if (o_n3_m0 !== 1'b0) begin $display("FAIL [reset_n3_m0]"); fail_count++; end
    else $display("PASS [reset_n3_m0]");
    if (o_n3_m1 !== 1'b0) begin $display("FAIL [reset_n3_m1]"); fail_count++; end
    else $display("PASS [reset_n3_m1]");
    if (o_n4_m0 !== 1'b0) begin $display("FAIL [reset_n4_m0]"); fail_count++; end
    else $display("PASS [reset_n4_m0]");
    if (o_n4_m1 !== 1'b0) begin $display("FAIL [reset_n4_m1]"); fail_count++; end
    else $display("PASS [reset_n4_m1]");

    // Release reset between clock edges
    @(negedge i_clk);
    i_rst_n = 1'b1;

    // ------------------------------------------------------------------
    // C1 checks — period = 2^N, high_time = 2^(N-1)
    // Each block uses the MEASURE macro to read the signal directly.
    // ------------------------------------------------------------------

    // N=1, MODE=0: period=2, high=1
    `MEASURE(o_n1_m0, 2)
    check_val("N1_M0_period", meas_period, 2);
    check_val("N1_M0_high",   meas_high,   1);

    // N=2, MODE=0: period=4, high=2
    `MEASURE(o_n2_m0, 4)
    check_val("N2_M0_period", meas_period, 4);
    check_val("N2_M0_high",   meas_high,   2);

    // N=3, MODE=0: period=8, high=4
    `MEASURE(o_n3_m0, 8)
    check_val("N3_M0_period", meas_period, 8);
    check_val("N3_M0_high",   meas_high,   4);

    // N=4, MODE=0: period=16, high=8
    `MEASURE(o_n4_m0, 16)
    check_val("N4_M0_period", meas_period, 16);
    check_val("N4_M0_high",   meas_high,   8);

    // ------------------------------------------------------------------
    // C3 checks — period = 2^N, pulse = 1 cycle
    // ------------------------------------------------------------------

    // N=1, MODE=1: period=2, high=1
    `MEASURE(o_n1_m1, 2)
    check_val("N1_M1_period", meas_period, 2);
    check_val("N1_M1_pulse",  meas_high,   1);

    // N=2, MODE=1: period=4, high=1
    `MEASURE(o_n2_m1, 4)
    check_val("N2_M1_period", meas_period, 4);
    check_val("N2_M1_pulse",  meas_high,   1);

    // N=3, MODE=1: period=8, high=1
    `MEASURE(o_n3_m1, 8)
    check_val("N3_M1_period", meas_period, 8);
    check_val("N3_M1_pulse",  meas_high,   1);

    // N=4, MODE=1: period=16, high=1
    `MEASURE(o_n4_m1, 16)
    check_val("N4_M1_period", meas_period, 16);
    check_val("N4_M1_pulse",  meas_high,   1);

    // ------------------------------------------------------------------
    // Summary
    // ------------------------------------------------------------------
    if (fail_count == 0) begin
      $display("*** TEST PASSED ***");
    end else begin
      $display("*** TEST FAILED *** (%0d failure(s))", fail_count);
    end

    $finish;
  end

endmodule

`default_nettype wire
