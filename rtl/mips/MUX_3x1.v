module mux_3x1 #(parameter N = 32) (
	output [N-1:0] MuxOut,
	input [N-1:0] MuxIn1, MuxIn2, MuxIn3,
	input [1:0] sel
);

	assign MuxOut = (sel == 2'b00) ? MuxIn1 :
	                (sel == 2'b01) ? MuxIn2 :
	                (sel == 2'b10) ? MuxIn3 :
	                MuxIn1;

endmodule
