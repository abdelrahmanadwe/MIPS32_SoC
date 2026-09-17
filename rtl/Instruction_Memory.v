module InstructionMemory #(
    parameter START_ADDR      = 32'h0000_0000,
    parameter END_ADDR        = 32'h0000_0FFF,
    parameter EXCEP_MEM_FILE  = "Tests/test8/Test8_Exception.excep.mem",
    parameter EXCEP_START_ADDR= 32'h0000_8180
)(
	output [31:0] instruction, // Instruction output
    input [31:0] Address       // Address input
);

    localparam MEM_SIZE_BYTES = END_ADDR - START_ADDR + 1;
    localparam EXCEP_MEM_SIZE = 4096; // 4KB Reserved Memory for Exception Handler

    // ROM with parameterized 8-bit entries
    reg [7:0] memory [0:MEM_SIZE_BYTES-1];
    reg [7:0] excep_memory [0:EXCEP_MEM_SIZE-1];

    integer j;
    initial begin
        for (j = 0; j < EXCEP_MEM_SIZE; j = j + 1) begin
            excep_memory[j] = 8'b0;
        end
        $readmemh(EXCEP_MEM_FILE, excep_memory);
    end

    // Fetch instruction
    // Address check: bit 15 (1 = Reserved section starting at 0x8000, 0 = Text section)
    wire is_rsvd = Address[15];

    // 1. Text Section (0x0000 - 0x7FFF)
    wire in_range = (Address >= START_ADDR && Address <= END_ADDR);
    wire [31:0] byte_addr = in_range ? (Address - START_ADDR) : 32'b0;
    wire [31:0] text_instruction = in_range ? {memory[byte_addr+3], memory[byte_addr+2], memory[byte_addr+1], memory[byte_addr]} : 32'b0;

    // 2. Reserved Exception Handler Section (0x8000 - 0xFFFF, entry point at 0x8180)
    wire in_excep_range = (Address >= EXCEP_START_ADDR);
    wire [31:0] excep_byte_addr = in_excep_range ? (Address - EXCEP_START_ADDR) : 32'b0;
    wire [31:0] rsvd_instruction = (in_excep_range && (excep_byte_addr + 3 < EXCEP_MEM_SIZE)) ?
                                   {excep_memory[excep_byte_addr+3], excep_memory[excep_byte_addr+2], excep_memory[excep_byte_addr+1], excep_memory[excep_byte_addr]} : 32'b0;

    assign instruction = is_rsvd ? rsvd_instruction : text_instruction;

endmodule



















