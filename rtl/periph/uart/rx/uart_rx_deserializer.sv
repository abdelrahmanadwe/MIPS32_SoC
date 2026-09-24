import uart_defs::*;

module uart_rx_deserializer (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  sample_pulse,
  input  logic                  rx_in_sampled,
  input  data_size_e            data_size_ctrl,
  output logic [7:0]            data_out
);

  logic [7:0] shift_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      shift_reg <= 8'b0;
    end else if (sample_pulse) begin
      // Shift right (LSB first), placing the new bit at MSB
      shift_reg <= {rx_in_sampled, shift_reg[7:1]};
    end
  end

  // Align the output based on configuration
  always_comb begin
    case (data_size_ctrl)
      DATA_5_BITS: data_out = {3'b0, shift_reg[7:3]};
      DATA_6_BITS: data_out = {2'b0, shift_reg[7:2]};
      DATA_7_BITS: data_out = {1'b0, shift_reg[7:1]};
      DATA_8_BITS: data_out = shift_reg;
      default:     data_out = shift_reg;
    endcase
  end

endmodule
