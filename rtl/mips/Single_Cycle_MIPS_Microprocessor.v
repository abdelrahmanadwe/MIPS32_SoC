module Single_Cycle_MIPS_Microprocessor #(
    parameter IM_START_ADDR = 32'h0000_0000,
    parameter IM_END_ADDR   = 32'h0000_0FFF,
    parameter DM_START_ADDR = 32'h0000_1000,
    parameter DM_END_ADDR   = 32'h0000_7FFF
)(
	output [15:0] TestValue,
	input reset,
	input clock
);
	wire [31:0] PCCurrentInstruction, PCPlus4, PCNextInstruction, PCBranch, PCBranchOrNot, PCJump;
	wire [31:0] instruction;
	wire [31:0] readData1Reg, readData2Reg, writeDataReg, readDataRam, ALUResult, SignImm, SrcB;
	wire [31:0] beqshiftout;
	wire MemWrite, Branch, ALUSrc, RegWrite;
	wire [1:0] RegDst, Jump;
	wire [2:0] MemToReg;
	wire Bne;
	wire [4:0] Address3WriteReg;

	wire [3:0] ALUControl;
	wire zero;
	wire is_signed;
	wire [1:0] MemSize;
	wire MemUnsigned;
	wire [1:0] ExtOp;
	wire hi_write, lo_write;
	wire [1:0] HILOSrc;
	
	wire branch_taken;
	wire [63:0] mul_product;
	wire [31:0] div_quotient;
	wire [31:0] div_remainder;
	wire [31:0] hi_in;
	wire [31:0] lo_in;
	wire [31:0] HI, LO;

	ProgramCounter pc(
		.ProgramCounterOut(PCCurrentInstruction),
		.ProgramCounterIn(PCNextInstruction),
		.clock(clock),
		.reset(reset)
	);
	
	Adder_32_bits add4(
		.out(PCPlus4),
		.in1(PCCurrentInstruction),
		.in2(32'b100)
	);
	
	InstructionMemory #(
		.START_ADDR(IM_START_ADDR),
		.END_ADDR(IM_END_ADDR)
	) ROM(
		.instruction(instruction), 
		.Address(PCCurrentInstruction)       
	);
	
	mux_3x1 #(.N(5)) write_reg_mux (
		.MuxOut(Address3WriteReg),
		.MuxIn1(instruction[20:16]),
		.MuxIn2(instruction[15:11]),
		.MuxIn3(5'd31),
		.sel(RegDst)
	);

	RegisterFile registers(
		.ReadData1(readData1Reg),
		.ReadData2(readData2Reg),  
		.Clock(clock),
		.reset(reset),
		.RegWrite(RegWrite),          
		.Address1Read(instruction[25:21]), 
		.Address2Read(instruction[20:16]), 
		.Address3Write(Address3WriteReg),
		.WriteData(writeDataReg),
		.is_mfc0(1'b0)
	);

	Sign_Extand sign_extand(
		.out(SignImm),
		.in(instruction[15:0]),
		.ExtOp(ExtOp)
	);
	
	Shift_Left_Twice #(.in_width(32),.out_width(32)) beqshift(
		.out(beqshiftout),
		.in(SignImm)
	);
	
	Adder_32_bits addbranch(
		.out(PCBranch),
		.in1(beqshiftout),
		.in2(PCPlus4)
	);

	Branch_Unit branch_unit_inst(
		.opcode(instruction[31:26]),
		.rt(instruction[20:16]),
		.rs_value(readData1Reg),
		.zero(zero),
		.Branch(Branch),
		.branch_taken(branch_taken)
	);

	mux_2x1 #(.N(32)) pc_branch_mux (
		.MuxOut(PCBranchOrNot),
		.MuxIn1(PCPlus4),
		.MuxIn2(PCBranch),
		.sel(branch_taken)
	);
	
	Shift_Left_Twice #(.in_width(26),.out_width(32)) jumpshift(
		.out(PCJump),
		.in(instruction[25:0])
	);
	
	mux_3x1 #(.N(32)) pc_next_mux (
		.MuxOut(PCNextInstruction),
		.MuxIn1(PCBranchOrNot),
		.MuxIn2({PCPlus4[31:28], PCJump[27:0]}),
		.MuxIn3(readData1Reg),
		.sel(Jump)
	);
	
	mux_2x1 #(.N(32)) SrcBmux(
		.MuxOut(SrcB),
		.MuxIn1(readData2Reg),
		.MuxIn2(SignImm),
		.sel(ALUSrc)
	);
	
	wire [63:0] ALUResult64;
	assign ALUResult     = ALUResult64[31:0];
	assign mul_product   = ALUResult64;
	assign div_quotient  = ALUResult64[31:0];
	assign div_remainder = ALUResult64[63:32];

	wire overflow;

	ALU_32_bits ALU(
		.ALUResult(ALUResult64),
		.Zero(zero),
		.Overflow(overflow),
		.divide_by_zero(),
		.SrcA(readData1Reg),
		.SrcB(SrcB),
		.ALUControl(ALUControl),
		.is_signed(is_signed),
		.shamt(instruction[10:6])
	);

	mux_3x1 #(.N(32)) hi_mux (
		.MuxOut(hi_in),
		.MuxIn1(mul_product[63:32]),
		.MuxIn2(div_remainder),
		.MuxIn3(readData1Reg),
		.sel(HILOSrc)
	);

	mux_3x1 #(.N(32)) lo_mux (
		.MuxOut(lo_in),
		.MuxIn1(mul_product[31:0]),
		.MuxIn2(div_quotient),
		.MuxIn3(readData1Reg),
		.sel(HILOSrc)
	);

	HILO_Regs hilo_regs_inst(
		.HI(HI),
		.LO(LO),
		.hi_in(hi_in),
		.lo_in(lo_in),
		.hi_write(hi_write),
		.lo_write(lo_write),
		.clock(clock),
		.reset(reset)
	);
	
	ControlUnit controlunit(
		.RegDst(RegDst),       
		.ALUSrc(ALUSrc),       
		.MemToReg(MemToReg),   
		.RegWrite(RegWrite),        
		.MemWrite(MemWrite),   
		.Branch(Branch),        
		.Jump(Jump),         
		.ALUControl(ALUControl),
		.is_signed(is_signed),
		.MemSize(MemSize),
		.MemUnsigned(MemUnsigned),
		.ExtOp(ExtOp),
		.Bne(Bne),
		.hi_write(hi_write),
		.lo_write(lo_write),
		.HILOSrc(HILOSrc),
		.cp0_write(),
		.is_syscall(),
		.is_break(),
		.is_undefined(),
		.opcode(instruction[31:26]),      
		.funct(instruction[5:0]),
		.rs(instruction[25:21])
	);
	
	Single_Cycle_Data_Memory #(
		.START_ADDR(DM_START_ADDR),
		.END_ADDR(DM_END_ADDR)
	) RAM(
		.ReadData(readDataRam),     
		.TestValue(TestValue),    
		.Clock(clock),
		.Reset(reset),
		.Address(ALUResult),      
		.WriteData(readData2Reg),    
		.WriteEnable(MemWrite),
		.MemSize(MemSize),
		.MemUnsigned(MemUnsigned)
	);
	
	mux_5x1 #(.N(32)) write_data_mux (
		.MuxOut(writeDataReg),
		.MuxIn1(ALUResult),
		.MuxIn2(readDataRam),
		.MuxIn3(PCPlus4),
		.MuxIn4(HI),
		.MuxIn5(LO),
		.sel(MemToReg)
	);

endmodule
