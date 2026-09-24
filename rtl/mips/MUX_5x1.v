module mux_5x1 #(parameter N = 32) (
	output [N-1:0] MuxOut,
	input [N-1:0] MuxIn1, MuxIn2, MuxIn3, MuxIn4, MuxIn5,
	input [2:0] sel
);

	assign MuxOut = (sel == 3'b000) ? MuxIn1 :
	                (sel == 3'b001) ? MuxIn2 :
	                (sel == 3'b010) ? MuxIn3 :
	                (sel == 3'b011) ? MuxIn4 :
	                (sel == 3'b100) ? MuxIn5 :
	                MuxIn1;

endmodule
