// =============================================================================
// Pipeline Registers for 5-Stage MIPS Microprocessor
// =============================================================================

// -----------------------------------------------------------------------------
// IF/ID Pipeline Register
// -----------------------------------------------------------------------------
module IF_ID_reg (
    input  wire        clock,
    input  wire        reset,
    input  wire        en,       // Active-high enable (!StallD)
    input  wire        flush,    // Synchronous flush (FlushD)
    input  wire [31:0] PCF,
    input  wire [31:0] PCPlus4F,
    input  wire [31:0] InstrF,
    output reg  [31:0] PCD,
    output reg  [31:0] PCPlus4D,
    output reg  [31:0] InstrD
);

    always @(posedge clock or negedge reset) begin
        if (!reset) begin
            PCD      <= 32'b0;
            PCPlus4D <= 32'b0;
            InstrD   <= 32'b0; // NOP (sll $0, $0, 0)
        end else if (flush) begin
            PCD      <= 32'b0;
            PCPlus4D <= 32'b0;
            InstrD   <= 32'b0; // NOP on flush
        end else if (en) begin
            PCD      <= PCF;
            PCPlus4D <= PCPlus4F;
            InstrD   <= InstrF;
        end
    end

endmodule

// -----------------------------------------------------------------------------
// ID/EX Pipeline Register
// -----------------------------------------------------------------------------
module ID_EX_reg (
    input  wire        clock,
    input  wire        reset,
    input  wire        flush,    // Synchronous flush / bubble (FlushE)

    // Control signals from ID stage
    input  wire        RegWriteD,
    input  wire [2:0]  MemToRegD,
    input  wire        MemWriteD,
    input  wire        BranchD,
    input  wire        ALUSrcD,
    input  wire [1:0]  RegDstD,
    input  wire [1:0]  JumpD,
    input  wire [3:0]  ALUControlD,
    input  wire        is_signedD,
    input  wire [1:0]  MemSizeD,
    input  wire        MemUnsignedD,
    input  wire        hi_writeD,
    input  wire        lo_writeD,
    input  wire [1:0]  HILOSrcD,
    input  wire        cp0_writeD,

    // Data / Address signals from ID stage
    input  wire [31:0] ReadData1D,
    input  wire [31:0] ReadData2D,
    input  wire [31:0] SignImmD,
    input  wire [4:0]  RsD,
    input  wire [4:0]  RtD,
    input  wire [4:0]  RdD,
    input  wire [4:0]  shamtD,
    input  wire [31:0] PCPlus4D,
    input  wire [31:0] PCD,
    input  wire [31:0] InstrD,

    // Control signals to EX stage
    output reg         RegWriteE,
    output reg  [2:0]  MemToRegE,
    output reg         MemWriteE,
    output reg         BranchE,
    output reg         ALUSrcE,
    output reg  [1:0]  RegDstE,
    output reg  [1:0]  JumpE,
    output reg  [3:0]  ALUControlE,
    output reg         is_signedE,
    output reg  [1:0]  MemSizeE,
    output reg         MemUnsignedE,
    output reg         hi_writeE,
    output reg         lo_writeE,
    output reg  [1:0]  HILOSrcE,
    output reg         cp0_writeE,

    // Data / Address signals to EX stage
    output reg  [31:0] ReadData1E,
    output reg  [31:0] ReadData2E,
    output reg  [31:0] SignImmE,
    output reg  [4:0]  RsE,
    output reg  [4:0]  RtE,
    output reg  [4:0]  RdE,
    output reg  [4:0]  shamtE,
    output reg  [31:0] PCPlus4E,
    output reg  [31:0] PCE,
    output reg  [31:0] InstrE
);

    always @(posedge clock or negedge reset) begin
        if (!reset || flush) begin
            // Reset/Flush: zero out all control signals to insert a bubble/NOP
            RegWriteE    <= 1'b0;
            MemToRegE    <= 3'b000;
            MemWriteE    <= 1'b0;
            BranchE      <= 1'b0;
            ALUSrcE      <= 1'b0;
            RegDstE      <= 2'b00;
            JumpE        <= 2'b00;
            ALUControlE  <= 4'b0000;
            is_signedE   <= 1'b0;
            MemSizeE     <= 2'b10;
            MemUnsignedE <= 1'b0;
            hi_writeE    <= 1'b0;
            lo_writeE    <= 1'b0;
            HILOSrcE     <= 2'b00;
            cp0_writeE   <= 1'b0;

            ReadData1E   <= 32'b0;
            ReadData2E   <= 32'b0;
            SignImmE     <= 32'b0;
            RsE          <= 5'b0;
            RtE          <= 5'b0;
            RdE          <= 5'b0;
            shamtE       <= 5'b0;
            PCPlus4E     <= 32'b0;
            PCE          <= 32'b0;
            InstrE       <= 32'b0;
        end else begin
            RegWriteE    <= RegWriteD;
            MemToRegE    <= MemToRegD;
            MemWriteE    <= MemWriteD;
            BranchE      <= BranchD;
            ALUSrcE      <= ALUSrcD;
            RegDstE      <= RegDstD;
            JumpE        <= JumpD;
            ALUControlE  <= ALUControlD;
            is_signedE   <= is_signedD;
            MemSizeE     <= MemSizeD;
            MemUnsignedE <= MemUnsignedD;
            hi_writeE    <= hi_writeD;
            lo_writeE    <= lo_writeD;
            HILOSrcE     <= HILOSrcD;
            cp0_writeE   <= cp0_writeD;

            ReadData1E   <= ReadData1D;
            ReadData2E   <= ReadData2D;
            SignImmE     <= SignImmD;
            RsE          <= RsD;
            RtE          <= RtD;
            RdE          <= RdD;
            shamtE       <= shamtD;
            PCPlus4E     <= PCPlus4D;
            PCE          <= PCD;
            InstrE       <= InstrD;
        end
    end

endmodule

// -----------------------------------------------------------------------------
// EX/MEM Pipeline Register
// -----------------------------------------------------------------------------
module EX_MEM_reg (
    input  wire        clock,
    input  wire        reset,

    // Control signals from EX stage
    input  wire        RegWriteE,
    input  wire [2:0]  MemToRegE,
    input  wire        MemWriteE,
    input  wire [1:0]  MemSizeE,
    input  wire        MemUnsignedE,

    // Data signals from EX stage
    input  wire [31:0] ALUOutE,
    input  wire [31:0] WriteDataE,
    input  wire [4:0]  WriteRegE,
    input  wire [31:0] PCPlus4E,
    input  wire [31:0] PCE,

    // Control signals to MEM stage
    output reg         RegWriteM,
    output reg  [2:0]  MemToRegM,
    output reg         MemWriteM,
    output reg  [1:0]  MemSizeM,
    output reg         MemUnsignedM,

    // Data signals to MEM stage
    output reg  [31:0] ALUOutM,
    output reg  [31:0] WriteDataM,
    output reg  [4:0]  WriteRegM,
    output reg  [31:0] PCPlus4M,
    output reg  [31:0] PCM
);

    always @(posedge clock or negedge reset) begin
        if (!reset) begin
            RegWriteM    <= 1'b0;
            MemToRegM    <= 3'b000;
            MemWriteM    <= 1'b0;
            MemSizeM     <= 2'b10;
            MemUnsignedM <= 1'b0;

            ALUOutM      <= 32'b0;
            WriteDataM   <= 32'b0;
            WriteRegM    <= 5'b0;
            PCPlus4M     <= 32'b0;
            PCM          <= 32'b0;
        end else begin
            RegWriteM    <= RegWriteE;
            MemToRegM    <= MemToRegE;
            MemWriteM    <= MemWriteE;
            MemSizeM     <= MemSizeE;
            MemUnsignedM <= MemUnsignedE;

            ALUOutM      <= ALUOutE;
            WriteDataM   <= WriteDataE;
            WriteRegM    <= WriteRegE;
            PCPlus4M     <= PCPlus4E;
            PCM          <= PCE;
        end
    end

endmodule

// -----------------------------------------------------------------------------
// MEM/WB Pipeline Register
// -----------------------------------------------------------------------------
module MEM_WB_reg (
    input  wire        clock,
    input  wire        reset,

    // Control signals from MEM stage
    input  wire        RegWriteM,
    input  wire [2:0]  MemToRegM,

    // Data signals from MEM stage
    input  wire [31:0] ALUOutM,
    input  wire [31:0] ReadDataM,
    input  wire [4:0]  WriteRegM,
    input  wire [31:0] PCPlus4M,
    input  wire [31:0] PCM,

    // Control signals to WB stage
    output reg         RegWriteW,
    output reg  [2:0]  MemToRegW,

    // Data signals to WB stage
    output reg  [31:0] ALUOutW,
    output reg  [31:0] ReadDataW,
    output reg  [4:0]  WriteRegW,
    output reg  [31:0] PCPlus4W,
    output reg  [31:0] PCW
);

    always @(posedge clock or negedge reset) begin
        if (!reset) begin
            RegWriteW <= 1'b0;
            MemToRegW <= 3'b000;

            ALUOutW   <= 32'b0;
            ReadDataW <= 32'b0;
            WriteRegW <= 5'b0;
            PCPlus4W  <= 32'b0;
            PCW       <= 32'b0;
        end else begin
            RegWriteW <= RegWriteM;
            MemToRegW <= MemToRegM;

            ALUOutW   <= ALUOutM;
            ReadDataW <= ReadDataM;
            WriteRegW <= WriteRegM;
            PCPlus4W  <= PCPlus4M;
            PCW       <= PCM;
        end
    end

endmodule

