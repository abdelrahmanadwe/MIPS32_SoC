`timescale 1ns/1ps
module Pipelined_MIPS_Microprocessor_tb();

	reg clock, reset;
	reg hardware_interrupt;
	wire [15:0] TestValue;
	wire [6:0]  PAD;
	wire        uart_tx;
	wire        uart_rx;

	// External loopback jumper wire between TX and RX
	assign uart_rx = uart_tx;
	assign PAD[1]  = PAD[0];

	MIPS_SoC #(
		.FAST_TIMER(1)
	) MIPS (
		.CLK_PAD(clock),
		.RST_PAD(reset),
		.PAD(PAD),
		.UART_TX(uart_tx),
		.UART_RX(uart_rx),
		.TestValue(TestValue),
		.ext_interrupt(hardware_interrupt)
	);
	
	initial begin
		clock = 0;
		hardware_interrupt = 0;
		forever #10 clock = ~clock;
	end

	// Monitor GPIO PAD outputs (LEDs on PAD[6:3])
	integer gpio_toggle_count = 0;
	always @(PAD[6:3]) begin
		if (reset) begin
			$display("[TB] GPIO LED Change detected: PAD[6:3] = 4'b%b (LEDs 3,4,5,6)", PAD[6:3]);
			gpio_toggle_count = gpio_toggle_count + 1;
			if (PAD[6:3] == 4'b0000 && gpio_toggle_count >= 4) begin
				$display("\n=======================================================");
				$display("    TEST 9 (SOC GPIO / TIMER VERIFICATION) PASSED!     ");
				$display("    Total GPIO Toggle Cycles = %0d                     ", gpio_toggle_count);
				$display("=======================================================\n");
				$finish;
			end
		end
	end

	always @(negedge clock) begin
		if (reset) begin
			if (MIPS.core.registers.registers[16][15:0] == 16'hD08E) begin
				$display("Simulation Finished!");
				$display("TestValue (RAM[1:0]) = %0d", TestValue);
				$display("Register $s0 ($16)   = 32'h%h (%0d)", MIPS.core.registers.registers[16], MIPS.core.registers.registers[16]);
				$display("RESULT: TEST PASSED!");
				$finish;
			end else if (MIPS.core.registers.registers[16][15:0] == 16'hDEAD) begin
				$display("Simulation Finished!");
				$display("TestValue (RAM[1:0]) = %0d", TestValue);
				$display("Register $s0 ($16)   = 32'h%h (%0d)", MIPS.core.registers.registers[16], MIPS.core.registers.registers[16]);
				$display("RESULT: TEST FAILED (DEAD)!");
				$finish;
			end
		end
	end

	// Dynamic test memory loading
	reg [1023:0] test_file;
	initial begin
		if ($value$plusargs("MEM_FILE=%s", test_file)) begin
			$display("Loading memory file: %s", test_file);
			$readmemh(test_file, MIPS.core.ROM.memory);
		end else begin
			$display("No MEM_FILE argument specified. Defaulting to Tests/test1/Test1.mem");
			$readmemh("Tests/test1/Test1.mem", MIPS.core.ROM.memory);
		end
	end

	initial begin
		reset = 0;
		# 20 reset = 1;
	end

	initial begin
		#500000; // Run for 500us to allow longer tests like test7 to complete
		$display("Simulation Finished!");
		$display("TestValue (RAM[1:0]) = %0d", TestValue);
		$display("Register $s0 ($16)   = 32'h%h (%0d)", MIPS.core.registers.registers[16], MIPS.core.registers.registers[16]);
		if (MIPS.core.registers.registers[16][15:0] == 16'hD08E) begin
			$display("RESULT: TEST PASSED!");
		end else if (MIPS.core.registers.registers[16][15:0] == 16'hDEAD) begin
			$display("RESULT: TEST FAILED (DEAD)!");
		end else begin
			$display("RESULT: TEST FAILED (Unknown state / did not finish)!");
		end
		$finish;
	end
endmodule
