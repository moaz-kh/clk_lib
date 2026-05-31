# clk_lib

## Project Overview
Enhanced FPGA project with comprehensive simulation and verification capabilities.

## Features
- **Complete simulation workflow** with Icarus Verilog
- **Waveform viewing** with GTKWave  
- **File list management** using rtl_list.f
- **Auto-example generation** with 8-bit adder
- **Standard modules library** (synchronizer, edge_detector, LED_logic, SPI debounce)
- **Comprehensive testbenches** with self-checking
- **Tool detection and verification**
- **One-command testing** with `make quick-test`

## Directory Structure
```
clk_lib/
├── sources/           # Source code
│   ├── rtl/          # RTL source files (.v, .sv)
│   │   └── STD_MODULES.v  # Standard utility modules
│   ├── tb/           # Testbenches
│   ├── include/      # Include files and headers
│   ├── constraints/  # Timing/pin constraints (.pcf, .xdc)
│   └── rtl_list.f    # File list with absolute paths
├── sim/              # Simulation workspace
│   ├── waves/        # Waveform dumps (.vcd, .fst)
│   └── logs/         # Log files
├── backend/          # Backend outputs
│   ├── synth/        # Synthesis outputs (.json)
│   ├── pnr/          # Place & route (.asc)
│   ├── bitstream/    # Final bitstreams (.bin)
│   └── reports/      # Timing/utilization reports
├── Makefile          # Build system
└── README.md         # Project documentation
```

## Standard Modules Library

The project includes `STD_MODULES.v` with ready-to-use modules:

### synchronizer
- **Purpose**: Multi-bit clock domain crossing synchronizer
- **Parameters**: WIDTH (default: 3 bits)
- **Usage**: Synchronize signals between clock domains

### edge_detector  
- **Purpose**: Detect positive and negative edges
- **Parameters**: sync_sig (0=async input, 1=sync input)
- **Outputs**: o_pos_edge, o_neg_edge

### LED_logic
- **Purpose**: Configurable LED blinker/flasher
- **Parameters**: 
  - time_count: Total blink duration (50MHz clk cycles)
  - toggle_count: On/off period (50MHz clk cycles)
- **Usage**: Status indication, error signaling

### spi_interface_debounce
- **Purpose**: Debounce SPI signals for reliable operation
- **Features**: 200MHz system clock, 2-cycle debounce
- **Signals**: SPI clock, MOSI, CS_n debouncing

## Quick Start Guide

### 1. Check tool availability
```bash
make check-tools
```

### 2. Create and test example adder
```bash
make quick-test
```
This will:
- Create example adder RTL (`sources/rtl/adder.v`)
- Create comprehensive testbench (`sources/tb/adder_tb.v`)
- Create iCE40 constraint files (`sources/constraints/adder.pcf`)
- Update file list
- Run simulation
- Open waveforms in GTKWave

### 3. Use standard modules
```verilog
// Example: Use synchronizer in your design
synchronizer #(.WIDTH(8)) sync_inst (
    .i_clk(clk),
    .i_rst_n(rst_n),
    .d_in(async_signal),
    .d_out(sync_signal)
);
```

### 4. Simulation workflow
```bash
# Update file list after adding new files
make update_list

# Run simulation only
make sim

# Run simulation and view waveforms
make sim-waves

# View existing waveforms
make waves
```

### 5. Project status
```bash
make status          # Show project status
make help            # Show all available targets
```

## Development Workflow

### Adding New RTL Modules
1. Add Verilog files to `sources/rtl/`
2. Add testbenches to `sources/tb/` (named `*_tb.v`)
3. Run `make update_list` to refresh file list
4. Test with `make sim-waves`

### Using Standard Modules
- All standard modules are available in `STD_MODULES.v`
- Include in your designs with module instantiation
- No need to add to file lists - automatically included

### Synthesis Workflow
```bash
# Basic synthesis with Yosys
make synth

# For FPGA-specific synthesis, customize the synth target in Makefile
```

## Example Adder Features
The auto-generated adder example includes:
- **8-bit ripple carry adder** with carry input/output
- **Modular design** using full adder components
- **iCE40 constraint file** ready for NextPNR (iCEBreaker board pinout)
- **Comprehensive testbench** with 600+ test cases:
  - Basic functionality tests
  - Random testing (100 cases)
  - Exhaustive corner cases (512 cases)
  - Self-checking verification
  - Detailed pass/fail statistics

## Available Make Targets

### Simulation
- `make sim` - Compile and run simulation
- `make waves` - Open waveform viewer
- `make sim-waves` - Run simulation and open waveforms

### Examples
- `make create-example` - Create adder example files
- `make quick-test` - Full automated test

### Utilities
- `make update_list` - Update rtl_list.f file list
- `make check-tools` - Verify tool installation
- `make status` - Show project status
- `make clean` - Clean generated files
- `make help` - Show all targets

## Tools Required
- **Icarus Verilog** (simulation): `sudo apt install iverilog`
- **GTKWave** (waveform viewer): `sudo apt install gtkwave`
- **Yosys** (synthesis): `sudo apt install yosys`
- **Make** (build automation): Usually pre-installed

## File Management
- `rtl_list.f` contains absolute paths to all source files
- Run `make update_list` after adding/removing files
- Many EDA tools support file lists with `-f` option

## Troubleshooting
- Run `make check-tools` to verify tool installation
- Check `sim/logs/simulation.log` for simulation output
- Ensure files are added to correct directories before `make update_list`

Generated with enhanced initiate_proj_script.sh
