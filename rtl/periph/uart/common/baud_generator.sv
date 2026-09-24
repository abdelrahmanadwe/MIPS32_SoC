import uart_defs::*;

module baud_generator #(
  parameter int OVERSAMPLING = 1 // 1 for TX, 16 for RX
)(
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic [15:0]           baud_div,
  input  logic                  active,
  output logic                  baud_out
);

  logic [19:0] max_count;
  logic [19:0] counter;

  always_comb begin
    if (OVERSAMPLING == 1) begin
      max_count = 20'(baud_div) * 20'd16;
    end else begin
      max_count = 20'(baud_div);
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter  <= 20'd0;
      baud_out <= 1'b0;
    end else if (!active) begin
      counter  <= 20'd0;
      baud_out <= 1'b0;
    end else begin
      if (counter >= max_count - 20'd1) begin
        counter  <= 20'd0;
        baud_out <= 1'b1;
      end else begin
        counter  <= counter + 20'd1;
        baud_out <= 1'b0;
      end
    end
  end

endmodule
