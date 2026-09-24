import uart_defs::*;

module UART (
  // APB Bus Interface
  input  logic                  PCLK,
  input  logic                  PRESETn,
  input  logic [4:0]            PADDR,
  input  logic                  PSEL,
  input  logic                  PENABLE,
  input  logic                  PWRITE,
  input  logic [31:0]           PWDATA,
  output logic                  PREADY,
  output logic [31:0]           PRDATA,
  output logic                  PSLVERR,

  // Serial interface
  output logic                  tx_serial,
  input  logic                  rx_serial,

  // Interrupt Outputs (Masked)
  output logic                  irq_tx_ready,
  output logic                  irq_tx_done,
  output logic                  irq_rx_done,
  output logic                  irq_rx_parity,
  output logic                  irq_rx_framing,
  output logic                  irq_rx_overrun,
  output logic                  irq
);

  // Internal wires connecting Register File to UART Core
  logic [7:0]   tx_data_hw;
  logic         tx_valid_hw;
  logic         tx_ready_hw;
  logic         tx_done_hw;

  logic [7:0]   rx_data_hw;
  logic         rx_valid_hw;
  logic         rx_parity_error_hw;
  logic         rx_framing_error_hw;

  data_size_e   data_size_ctrl;
  parity_ctrl_e parity_ctrl;
  stop_bits_e   stop_bits_ctrl;
  logic [15:0]  baud_div;
  logic         tx_enable_ctrl;
  logic         rx_enable_ctrl;

  // Gated core interfaces based on enable signals
  logic         tx_valid_gated;
  logic         rx_serial_gated;

  assign tx_valid_gated  = tx_valid_hw && tx_enable_ctrl;
  assign rx_serial_gated = rx_enable_ctrl ? rx_serial : 1'b1;

  // Instantiate Register File (CSRs with APB bus interface)
  uart_reg_file u_reg_file (
    .PCLK                 (PCLK),
    .PRESETn              (PRESETn),
    .PADDR                (PADDR),
    .PSEL                 (PSEL),
    .PENABLE              (PENABLE),
    .PWRITE               (PWRITE),
    .PWDATA               (PWDATA),
    .PREADY               (PREADY),
    .PRDATA               (PRDATA),
    .PSLVERR              (PSLVERR),
    .tx_ready_hw          (tx_ready_hw),
    .tx_done_hw           (tx_done_hw),
    .rx_data_hw           (rx_data_hw),
    .rx_valid_hw          (rx_valid_hw),
    .rx_parity_error_hw   (rx_parity_error_hw),
    .rx_framing_error_hw  (rx_framing_error_hw),
    .tx_data_hw           (tx_data_hw),
    .tx_valid_hw          (tx_valid_hw),
    .data_size_ctrl       (data_size_ctrl),
    .parity_ctrl          (parity_ctrl),
    .stop_bits_ctrl       (stop_bits_ctrl),
    .baud_div             (baud_div),
    .tx_enable_ctrl       (tx_enable_ctrl),
    .rx_enable_ctrl       (rx_enable_ctrl),
    .irq_tx_ready         (irq_tx_ready),
    .irq_tx_done          (irq_tx_done),
    .irq_rx_done          (irq_rx_done),
    .irq_rx_parity        (irq_rx_parity),
    .irq_rx_framing       (irq_rx_framing),
    .irq_rx_overrun       (irq_rx_overrun),
    .irq                  (irq)
  );

  // Instantiate UART Core (TX + RX)
  uart_top u_core (
    .clk                  (PCLK),
    .rst_n                (PRESETn),
    .tx_data              (tx_data_hw),
    .tx_valid             (tx_valid_gated),
    .tx_ready             (tx_ready_hw),
    .tx_done              (tx_done_hw),
    .rx_data              (rx_data_hw),
    .rx_valid             (rx_valid_hw),
    .rx_parity_error      (rx_parity_error_hw),
    .rx_framing_error     (rx_framing_error_hw),
    .data_size_ctrl       (data_size_ctrl),
    .parity_ctrl          (parity_ctrl),
    .stop_bits_ctrl       (stop_bits_ctrl),
    .baud_div             (baud_div),
    .tx_serial            (tx_serial),
    .rx_serial            (rx_serial_gated)
  );

endmodule
