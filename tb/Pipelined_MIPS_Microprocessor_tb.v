`timescale 1ns/1ps
module Pipelined_MIPS_Microprocessor_tb();

	reg clock, reset;
	wire [15:0] TestValue;
	
	Pipelined_MIPS_Microprocessor MIPS (
		.TestValue(TestValue),
		.reset(reset),
		.clock(clock)
	);
	
	initial begin
		clock = 0;
		forever #10 clock = ~clock;
	end

	always @(negedge clock) begin
		if (reset) begin
			if (MIPS.registers.registers[16][15:0] == 16'hD08E) begin
				$display("Simulation Finished!");
				$display("TestValue (RAM[1:0]) = %0d", TestValue);
				$display("Register $s0 ($16)   = 32'h%h (%0d)", MIPS.registers.registers[16], MIPS.registers.registers[16]);
				$display("RESULT: TEST PASSED!");
				$finish;
			end else if (MIPS.registers.registers[16][15:0] == 16'hDEAD) begin
				$display("Simulation Finished!");
				$display("TestValue (RAM[1:0]) = %0d", TestValue);
				$display("Register $s0 ($16)   = 32'h%h (%0d)", MIPS.registers.registers[16], MIPS.registers.registers[16]);
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
			$readmemh(test_file, MIPS.ROM.memory);
		end else begin
			$display("No MEM_FILE argument specified. Defaulting to Tests/test1/Test1.mem");
			$readmemh("Tests/test1/Test1.mem", MIPS.ROM.memory);
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
		$display("Register $s0 ($16)   = 32'h%h (%0d)", MIPS.registers.registers[16], MIPS.registers.registers[16]);
		if (MIPS.registers.registers[16][15:0] == 16'hD08E) begin
			$display("RESULT: TEST PASSED!");
		end else if (MIPS.registers.registers[16][15:0] == 16'hDEAD) begin
			$display("RESULT: TEST FAILED (DEAD)!");
		end else begin
			$display("RESULT: TEST FAILED (Unknown state / did not finish)!");
		end
		$finish;
	end
endmodule

