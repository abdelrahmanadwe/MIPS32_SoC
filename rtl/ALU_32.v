module ALU_32_bits(
	output reg [63:0]ALUResult,
	output reg Zero,
	output reg Overflow,
	output wire divide_by_zero,
	input [31:0]SrcA,SrcB,
	input [3:0] ALUControl,
	input is_signed,
	input [4:0] shamt
);

	parameter AND  = 4'b0000,
			  OR   = 4'b0001,
			  ADD  = 4'b0010,
			  SLL  = 4'b0011,
			  SUB  = 4'b0100,
			  MULT = 4'b0101,
			  SLT  = 4'b0110,
			  SRL  = 4'b0111,
			  SRA  = 4'b1000,
			  SLLV = 4'b1001,
			  SRLV = 4'b1010,
			  SRAV = 4'b1011,
			  XOR  = 4'b1100,
			  LUI  = 4'b1101,
			  NOR  = 4'b1110,
			  DIV  = 4'b1111;

	wire [32:0] adder_sub_sum;
	wire is_sub = (ALUControl == SUB || ALUControl == SLT);

	adder_sub #(.WIDTH(32)) adder_sub_inst (
		.a(SrcA),
		.b(SrcB),
		.is_signed(is_signed),
		.is_sub(is_sub),
		.sum(adder_sub_sum)
	);

	wire [63:0] mul_product;
	wire [31:0] div_quotient;
	wire [31:0] div_remainder;

	multiplier multiplier_inst(
		.a(SrcA),
		.b(SrcB),
		.is_signed(is_signed),
		.product(mul_product)
	);

	wire div_by_zero_raw;
	divider divider_inst(
		.a(SrcA),
		.b(SrcB),
		.is_signed(is_signed),
		.quotient(div_quotient),
		.remainder(div_remainder),
		.divide_by_zero(div_by_zero_raw)
	);

	assign divide_by_zero = (ALUControl == DIV) && div_by_zero_raw;

	always @(*)begin
		Overflow = 1'b0;
		case (ALUControl)
			AND  : ALUResult = {32'b0, SrcA & SrcB} ;
			OR   : ALUResult = {32'b0, SrcA | SrcB} ;
			ADD  : begin
				ALUResult = {32'b0, adder_sub_sum[31:0]} ;
				Overflow = (SrcA[31] == SrcB[31]) && (adder_sub_sum[31] != SrcA[31]);
			end
			SLL  : ALUResult = {32'b0, SrcB << shamt} ;
			SUB  : begin
				ALUResult = {32'b0, adder_sub_sum[31:0]} ;
				Overflow = (SrcA[31] != SrcB[31]) && (adder_sub_sum[31] != SrcA[31]);
			end
			MULT : ALUResult = mul_product ;
			DIV  : ALUResult = {div_remainder, div_quotient} ;
			SLT  : ALUResult = ((SrcA[31] == SrcB[31]) ? adder_sub_sum[31] : (is_signed ? SrcA[31] : SrcB[31])) ? 64'b1 : 64'b0;
			SRL  : ALUResult = {32'b0, SrcB >> shamt} ;
			SRA  : ALUResult = {32'b0, $signed(SrcB) >>> shamt} ;
			SLLV : ALUResult = {32'b0, SrcB << SrcA[4:0]} ;
			SRLV : ALUResult = {32'b0, SrcB >> SrcA[4:0]} ;
			SRAV : ALUResult = {32'b0, $signed(SrcB) >>> SrcA[4:0]} ;
			XOR  : ALUResult = {32'b0, SrcA ^ SrcB} ;
			LUI  : ALUResult = {32'b0, SrcB} ;
			NOR  : ALUResult = {32'b0, ~(SrcA | SrcB)} ;
			default: ALUResult = 64'b0;
		endcase
		if(ALUResult == 0) Zero = 1'b1; else Zero = 1'b0;
	
	end

endmodule