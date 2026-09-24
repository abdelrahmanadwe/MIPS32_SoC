# MIPS 32-bit SoC (5-Stage Pipelined Core with AHB-Lite & APB Subsystem)

A synthesizable, 32-bit System-on-Chip (SoC) based on the MIPS architecture, implemented in Verilog and SystemVerilog. The design integrates an advanced **5-stage Pipelined MIPS Processor Core with Coprocessor 0 (CP0) Exception/Interrupt handling, a 2-Bit Dynamic Branch Predictor, and Hazard Unit**, an **AHB-Lite Bus Matrix**, a **Synchronous 4-Bank Data Memory (BRAM)**, an **AHB-to-APB Subsystem Bridge**, and standard/custom peripherals (**CMSDK GPIO**, **CMSDK Timer**, and a **Custom UVM-Verified APB UART**).

A structural **Single-Cycle Processor** is also retained as a golden verification reference.

---

## 1. SoC Architecture & Interconnect

The top-level SoC module (`MIPS_SoC.v`) encapsulates the processor core and all bus infrastructure, behaving like a physical microcontroller with cleanly exposed I/O pads and serial interfaces.

```
                      +---------------------------------------+
                      |         Pipelined MIPS Core           |
                      |  (5 Stages, Dynamic BP, Hazard, CP0)  |
                      +---------------------------------------+
                           | MEM Addr/Ctrl         ^ Read Data
                           v                       |
                  +-----------------+     +-----------------+
                  |   ahb_decoder   |     |  ahb_slave_mux  |
                  +-----------------+     +-----------------+
                     |    |    |   \         ^   ^   ^   ^
           +---------+    |    |    \        |   |   |   |
           |              |    |     \       |   |   |   |
           v              v    |      v      |   |   |   |
     +-----------+  +--------+ |   +---------------+ |   |
     |   Data    |  |  GPIO  | |   |  ahb_to_apb   | |   |
     |  Memory   |  | (cmsdk)| |   | Subsystem     | |   |
     | (4-bank)  |  +--------+ |   |    Bridge     | |   |
     +-----------+      |      |   +---------------+ |   |
           |            |      |      |         |    |   |
           |            |      |      | APB     |    |   |
           |            |      |      v         v    |   |
           |            |      |  +--------+ +-----+ |   |
           |            |      |  |  Timer | |UART | |   |
           |            |      |  | (cmsdk)| |(Own)|-+---+
           |            |      |  +--------+ +-----+ |
           |            |      v      |         |    |
           |            |  +-----------+     TX | RX |
           |            |  | ahb_def_  |        |    |
           |            |  |   slave   |--------+----+
           |            |  +-----------+        |    |
           +------------+                       |    |
                 |                              |    |
        gpio_int | tim_int | uart_int           |    |
                 v    v        v                |    |
           +---------------------------+        |    |
           |  CP0 Interrupt Controller |        |    |
           +---------------------------+        |    |
                                                |    |
         ================== CHIP BOUNDARY ======|====|=======================
                                                |    |
                                                v    ^
                                             UART_TX UART_RX
                                             (PAD[0])(PAD[1])
                                                |    |
                         [ External Jumper Wire |====| in Testbench ]
```

### Key Subsystems:
1. **AHB-Lite Bus Decoder (`ahb_decoder.v`)**:
   - Translates MIPS core memory access requests into standard AHB-Lite bus transfers (`HTRANS`, `HSIZE`, `HWRITE`, `HADDR`).
   - Decodes target peripherals based on higher address bits and activates corresponding `HSEL` lines.
2. **AHB-Lite Slave Multiplexer (`ahb_slave_mux.v`)**:
   - Routes `HRDATA`, `HREADYOUT`, and `HRESP` from the active slave back to the core based on pipelined select signals.
3. **Synchronous 4-Bank Data Memory (`rtl/ram/Data_Memory.v`)**:
   - Implements 32 KB of byte-addressable synchronous BRAM partitioned into 4 byte banks (`RAM0` - `RAM3`).
   - Supports native byte write enables (`byte_we[3:0]`) for single-cycle `sb`, `sh`, and `sw` operations with zero wait states.
4. **Dual-Protocol AHB-to-APB Subsystem Bridge (`rtl/bus/ahb_to_apb.v`)**:
   - Translates AHB-Lite transactions into APB bus transfers.
   - **Custom UART Timing**: Generates standard APB access phases (`PENABLE = 1`) for register writes.
   - **CMSDK Timer Timing**: Conforms to ARM CMSDK 1-cycle APB convention (`PENABLE = 0`, sampled on `PSEL & ~PENABLE & PWRITE`).
   - **Hazard Handling**: Prioritizes pending write data phases over consecutive read setup phases, preventing back-to-back transfer corruption without wait states.
5. **ARM CMSDK AHB GPIO (`rtl/periph/gpio/`)**:
   - Provides 16-bit software-configurable parallel I/O.
   - Bonded to external `PAD[6:0]` for JB pin-io, switches, and LEDs.
   - Generates edge/level interrupts routed to CP0.
6. **ARM CMSDK APB Timer (`rtl/periph/cmsdk_apb_timer.v`)**:
   - 32-bit down-counter with programmable reload, periodic/one-shot modes, and external clock gating.
   - External event pin hooked to `PAD[2]` (Switch).
   - Generates `tim_int` connected to CP0.
7. **Custom Configurable SystemVerilog APB UART (`rtl/periph/uart/`)**:
   - Full-duplex serial communication with configurable baud generator, 8-bit data, configurable parity (none/odd/even), and stop bits.
   - Independent TX and RX finite state machines.
   - Register file mapped via APB (`DATA`, `STATUS`, `CTRL`, `CFG`, `BAUD_DIV`, `IER`, `ISR`).
   - Generates `uart_int` on TX ready, TX done, RX done, parity error, framing error, or overrun.
8. **AHB-Lite Default Slave (`rtl/bus/ahb_default_slave.v`)**:
   - Handles accesses to unmapped address space cleanly (Read-As-Zero, Writes-Ignored).
9. **External I/O Pads & Clean Pinout Interface**:
   - `PAD[0]`: JB pin-io (FPGA V8) / UART TX
   - `PAD[1]`: JB pin-io (FPGA W8) / UART RX
   - `PAD[2]`: Switch (FPGA G18) / Timer EXTIN
   - `PAD[6:3]`: LEDs (FPGA D13, G14, M15, RE4)
   - `UART_TX` / `UART_RX`: Dedicated top-level serial ports.

---

## 2. Memory & Peripheral Address Map

| Peripheral | Base Address Range | Size | Bus Protocol | Function |
| :--- | :--- | :---: | :---: | :--- |
| **Data Memory (RAM)** | `0x0000_0000 - 0x0000_7FFF` | 32 KB | AHB-Lite | 4-bank Synchronous BRAM (`lb`, `lh`, `lw`, `sb`, `sh`, `sw`) |
| **AHB GPIO** | `0xA000_0000 - 0xA000_07FF` | 2 KB | AHB-Lite | ARM CMSDK GPIO (`DATA`, `DATAOUT`, `OUTENSET`, `INTEN`) |
| **APB UART** | `0xA000_0800 - 0xA000_0BFF` | 1 KB | APB | Custom Serial Transceiver (`DATA`, `STATUS`, `CFG`, `BAUD`) |
| **APB Timer** | `0xA000_0C00 - 0xA000_0FFF` | 1 KB | APB | ARM CMSDK 32-bit Timer (`CTRL`, `VALUE`, `RELOAD`, `INTCLEAR`) |
| **Default Slave** | *Unmapped space* | - | AHB-Lite | RAZ-WI (Read-As-Zero, Writes-Ignored) |

---

## 3. Core Architecture & Features

### A. 5-Stage Pipelined Processor (`Pipelined_MIPS_Microprocessor.v`)
1. **Instruction Fetch (IF)**:
   - Program Counter with freeze support (`StallF`, `hw_int_pending`).
   - Synthesizable byte-addressable ROM (`InstructionMemory`) supporting dual-region decoding (User Text vs. Reserved Exception Handler).
   - Dynamic branch prediction via integrated 1024-entry BTB.
2. **Instruction Decode (ID)**:
   - Centralized `ControlUnit` decoding R, I, J, and Coprocessor 0 (`mfc0`, `mtc0`, `syscall`, `break`) instructions.
   - Synchronous exception detection for `syscall`, `break`, and undefined instructions.
   - 32x32 `RegisterFile` with internal WB-to-ID bypass.
   - Early Branch Evaluation for 1-cycle branch resolution.
3. **Execute (EX)**:
   - 32-bit ALU (`ALU_32_bits`) with integrated `multiplier` and `divider`.
   - Arithmetic overflow detection on signed operations (`add`, `sub`, `addi`) and divide-by-zero detection.
   - Dedicated `HI` and `LO` registers (`HILO_Regs`) for `mult`, `multu`, `div`, `divu`, `mul`, `mfhi`, `mflo`, `mthi`, `mtlo`.
   - Forwarding multiplexers (`ForwardAE`, `ForwardBE`).
4. **Memory Access (MEM)**:
   - Generates clean memory requests to external AHB-Lite bus decoder.
   - Exception qualification suppressing bus writes on faulting instructions (`MemWriteE_eff`).
5. **Writeback (WB)**:
   - Unified writeback multiplexer selecting ALU, Memory load data, return address (`PC+4`), HI/LO registers, and CP0 registers.

### B. Coprocessor 0 (CP0) & Exception Unit (`Coprocessor0.v`)
- **Registers**: 32 32-bit registers including Register 13 (`Cause`) and Register 14 (`EPC`).
- **Supported Exceptions & Codes**:
  - **Hardware Interrupt**: Cause `32'h0000_0000`, EPC = `PCF`, Vectors to `0x0000_8180`.
  - **Syscall**: Cause `32'h0000_0020`, EPC = `PCPlus4D`, Vectors to `0x0000_8180`.
  - **Break**: Cause `32'h0000_0024`, EPC = `PCPlus4D`, Vectors to `0x0000_8180`.
  - **Divide by Zero**: Cause `32'h0000_0024`, EPC = `PCPlus4E`, Vectors to `0x0000_8180`.
  - **Undefined Instruction**: Cause `32'h0000_0028`, EPC = `PCPlus4D`, Vectors to `0x0000_8180`.
  - **Arithmetic Overflow**: Cause `32'h0000_0030`, EPC = `PCPlus4E`, Vectors to `0x0000_8180`.
- **Interrupt Routing**: Aggregates `gpio_int | tim_int | uart_int | ext_interrupt` directly into CP0.

### C. 2-Bit Dynamic Branch Predictor (`Branch_Predictor.v`)
- 1024-entry Branch Target Buffer (BTB).
- 2-Bit Saturating Counter FSM (`Strongly/Weakly Taken/Not Taken`).
- Zero-bubble branch execution when correctly predicted; 1-cycle flush and target recovery on misprediction.

---

## 4. Directory Layout

```
├── README.md                           # Comprehensive documentation
├── supported_isa.md                    # Reference manual of supported MIPS instructions
├── run.do                              # ModelSim / QuestaSim automation script
├── run_test.sh                         # Linux shell regression runner
├── clean.sh                            # Script to clean simulation and build artifacts
├── rtl/                                # Hardware RTL Source Code
│   ├── MIPS_SoC.v                      # Top-Level System-on-Chip (Microcontroller)
│   ├── mips/                           # MIPS Core Datapath & Control
│   │   ├── ALU_32.v                    # 32-bit ALU
│   │   ├── ALU_Decoder.v               # ALU decoder
│   │   ├── Adder_32.v                  # 32-bit binary adder
│   │   ├── adder_sub.sv                # Adder/subtractor
│   │   ├── Branch_Predictor.v          # 2-bit dynamic Branch Predictor with BTB
│   │   ├── Branch_Unit.v               # Branch condition evaluation
│   │   ├── Control_Unit.v              # Main control unit
│   │   ├── Coprocessor0.v              # CP0 unit with 32 registers, Cause & EPC
│   │   ├── divider.v                   # Divider with divide-by-zero detection
│   │   ├── Hazard_Unit.v               # Hazard detection, forwarding & stall unit
│   │   ├── HILO_Regs.v                 # HI and LO registers
│   │   ├── Instruction_Memory.v        # Dual-region instruction ROM
│   │   ├── Main_Decoder.v              # Control signal decoder
│   │   ├── multiplier.v                # Multiplier
│   │   ├── MUX_2x1.v, MUX_3x1.v, MUX_5x1.v # Multiplexers
│   │   ├── Pipeline_Registers.v        # Pipeline stage registers (IF/ID, ID/EX, EX/MEM, MEM/WB)
│   │   ├── Pipelined_MIPS_Microprocessor.v # 5-Stage Pipelined Processor Core
│   │   ├── ProgramCounter.v            # 32-bit Program Counter
│   │   ├── Register_File.v             # 32x32 Register File
│   │   ├── Shift_Left_Twice.v          # Word aligner
│   │   ├── Sign_Extand.v               # Sign / Zero extender
│   │   ├── Single_Cycle_Data_Memory.v  # Dedicated data memory for single-cycle reference
│   │   └── Single_Cycle_MIPS_Microprocessor.v # Golden reference Single-Cycle Core
│   ├── ram/                            # Memory Subsystem
│   │   └── Data_Memory.v               # 4-bank Synchronous BRAM (AHB-Lite Slave)
│   ├── bus/                            # Bus Fabric
│   │   ├── ahb_decoder.v               # AHB-Lite Address Decoder
│   │   ├── ahb_slave_mux.v             # AHB-Lite Slave Multiplexer
│   │   ├── ahb_to_apb.v                # Dual-protocol AHB-to-APB Subsystem Bridge
│   │   └── ahb_default_slave.v         # AHB-Lite Default Slave
│   └── periph/                         # Peripherals
│       ├── cmsdk_apb_timer.v           # ARM CMSDK APB Timer
│       ├── gpio/                       # ARM CMSDK AHB GPIO
│       │   ├── cmsdk_ahb_gpio.v
│       │   ├── cmsdk_ahb_to_iop.v
│       │   └── cmsdk_iop_gpio.v
│       └── uart/                       # Custom APB UART (SystemVerilog)
│           ├── common/uart_defs.sv     # Register definitions & parameters
│           ├── common/baud_generator.sv # Configurable baud generator
│           ├── tx/                     # UART Transmitter (FSM, serializer, parity)
│           ├── rx/                     # UART Receiver (FSM, deserializer, sampler)
│           ├── uart_reg_file.sv        # APB Register File
│           ├── uart_top.sv             # UART Core Top
│           └── UART.sv                 # Top-Level APB UART Peripheral
├── tb/                                 # Verification Testbenches
│   ├── Pipelined_MIPS_Microprocessor_tb.v    # SoC Top Testbench with external UART loopback
│   ├── Single_Cycle_MIPS_Microprocessor_tb.v # Single-Cycle Golden Reference Testbench
│   └── tb_hw_interrupt.v               # Hardware Interrupt Verification Testbench
└── Tests/                              # Regression Test Suite
    ├── test1/                          # ALU operations & Load-Use hazard test
    ├── test2/                          # Subroutine calling & stack pointer test (jal, jr)
    ├── test3/                          # Branches (blez, bgtz, bltz, bgez, beq, bne) & Logic test
    ├── test4/                          # Control flow & immediate logical test
    ├── test5/                          # Shift operations (sll, srl, sra, sllv, srlv, srav) test
    ├── test6/                          # Multiplication & Division (mul, mult, div, mfhi, mflo) test
    ├── test7/                          # Branch Predictor verification test (4,000 loop iterations)
    ├── test8/                          # Coprocessor 0 & Exception Handling verification test
    ├── test9/                          # SoC CMSDK Timer & GPIO LED cycling test
    ├── test10/                         # AHB-Lite Memory Subsystem (Byte/Half/Word read & write)
    ├── test11/                         # Full SoC Integration Test (Core + RAM + GPIO + Timer + UART)
    └── instructions1/                  # Basic loop & factorial test
```

---

## 5. Verification & Testing

The testbench dynamically loads assembled memory files (`.mem`) using simulation plusargs (`+MEM_FILE`), avoiding the need to recompile between tests.

### Running Tests (QuestaSim / ModelSim)

You can run any test directly using `./run_test.sh`:

```bash
# Run full SoC integration test (ALU, BRAM, GPIO, Timer, UART loopback):
./run_test.sh test11

# Run SoC GPIO and Timer test:
./run_test.sh test9

# Run AHB-Lite Memory Subsystem test:
./run_test.sh test10

# Run core MIPS tests (Tests 1 through 8):
./run_test.sh test1
./run_test.sh test7
./run_test.sh test8

# Run dedicated hardware interrupt testbench:
./run_test.sh test1 tb_hw_interrupt

# Run Single-Cycle Processor (Golden Reference):
./run_test.sh test1 Single_Cycle_MIPS_Microprocessor_tb
```

### Complete Regression Results

| Test Name | Focus Area | Status | Expected Return (`$s0`) |
| :--- | :--- | :---: | :---: |
| **test1** | Basic ALU operations, Load-Use stall detection, branch | **PASSED** ✅ | `32'hffffd08e` |
| **test2** | Procedures, Stack handling, `jal`, `jr`, RAW dependencies | **PASSED** ✅ | `32'hffffd08e` |
| **test3** | All conditional branches (`blez`, `bgtz`, `bltz`, `bgez`, `beq`, `bne`), `jalr` | **PASSED** ✅ | `32'hffffd08e` |
| **test4** | Immediate arithmetic, logic, and control flow | **PASSED** ✅ | `32'hffffd08e` |
| **test5** | Shift instructions (`sll`, `srl`, `sra`, `sllv`, `srlv`, `srav`) | **PASSED** ✅ | `32'hffffd08e` |
| **test6** | Multiplier & Divider, HI/LO ops (`mul`, `mult`, `div`, `mfhi`, `mflo`, `mthi`, `mtlo`) | **PASSED** ✅ | `32'hffffd08e` |
| **test7** | **Dynamic Branch Prediction** across 4,000 loop iterations | **PASSED** ✅ | `32'hffffd08e` |
| **test8** | **Coprocessor 0 (CP0) & Exceptions**: Divide-by-zero, Arithmetic overflow, handler execution & EPC return | **PASSED** ✅ | `32'hffffd08e` |
| **test9** | **SoC Timer & GPIO**: CMSDK Timer countdown, GPIO LED toggling on `PAD[6:3]` | **PASSED** ✅ | `32'hffffd08e` |
| **test10** | **AHB-Lite Memory**: BRAM 4-bank byte/half/word writes (`sb`, `sh`, `sw`) and reads | **PASSED** ✅ | `32'hffffd08e` |
| **test11** | **Full SoC Integration**: Core ALU + BRAM + GPIO + Timer + UART TX/RX Loopback & Interrupt | **PASSED** ✅ | `32'hffffd08e` |
| **tb_hw_interrupt** | **Hardware Interrupt**: External interrupt line, pipeline drain, CP0 vectoring | **PASSED** ✅ | `32'hffffd08e` |

### Result Criteria
- **TEST PASSED**: Register `$s0` lower 16 bits contain `16'hD08E` (or GPIO LEDs complete cycling in Test 9).
- **TEST FAILED**: Register `$s0` lower 16 bits contain `16'hDEAD`.
