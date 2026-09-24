// =============================================================================
// ahb_to_apb.v
// AHB-Lite to APB Subsystem Bridge
// Translates AHB-Lite single-cycle transfers to APB transfers for:
//   1. APB Timer (cmsdk_apb_timer) at 0xA000_0C00 - 0xA000_0FFF (1-cycle CMSDK mode)
//   2. APB UART  (Custom UART)     at 0xA000_0800 - 0xA000_0BFF (Standard APB mode)
// Provides 0 wait-states to AHB-Lite to maintain pipelined execution without stalls.
// =============================================================================

module ahb_to_apb (
    // AHB-Lite Slave Interface
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
    output wire [31:0] HRDATA,

    // APB Master Interface to Timer (0xA000_0C00 - 0xA000_0FFF)
    output wire        PSEL_TIMER,
    output wire        PENABLE_TIMER,
    output wire        PWRITE_TIMER,
    output wire [11:2] PADDR_TIMER,
    output wire [31:0] PWDATA_TIMER,
    input  wire [31:0] PRDATA_TIMER,
    input  wire        PREADY_TIMER,
    input  wire        PSLVERR_TIMER,

    // APB Master Interface to UART (0xA000_0800 - 0xA000_0BFF)
    output wire        PSEL_UART,
    output wire        PENABLE_UART,
    output wire        PWRITE_UART,
    output wire [4:0]  PADDR_UART,
    output wire [31:0] PWDATA_UART,
    input  wire [31:0] PRDATA_UART,
    input  wire        PREADY_UART,
    input  wire        PSLVERR_UART
);

    // Address Phase Decode
    wire ahb_transfer   = HSEL & HTRANS[1] & HREADY;
    wire sel_uart_addr  = (HADDR[11:10] == 2'b10); // 0xA000_0800 - 0xA000_0BFF
    wire sel_timer_addr = (HADDR[11:10] == 2'b11); // 0xA000_0C00 - 0xA000_0FFF

    // Setup for Timer read (CMSDK requires PSEL & ~PWRITE in address phase)
    wire timer_read_setup = ahb_transfer & sel_timer_addr & (~HWRITE);

    // Registers to hold transfer attributes across to Data Phase
    reg [9:0] paddr_reg;
    reg       psel_timer_reg;
    reg       psel_uart_reg;
    reg       pwrite_reg;
    reg       periph_sel_reg; // 0: UART, 1: Timer

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            psel_timer_reg <= 1'b0;
            psel_uart_reg  <= 1'b0;
            pwrite_reg     <= 1'b0;
            paddr_reg      <= 10'h000;
            periph_sel_reg <= 1'b0;
        end else if (HREADY) begin
            psel_timer_reg <= ahb_transfer & sel_timer_addr;
            psel_uart_reg  <= ahb_transfer & sel_uart_addr;
            pwrite_reg     <= HWRITE;
            paddr_reg      <= HADDR[9:0];
            periph_sel_reg <= sel_timer_addr;
        end
    end

    // -------------------------------------------------------------------------
    // APB Signals for Timer (CMSDK 1-cycle APB convention)
    // -------------------------------------------------------------------------
    wire timer_write_data_phase = psel_timer_reg & pwrite_reg;

    assign PSEL_TIMER    = psel_timer_reg | timer_read_setup;
    assign PWRITE_TIMER  = timer_write_data_phase ? 1'b1 : (timer_read_setup ? 1'b0 : pwrite_reg);
    assign PENABLE_TIMER = 1'b0; // CMSDK peripheral samples write on ~PENABLE
    assign PADDR_TIMER   = timer_write_data_phase ? {2'b00, paddr_reg[9:2]} :
                           (timer_read_setup ? {2'b00, HADDR[9:2]} : {2'b00, paddr_reg[9:2]});
    assign PWDATA_TIMER  = HWDATA;

    // -------------------------------------------------------------------------
    // APB Signals for UART (Standard APB convention: PENABLE=1 in Data Phase)
    // -------------------------------------------------------------------------
    assign PSEL_UART    = psel_uart_reg;
    assign PWRITE_UART  = pwrite_reg;
    assign PENABLE_UART = psel_uart_reg; // Active during Data/Access phase
    assign PADDR_UART   = paddr_reg[4:0];
    assign PWDATA_UART  = HWDATA;

    // -------------------------------------------------------------------------
    // AHB Responses
    // -------------------------------------------------------------------------
    assign HRDATA    = periph_sel_reg ? PRDATA_TIMER : PRDATA_UART;
    assign HREADYOUT = 1'b1;
    assign HRESP     = 1'b0;

endmodule
