// =============================================================================
// ahb_slave_mux.v
// AHB-Lite Slave-to-Master Multiplexer
// Selects HRDATA, HREADY, and HRESP from the active slave in the Data Phase.
// =============================================================================

module ahb_slave_mux (
    input  wire        HCLK,
    input  wire        HRESETn,

    // Slave select lines from decoder (Address Phase)
    input  wire        HSEL_DM,
    input  wire        HSEL_GPIO,
    input  wire        HSEL_APB,
    input  wire        HSEL_DEF,

    // Responses from Data Memory
    input  wire [31:0] HRDATA_DM,
    input  wire        HREADYOUT_DM,
    input  wire        HRESP_DM,

    // Responses from GPIO
    input  wire [31:0] HRDATA_GPIO,
    input  wire        HREADYOUT_GPIO,
    input  wire        HRESP_GPIO,

    // Responses from APB Bridge
    input  wire [31:0] HRDATA_APB,
    input  wire        HREADYOUT_APB,
    input  wire        HRESP_APB,

    // Responses from Default Slave
    input  wire [31:0] HRDATA_DEF,
    input  wire        HREADYOUT_DEF,
    input  wire        HRESP_DEF,

    // Multiplexed bus outputs (Data Phase)
    output reg  [31:0] HRDATA,
    output wire        HREADY,
    output reg         HRESP
);

    reg [2:0] sel_reg;
    reg       hreadyout_mux;

    // Register active slave from Address Phase to Data Phase
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            sel_reg <= 3'b000;
        end else if (HREADY) begin
            if (HSEL_DM)
                sel_reg <= 3'b001;
            else if (HSEL_GPIO)
                sel_reg <= 3'b010;
            else if (HSEL_APB)
                sel_reg <= 3'b011;
            else if (HSEL_DEF)
                sel_reg <= 3'b100;
            else
                sel_reg <= 3'b000;
        end
    end

    // Multiplexer in Data Phase
    always @(*) begin
        case (sel_reg)
            3'b001: begin
                HRDATA        = HRDATA_DM;
                hreadyout_mux = HREADYOUT_DM;
                HRESP         = HRESP_DM;
            end
            3'b010: begin
                HRDATA        = HRDATA_GPIO;
                hreadyout_mux = HREADYOUT_GPIO;
                HRESP         = HRESP_GPIO;
            end
            3'b011: begin
                HRDATA        = HRDATA_APB;
                hreadyout_mux = HREADYOUT_APB;
                HRESP         = HRESP_APB;
            end
            3'b100: begin
                HRDATA        = HRDATA_DEF;
                hreadyout_mux = HREADYOUT_DEF;
                HRESP         = HRESP_DEF;
            end
            default: begin
                HRDATA        = 32'b0;
                hreadyout_mux = 1'b1;
                HRESP         = 1'b0;
            end
        endcase
    end

    assign HREADY = hreadyout_mux;

endmodule

