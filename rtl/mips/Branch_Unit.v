module Branch_Unit (
	input [5:0] opcode,
	input [4:0] rt,
	input [31:0] rs_value,
	input zero,
	input Branch,
	output branch_taken
);

	wire is_beq  = (opcode == 6'b000100);
	wire is_bne  = (opcode == 6'b000101);
	wire is_blez = (opcode == 6'b000110);
	wire is_bgtz = (opcode == 6'b000111);
	wire is_regimm = (opcode == 6'b000001);
	wire is_bltz = is_regimm && (rt == 5'b00000);
	wire is_bgez = is_regimm && (rt == 5'b00001);

	wire rs_zero = (rs_value == 32'b0);
	wire rs_negative = rs_value[31];

	reg branch_condition_met;
	always @(*) begin
		if (is_beq)
			branch_condition_met = zero;
		else if (is_bne)
			branch_condition_met = !zero;
		else if (is_blez)
			branch_condition_met = (rs_negative || rs_zero);
		else if (is_bgtz)
			branch_condition_met = (!rs_negative && !rs_zero);
		else if (is_bltz)
			branch_condition_met = rs_negative;
		else if (is_bgez)
			branch_condition_met = !rs_negative;
		else
			branch_condition_met = 1'b0;
	end

	assign branch_taken = Branch & branch_condition_met;

endmodule
