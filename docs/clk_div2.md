# clk_div2

Fixed divide-by-2 clock divider. Produces a **C1** output (50% duty cycle) at
half the input clock frequency.

---

## Interface

```systemverilog
module clk_div2 (
  input  logic i_clk,
  input  logic i_rst_n,
  output logic o_clk_out   // C1: 50% duty cycle at f_clk/2
);
```

No parameters — single-purpose module. For divide-by-2^N use `clk_div_even`.

---

## Design Decisions

### Why reset value = 0

`o_clk_out` is driven LOW during reset. On the first posedge after `i_rst_n`
deasserts, the flop inverts → `o_clk_out` goes HIGH.

Driving HIGH during reset would be dangerous: a spurious enable could activate
downstream logic before the system is initialised. LOW is the safe idle state.

### No parameters

`clk_div2` is intentionally non-parameterised. Adding a parameter to select
the divide ratio would duplicate the functionality of `clk_div_even`. Each
module has a single, clearly defined purpose.

### No ICG insertion

The module does not instantiate an integrated clock gate. ICG inference is a
synthesis decision driven by fanout at the output net. That decision belongs
to the synthesis tool and the consumer, not the divider. Inserting an ICG here
would create a false assumption about how the output will be used.

### Async assert, sync deassert reset

Reset asserts asynchronously (immediate, no clock edge required — safe for
power-on). Reset deasserts synchronously (captured on a clock edge — avoids
metastability from the deassert propagating mid-cycle).

---

## Phase Alignment

`o_clk_out` asserts HIGH on the first posedge after `i_rst_n` deasserts.

Two `clk_div2` instances released from reset on the same clock edge are
phase-aligned — their `o_clk_out` signals will toggle in lock-step.

Any consumer that taps `o_clk_out` through a pipeline register delays it by
one cycle, which **inverts the phase** of the divided signal. All consumers
must tap at the same pipeline depth, or add explicit delay matching.

---

## Timing diagram

```
i_clk   : _|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_
i_rst_n : ______|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
o_clk_out: ______|‾‾‾|___|‾‾‾|___|‾‾‾|___|‾‾‾
             rst  ^1st HIGH
```

---

## Usage Warning

`o_clk_out` is a **clock enable**, not a clock signal. Use it as:

```systemverilog
always_ff @(posedge i_clk or negedge i_rst_n) begin
  if (!i_rst_n) begin
    // reset
  end else if (o_clk_out) begin
    // logic that runs at f_clk/2
  end
end
```

Do **not** connect `o_clk_out` directly to a clock port. On ASIC this bypasses
CTS; on FPGA it requires explicit BUFG insertion. The user is responsible for
correct downstream usage.
