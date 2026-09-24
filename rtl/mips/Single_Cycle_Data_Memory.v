module Single_Cycle_Data_Memory #(
    parameter START_ADDR = 32'h0000_1000,
    parameter END_ADDR   = 32'h0000_7FFF
)(
	output [31:0] ReadData,      // Data output
	output [15:0] TestValue,     // test value
    input Clock,Reset,           // Clock and reset signals
    input [31:0] Address,        // Address input
    input [31:0] WriteData,      // Data to be written
    input WriteEnable,           // Memory write enable
    input [1:0] MemSize,         // Memory access size: 00=byte, 01=half, 10=word
    input MemUnsigned            // Memory load sign: 0=signed, 1=unsigned
);
    localparam MEM_SIZE_BYTES = END_ADDR - START_ADDR + 1;

    wire in_range = (Address >= START_ADDR && Address <= END_ADDR);
    
    // RAM 
    reg [7:0] memory [0:MEM_SIZE_BYTES-1];

    // Compute safe internal addresses to prevent simulation array-bound warnings
    wire [31:0] mapped_addr = in_range ? (Address - START_ADDR) : 32'b0;
    wire [31:0] WordAddress = {Address[31:2], 2'b00};
    wire [31:0] mapped_word_addr = in_range ? (WordAddress - START_ADDR) : 32'b0;

    // Read data (Combinational)
    reg [31:0] read_data_mux;
    always @(*) begin
        if (!in_range) begin
            read_data_mux = 32'b0;
        end
        else if (MemSize == 2'b00) begin // Byte read (lb/lbu)
            if (MemUnsigned)
                read_data_mux = {24'b0, memory[mapped_addr]};
            else
                read_data_mux = {{24{memory[mapped_addr][7]}}, memory[mapped_addr]};
        end
        else if (MemSize == 2'b01) begin // Halfword read (lh/lhu)
            if (MemUnsigned)
                read_data_mux = {16'b0, memory[mapped_addr+1], memory[mapped_addr]};
            else
                read_data_mux = {{16{memory[mapped_addr+1][7]}}, memory[mapped_addr+1], memory[mapped_addr]};
        end
        else begin // Word read (lw)
            read_data_mux = {memory[mapped_word_addr+3], memory[mapped_word_addr+2], memory[mapped_word_addr+1], memory[mapped_word_addr]};
        end
    end
    assign ReadData = read_data_mux;

	assign TestValue = {memory[1],memory[0]};

    // Write data
    always @(posedge Clock or negedge Reset) begin
        if(!Reset) begin : reset_memory
            integer i;
            for (i = 0; i < MEM_SIZE_BYTES; i = i + 1) begin
                memory[i] <= 8'b0;
            end
        end
        else if (WriteEnable && in_range) begin
            if (MemSize == 2'b00) begin // Byte write (sb)
                memory[mapped_addr] <= WriteData[7:0];
            end
            else if (MemSize == 2'b01) begin // Halfword write (sh)
                memory[mapped_addr]   <= WriteData[7:0];
                memory[mapped_addr+1] <= WriteData[15:8];
            end
            else begin // Word write (sw)
                memory[mapped_word_addr]   <= WriteData[7:0];
                memory[mapped_word_addr+1] <= WriteData[15:8];
                memory[mapped_word_addr+2] <= WriteData[23:16];
                memory[mapped_word_addr+3] <= WriteData[31:24];
            end
        end
    end

endmodule

