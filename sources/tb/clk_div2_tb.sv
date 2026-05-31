//-----------------------------------------------------------------------------
// Module  : tb_clk_div2
// Purpose : Self-checking testbench for clk_div2.
//
// Tests:
//   1. o_clk_out = 0 during reset
//   2. o_clk_out = 1 on first posedge after reset deasserts
//   3. Toggle behaviour verified for 10+ cycles
//   4. Reset-during-operation: o_clk_out returns to 0
//   5. Recovery: after re-deassert, o_clk_out = 1 on first cycle
//
// Run: make sim TOP_MODULE=clk_div2 TESTBENCH=tb_clk_div2
//-----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module tb_clk_div2;

  // -------------------------------------------------------------------------
  // Clock generation — 10 ns period
  // -------------------------------------------------------------------------
  logic i_clk;
  logic i_rst_n;
  logic o_clk_out;

  localparam CLK_PERIOD = 10;

  initial i_clk = 1'b0;
  always #(CLK_PERIOD/2) i_clk = ~i_clk;

  // -------------------------------------------------------------------------
  // DUT
  // -------------------------------------------------------------------------
  clk_div2 u_dut (
    .i_clk    (i_clk),
    .i_rst_n  (i_rst_n),
    .o_clk_out(o_clk_out)
  );

  // -------------------------------------------------------------------------
  // Waveform dump
  // -------------------------------------------------------------------------
  initial begin
    $dumpfile("sim/waves/clk_div2_tb.vcd");
    $dumpvars(0, tb_clk_div2);
  end

  // -------------------------------------------------------------------------
  // Test body
  // -------------------------------------------------------------------------
  integer fail_count;

  task automatic check(input string label, input logic got, input logic expected);
    if (got !== expected) begin
      $display("FAIL [%s]: got=%b expected=%b", label, got, expected);
      fail_count++;
    end else begin
      $display("PASS [%s]", label);
    end
  endtask

  initial begin
    fail_count = 0;
    i_rst_n    = 1'b0;

    // ------------------------------------------------------------------
    // Test 1: o_clk_out = 0 during reset
    // ------------------------------------------------------------------
    repeat (5) @(posedge i_clk);
    #1;
    check("reset_low", o_clk_out, 1'b0);

    // ------------------------------------------------------------------
    // Test 2: o_clk_out = 1 on first posedge after deassert
    // Deassert reset between clock edges (negedge) so it's captured
    // on the very next posedge.
    // ------------------------------------------------------------------
    @(negedge i_clk);
    i_rst_n = 1'b1;
    @(posedge i_clk);
    #1;
    check("first_high_after_reset", o_clk_out, 1'b1);

    // ------------------------------------------------------------------
    // Test 3: Toggle behaviour — 10 full periods
    // ------------------------------------------------------------------
    begin
      logic expected_val;
      expected_val = 1'b1;  // already HIGH after first posedge
      repeat (20) begin
        @(posedge i_clk);
        #1;
        expected_val = ~expected_val;
        check("toggle", o_clk_out, expected_val);
      end
    end

    // ------------------------------------------------------------------
    // Test 4: Reset during operation — output returns to 0 immediately
    // ------------------------------------------------------------------
    @(posedge i_clk);
    #1;
    i_rst_n = 1'b0;         // async assert
    #1;
    check("reset_during_op", o_clk_out, 1'b0);

    // Hold reset a few cycles
    repeat (4) @(posedge i_clk);
    #1;
    check("held_low_in_reset", o_clk_out, 1'b0);

    // ------------------------------------------------------------------
    // Test 5: Recovery — o_clk_out = 1 on first posedge after re-deassert
    // ------------------------------------------------------------------
    @(negedge i_clk);
    i_rst_n = 1'b1;
    @(posedge i_clk);
    #1;
    check("recovery_first_high", o_clk_out, 1'b1);

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
