import uart_defs::*;

module uart_tx_parity (
  input  logic [7:0]            data_in,
  input  data_size_e            data_size_ctrl,
  input  parity_ctrl_e          parity_ctrl,
  output logic                  par_bit
);

  logic active_data_xor;

  // XOR reduction of active data bits based on size
  always_comb begin
    case (data_size_ctrl)
      DATA_5_BITS: active_data_xor = ^data_in[4:0];
      DATA_6_BITS: active_data_xor = ^data_in[5:0];
      DATA_7_BITS: active_data_xor = ^data_in[6:0];
      DATA_8_BITS: active_data_xor = ^data_in[7:0];
      default:     active_data_xor = 1'b0;
    endcase
  end

  // Parity bit determination
  always_comb begin
    case (parity_ctrl)
      PARITY_ODD:  par_bit = ~active_data_xor; // Odd parity
      PARITY_EVEN: par_bit = active_data_xor;  // Even parity
      default:     par_bit = 1'b0;             // Default to 0 if disabled
    endcase
  end

endmodule
