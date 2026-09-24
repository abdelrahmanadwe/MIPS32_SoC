import uart_defs::*;

module uart_rx (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  RX_IN,
  input  data_size_e            data_size_ctrl,
  input  parity_ctrl_e          parity_ctrl,
  input  stop_bits_e            stop_bits_ctrl,
  input  logic [15:0]           baud_div,

  output logic [7:0]            P_DATA,
  output logic                  Data_Valid,
  output logic                  parity_error,
  output logic                  framing_error
);

  // Interconnect signals
  logic        clk_en_16x;
  logic        rx_active;
  logic        sample_pulse;
  logic        rx_in_sampled;

  // Latched signals
  data_size_e   latched_data_size;
  parity_ctrl_e latched_parity_ctrl;
  stop_bits_e   latched_stop_bits;
  logic [15:0]  latched_baud_div;

  // Deserializer parallel data output before registration
  logic [7:0]   deserialized_data;

  baud_generator #(.OVERSAMPLING(16)) u_baud_generator (
    .clk            (clk),
    .rst_n          (rst_n),
    .baud_div       (latched_baud_div),
    .active         (rx_active),
    .baud_out       (clk_en_16x)
  );

  // Instantiate Deserializer Shift Register
  uart_rx_deserializer u_deserializer (
    .clk            (clk),
    .rst_n          (rst_n),
    .sample_pulse   (sample_pulse),
    .rx_in_sampled  (rx_in_sampled),
    .data_size_ctrl (latched_data_size),
    .data_out       (deserialized_data)
  );

  // Instantiate FSM Controller
  uart_rx_fsm u_fsm (
    .clk                 (clk),
    .rst_n               (rst_n),
    .RX_IN               (RX_IN),
    .clk_en_16x          (clk_en_16x),
    .data_size_ctrl      (data_size_ctrl),
    .parity_ctrl         (parity_ctrl),
    .stop_bits_ctrl      (stop_bits_ctrl),
    .baud_div            (baud_div),
    .deserialized_data   (deserialized_data),
    .sample_pulse        (sample_pulse),
    .rx_in_sampled       (rx_in_sampled),
    .rx_active           (rx_active),
    .P_DATA              (P_DATA),
    .Data_Valid          (Data_Valid),
    .parity_error        (parity_error),
    .framing_error       (framing_error),
    .latched_data_size   (latched_data_size),
    .latched_parity_ctrl (latched_parity_ctrl),
    .latched_stop_bits   (latched_stop_bits),
    .latched_baud_div    (latched_baud_div)
  );

endmodule
