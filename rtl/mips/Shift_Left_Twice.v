module Shift_Left_Twice #(parameter in_width = 32,
									out_width = 32
)(
	output [out_width-1 :0] out,
	input  [in_width-1 :0] in

);
	
	assign out = in << 2;
endmodule