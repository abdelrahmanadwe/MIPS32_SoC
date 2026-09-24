// =============================================================================
// ahb_default_slave.v
// AHB-Lite Default Slave for unmapped address accesses
// Returns OKAY response with 0 data to prevent bus hang.
// =============================================================================

module ahb_default_slave (
    input  wire        HCLK,
    input  wire        HRESETn,
    input  wire        HSEL,
    input  wire        HREADY,
    input  wire [1:0]  HTRANS,
    input  wire [2:0]  HSIZE,
    input  wire        HWRITE,
    input  wire [31:0] HADDR,
    input  wire [31:0] HWDATA,

    output wire        HREADYOUT,
    output wire        HRESP,
    output wire [31:0] HRDATA
);
    assign HREADYOUT = 1'b1;
    assign HRESP     = 1'b0; // OKAY
    assign HRDATA    = 32'b0;

endmodule

