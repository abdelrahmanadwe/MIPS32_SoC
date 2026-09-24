
# =============================================================================
# Test11_Soc_All.asm
# Comprehensive Full-SoC Integration Test
# Tests:
#   1. Pipelined MIPS Core (ALU arithmetic & branch flow)
#   2. Data Memory BRAM Slave (Word write, byte write-enable, word readback)
#   3. AHB GPIO Peripheral (LED write & readback)
#   4. APB Timer Peripheral (Current value write, readback, decrement check)
#   5. APB UART Peripheral:
#      - Baud divisor configuration & readback
#      - CFG register (TX/RX enable, 8-bit, 1-stop, no-parity)
#      - IER register (rx_done_ie enable)
#      - STATUS register (tx_ready verification)
#      - Transmit byte (0xA5)
#      - Hardware Loopback reception (tx_serial -> rx_serial)
#      - Polling STATUS[3] (rx_done)
#      - Readback received byte from DATA register, verify == 0xA5
#      - Verification that reading DATA clears rx_done flag
#   6. Result: $s0 = 0xD08E on success, $s0 = 0xDEAD on error
# =============================================================================

# 0x0000: Kernel Init
addi $sp, $0, 0x7FFC
addi $gp, $0, 0x1080
jal main
nop

# Fill up to 0x0400 (main) with 0
.org 0x0400
main:
    # -------------------------------------------------------------------------
    # 1. Pipelined Core ALU Test
    # -------------------------------------------------------------------------
    addi $t0, $0, 42
    addi $t1, $0, 58
    add  $t2, $t0, $t1
    addi $t3, $0, 100
    bne  $t2, $t3, ERROR

    # -------------------------------------------------------------------------
    # 2. Data Memory BRAM Byte-Enable Test
    # -------------------------------------------------------------------------
    lui  $t0, 0x0000
    ori  $t0, $t0, 0x0100
    lui  $t1, 0x1234
    ori  $t1, $t1, 0x5678
    sw   $t1, 0($t0)
    addi $t2, $0, 0x00AA
    sb   $t2, 1($t0)
    lw   $t3, 0($t0)
    lui  $t4, 0x1234
    ori  $t4, $t4, 0xAA78
    bne  $t3, $t4, ERROR

    # -------------------------------------------------------------------------
    # 3. AHB GPIO Peripheral Test
    # -------------------------------------------------------------------------
    lui  $t0, 0xA000
    ori  $t0, $t0, 0x0000
    addi $t1, $0, 0x0078
    sw   $t1, 0($t0)
    lw   $t2, 4($t0)
    addi $t3, $0, 0x0078
    bne  $t2, $t3, ERROR

    # -------------------------------------------------------------------------
    # 4. APB Timer Peripheral Test
    # -------------------------------------------------------------------------
    lui  $t0, 0xA000
    ori  $t0, $t0, 0x0C00
    addi $t1, $0, 50
    sw   $t1, 4($t0)
    lw   $t2, 4($t0)
    addi $t3, $0, 50
    bne  $t2, $t3, ERROR
    addi $t1, $0, 1
    sw   $t1, 0($t0)
    nop
    nop
    nop
    nop
    lw   $t4, 4($t0)
    slt  $t5, $t4, $t3
    beq  $t5, $0, ERROR

    # -------------------------------------------------------------------------
    # 5. APB UART Peripheral Loopback Test
    # -------------------------------------------------------------------------
    lui  $t0, 0xA000
    ori  $t0, $t0, 0x0800

    # 5a. Set BAUD_DIV = 1 (offset 0x10)
    addi $t1, $0, 1
    sw   $t1, 0x10($t0)
    lw   $t2, 0x10($t0)
    addi $t3, $0, 1
    bne  $t2, $t3, ERROR

    # 5b. Configure UART CFG = 0x0318 (offset 0x00)
    ori  $t1, $0, 0x0318
    sw   $t1, 0x00($t0)
    lw   $t2, 0x00($t0)
    ori  $t3, $0, 0x0318
    bne  $t2, $t3, ERROR

    # 5c. Enable RX Done Interrupt IER = 0x08 (offset 0x08)
    addi $t1, $0, 0x0008
    sw   $t1, 0x08($t0)

    # 5d. Check STATUS tx_ready = 1 (offset 0x04)
    lw   $t2, 0x04($t0)
    andi $t3, $t2, 0x0010
    beq  $t3, $0, ERROR

    # 5e. Transmit Byte 0xA5 to DATA (offset 0x0C)
    ori  $t1, $0, 0x00A5
    sw   $t1, 0x0C($t0)

    # 5f. Poll STATUS[3] (rx_done)
wait_rx:
    lw   $t2, 0x04($t0)
    andi $t3, $t2, 0x0008
    bne  $t3, $0, rx_done_ok
    j    wait_rx

rx_done_ok:
    # 5g. Read received byte from DATA (offset 0x0C) and verify == 0xA5
    lw   $t4, 0x0C($t0)
    andi $t4, $t4, 0x00FF
    ori  $t5, $0, 0x00A5
    bne  $t4, $t5, ERROR

    # 5h. Verify that reading DATA cleared rx_done flag
    lw   $t2, 0x04($t0)
    andi $t3, $t2, 0x0008
    bne  $t3, $0, ERROR

    # -------------------------------------------------------------------------
    # 6. Turn off LEDs & Signal Success
    # -------------------------------------------------------------------------
    lui  $t0, 0xA000
    ori  $t0, $t0, 0x0000
    sw   $0, 0($t0)

    addiu $s0, $0, 0xD08E
    j    DONE

ERROR:
    addiu $s0, $0, 0xDEAD

DONE:
    nop
    j    DONE
