# clk_div_prog

Runtime-programmable even clock divider. The division ratio is changed at
runtime via a valid/ready handshake and takes effect glitch-free at the next
terminal count.

---

## Interface

```systemverilog
module clk_div_prog #(
  parameter int unsigned RATIO_WIDTH = 8,
  parameter int unsigned DEFAULT_DIV = 8,
  parameter int unsigned MODE        = 0,
  parameter int unsigned IMPL        = 1
) (
  input  logic                   i_clk,
  input  logic                   i_rst_n,
  input  logic [RATIO_WIDTH-1:0] i_ratio,
  input  logic                   i_valid,
  output logic                   o_rdy,
  output logic                   o_clk_out
);
```

---

## Architecture

```
     valid/rdy handshake            terminal count event
           |                                |
           v                                v
 i_ratio → shadow_reg → active_reg → counter → clk_out logic
```

A **shadow register** captures the new ratio from `i_ratio` when the handshake
is accepted. An **active register** latches the shadow at the next terminal count.
The counter always runs from the active register — never the shadow — so the
output is never disturbed mid-period.

---

## Valid/Ready Handshake

Two states, transitions mutually exclusive by construction:

| State | pending | o_rdy | Behaviour |
|-------|---------|-------|-----------|
| IDLE | 0 | 1 | Accepts new ratio on `i_valid & o_rdy` |
| PENDING | 1 | 0 | New ratio in shadow; applies at next terminal |

`i_valid & ~pending` and `terminal & pending` cannot both be true in the same
cycle because `pending` transitions atomically. No priority arbitration is
needed.

### Edge case: i_valid simultaneous with terminal (pending=0)

`i_valid & ~pending` fires → shadow captures new ratio → pending = 1.
`terminal & pending` is false (pending was 0 before the edge).
The active register does **not** load this cycle.
The new ratio takes effect at the **next** terminal count.

This 1-period latency in this edge case is documented behaviour, not a bug.
The output waveform remains glitch-free.

---

## Implementation Variants

### Option A (IMPL=0) — up-counter

Shadow and active registers store the **full ratio**.

- Counter counts 0 → ratio-1, then wraps.
- Terminal: `count == active - 1` — a multi-bit runtime comparator.
- C1 toggle: at terminal **and** midpoint (`count == active/2 - 1`).
- C3 output: `terminal_a` directly (1-cycle pulse at each wrap).

### Option B (IMPL=1, default) — down-counter

Shadow and active registers store **ratio/2** (internal width is RATIO_WIDTH-1 bits).

- Counter counts (ratio/2 - 1) → 0, then reloads.
- Terminal: `~|count` — NOR of all bits. No comparator, just a wired-OR reduction.
- C1 toggle: every terminal. Period = 2 × (ratio/2) = ratio. 50% duty cycle "for free."
- C3 output: `terminal & skip_b`. The skip flop (`skip_b`) toggles every terminal,
  suppressing every other pulse → 1 pulse per full ratio period.

### Why Option B is the default

For large RATIO_WIDTH, Option A's comparator (`count == active - 1`) is an
N-bit equality check that costs area and sits on the critical path. Option B
replaces it with `~|count` — a single NOR gate after the counter chain — which
has constant cost regardless of RATIO_WIDTH.

| Dimension | Option A | Option B |
|-----------|----------|----------|
| Counter direction | up | down |
| Internal storage | full ratio | ratio/2 |
| Terminal detect | comparator (N bits) | NOR (1 gate) |
| C1 toggle points | terminal + midpoint | every terminal |
| C3 extra logic | midpoint comparator | 1 skip flop + 1 AND |

---

## Constraints

| Constraint | Detail |
|------------|--------|
| `i_ratio` must be even | LSB is discarded (`ratio >> 1`). Odd values are silently truncated. |
| `i_ratio ≥ 2` | Values 0 and 1 cause degenerate counter behaviour. Module does not assert. |
| `DEFAULT_DIV` must be even and ≥ 2 | Same reason — used as the reset-state ratio. |
| `RATIO_WIDTH ≥ $clog2(DEFAULT_DIV)+1` | Must be wide enough to represent DEFAULT_DIV. |
| `i_ratio` must be synchronous to `i_clk` | If ratio originates from another clock domain, use `fpga_cdc_lib` to cross it safely. |

---

## C3 Output Behaviour (Option B)

The `skip_b` flop inverts the phase relationship between terminals and the
C3 pulse on every ratio change. The first C3 pulse after a ratio change may
appear at either the first or second terminal count depending on the state of
`skip_b` at the time the active register loads. This is expected behaviour —
C3 consumers should not rely on absolute phase.

---

## Usage Warning

`o_clk_out` is a **clock enable**, not a clock signal. See `clk_div2.md` for
the canonical usage pattern and the rationale for not driving clock ports
directly.
