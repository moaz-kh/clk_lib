# clk_div_even

Fixed divide-by-2^N clock divider. N is a compile-time parameter (N ≥ 1).
Output type (C1 or C3) is selected by the MODE parameter.

---

## Interface

```systemverilog
module clk_div_even #(
  parameter int unsigned N    = 2,  // division ratio = 2^N (N >= 1)
  parameter int unsigned MODE = 0   // 0 = C1 (50% duty), 1 = C3 (1-cycle pulse)
) (
  input  logic i_clk,
  input  logic i_rst_n,
  output logic o_clk_out
);
```

---

## Output Types

| MODE | Type | Description |
|------|------|-------------|
| 0 | C1 | 50% duty cycle waveform. HIGH for 2^(N-1) cycles, LOW for 2^(N-1) cycles. |
| 1 | C3 | Single-cycle pulse. HIGH for exactly 1 master cycle every 2^N master cycles. |

---

## Core Implementation

```systemverilog
logic [N-1:0] count_r;

always_ff @(posedge i_clk or negedge i_rst_n) begin
  if (!i_rst_n) count_r <= '0;
  else          count_r <= count_r + 1'b1;
end

assign o_clk_out = (MODE == 0) ? count_r[N-1] : (count_r == '1);
```

---

## Design Decisions

### Binary counter, not one-hot shift register

For 2^N division, a binary counter uses N flops. A one-hot shift register
uses 2^N flops. Binary always wins on area for power-of-2 division.

One-hot becomes relevant in Phase 2 for arbitrary (non-power-of-2) division
ratios, where the shift register gives glitch-free output without a comparator.

### C1: MSB of counter (`count_r[N-1]`)

The MSB of an N-bit free-running counter is LOW for the lower half of the
count range and HIGH for the upper half — exactly 50% duty cycle by
construction. Zero additional logic.

### C3: All-ones detect (`count_r == '1`)

The counter hits the all-ones state once per 2^N cycles, producing a
one-cycle-wide HIGH pulse. Because `count_r` resets to 0 (all-zeros),
the comparison is FALSE during reset — `o_clk_out` is safely LOW.

**Why `'1` and not `'0`?** If `count_r == '0` were used, `o_clk_out` would
be HIGH during reset (count=0 satisfies the condition). That is dangerous:
a spurious enable during reset could activate downstream logic before
initialisation is complete.

### MODE resolves at elaboration

The `? :` expression in `assign o_clk_out = (MODE == 0) ? ... : ...` is
resolved by the synthesis tool at compile time when MODE is a parameter.
It is equivalent to a `generate if` statement — zero runtime cost and no
multiplexer in the synthesised netlist.

### Combinational output is safe for synchronous consumers

Both outputs are combinational (derived from registered `count_r`). A
synchronous consumer samples `o_clk_out` at the next clock edge, after
setup time has been satisfied (guaranteed by STA). Glitches between clock
edges are invisible to synchronous logic.

---

## Parameter Validity

| Parameter | Valid range | Notes |
|-----------|-------------|-------|
| N | ≥ 1 | N=1 degenerates to ÷2, equivalent to `clk_div2`. No upper limit enforced. |
| MODE | 0 or 1 | Other values produce undefined output. |

---

## Phase Alignment

`o_clk_out` in MODE=0 (C1) is `count_r[N-1]`. The counter resets to 0, so
the first HIGH edge occurs after 2^(N-1) master clock cycles. Two instances
with the same N released from reset on the same edge are phase-aligned.

Tapping through a pipeline stage delays `o_clk_out` by one master cycle and
can shift its phase relative to other consumers.

---

## Usage Warning

`o_clk_out` is a **clock enable**, not a clock signal. See `clk_div2.md` for
the canonical usage pattern and the rationale for not driving clock ports
directly.
