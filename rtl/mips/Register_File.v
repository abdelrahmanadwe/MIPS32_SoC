module RegisterFile(
	output [31:0] ReadData1,    // Data from first read register
    output [31:0] ReadData2,    // Data from second read register
    input Clock,reset,          // Clock and reset signals
    input RegWrite,             // Register write enable
    input [4:0] Address1Read,   // First register to read
    input [4:0] Address2Read,   // Second register to read
    input [4:0] Address3Write,  // Register to write
    input [31:0] WriteData,     // Data to write
    input is_mfc0               // High if writing from mfc0 instruction
);

    // Register file with 32 32-bit registers
    reg [31:0] registers [0:31];
	
    // Read data (Register 0 is hardwired to 0)
    assign ReadData1 = (Address1Read == 5'b0) ? 32'b0 : registers[Address1Read];
    assign ReadData2 = (Address2Read == 5'b0) ? 32'b0 : registers[Address2Read];

    // Write data (Ignore writes to register 0)
    always @(posedge Clock or negedge reset) begin
		if (!reset) begin : resetvalues
		    integer i;
		    for (i = 0; i < 32; i = i + 1) begin
		        registers[i] <= 32'b0;
		    end
		end
		else begin
		    if (RegWrite && Address3Write != 5'b0) begin
			    registers[Address3Write] <= WriteData;
			    // Support exception return: if mfc0 writes EPC to register 14, mirror to 30 ($fp) and 26 ($k0)
			    if (Address3Write == 5'd14 && is_mfc0) begin
			        registers[5'd30] <= WriteData;
			        registers[5'd26] <= WriteData;
			    end
		    end
		end
    end
    
	// Debug wires for easier waveform and testbench register inspection (dot-operator access)
	wire [31:0] zero = registers[0];
	wire [31:0] at   = registers[1];
	wire [31:0] v0   = registers[2];
	wire [31:0] v1   = registers[3];
	wire [31:0] a0   = registers[4];
	wire [31:0] a1   = registers[5];
	wire [31:0] a2   = registers[6];
	wire [31:0] a3   = registers[7];
	wire [31:0] t0   = registers[8];
	wire [31:0] t1   = registers[9];
	wire [31:0] t2   = registers[10];
	wire [31:0] t3   = registers[11];
	wire [31:0] t4   = registers[12];
	wire [31:0] t5   = registers[13];
	wire [31:0] t6   = registers[14];
	wire [31:0] t7   = registers[15];
	wire [31:0] s0   = registers[16];
	wire [31:0] s1   = registers[17];
	wire [31:0] s2   = registers[18];
	wire [31:0] s3   = registers[19];
	wire [31:0] s4   = registers[20];
	wire [31:0] s5   = registers[21];
	wire [31:0] s6   = registers[22];
	wire [31:0] s7   = registers[23];
	wire [31:0] t8   = registers[24];
	wire [31:0] t9   = registers[25];
	wire [31:0] k0   = registers[26];
	wire [31:0] k1   = registers[27];
	wire [31:0] gp   = registers[28];
	wire [31:0] sp   = registers[29];
	wire [31:0] fp   = registers[30];
	wire [31:0] ra   = registers[31];

endmodule
