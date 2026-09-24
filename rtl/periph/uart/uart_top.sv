import uart_defs::*;

module uart_top (
  input  logic                  clk,
  input  logic                  rst_n,

  // TX parallel interface
  input  logic [7:0]            tx_data,
  input  logic                  tx_valid,
  output logic                  tx_ready,
  output logic                  tx_done,

  // RX parallel interface
  output logic [7:0]            rx_data,
  output logic                  rx_valid,
  output logic                  rx_parity_error,
  output logic                  rx_framing_error,

  input  data_size_e            data_size_ctrl,
  input  parity_ctrl_e          parity_ctrl,
  input  stop_bits_e            stop_bits_ctrl,
  input  logic [15:0]           baud_div,

  // Serial interface
  output logic                  tx_serial,
  input  logic                  rx_serial
);

  // Instantiate UART Transmitter
  uart_tx u_tx (
    .clk            (clk),
    .rst_n          (rst_n),
    .P_DATA         (tx_data),
    .Data_Valid     (tx_valid),
    .data_size_ctrl (data_size_ctrl),
    .parity_ctrl    (parity_ctrl),
    .stop_bits_ctrl (stop_bits_ctrl),
    .baud_div       (baud_div),
    .TX_OUT         (tx_serial),
    .ready          (tx_ready),
    .tx_done        (tx_done)
  );

  // Instantiate UART Receiver
  uart_rx u_rx (
    .clk            (clk),
    .rst_n          (rst_n),
    .RX_IN          (rx_serial),
    .data_size_ctrl (data_size_ctrl),
    .parity_ctrl    (parity_ctrl),
    .stop_bits_ctrl (stop_bits_ctrl),
    .baud_div       (baud_div),
    .P_DATA         (rx_data),
    .Data_Valid     (rx_valid),
    .parity_error   (rx_parity_error),
    .framing_error  (rx_framing_error)
  );

endmodule
