module ProgramCounter(
	output reg [31:0]ProgramCounterOut,
	input [31:0]ProgramCounterIn,
	input clock,reset
);

	always @(posedge clock or negedge reset) begin 
		if(!reset)begin
			ProgramCounterOut <= 32'b0;
		end
		else begin
			ProgramCounterOut <= ProgramCounterIn;
		end
	end

endmodule