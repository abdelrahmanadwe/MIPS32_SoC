// =============================================================================
// Pipelined_MIPS_Microprocessor.v
// 5-Stage Pipelined MIPS Processor with 2-Bit Dynamic Branch Predictor & Hazard Unit
// Stages: IF -> ID -> EX -> MEM -> WB
// Features: Dynamic Branch Prediction, Data Forwarding, Load-Use & Branch Stalling
// =============================================================================

module Pipelined_MIPS_Microprocessor #(
    parameter IM_START_ADDR = 32'h0000_0000,
    parameter IM_END_ADDR   = 32'h0000_0FFF,
    parameter DM_START_ADDR = 32'h0000_1000,
    parameter DM_END_ADDR   = 32'h0000_7FFF
)(
    output [15:0] TestValue,
    input         reset,
    input         clock
);

    // =========================================================================
    // Hazard & Branch Prediction Wires
    // =========================================================================
    wire [1:0]  ForwardAE, ForwardBE;
    wire        ForwardAD, ForwardBD;
    wire        StallF, StallD, FlushE, FlushD;
    wire        branch_pred_sel, mispred_sel;
    wire [31:0] branch_pred_target, mispred_correct_target;
    wire [31:0] branch_write_target, jump_write_target;
    wire        branch_taken_D;
    wire        jr_sel;
    wire [31:0] rs_for_branch;

    // =========================================================================
    // Stage 1: Instruction Fetch (IF)
    // =========================================================================
    wire [31:0] PCF;
    wire [31:0] PCPlus4F;

    // Mux 1: Select between PC+4 and predicted branch target (Slide 5)
    wire [31:0] Mux1Out = branch_pred_sel ? branch_pred_target : PCPlus4F;

    // Mux 2: Select between Mux 1 output and misprediction recovery target (Slide 5)
    wire [31:0] Mux2Out = mispred_sel ? mispred_correct_target : Mux1Out;

    // Next PC multiplexer (handles JR if active)
    wire [31:0] PCNext = jr_sel ? rs_for_branch : Mux2Out;

    // Stall logic freezes PC register
    wire [31:0] PCInput = StallF ? PCF : PCNext;

    ProgramCounter pc (
        .ProgramCounterOut(PCF),
        .ProgramCounterIn(PCInput),
        .clock(clock),
        .reset(reset)
    );

    Adder_32_bits add4_inst (
        .out(PCPlus4F),
        .in1(PCF),
        .in2(32'd4)
    );

    wire [31:0] InstrF;
    InstructionMemory #(
        .START_ADDR(IM_START_ADDR),
        .END_ADDR(IM_END_ADDR)
    ) ROM (
        .instruction(InstrF),
        .Address(PCF)
    );

    // -------------------------------------------------------------------------
    // IF / ID Pipeline Register (with clr on mispred / flush)
    // -------------------------------------------------------------------------
    wire [31:0] PCD, PCPlus4D, InstrD;

    IF_ID_reg if_id_inst (
        .clock(clock),
        .reset(reset),
        .en(!StallD),
        .flush(FlushD),
        .PCF(PCF),
        .PCPlus4F(PCPlus4F),
        .InstrF(InstrF),
        .PCD(PCD),
        .PCPlus4D(PCPlus4D),
        .InstrD(InstrD)
    );

    // =========================================================================
    // Stage 2: Instruction Decode (ID)
    // =========================================================================
    wire [1:0] RegDstD, JumpD, MemSizeD, ExtOpD, HILOSrcD;
    wire [2:0] MemToRegD;
    wire [3:0] ALUControlD;
    wire       ALUSrcD, RegWriteD, MemWriteD, BranchD, BneD;
    wire       is_signedD, MemUnsignedD, hi_writeD, lo_writeD;

    ControlUnit controlunit (
        .RegDst(RegDstD),       
        .ALUSrc(ALUSrcD),       
        .MemToReg(MemToRegD),   
        .RegWrite(RegWriteD),        
        .MemWrite(MemWriteD),   
        .Branch(BranchD),        
        .Jump(JumpD),         
        .ALUControl(ALUControlD),
        .is_signed(is_signedD),
        .MemSize(MemSizeD),
        .MemUnsigned(MemUnsignedD),
        .ExtOp(ExtOpD),
        .Bne(BneD),
        .hi_write(hi_writeD),
        .lo_write(lo_writeD),
        .HILOSrc(HILOSrcD),
        .opcode(InstrD[31:26]),      
        .funct(InstrD[5:0])    
    );

    wire [31:0] ReadData1D_raw, ReadData2D_raw;
    wire [31:0] ResultW;
    wire [4:0]  WriteRegW;
    wire        RegWriteW;

    RegisterFile registers (
        .ReadData1(ReadData1D_raw),
        .ReadData2(ReadData2D_raw),  
        .Clock(clock),
        .reset(reset),
        .RegWrite(RegWriteW),          
        .Address1Read(InstrD[25:21]), 
        .Address2Read(InstrD[20:16]), 
        .Address3Write(WriteRegW),
        .WriteData(ResultW)  
    );

    // Register File Internal Forwarding (WB stage bypass to ID stage)
    wire [31:0] ReadData1D = (RegWriteW && (WriteRegW != 5'b0) && (WriteRegW == InstrD[25:21])) ? ResultW : ReadData1D_raw;
    wire [31:0] ReadData2D = (RegWriteW && (WriteRegW != 5'b0) && (WriteRegW == InstrD[20:16])) ? ResultW : ReadData2D_raw;

    // ID Forwarding for Branch Comparison (forwarding from MEM stage)
    wire [31:0] ALUOutM;
    assign rs_for_branch = ForwardAD ? ALUOutM : ReadData1D;
    wire [31:0] rt_for_branch = ForwardBD ? ALUOutM : ReadData2D;

    // Early Branch Comparison Unit in ID Stage (Slide 5)
    Branch_Unit branch_comparison_inst (
        .opcode(InstrD[31:26]),
        .rt(InstrD[20:16]),
        .rs_value(rs_for_branch),
        .zero(rs_for_branch == rt_for_branch),
        .Branch(BranchD),
        .branch_taken(branch_taken_D)
    );

    wire [31:0] SignImmD;
    Sign_Extand sign_extand (
        .out(SignImmD),
        .in(InstrD[15:0]),
        .ExtOp(ExtOpD)
    );

    // Branch and Jump Target Calculations in ID Stage (Slide 5)
    assign branch_write_target = PCPlus4D + (SignImmD << 2);
    assign jump_write_target   = {PCPlus4D[31:28], InstrD[25:0], 2'b00};

    // JR signal
    assign jr_sel = (JumpD == 2'b10) && !StallD;

    // Instruction source decoder for hazard detection
    wire [5:0] opD    = InstrD[31:26];
    wire [5:0] functD = InstrD[5:0];

    wire uses_rsD = !(
        (opD == 6'b000010) || // j
        (opD == 6'b000011) || // jal
        (opD == 6'b001111) || // lui
        (opD == 6'b000000 && (functD == 6'b000000 || functD == 6'b000010 || functD == 6'b000011)) || // sll, srl, sra
        (opD == 6'b000000 && (functD == 6'b010000 || functD == 6'b010010)) // mfhi, mflo
    );

    wire uses_rtD = (
        (opD == 6'b000000 && !(
            functD == 6'b001000 || // jr
            functD == 6'b001001 || // jalr
            functD == 6'b010000 || // mfhi
            functD == 6'b010001 || // mthi
            functD == 6'b010010 || // mflo
            functD == 6'b010011    // mtlo
        )) ||
        (opD == 6'b011100) || // mul
        (opD == 6'b101011) || // sw
        (opD == 6'b101000) || // sb
        (opD == 6'b101001) || // sh
        (opD == 6'b000100) || // beq
        (opD == 6'b000101)    // bne
    );

    // =========================================================================
    // 2-Bit Dynamic Branch Predictor Instance (Slide 5 & Slide 8)
    // =========================================================================
    Branch_Predictor #(
        .TABLE_ENTRIES(1024)
    ) bp_inst (
        .clk(clock),
        .reset(reset),
        .stall(StallD),
        .read_addr(PCF),
        .branch_pred_target(branch_pred_target),
        .branch_pred_sel(branch_pred_sel),
        .write_address(PCPlus4D),
        .branch_write_enable(BranchD && !StallD),
        .branch_taken(branch_taken_D),
        .branch_write_target(branch_write_target),
        .jump_write_enable((JumpD == 2'b01) && !StallD),
        .jump_write_target(jump_write_target),
        .mispred_correct_target(mispred_correct_target),
        .mispred_sel(mispred_sel)
    );

    // -------------------------------------------------------------------------
    // ID / EX Pipeline Register
    // -------------------------------------------------------------------------
    wire        RegWriteE, MemWriteE, BranchE, ALUSrcE, is_signedE, MemUnsignedE, hi_writeE, lo_writeE;
    wire [1:0]  RegDstE, JumpE, MemSizeE, HILOSrcE;
    wire [2:0]  MemToRegE;
    wire [3:0]  ALUControlE;
    wire [31:0] ReadData1E, ReadData2E, SignImmE, PCPlus4E, PCE, InstrE;
    wire [4:0]  RsE, RtE, RdE, shamtE;

    ID_EX_reg id_ex_inst (
        .clock(clock),
        .reset(reset),
        .flush(FlushE),

        .RegWriteD(RegWriteD),
        .MemToRegD(MemToRegD),
        .MemWriteD(MemWriteD),
        .BranchD(BranchD),
        .ALUSrcD(ALUSrcD),
        .RegDstD(RegDstD),
        .JumpD(JumpD),
        .ALUControlD(ALUControlD),
        .is_signedD(is_signedD),
        .MemSizeD(MemSizeD),
        .MemUnsignedD(MemUnsignedD),
        .hi_writeD(hi_writeD),
        .lo_writeD(lo_writeD),
        .HILOSrcD(HILOSrcD),

        .ReadData1D(ReadData1D),
        .ReadData2D(ReadData2D),
        .SignImmD(SignImmD),
        .RsD(InstrD[25:21]),
        .RtD(InstrD[20:16]),
        .RdD(InstrD[15:11]),
        .shamtD(InstrD[10:6]),
        .PCPlus4D(PCPlus4D),
        .PCD(PCD),
        .InstrD(InstrD),

        .RegWriteE(RegWriteE),
        .MemToRegE(MemToRegE),
        .MemWriteE(MemWriteE),
        .BranchE(BranchE),
        .ALUSrcE(ALUSrcE),
        .RegDstE(RegDstE),
        .JumpE(JumpE),
        .ALUControlE(ALUControlE),
        .is_signedE(is_signedE),
        .MemSizeE(MemSizeE),
        .MemUnsignedE(MemUnsignedE),
        .hi_writeE(hi_writeE),
        .lo_writeE(lo_writeE),
        .HILOSrcE(HILOSrcE),

        .ReadData1E(ReadData1E),
        .ReadData2E(ReadData2E),
        .SignImmE(SignImmE),
        .RsE(RsE),
        .RtE(RtE),
        .RdE(RdE),
        .shamtE(shamtE),
        .PCPlus4E(PCPlus4E),
        .PCE(PCE),
        .InstrE(InstrE)
    );

    // =========================================================================
    // Stage 3: Execute (EX)
    // =========================================================================
    // Forwarding Mux for SrcA
    reg [31:0] SrcAE_forwarded;
    always @(*) begin
        case (ForwardAE)
            2'b10:   SrcAE_forwarded = ALUOutM;
            2'b01:   SrcAE_forwarded = ResultW;
            default: SrcAE_forwarded = ReadData1E;
        endcase
    end

    // Forwarding Mux for SrcB / Store WriteData
    reg [31:0] WriteDataE_forwarded;
    always @(*) begin
        case (ForwardBE)
            2'b10:   WriteDataE_forwarded = ALUOutM;
            2'b01:   WriteDataE_forwarded = ResultW;
            default: WriteDataE_forwarded = ReadData2E;
        endcase
    end

    // ALUSrc Mux
    wire [31:0] SrcBE_final = ALUSrcE ? SignImmE : WriteDataE_forwarded;

    // ALU 32-bit Execution
    wire [63:0] ALUResult64E;
    wire zeroE, overflowE;

    ALU_32_bits ALU (
        .ALUResult(ALUResult64E),
        .Zero(zeroE),
        .Overflow(overflowE),
        .SrcA(SrcAE_forwarded),
        .SrcB(SrcBE_final),
        .ALUControl(ALUControlE),
        .is_signed(is_signedE),
        .shamt(shamtE)
    );

    // HI / LO Register handling
    wire [31:0] mul_product_hi = ALUResult64E[63:32];
    wire [31:0] mul_product_lo = ALUResult64E[31:0];
    wire [31:0] div_remainder  = ALUResult64E[63:32];
    wire [31:0] div_quotient   = ALUResult64E[31:0];

    wire [31:0] hi_in_E = (HILOSrcE == 2'b00) ? mul_product_hi :
                          (HILOSrcE == 2'b01) ? div_remainder :
                          SrcAE_forwarded; // for mthi

    wire [31:0] lo_in_E = (HILOSrcE == 2'b00) ? mul_product_lo :
                          (HILOSrcE == 2'b01) ? div_quotient :
                          SrcAE_forwarded; // for mtlo

    wire [31:0] HI, LO;
    HILO_Regs hilo_regs_inst (
        .HI(HI),
        .LO(LO),
        .hi_in(hi_in_E),
        .lo_in(lo_in_E),
        .hi_write(hi_writeE),
        .lo_write(lo_writeE),
        .clock(clock),
        .reset(reset)
    );

    // Merge ALU result, HI, LO, and PCPlus4 for unified datapath
    reg [31:0] ALUOutFinalE;
    always @(*) begin
        case (MemToRegE)
            3'b010:  ALUOutFinalE = PCPlus4E;          // jal, jalr
            3'b011:  ALUOutFinalE = HI;                // mfhi
            3'b100:  ALUOutFinalE = LO;                // mflo
            default: ALUOutFinalE = ALUResult64E[31:0]; // Standard ALU / mul / shift
        endcase
    end

    // Destination Register Selection
    wire [4:0] WriteRegE = (RegDstE == 2'b10) ? 5'd31 :
                           (RegDstE == 2'b01) ? RdE :
                           RtE;

    // -------------------------------------------------------------------------
    // EX / MEM Pipeline Register
    // -------------------------------------------------------------------------
    wire        RegWriteM, MemWriteM, MemUnsignedM;
    wire [1:0]  MemSizeM;
    wire [2:0]  MemToRegM;
    wire [31:0] WriteDataM, PCPlus4M, PCM;
    wire [4:0]  WriteRegM;

    EX_MEM_reg ex_mem_inst (
        .clock(clock),
        .reset(reset),

        .RegWriteE(RegWriteE),
        .MemToRegE(MemToRegE),
        .MemWriteE(MemWriteE),
        .MemSizeE(MemSizeE),
        .MemUnsignedE(MemUnsignedE),

        .ALUOutE(ALUOutFinalE),
        .WriteDataE(WriteDataE_forwarded),
        .WriteRegE(WriteRegE),
        .PCPlus4E(PCPlus4E),
        .PCE(PCE),

        .RegWriteM(RegWriteM),
        .MemToRegM(MemToRegM),
        .MemWriteM(MemWriteM),
        .MemSizeM(MemSizeM),
        .MemUnsignedM(MemUnsignedM),

        .ALUOutM(ALUOutM),
        .WriteDataM(WriteDataM),
        .WriteRegM(WriteRegM),
        .PCPlus4M(PCPlus4M),
        .PCM(PCM)
    );

    // =========================================================================
    // Stage 4: Memory Access (MEM)
    // =========================================================================
    wire [31:0] ReadDataM;

    Data_Memory #(
        .START_ADDR(DM_START_ADDR),
        .END_ADDR(DM_END_ADDR)
    ) RAM (
        .ReadData(ReadDataM),     
        .TestValue(TestValue),    
        .Clock(clock),
        .Reset(reset),
        .Address(ALUOutM),      
        .WriteData(WriteDataM),    
        .WriteEnable(MemWriteM),
        .MemSize(MemSizeM),
        .MemUnsigned(MemUnsignedM)
    );

    // -------------------------------------------------------------------------
    // MEM / WB Pipeline Register
    // -------------------------------------------------------------------------
    wire [2:0]  MemToRegW;
    wire [31:0] ALUOutW, ReadDataW, PCPlus4W, PCW;

    MEM_WB_reg mem_wb_inst (
        .clock(clock),
        .reset(reset),

        .RegWriteM(RegWriteM),
        .MemToRegM(MemToRegM),

        .ALUOutM(ALUOutM),
        .ReadDataM(ReadDataM),
        .WriteRegM(WriteRegM),
        .PCPlus4M(PCPlus4M),
        .PCM(PCM),

        .RegWriteW(RegWriteW),
        .MemToRegW(MemToRegW),

        .ALUOutW(ALUOutW),
        .ReadDataW(ReadDataW),
        .WriteRegW(WriteRegW),
        .PCPlus4W(PCPlus4W),
        .PCW(PCW)
    );

    // =========================================================================
    // Stage 5: Writeback (WB)
    // =========================================================================
    assign ResultW = (MemToRegW == 3'b001) ? ReadDataW : ALUOutW;

    // =========================================================================
    // Hazard Detection & Forwarding Unit
    // =========================================================================
    Hazard_Unit hazard_unit_inst (
        .RsE(RsE),
        .RtE(RtE),
        .WriteRegM(WriteRegM),
        .RegWriteM(RegWriteM),
        .WriteRegW(WriteRegW),
        .RegWriteW(RegWriteW),
        .RsD(InstrD[25:21]),
        .RtD(InstrD[20:16]),
        .WriteRegE(WriteRegE),
        .RegWriteE(RegWriteE),
        .MemToRegE(MemToRegE),
        .MemToRegM(MemToRegM),
        .BranchD(BranchD),
        .JumpD(JumpD),
        .uses_rsD(uses_rsD),
        .uses_rtD(uses_rtD),
        .mispred_sel(mispred_sel),
        .jr_sel(jr_sel),
        .ForwardAE(ForwardAE),
        .ForwardBE(ForwardBE),
        .ForwardAD(ForwardAD),
        .ForwardBD(ForwardBD),
        .StallF(StallF),
        .StallD(StallD),
        .FlushE(FlushE),
        .FlushD(FlushD)
    );

endmodule
