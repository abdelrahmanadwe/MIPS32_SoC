import uart_defs::*;

module uart_tx (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic [7:0]            P_DATA,
  input  logic                  Data_Valid,
  input  data_size_e            data_size_ctrl,
  input  parity_ctrl_e          parity_ctrl,
  input  stop_bits_e            stop_bits_ctrl,
  input  logic [15:0]           baud_div,

  output logic                  TX_OUT,
  output logic                  ready,
  output logic                  tx_done
);

  // Interconnect signals
  logic        clk_en; // Internal clock enable from baud generator
  logic        ser_en;
  logic        ser_done;
  logic        ser_data;
  logic        par_bit;
  logic [2:0]  mux_sel;
  logic        tx_active;

  logic [7:0]   latched_data;
  data_size_e   latched_data_size;
  parity_ctrl_e latched_parity_ctrl;
  stop_bits_e   latched_stop_bits;
  logic [15:0]  latched_baud_div;

  // MUX selection localparams
  localparam [2:0] MUX_SEL_IDLE   = 3'd0;
  localparam [2:0] MUX_SEL_START  = 3'd1;
  localparam [2:0] MUX_SEL_DATA   = 3'd2;
  localparam [2:0] MUX_SEL_PARITY = 3'd3;
  localparam [2:0] MUX_SEL_STOP   = 3'd4;

  baud_generator #(.OVERSAMPLING(1)) u_baud_generator (
    .clk            (clk),
    .rst_n          (rst_n),
    .baud_div       (latched_baud_div),
    .active         (tx_active),
    .baud_out       (clk_en)
  );

  // Instantiate FSM Controller
  uart_tx_fsm u_fsm (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .clk_en                 (clk_en),
    .Data_Valid             (Data_Valid),
    .P_DATA                 (P_DATA),
    .data_size_ctrl         (data_size_ctrl),
    .parity_ctrl            (parity_ctrl),
    .stop_bits_ctrl         (stop_bits_ctrl),
    .baud_div               (baud_div),
    .ser_done               (ser_done),
    .ready                  (ready),
    .tx_done                (tx_done),
    .ser_en                 (ser_en),
    .mux_sel                (mux_sel),
    .tx_active              (tx_active),
    .latched_data           (latched_data),
    .latched_data_size      (latched_data_size),
    .latched_parity_ctrl    (latched_parity_ctrl),
    .latched_stop_bits      (latched_stop_bits),
    .latched_baud_div       (latched_baud_div)
  );

  // Instantiate Serializer
  uart_tx_serializer u_serializer (
    .clk            (clk),
    .rst_n          (rst_n),
    .data_in        (latched_data),
    .data_size_ctrl (latched_data_size),
    .ser_en         (ser_en),
    .clk_en         (clk_en),
    .ser_data       (ser_data),
    .ser_done       (ser_done)
  );

  // Instantiate Parity Calculator
  uart_tx_parity u_parity (
    .data_in        (latched_data),
    .data_size_ctrl (latched_data_size),
    .parity_ctrl    (latched_parity_ctrl),
    .par_bit        (par_bit)
  );

  // Output MUX Logic
  always_comb begin
    case (mux_sel)
      MUX_SEL_IDLE:   TX_OUT = 1'b1; // Idle line is 1
      MUX_SEL_START:  TX_OUT = 1'b0; // Start bit is 0
      MUX_SEL_DATA:   TX_OUT = ser_data;
      MUX_SEL_PARITY: TX_OUT = par_bit;
      MUX_SEL_STOP:   TX_OUT = 1'b1; // Stop bit is 1
      default:        TX_OUT = 1'b1;
    endcase
  end

endmodule
