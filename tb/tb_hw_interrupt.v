`timescale 1ns/1ps

module tb_hw_interrupt;
    reg clock;
    reg reset;
    reg hardware_interrupt;
    wire [15:0] TestValue;
    wire [6:0]  PAD;
    wire        uart_tx;

    MIPS_SoC MIPS (
        .CLK_PAD(clock),
        .RST_PAD(reset),
        .PAD(PAD),
        .UART_TX(uart_tx),
        .UART_RX(1'b1),
        .TestValue(TestValue),
        .ext_interrupt(hardware_interrupt)
    );

    initial begin
        clock = 0;
        hardware_interrupt = 0;
        forever #10 clock = ~clock;
    end

    initial begin
        reset = 0;
        #20 reset = 1;
        
        // Let processor run for a bit in test1
        #200;
        $display("[TB] Asserting hardware_interrupt at t=%0t ns, PCF=%h", $time, MIPS.core.PCF);
        hardware_interrupt = 1;
        #20;
        hardware_interrupt = 0;
        $display("[TB] Deasserted hardware_interrupt at t=%0t ns", $time);
    end

    // Monitor CP0 and execution
    reg interrupt_detected = 0;
    always @(posedge clock) begin
        if (MIPS.core.cp0_inst.exception_trigger && MIPS.core.cp0_inst.exception_cause == 32'h0000_0000) begin
            $display("[TB] SUCCESS: Hardware Interrupt triggered in CP0 at t=%0t ns! exception_epc=%h, Cause_in=%h",
                $time, MIPS.core.cp0_inst.exception_epc, MIPS.core.cp0_inst.exception_cause);
            interrupt_detected <= 1;
        end
        if (interrupt_detected && MIPS.core.PCF == 32'h0000_8180) begin
            $display("[TB] SUCCESS: At handler entry 0x0000_8180 at t=%0t ns: EPC_out=%h, Cause_out=%h",
                $time, MIPS.core.cp0_inst.EPC_out, MIPS.core.cp0_inst.Cause_out);
        end
    end

    initial begin
        $readmemh("Tests/test1/Test1.mem", MIPS.core.ROM.memory);
        #10000;
        if (interrupt_detected && MIPS.core.registers.registers[16][15:0] == 16'hD08E) begin
            $display("\n=======================================================");
            $display("    RESULT: HARDWARE INTERRUPT TEST PASSED!            ");
            $display("=======================================================\n");
        end else begin
            $display("\n=======================================================");
            $display("    RESULT: HARDWARE INTERRUPT TEST FAILED!            ");
            $display("    interrupt_detected=%b, $s0=%h", interrupt_detected, MIPS.core.registers.registers[16]);
            $display("=======================================================\n");
        end
        $finish;
    end

endmodule
