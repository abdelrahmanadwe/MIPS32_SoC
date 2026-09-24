// =============================================================================
// ahb_decoder.v
// AHB-Lite Bus Decoder & Master Adapter
// Converts MIPS Core MEM-stage memory interface to AHB-Lite protocol
// and generates slave selection signals.
// =============================================================================

module ahb_decoder (
    input  wire        HCLK,
    input  wire        HRESETn,

    // Inputs from MIPS Core (MEM stage)
    input  wire [31:0] MemAddrM,
    input  wire [31:0] MemWriteDataM,
    input  wire        MemWriteM,
    input  wire        MemReadM,
    input  wire [1:0]  MemSizeM,
    input  wire        MemUnsignedM,

    // Bus ready input from Slave MUX
    input  wire        HREADY,

    // AHB-Lite Master Bus outputs
    output wire [31:0] HADDR,
    output reg  [31:0] HWDATA,
    output wire        HWRITE,
    output wire [2:0]  HSIZE,
    output wire [1:0]  HTRANS,
    output wire        HUSER,

    // Slave Selects
    output reg         HSEL_DM,
    output reg         HSEL_GPIO,
    output reg         HSEL_APB,
    output reg         HSEL_DEF
);

    // Address Phase Signals
    assign HADDR  = MemAddrM;
    assign HWRITE = MemWriteM;
    assign HSIZE  = {1'b0, MemSizeM};
    assign HTRANS = (MemWriteM || MemReadM) ? 2'b10 : 2'b00; // NONSEQ or IDLE
    assign HUSER  = MemUnsignedM;

    // Address Decoding (Address Phase)
    always @(*) begin
        if (HTRANS[1]) begin
            // GPIO Base: 0xA000_0000 - 0xA000_07FF
            if ((MemAddrM[31:12] == 20'hA0000) && (MemAddrM[11] == 1'b0)) begin
                HSEL_GPIO = 1'b1;
                HSEL_DM   = 1'b0;
                HSEL_APB  = 1'b0;
                HSEL_DEF  = 1'b0;
            // APB Subsystem (UART & Timer): 0xA000_0800 - 0xA000_0FFF
            end else if ((MemAddrM[31:12] == 20'hA0000) && (MemAddrM[11] == 1'b1)) begin
                HSEL_APB  = 1'b1;
                HSEL_DM   = 1'b0;
                HSEL_GPIO = 1'b0;
                HSEL_DEF  = 1'b0;
            // Data RAM Base: 0x0000_0000 - 0x0000_7FFF
            end else if (MemAddrM <= 32'h0000_7FFF) begin
                HSEL_DM   = 1'b1;
                HSEL_GPIO = 1'b0;
                HSEL_APB  = 1'b0;
                HSEL_DEF  = 1'b0;
            // Unmapped / Default Slave
            end else begin
                HSEL_DEF  = 1'b1;
                HSEL_DM   = 1'b0;
                HSEL_GPIO = 1'b0;
                HSEL_APB  = 1'b0;
            end
        end else begin
            HSEL_DM   = 1'b0;
            HSEL_GPIO = 1'b0;
            HSEL_APB  = 1'b0;
            HSEL_DEF  = 1'b0;
        end
    end

    // Data Phase Write Data (registered to align with Data Phase)
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HWDATA <= 32'b0;
        end else if (HREADY) begin
            HWDATA <= MemWriteDataM;
        end
    end

endmodule

