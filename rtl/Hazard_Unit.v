// =============================================================================
// Hazard_Unit.v
// Hazard Detection & Forwarding Unit with Early Branch Resolution Support
// =============================================================================

module Hazard_Unit (
    // Inputs for Forwarding logic (EX stage)
    input  wire [4:0] RsE,
    input  wire [4:0] RtE,
    input  wire [4:0] WriteRegM,
    input  wire       RegWriteM,
    input  wire [4:0] WriteRegW,
    input  wire       RegWriteW,

    // Inputs for Stall & ID Forwarding logic
    input  wire [4:0] RsD,
    input  wire [4:0] RtD,
    input  wire [4:0] WriteRegE,
    input  wire       RegWriteE,
    input  wire [2:0] MemToRegE,
    input  wire [2:0] MemToRegM,
    input  wire       BranchD,
    input  wire [1:0] JumpD,
    input  wire       uses_rsD,
    input  wire       uses_rtD,

    // Control hazard inputs from Branch Predictor / Jump
    input  wire       mispred_sel,
    input  wire       jr_sel,

    // Outputs
    output reg  [1:0] ForwardAE,
    output reg  [1:0] ForwardBE,
    output wire       ForwardAD,
    output wire       ForwardBD,
    output wire       StallF,
    output wire       StallD,
    output wire       FlushE,
    output wire       FlushD
);

    // =========================================================================
    // 1. Forwarding Unit for EX Stage (ALU inputs)
    // =========================================================================
    always @(*) begin
        if (RegWriteM && (WriteRegM != 5'd0) && (WriteRegM == RsE)) begin
            ForwardAE = 2'b10; // Forward from MEM stage (ALUOutM)
        end else if (RegWriteW && (WriteRegW != 5'd0) && (WriteRegW == RsE)) begin
            ForwardAE = 2'b01; // Forward from WB stage (ResultW)
        end else begin
            ForwardAE = 2'b00; // No forwarding
        end
    end

    always @(*) begin
        if (RegWriteM && (WriteRegM != 5'd0) && (WriteRegM == RtE)) begin
            ForwardBE = 2'b10; // Forward from MEM stage (ALUOutM)
        end else if (RegWriteW && (WriteRegW != 5'd0) && (WriteRegW == RtE)) begin
            ForwardBE = 2'b01; // Forward from WB stage (ResultW)
        end else begin
            ForwardBE = 2'b00; // No forwarding
        end
    end

    // =========================================================================
    // 2. Forwarding Unit for ID Stage (Branch Comparison inputs)
    // =========================================================================
    // Forward from MEM stage if previous ALU instruction produced result.
    // WB stage forwarding is handled internally in RegisterFile.
    assign ForwardAD = RegWriteM && (WriteRegM != 5'd0) && (WriteRegM == RsD);
    assign ForwardBD = RegWriteM && (WriteRegM != 5'd0) && (WriteRegM == RtD);

    // =========================================================================
    // 3. Stall Detection
    // =========================================================================
    // A. Standard Load-Use Hazard (Load in EX, dependent instruction in ID)
    wire MemReadE = (MemToRegE == 3'b001);
    wire lw_stall = MemReadE && (
        (uses_rsD && (RtE != 5'd0) && (RtE == RsD)) ||
        (uses_rtD && (RtE != 5'd0) && (RtE == RtD))
    );

    // B. Branch Data Hazards (Branch evaluated in ID stage)
    // If instruction in EX will write a source register used by the branch:
    wire branch_stall_ex = BranchD && RegWriteE && (WriteRegE != 5'd0) && (
        (uses_rsD && (WriteRegE == RsD)) ||
        (uses_rtD && (WriteRegE == RtD))
    );

    // If load instruction in MEM will write a source register used by the branch:
    wire branch_stall_mem = BranchD && (MemToRegM == 3'b001) && (WriteRegM != 5'd0) && (
        (uses_rsD && (WriteRegM == RsD)) ||
        (uses_rtD && (WriteRegM == RtD))
    );

    wire branch_stall = branch_stall_ex || branch_stall_mem;

    // C. JR Data Hazards (Jump Register evaluated in ID stage)
    wire jr_stall_ex = (JumpD == 2'b10) && RegWriteE && (WriteRegE != 5'd0) && (WriteRegE == RsD);
    wire jr_stall_mem = (JumpD == 2'b10) && (MemToRegM == 3'b001) && (WriteRegM != 5'd0) && (WriteRegM == RsD);
    wire jr_stall = jr_stall_ex || jr_stall_mem;

    wire total_stall = lw_stall || branch_stall || jr_stall;

    // =========================================================================
    // 4. Control Signals (Stall & Flush)
    // =========================================================================
    // Control redirects (misprediction or jr taken) take priority over stalling
    assign StallF = total_stall && !mispred_sel && !jr_sel;
    assign StallD = total_stall && !mispred_sel && !jr_sel;
    assign FlushE = (total_stall && !mispred_sel && !jr_sel);
    assign FlushD = mispred_sel || jr_sel;

endmodule
