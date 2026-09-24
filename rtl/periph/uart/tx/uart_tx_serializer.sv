import uart_defs::*;

module uart_tx_serializer (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic [7:0]            data_in,
  input  data_size_e            data_size_ctrl,
  input  logic                  ser_en,
  input  logic                  clk_en,
  output logic                  ser_data,
  output logic                  ser_done
);

  logic [7:0] shift_reg;
  logic [2:0] bit_cnt;

  // Serial output is the LSB of the shift register
  assign ser_data = shift_reg[0];

  // Done signal when the last bit is being transmitted
  always_comb begin
    ser_done = 1'b0;
    case (data_size_ctrl)
      DATA_5_BITS: ser_done = (bit_cnt == 3'd4);
      DATA_6_BITS: ser_done = (bit_cnt == 3'd5);
      DATA_7_BITS: ser_done = (bit_cnt == 3'd6);
      DATA_8_BITS: ser_done = (bit_cnt == 3'd7);
      default:     ser_done = 1'b0;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      shift_reg <= 8'b0;
      bit_cnt   <= 3'b0;
    end else begin
      if (!ser_en) begin
        // Keep loading the input data and reset counter when not enabled
        shift_reg <= data_in;
        bit_cnt   <= 3'b0;
      end else if (clk_en) begin
        // Shift right (LSB first) and increment bit counter
        shift_reg <= {1'b0, shift_reg[7:1]};
        bit_cnt   <= bit_cnt + 1'b1;
      end
    end
  end

endmodule
