# clk_lib

A SystemVerilog library of clock divider modules. Each module is standalone, parameterized, and verified with a self-checking testbench.

## Modules

### clk_div2

Fixed divide-by-2. Output is C1 (50% duty cycle at half the input frequency).

```
i_clk, i_rst_n --> [toggle FF] --> o_clk_out (C1, f_clk/2)
```

No parameters. For larger ratios use `clk_div_even`.

---

### clk_div_even

Fixed divide-by-2^N. N is a compile-time parameter. Output type is selected by MODE.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `N` | 2 | Division ratio = 2^N (N ≥ 1) |
| `MODE` | 0 | 0 = C1 (50% duty), 1 = C3 (1-cycle pulse) |

```
i_clk, i_rst_n --> [N-bit counter] --> o_clk_out
                                         ^
                   MODE=0: count[N-1]    |  (C1, 50% duty)
                   MODE=1: count == '1   |  (C3, 1-cycle pulse every 2^N cycles)
```

N=1 degenerates to divide-by-2, equivalent to `clk_div2`.

---

### clk_div_prog

Runtime-programmable even divider. Ratio is changed via a valid/ready handshake and takes effect glitch-free at the next terminal count.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `RATIO_WIDTH` | 8 | Bit width of `i_ratio` port |
| `DEFAULT_DIV` | 8 | Reset-state ratio (must be even, ≥ 2) |
| `MODE` | 0 | 0 = C1 (50% duty), 1 = C3 (1-cycle pulse) |
| `IMPL` | 1 | 0 = Option A (up-counter), 1 = Option B (down-counter, default) |

```
                valid/rdy handshake        terminal event
                      |                        |
                      v                        v
  i_ratio --> [shadow_reg] --> [active_reg] --> [counter] --> o_clk_out
```

**Option A (IMPL=0)** — up-counter (0 → ratio-1), terminal detected by full comparator.

**Option B (IMPL=1, default)** — down-counter (ratio/2-1 → 0), terminal detected as `~|count` (NOR — no comparator). Stores ratio/2 internally, so internal width is RATIO_WIDTH-1 bits. Lower area for large RATIO_WIDTH.

Both options produce functionally equivalent outputs for the same ratio.

---

## Output Types

| Code | Type | Description |
|------|------|-------------|
| C1 | Real clock, 50% duty | HIGH for half the period, LOW for half |
| C3 | Clock enable pulse | HIGH for exactly 1 master clock cycle per N cycles |

**Usage warning:** All outputs are intended to be used as **clock enables** — `if (o_clk_out)` inside a downstream `always_ff`. Do not connect to a clock port directly. On ASIC this bypasses CTS; on FPGA it requires explicit BUFG insertion.

---

## Quick Start

```bash
# Simulate each module
make sim TOP_MODULE=clk_div2      TESTBENCH=tb_clk_div2
make sim TOP_MODULE=clk_div_even  TESTBENCH=tb_clk_div_even
make sim TOP_MODULE=clk_div_prog  TESTBENCH=tb_clk_div_prog

# View waveforms
make waves TESTBENCH=tb_clk_div2

# Synthesize for iCE40
make synth-ice40 TOP_MODULE=clk_div2
```

All testbenches print `*** TEST PASSED ***` or `*** TEST FAILED ***`.

---

## Design Conventions

- `always_ff` and `always_comb` only — no legacy `always` blocks
- Reset: async assert, synchronous deassert (`i_rst_n` active-low)
- `logic` type only — no `reg` or `wire`
- No vendor primitives — portable across Lattice, Xilinx, Intel, etc.
- One module per file, filename matches module name

---

## Directory Structure

```
clk_lib/
├── sources/
│   ├── rtl/
│   │   ├── clk_div2.sv
│   │   ├── clk_div_even.sv
│   │   └── clk_div_prog.sv
│   ├── tb/
│   │   ├── clk_div2_tb.sv
│   │   ├── clk_div_even_tb.sv
│   │   └── clk_div_prog_tb.sv
│   ├── include/
│   └── constraints/
├── sim/
│   ├── waves/
│   └── logs/
├── backend/
│   ├── synth/
│   ├── pnr/
│   ├── bitstream/
│   └── reports/
├── docs/
│   ├── clk_div2.md
│   ├── clk_div_even.md
│   └── clk_div_prog.md
├── Makefile
└── README.md
```

---

## Tools

| Tool | Purpose | Install |
|------|---------|---------|
| Icarus Verilog | Simulation | `sudo apt install iverilog` |
| GTKWave | Waveform viewer | `sudo apt install gtkwave` |
| Yosys | Synthesis | `sudo apt install yosys` |
| NextPNR | Place & route (optional) | `sudo apt install nextpnr-ice40` |

---

## Status

| Module | Simulation | Synthesis (iCE40) |
|--------|------------|-------------------|
| clk_div2 | PASS | - |
| clk_div_even | PASS | - |
| clk_div_prog | PASS | - |

---

## License

MIT License — Copyright (c) 2026 [moaz khaled](https://github.com/moaz-kh).

Free to use, modify, and distribute for any purpose. Attribution required — keep the copyright notice in all copies or substantial portions of the code.
