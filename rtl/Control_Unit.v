module ControlUnit(
    output [1:0] RegDst,   // Register destination: 00=rt, 01=rd, 10=$31
    output ALUSrc,       // ALU source
    output [2:0] MemToReg, // Memory to register: 000=ALUResult, 001=ReadDataRam, 010=PCPlus4, 011=HI, 100=LO
    output RegWrite,     // Register write enable
    output MemWrite,     // Memory write enable
    output Branch,       // Branch signal
    output [1:0] Jump,   // Jump signal: 00=no jump, 01=jump target, 10=jump register
    output [3:0] ALUControl, // ALU control signal
    output is_signed,    // Sign control for ALU/Multiplier/Divider
    output [1:0] MemSize, // Memory access size: 00=byte, 01=half, 10=word
    output MemUnsigned,   // Memory load sign: 0=signed, 1=unsigned
    output [1:0] ExtOp,   // Extension operation: 00=zero, 01=sign, 10=upper imm
    output Bne,           // Control signal for branch on not equal
    output hi_write,      // Write enable for HI register
    output lo_write,      // Write enable for LO register
    output [1:0] HILOSrc, // Select HI/LO source: 00=mul, 01=div, 10=rs
    output cp0_write,     // Write enable for CP0 register (mtc0)
    output is_syscall,    // System call exception flag
    output is_break,      // Breakpoint exception flag
    output is_undefined,  // Undefined instruction exception flag
	input [5:0] opcode,      // Opcode field from the instruction
    input [5:0] funct,       // Function field from the instruction (for R-type)
    input [4:0] rs           // rs field for CP0 instructions
);

    wire [3:0] ALUOp;  // ALU operation (expanded to 4 bits)
    // Instantiate Main Decoder
    MainDecoder maindecoder(
		.ALUOp(ALUOp),  
		.MemToReg(MemToReg),    
		.MemWrite(MemWrite),    
		.Branch(Branch),      
		.ALUSrc(ALUSrc),      
		.RegDst(RegDst),      
		.RegWrite(RegWrite),    
		.Jump(Jump),        
		.MemSize(MemSize),
		.MemUnsigned(MemUnsigned),
		.ExtOp(ExtOp),
		.Bne(Bne),
		.hi_write(hi_write),
		.lo_write(lo_write),
		.HILOSrc(HILOSrc),
		.cp0_write(cp0_write),
		.is_syscall(is_syscall),
		.is_break(is_break),
		.is_undefined(is_undefined),
		.opcode(opcode),
		.funct(funct),
		.rs(rs)
	);

    // Instantiate ALU Decoder
    ALUDecoder aluDecoder (
        .ALUOp(ALUOp),
        .Funct(funct),
        .ALUControl(ALUControl)
    );

    // Determine is_signed
    assign is_signed = (opcode == 6'b000000) ? 
                       (funct == 6'b100000 || funct == 6'b100010 || funct == 6'b101010 || funct == 6'b011000 || funct == 6'b011010) : // add, sub, slt, mult, div
                       (opcode == 6'b001000 || opcode == 6'b100011 || opcode == 6'b101011 || opcode == 6'b000100 || opcode == 6'b001010); // addi, lw, sw, beq, slti

endmodule
