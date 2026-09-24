module mux_2x1 #(parameter N = 32 ) (
	output [N-1:0]MuxOut,
	input [N-1:0] MuxIn1,MuxIn2,
	input sel
);

	assign MuxOut = (sel == 1'b0) ? MuxIn1 : MuxIn2;

endmodule
