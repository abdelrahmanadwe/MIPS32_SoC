// =============================================================================
// Data_Memory.v
// AHB-Lite Compliant Byte-Addressable Data Memory (RAM) Slave
// Implements 4-Bank Byte-Wide Write Enables (we[3:0]) and True Synchronous
// Block RAM (BRAM) Read Architecture for direct FPGA synthesis.
// =============================================================================

module Data_Memory #(
    parameter START_ADDR = 32'h0000_0000,
    parameter END_ADDR   = 32'h0000_7FFF
)(
    // AHB-Lite Bus Interface
    input  wire        HCLK,
    input  wire        HRESETn,
    input  wire        HSEL,
    input  wire        HREADY,
    input  wire [1:0]  HTRANS,
    input  wire [2:0]  HSIZE,
    input  wire        HWRITE,
    input  wire [31:0] HADDR,
    input  wire [31:0] HWDATA,
    input  wire        HUSER,       // MemUnsigned: 0=signed, 1=unsigned

    output wire        HREADYOUT,
    output wire        HRESP,
    output reg  [31:0] HRDATA,

    // Test output for TB verification
    output wire [15:0] TestValue
);
    localparam MEM_SIZE_BYTES = END_ADDR - START_ADDR + 1;
    localparam NUM_WORDS      = MEM_SIZE_BYTES / 4;

    // =========================================================================
    // 1. 4-Bank Byte-Wide Block RAM Arrays (FPGA BRAM Inference Compatible)
    // =========================================================================
    reg [7:0] ram_b0 [0:NUM_WORDS-1];
    reg [7:0] ram_b1 [0:NUM_WORDS-1];
    reg [7:0] ram_b2 [0:NUM_WORDS-1];
    reg [7:0] ram_b3 [0:NUM_WORDS-1];

    // Synchronous BRAM output registers
    reg [7:0] dout_b0;
    reg [7:0] dout_b1;
    reg [7:0] dout_b2;
    reg [7:0] dout_b3;

    // Address calculation (Address Phase)
    wire in_range_in = (HADDR >= START_ADDR && HADDR <= END_ADDR);
    wire [29:0] word_addr_in = in_range_in ? ((HADDR - START_ADDR) >> 2) : 30'b0;

    // Pipeline registers: Address Phase -> Data Phase
    reg [31:0] addr_reg;
    reg        write_reg;
    reg [1:0]  size_reg;
    reg        user_reg;
    reg        active_reg;
    reg [29:0] word_addr_reg;

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            addr_reg      <= 32'b0;
            write_reg     <= 1'b0;
            size_reg      <= 2'b10;
            user_reg      <= 1'b0;
            active_reg    <= 1'b0;
            word_addr_reg <= 30'b0;
        end else if (HREADY) begin
            active_reg <= HSEL && HTRANS[1];
            if (HSEL && HTRANS[1]) begin
                addr_reg      <= HADDR;
                write_reg     <= HWRITE;
                size_reg      <= HSIZE[1:0];
                user_reg      <= HUSER;
                word_addr_reg <= word_addr_in;
            end
        end
    end

    // Address mapping for Data Phase
    wire in_range_data = (addr_reg >= START_ADDR && addr_reg <= END_ADDR);

    // =========================================================================
    // 2. Byte Write Enable (we[3:0]) Generation (Data Phase)
    // =========================================================================
    reg [3:0] we;
    reg [7:0] din_b0, din_b1, din_b2, din_b3;

    // Handle both unaligned (MIPS register format) and aligned HWDATA
    wire [7:0] byte_data = (HWDATA[31:8] != 24'b0 && addr_reg[1:0] != 2'b00) ? 
                           (HWDATA >> (8 * addr_reg[1:0])) : HWDATA[7:0];
    wire [15:0] hw_data  = (HWDATA[31:16] != 16'b0 && addr_reg[1]) ? 
                           HWDATA[31:16] : HWDATA[15:0];

    always @(*) begin
        we = 4'b0000;
        din_b0 = 8'b0;
        din_b1 = 8'b0;
        din_b2 = 8'b0;
        din_b3 = 8'b0;

        if (active_reg && write_reg && in_range_data) begin
            case (size_reg)
                2'b00: begin // Byte write (sb)
                    case (addr_reg[1:0])
                        2'b00: begin we = 4'b0001; din_b0 = byte_data; end
                        2'b01: begin we = 4'b0010; din_b1 = byte_data; end
                        2'b10: begin we = 4'b0100; din_b2 = byte_data; end
                        2'b11: begin we = 4'b1000; din_b3 = byte_data; end
                    endcase
                end

                2'b01: begin // Halfword write (sh)
                    if (addr_reg[1] == 1'b0) begin
                        we = 4'b0011;
                        din_b0 = hw_data[7:0];
                        din_b1 = hw_data[15:8];
                    end else begin
                        we = 4'b1100;
                        din_b2 = hw_data[7:0];
                        din_b3 = hw_data[15:8];
                    end
                end

                default: begin // Word write (sw)
                    we = 4'b1111;
                    din_b0 = HWDATA[7:0];
                    din_b1 = HWDATA[15:8];
                    din_b2 = HWDATA[23:16];
                    din_b3 = HWDATA[31:24];
                end
            endcase
        end
    end

    // =========================================================================
    // 3. Synchronous Block RAM Read & Write Operations (BRAM Template)
    // =========================================================================
    // Same-cycle write-first bypass check for back-to-back RAW operations
    wire raw_hazard = (active_reg && write_reg && (word_addr_reg == word_addr_in));

    always @(posedge HCLK) begin
        if (HREADY && HSEL && HTRANS[1]) begin
            dout_b0 <= (raw_hazard && we[0]) ? din_b0 : ram_b0[word_addr_in];
            dout_b1 <= (raw_hazard && we[1]) ? din_b1 : ram_b1[word_addr_in];
            dout_b2 <= (raw_hazard && we[2]) ? din_b2 : ram_b2[word_addr_in];
            dout_b3 <= (raw_hazard && we[3]) ? din_b3 : ram_b3[word_addr_in];
        end
    end

    // Memory write on posedge HCLK at the end of the Data Phase
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin : reset_memory
            integer i;
            for (i = 0; i < NUM_WORDS; i = i + 1) begin
                ram_b0[i] <= 8'b0;
                ram_b1[i] <= 8'b0;
                ram_b2[i] <= 8'b0;
                ram_b3[i] <= 8'b0;
            end
        end else begin
            if (we[0]) ram_b0[word_addr_reg] <= din_b0;
            if (we[1]) ram_b1[word_addr_reg] <= din_b1;
            if (we[2]) ram_b2[word_addr_reg] <= din_b2;
            if (we[3]) ram_b3[word_addr_reg] <= din_b3;
        end
    end

    // =========================================================================
    // 4. Read Data Formatting & Extension (Data Phase)
    // =========================================================================
    wire [31:0] dout_word = {dout_b3, dout_b2, dout_b1, dout_b0};

    // Halfword selection
    wire [15:0] selected_halfword = addr_reg[1] ? dout_word[31:16] : dout_word[15:0];

    // Byte selection
    reg [7:0] selected_byte;
    always @(*) begin
        case (addr_reg[1:0])
            2'b00:   selected_byte = dout_word[7:0];
            2'b01:   selected_byte = dout_word[15:8];
            2'b10:   selected_byte = dout_word[23:16];
            default: selected_byte = dout_word[31:24];
        endcase
    end

    // Final HRDATA generation with sign/zero extension
    always @(*) begin
        if (!active_reg || write_reg || !in_range_data) begin
            HRDATA = 32'b0;
        end else if (size_reg == 2'b00) begin // Byte read (lb / lbu)
            if (user_reg)
                HRDATA = {24'b0, selected_byte};
            else
                HRDATA = {{24{selected_byte[7]}}, selected_byte};
        end else if (size_reg == 2'b01) begin // Halfword read (lh / lhu)
            if (user_reg)
                HRDATA = {16'b0, selected_halfword};
            else
                HRDATA = {{16{selected_halfword[15]}}, selected_halfword};
        end else begin // Word read (lw)
            HRDATA = dout_word;
        end
    end

    // =========================================================================
    // 5. Outputs
    // =========================================================================
    assign HREADYOUT = 1'b1;
    assign HRESP     = 1'b0; // OKAY response

    // Test output (bytes 1 and 0 of word 0)
    assign TestValue = {ram_b1[0], ram_b0[0]};

endmodule
