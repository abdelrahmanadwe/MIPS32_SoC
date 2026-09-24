module HILO_Regs (
	output reg [31:0] HI,
	output reg [31:0] LO,
	input [31:0] hi_in,
	input [31:0] lo_in,
	input hi_write,
	input lo_write,
	input clock,
	input reset
);

	always @(posedge clock or negedge reset) begin
		if (!reset) begin
			HI <= 32'b0;
			LO <= 32'b0;
		end
		else begin
			if (hi_write) HI <= hi_in;
			if (lo_write) LO <= lo_in;
		end
	end

endmodule
