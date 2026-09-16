module Hazard_Unit (
    // Inputs for Forwarding logic
    input  wire [4:0] RsE,
    input  wire [4:0] RtE,
    input  wire [4:0] WriteRegM,
    input  wire       RegWriteM,
    input  wire [4:0] WriteRegW,
    input  wire       RegWriteW,

    // Inputs for Stall logic (Load-Use)
    input  wire [4:0] RsD,
    input  wire [4:0] RtD,
    input  wire [2:0] MemToRegE,
    input  wire       uses_rsD,
    input  wire       uses_rtD,

    // Input for Control Hazard (Branch / Jump taken in EX stage)
    input  wire       PCSrcE,

    // Outputs
    output reg  [1:0] ForwardAE,
    output reg  [1:0] ForwardBE,
    output wire       StallF,
    output wire       StallD,
    output wire       FlushE,
    output wire       FlushD
);

    // =========================================================================
    // 1. Forwarding Unit (EX Stage ALU inputs)
    // =========================================================================
    // Priority:
    // 1. MEM hazard (instruction in MEM stage is most recent)
    // 2. WB hazard (instruction in WB stage is next most recent)
    // 3. No hazard (use ID/EX register data)

    // Forwarding for SrcA
    always @(*) begin
        if (RegWriteM && (WriteRegM != 5'd0) && (WriteRegM == RsE)) begin
            ForwardAE = 2'b10; // Forward from MEM stage (ALUOutM)
        end else if (RegWriteW && (WriteRegW != 5'd0) && (WriteRegW == RsE)) begin
            ForwardAE = 2'b01; // Forward from WB stage (ResultW)
        end else begin
            ForwardAE = 2'b00; // No forwarding
        end
    end

    // Forwarding for SrcB
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
    // 2. Load-Use Hazard Detection
    // =========================================================================
    // If instruction in EX is a load (MemToRegE == 3'b001) and destination RtE
    // matches a source register required by the instruction in ID stage:
    wire MemReadE = (MemToRegE == 3'b001);

    wire lw_stall = MemReadE && (
        (uses_rsD && (RtE != 5'd0) && (RtE == RsD)) ||
        (uses_rtD && (RtE != 5'd0) && (RtE == RtD))
    );

    // =========================================================================
    // 3. Hazard Resolution (Stall & Flush)
    // =========================================================================
    // If PCSrcE is asserted (branch taken or jump in EX), flushing takes priority.
    assign StallF = lw_stall && !PCSrcE;
    assign StallD = lw_stall && !PCSrcE;
    assign FlushD = PCSrcE;
    assign FlushE = (lw_stall && !PCSrcE) || PCSrcE;

endmodule

