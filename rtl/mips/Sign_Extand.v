module Sign_Extand(
	output reg [31:0]out,
	input  [15:0]in,
	input [1:0] ExtOp
);
	always @(*) begin
		case (ExtOp)
			2'b00:   out = {16'b0, in};             // Zero-extension
			2'b01:   out = {{16{in[15]}}, in};      // Sign-extension
			2'b10:   out = {in, 16'b0};             // Upper immediate (LUI)
			default: out = {{16{in[15]}}, in};      // Default to sign-extension
		endcase
	end

endmodule