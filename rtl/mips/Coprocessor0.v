// =============================================================================
// Coprocessor0.v
// MIPS Coprocessor 0 (CP0) for Exception and Interrupt Handling
// Features 32 special-purpose 32-bit registers (including Cause & EPC)
// Supports mfc0, mtc0, and hardware exception state updates
// =============================================================================

module Coprocessor0 (
    input  wire        clock,
    input  wire        reset,

    // Instruction interface (mfc0 / mtc0)
    input  wire [4:0]  reg_addr,       // Register address from instruction (Instr[15:11])
    input  wire        alt_cause,      // Alternate Cause encoding (Instr[15:8] == 8'h0D)
    input  wire        cp0_write_en,   // Write enable for mtc0
    input  wire [31:0] cp0_write_data, // Data to write from GPR rt (for mtc0)
    output wire [31:0] cp0_read_data,  // Data read from CP0 reg (for mfc0)

    // Hardware Exception interface
    input  wire        exception_trigger, // Pulses high when exception occurs
    input  wire [31:0] exception_cause,   // Exception cause code
    input  wire [31:0] exception_epc,     // Return PC saved to EPC

    // Direct register outputs for processor / debug
    output wire [31:0] Cause_out,
    output wire [31:0] EPC_out
);

    // 32 32-bit Coprocessor 0 registers
    reg [31:0] registers [0:31];

    // Effective register address: handles standard rd in [15:11] and alt Cause in [15:8]
    wire [4:0] effective_addr = (alt_cause && (reg_addr == 5'd1 || reg_addr == 5'd0)) ? 5'd13 : reg_addr;

    // Asynchronous / Combinational read for mfc0
    assign cp0_read_data = registers[effective_addr];

    // Direct access to Cause (13) and EPC (14)
    assign Cause_out = registers[13];
    assign EPC_out   = registers[14];

    integer i;
    always @(posedge clock or negedge reset) begin
        if (!reset) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'b0;
            end
        end else begin
            // Hardware Exception has highest priority: update Cause and EPC
            if (exception_trigger) begin
                registers[13] <= exception_cause;
                registers[14] <= exception_epc;
            end else if (cp0_write_en) begin
                registers[effective_addr] <= cp0_write_data;
            end
        end
    end

endmodule
