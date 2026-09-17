# MIPS 32-bit Processor (Pipelined with CP0 Exceptions, Dynamic Branch Prediction & Single-Cycle)

A synthesizable, 32-bit MIPS Microprocessor implemented in Verilog. This repository features both an advanced **5-stage Pipelined Processor with Coprocessor 0 (CP0) Exception/Interrupt handling, a 2-Bit Dynamic Branch Predictor, and Hazard Unit**, as well as a pure structural **Single-Cycle Processor** for golden reference. It features an optimized, parameterized memory architecture designed to support dynamic test loading and prepares the design for Memory-Mapped I/O (MMIO).

---

## 1. Architecture Overview

### A. 5-Stage Pipelined Processor (`Pipelined_MIPS_Microprocessor.v`)
The core design implements a classic 5-stage instruction pipeline (`IF` -> `ID` -> `EX` -> `MEM` -> `WB`) with comprehensive hazard resolution, dynamic speculation, and hardware exception vectoring:
1. **Instruction Fetch (IF)**:
   - Program Counter with freeze support (`StallF`, `hw_int_pending`).
   - Synthesizable byte-addressable ROM (`InstructionMemory`) supporting dual-region decoding (User Text vs. Reserved Exception Handler).
   - PC+4 Incrementer.
   - Dual-multiplexer selection network driven by dynamic branch prediction, misprediction recovery, and exception vectoring to `0x0000_8180`.
2. **Instruction Decode (ID)**:
   - Centralized `ControlUnit` decoding R-type, I-type, J-type, and Coprocessor 0 (`mfc0`, `mtc0`, `syscall`, `break`) instructions.
   - Synchronous exception detection for `syscall`, `break`, and undefined instructions (`is_undefined`).
   - 32x32 `RegisterFile` with internal WB-to-ID bypass for same-cycle read-after-write.
   - Early Branch Evaluation (`Branch_Unit` / `Branch Comparison`) for low branch penalty.
   - Sign/Zero extension (`Sign_Extand`).
   - Branch target and jump target calculation.
3. **Execute (EX)**:
   - 32-bit ALU (`ALU_32_bits`) with integrated combinational `multiplier` and `divider` units.
   - Synchronous exception detection for divide-by-zero (`divisor == 0`) and arithmetic overflow on signed operations (`add`, `sub`, `addi`).
   - Special-purpose `HI` and `LO` registers (`HILO_Regs`) for `mult`, `multu`, `div`, `divu`, `mul`, `mfhi`, `mflo`, `mthi`, `mtlo`.
   - Coprocessor 0 register reading/writing (`mfc0`, `mtc0`).
   - Forwarding multiplexers for operands `SrcA` and `SrcB` (`ForwardAE`, `ForwardBE`).
4. **Memory Access (MEM)**:
   - Parameterized, byte-addressable Data RAM (`Data_Memory`) with byte, halfword, and word read/write support (`lb`, `lbu`, `lh`, `lhu`, `lw`, `sb`, `sh`, `sw`).
   - Exception qualification suppressing data memory writes on faulting instructions (`MemWriteE_eff`).
5. **Writeback (WB)**:
   - Unified datapath writeback selecting between ALU results, Memory load data, return address (`PC+4`), HI/LO registers, and CP0 registers (`mfc0`).
   - Exception qualification suppressing register file writes on faulting instructions (`RegWriteE_eff`).

---

### B. Coprocessor 0 (CP0) & Exception Handling Unit (`Coprocessor0.v`)
The processor integrates full MIPS Coprocessor 0 support for hardware interrupts and internal exceptions:
- **CP0 Registers**: 32 32-bit special-purpose registers, notably:
  - **Register 13 (`Cause`)**: Records the exception type code.
  - **Register 14 (`EPC`)**: Exception Program Counter storing the return address for handler resumption.
- **Instruction Support**:
  - `mfc0 rt, rd`: Transfers CP0 register `rd` into general-purpose register `rt`.
  - `mtc0 rt, rd`: Transfers general-purpose register `rt` into CP0 register `rd`.
- **Supported Exceptions & Codes**:

| Exception Type | Detection Stage & Condition | Cause Code | Saved EPC | Handler Entry |
| :--- | :--- | :---: | :---: | :---: |
| **Hardware Interrupt** | External input `hardware_interrupt`; pipeline drains in-flight instructions | `32'h0000_0000` | Next PC turn (`PCF`) | `0x0000_8180` |
| **Syscall** | ID Stage: Opcode `000000`, Funct `001100` (`12`) | `32'h0000_0020` | `PCPlus4D` | `0x0000_8180` |
| **Break** | ID Stage: Opcode `000000`, Funct `001101` (`13`) | `32'h0000_0024` | `PCPlus4D` | `0x0000_8180` |
| **Divide by Zero** | EX Stage: Signed/unsigned `div`/`divu` with divisor == 0 | `32'h0000_0024` | `PCPlus4E` | `0x0000_8180` |
| **Undefined Instruction** | ID Stage: Unrecognized opcode or illegal funct field | `32'h0000_0028` | `PCPlus4D` | `0x0000_8180` |
| **Arithmetic Overflow** | EX Stage: Signed `add`, `sub`, or `addi` with arithmetic overflow | `32'h0000_0030` | `PCPlus4E` | `0x0000_8180` |

- **Dual-Region Instruction Memory**:
  - Bit 15 (`Address[15] == 0`): User Text Section (`0x0000_0000` - `0x0000_0FFF`).
  - Bit 15 (`Address[15] == 1`): Reserved Exception Section (`0x0000_8000` - `0x0000_8FFF`), with handler entry point at `0x0000_8180`.
- **Pipeline Flush & State Protection**:
  - Faulting instructions have their register, memory, and HI/LO writes suppressed immediately.
  - IF and ID stages are synchronously flushed, and PC vectors atomically to `0x0000_8180`.

---

### C. Hazard Detection & Forwarding Unit (`Hazard_Unit.v`)
- **Data Hazards (Forwarding)**:
  - **EX Forwarding**: Forwards results from `MEM` stage (`ALUOutM`) and `WB` stage (`ResultW`) directly to ALU inputs `SrcAE` and `SrcBE`.
  - **ID Forwarding**: Forwards results from `MEM` stage directly to ID-stage Branch Comparison and Jump Register (`jr`).
  - **CP0 Forwarding & Stalling**: Automatically stalls `jr` when reading `EPC` via `mfc0` in EX stage, then forwards the value directly from MEM stage to ID.
  - **Store Forwarding**: Forwards store data directly to `WriteDataM`.
  - **Internal RF Bypass**: Same-cycle WB-to-ID register forwarding with 0 stalls.
- **Load-Use Hazards (Stalls / Bubbles)**:
  - Stalls `PC` and `IF/ID` register for 1 cycle and injects a bubble (`NOP`) into `ID/EX` when an instruction in ID depends on a load instruction in EX.
- **Branch Data Stalling**:
  - Automatically stalls for 1 cycle if a branch operand is being computed by an ALU instruction in EX or a load in MEM.

---

### D. 2-Bit Dynamic Branch Predictor (`Branch_Predictor.v`)
- **Branch Target Buffer (BTB)**:
  - 1024-entry direct-mapped BTB covering the entire 4KB instruction address space with zero aliasing.
- **2-Bit Saturating Counter State Machine**:
  - `00`: Strongly Not Taken (Predict Not Taken)
  - `01`: Weakly Not Taken (Predict Not Taken)
  - `10`: Weakly Taken (Predict Taken)
  - `11`: Strongly Taken (Predict Taken)
- **Zero-Cycle Branch Speculation**:
  - Predicts branch/jump targets in the IF stage, selecting the target via `branch_pred_sel` with 0 bubbles when correct.
- **Fast Recovery on Misprediction**:
  - Evaluates actual branch outcome in the ID stage.
  - On misprediction, asserts `mispred_sel`, flushing the speculatively fetched instruction from `IF/ID` (`clr`) and restoring `PC` to `mispred_correct_target` in only 1 cycle.

---

## 2. Memory Organization & Mapping

- **Instruction Memory (ROM)**:
  - **User Text Segment**: `0x0000_0000` to `0x0000_0FFF` (4KB, 1024 words).
  - **Reserved Exception Vector**: `0x0000_8000` to `0x0000_8FFF` (4KB), with handler entry at `0x0000_8180`.
- **Data Memory (RAM)**:
  - **Size**: 28KB (28,672 bytes).
  - **Address Range**: `0x0000_1000` to `0x0000_7FFF`.
  - **Address Translation**: Validates addresses within `[0x1000, 0x7FFF]`. If valid, translates via `Address - 32'h1000`.
- **Reserved / MMIO Space**:
  - Addresses `< 0x1000` and `>= 0x8000` reserved for MMIO peripherals and exception handling.

---

## 3. Directory Layout

```
├── README.md                           # Main project documentation
├── supported_isa.md                    # Reference manual of supported MIPS instructions
├── run.do                              # QuestaSim / ModelSim automation simulation script
├── run_test.sh                         # Linux shell test runner script
├── clean.sh                            # Script to clean simulation and build artifacts
├── rtl/                                # Hardware RTL Source Code
│   ├── ALU_32.v                        # 32-bit Arithmetic Logic Unit
│   ├── ALU_Decoder.v                   # ALU function code decoder
│   ├── Adder_32.v                      # 32-bit binary adder
│   ├── adder_sub.sv                    # Configurable adder/subtractor
│   ├── Branch_Predictor.v              # 2-bit saturating dynamic branch predictor with BTB
│   ├── Branch_Unit.v                   # Branch condition evaluation unit
│   ├── Control_Unit.v                  # CPU control unit (Main + ALU decoders)
│   ├── Coprocessor0.v                  # Coprocessor 0 (CP0) with 32 registers, Cause & EPC
│   ├── Data_Memory.v                   # Parameterized Data Memory (RAM)
│   ├── divider.v                       # 32-bit unsigned/signed divider with div-by-zero detection
│   ├── Hazard_Unit.v                   # Forwarding, stall, and flush hazard detection unit
│   ├── HILO_Regs.v                     # Special-purpose HI and LO registers
│   ├── Instruction_Memory.v            # Dual-region synthesizable byte-addressable ROM
│   ├── Main_Decoder.v                  # Control signal decoder (with CP0 & exception decode)
│   ├── MUX_2x1.v                       # Parameterized 2:1 multiplexer
│   ├── MUX_3x1.v                       # Parameterized 3:1 multiplexer
│   ├── MUX_5x1.v                       # Parameterized 5:1 multiplexer
│   ├── multiplier.v                    # 32-bit unsigned/signed multiplier
│   ├── Pipeline_Registers.v            # Synchronous IF/ID, ID/EX, EX/MEM, MEM/WB registers
│   ├── Pipelined_MIPS_Microprocessor.v # Top-level 5-stage Pipelined Processor
│   ├── ProgramCounter.v                # 32-bit PC register
│   ├── Register_File.v                 # 32x32 Register File
│   ├── Shift_Left_Twice.v              # Word-aligning shifter
│   ├── Sign_Extand.v                   # Immediate sign / zero / upper extender
│   └── Single_Cycle_MIPS_Microprocessor.v # Top-level Single-Cycle Processor
├── tb/                                 # Verification Testbenches
│   ├── Pipelined_MIPS_Microprocessor_tb.v    # Dynamic loading testbench (Pipelined)
│   ├── Single_Cycle_MIPS_Microprocessor_tb.v # Dynamic loading testbench (Single-Cycle)
│   └── tb_hw_interrupt.v               # Dedicated Hardware Interrupt verification testbench
└── Tests/                              # Organized MIPS Test Suite
    ├── test1/                          # ALU operations & Load-Use hazard test
    ├── test2/                          # Subroutine calling & stack pointer test (jal, jr)
    ├── test3/                          # Branches (blez, bgtz, bltz, bgez, beq, bne) & Logic test
    ├── test4/                          # Control flow & immediate logical test
    ├── test5/                          # Shift operations (sll, srl, sra, sllv, srlv, srav) test
    ├── test6/                          # Multiplication & Division (mul, mult, div, mfhi, mflo) test
    ├── test7/                          # Branch Predictor verification test (4,000 loop iterations)
    ├── test8/                          # Coprocessor 0 & Exception Handling verification test
    └── instructions1/                  # Basic loop & factorial test
```

---

## 4. Verification & Testing

The test suite dynamically loads byte-by-byte memory files (`.mem`) using simulation plusargs (`+MEM_FILE`), avoiding the need to modify source files or recompile between tests.

### Running Tests (QuestaSim / ModelSim)

You can run any test directly from your terminal using the `./run_test.sh` script:

```bash
# Run tests on the 5-Stage Pipelined Processor (Default):
./run_test.sh test1
./run_test.sh test2
./run_test.sh test3
./run_test.sh test4
./run_test.sh test5
./run_test.sh test6
./run_test.sh test7
./run_test.sh test8

# Run dedicated hardware interrupt test:
vlog -sv rtl/*.v rtl/*.sv tb/tb_hw_interrupt.v && vsim -c -do "run -all; quit" tb_hw_interrupt

# Run tests on the Single-Cycle Processor (Golden Reference):
./run_test.sh test1 Single_Cycle_MIPS_Microprocessor_tb
```

### Verification Test Suite Results

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
| **hw_int** | **Hardware Interrupt**: External interrupt pin, pipeline drain, CP0 Cause=0 & EPC save, vector to `0x8180` | **PASSED** ✅ | `32'hffffd08e` |

### Result Criteria
- **TEST PASSED**: Register `$s0` lower 16 bits contain `16'hD08E`.
- **TEST FAILED**: Register `$s0` lower 16 bits contain `16'hDEAD`.
