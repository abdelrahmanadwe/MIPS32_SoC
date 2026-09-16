// =============================================================================
// Branch_Predictor.v
// 2-Bit Dynamic Branch Predictor with Branch Target Buffer (BTB)
// States: 
//   00: Strongly Not Taken
//   01: Weakly Not Taken
//   10: Weakly Taken
//   11: Strongly Taken
// =============================================================================

module Branch_Predictor #(
    parameter TABLE_ENTRIES = 1024
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,                  // Hold predictor update on pipeline stall

    // Read interface (IF stage)
    input  wire [31:0] read_addr,              // PC in IF stage (PCF)
    output wire [31:0] branch_pred_target,     // Predicted target address
    output wire        branch_pred_sel,        // 1 = Predict Taken, 0 = Predict Not Taken

    // Feedback interface (ID stage)
    input  wire [31:0] write_address,          // PC_D (from IF/ID register = PC_branch + 4)
    input  wire        branch_write_enable,    // branchD from Control Unit
    input  wire        branch_taken,           // PCSrcD from Branch Comparison
    input  wire [31:0] branch_write_target,    // Target address from ID branch adder
    input  wire        jump_write_enable,      // jumpD from Control Unit
    input  wire [31:0] jump_write_target,      // Target address from ID jump calculation

    // Misprediction Recovery interface
    output reg  [31:0] mispred_correct_target, // Recovery target
    output reg         mispred_sel             // 1 = Misprediction / Recovery needed
);

    localparam INDEX_BITS = 10; // 1024 entries covers full 4KB instruction memory

    // Tables
    reg [1:0]  state_table  [0:TABLE_ENTRIES-1];
    reg        valid_table  [0:TABLE_ENTRIES-1];
    reg [31:0] target_table [0:TABLE_ENTRIES-1];

    // Read index (IF Stage)
    wire [INDEX_BITS-1:0] read_index = read_addr[INDEX_BITS+1:2];

    // Branch prediction output in IF stage
    wire [1:0]  pred_state  = state_table[read_index];
    wire        pred_valid  = valid_table[read_index];
    wire [31:0] pred_target = target_table[read_index];

    assign branch_pred_sel    = pred_valid && (pred_state[1] == 1'b1);
    assign branch_pred_target = pred_target;

    // Write index (ID Stage)
    // write_address is PC_D = (branch_pc + 4), so branch_pc = write_address - 4
    wire [31:0] branch_pc   = write_address - 32'd4;
    wire [INDEX_BITS-1:0] write_index = branch_pc[INDEX_BITS+1:2];

    wire [1:0] curr_state = state_table[write_index];
    wire       curr_valid = valid_table[write_index];
    wire       curr_pred_taken = curr_valid && curr_state[1];

    // State machine transitions and misprediction outputs (Slide 8 Table)
    reg [1:0]  next_state;
    reg [31:0] next_target;
    reg        update_enable;

    always @(*) begin
        mispred_sel            = 1'b0;
        mispred_correct_target = 32'b0;
        next_state             = curr_state;
        next_target            = branch_write_target;
        update_enable          = 1'b0;

        if (jump_write_enable) begin
            update_enable = 1'b1;
            next_state    = 2'b11; // Strongly taken
            next_target   = jump_write_target;
            if (!curr_pred_taken) begin
                mispred_sel            = 1'b1;
                mispred_correct_target = jump_write_target;
            end else begin
                mispred_sel            = 1'b0;
                mispred_correct_target = 32'b0;
            end
        end
        else if (branch_write_enable) begin
            update_enable = 1'b1;
            next_target   = branch_write_target;
            case (curr_state)
                2'b00: begin // Strongly Not Taken
                    if (branch_taken) begin
                        next_state             = 2'b01; // weakly not taken
                        mispred_sel            = 1'b1;
                        mispred_correct_target = branch_write_target;
                    end else begin
                        next_state             = 2'b00; // strongly not taken
                        mispred_sel            = 1'b0;
                        mispred_correct_target = 32'b0;
                    end
                end

                2'b01: begin // Weakly Not Taken
                    if (branch_taken) begin
                        next_state             = 2'b10; // weakly taken
                        mispred_sel            = 1'b1;
                        mispred_correct_target = branch_write_target;
                    end else begin
                        next_state             = 2'b00; // strongly not taken
                        mispred_sel            = 1'b0;
                        mispred_correct_target = 32'b0;
                    end
                end

                2'b10: begin // Weakly Taken
                    if (branch_taken) begin
                        next_state             = 2'b11; // strongly taken
                        mispred_sel            = 1'b0;
                        mispred_correct_target = 32'b0;
                    end else begin
                        next_state             = 2'b01; // weakly not taken
                        mispred_sel            = 1'b1;
                        mispred_correct_target = write_address; // PC_D (fallthrough address)
                    end
                end

                2'b11: begin // Strongly Taken
                    if (branch_taken) begin
                        next_state             = 2'b11; // strongly taken
                        mispred_sel            = 1'b0;
                        mispred_correct_target = 32'b0;
                    end else begin
                        next_state             = 2'b10; // weakly taken
                        mispred_sel            = 1'b1;
                        mispred_correct_target = write_address; // PC_D (fallthrough address)
                    end
                end
            endcase
        end
    end

    // Sequential update of BTB and 2-bit counter table
    always @(posedge clk or negedge reset) begin
        if (!reset) begin : reset_table
            integer i;
            for (i = 0; i < TABLE_ENTRIES; i = i + 1) begin
                state_table[i]  <= 2'b00; // Strongly Not Taken
                valid_table[i]  <= 1'b0;
                target_table[i] <= 32'b0;
            end
        end else if (!stall && update_enable) begin
            state_table[write_index]  <= next_state;
            target_table[write_index] <= next_target;
            valid_table[write_index]  <= 1'b1;
        end
    end

endmodule

