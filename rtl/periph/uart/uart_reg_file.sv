import uart_defs::*;

module uart_reg_file (
  input logic                   PCLK,
  input logic                   PRESETn,
  input logic [4:0]             PADDR,
  input logic                   PSEL,
  input logic                   PENABLE,
  input logic                   PWRITE,
  input logic [31:0]            PWDATA,
  output logic [31:0]           PRDATA,
  output logic                  PREADY,
  output logic                  PSLVERR,

  // Hardware Status Inputs from RX/TX
  input logic                   tx_ready_hw,
  input logic                   tx_done_hw,
  input logic                   rx_valid_hw,
  input logic [7:0]             rx_data_hw,
  input logic                   rx_parity_error_hw,
  input logic                   rx_framing_error_hw,

  // Control Outputs to RX/TX
  output logic [7:0]            tx_data_hw,
  output logic                  tx_valid_hw,
  output logic [15:0]           baud_div,
  output logic                  tx_enable_ctrl,
  output logic                  rx_enable_ctrl,
  output data_size_e            data_size_ctrl,
  output parity_ctrl_e          parity_ctrl,
  output stop_bits_e            stop_bits_ctrl,

  // Interrupt Outputs (Masked)
  output logic                  irq_tx_ready,
  output logic                  irq_tx_done,
  output logic                  irq_rx_done,
  output logic                  irq_rx_parity,
  output logic                  irq_rx_framing,
  output logic                  irq_rx_overrun,
  output logic                  irq
);

  // APB Address Decodes (5-bit byte offset)
  localparam bit [4:0] ADDR_CFG       = 5'h00;
  localparam bit [4:0] ADDR_STATUS    = 5'h04; // Raw Status/Interrupt register (combines STATUS and RIS)
  localparam bit [4:0] ADDR_IER       = 5'h08; // Interrupt Enable Register
  localparam bit [4:0] ADDR_DATA      = 5'h0C; // Shared Transmit/Receive Data Register
  localparam bit [4:0] ADDR_BAUD_DIV  = 5'h10; // Shifted divisor register

  // Generate internal write/read strobe signals
  logic reg_write;
  logic reg_read;

  assign reg_write = PSEL && PENABLE && PWRITE;
  assign reg_read  = PSEL && PENABLE && !PWRITE;

  // Address validity check
  logic addr_valid;
  assign addr_valid = (PADDR == ADDR_CFG) ||
                       (PADDR == ADDR_STATUS) ||
                       (PADDR == ADDR_IER) ||
                       (PADDR == ADDR_DATA) ||
                       (PADDR == ADDR_BAUD_DIV);

  // Ready and Slave Error logic
  assign PREADY  = 1'b1; // Zero wait-states
  assign PSLVERR = PSEL && PENABLE && !addr_valid;

  // 1. Config Register (CFG)
  // [2:0]: Reserved/Unused
  // [4:3]: data_size_ctrl (Default: DATA_8_BITS = 2'b11)
  // [6:5]: parity_ctrl    (Default: PARITY_NONE = 2'b00)
  // [7]  : stop_bits_ctrl  (Default: STOP_1_BIT  = 1'b0)
  // [8]  : tx_enable_ctrl  (Default: 1'b0)
  // [9]  : rx_enable_ctrl  (Default: 1'b0)
  logic [9:0] cfg_reg;
  
  assign data_size_ctrl  = data_size_e'(cfg_reg[4:3]);
  assign parity_ctrl     = parity_ctrl_e'(cfg_reg[6:5]);
  assign stop_bits_ctrl  = stop_bits_e'(cfg_reg[7]);
  assign tx_enable_ctrl  = cfg_reg[8];
  assign rx_enable_ctrl  = cfg_reg[9];

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      cfg_reg <= 10'h18; // 8-bit, No Parity, 1 Stop, TX/RX Disabled
    end else if (reg_write && PADDR == ADDR_CFG) begin
      cfg_reg <= PWDATA[9:0];
    end
  end

  // 1b. Baud Divisor Register (BAUD_DIV)
  logic [15:0] baud_div_reg;
  assign baud_div = baud_div_reg;

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      baud_div_reg <= 16'd163; // Default 19.2K Baud under 50MHz
    end else if (reg_write && PADDR == ADDR_BAUD_DIV) begin
      baud_div_reg <= PWDATA[15:0];
    end
  end

  // TX buffer empty status for register interface (UDRE / transmit buffer empty)
  logic tx_pending;
  logic tx_ready_reg_file;
  assign tx_ready_reg_file = tx_ready_hw && !tx_pending;

  // 2. Status Register (STATUS) - Combines raw flags and status
  // [0]: tx_done (W1C)
  // [1]: parity_error (W1C)
  // [2]: framing_error (W1C)
  // [3]: rx_done (set on rx_valid_hw, cleared on RX_DATA read or W1C)
  // [4]: tx_ready (Level-sensitive, reflecting tx_ready_hw status)
  // [5]: overrun_error (set on overrun, cleared on RX_DATA read or W1C)
  logic [5:0] status_reg;
  logic [4:0] status_latched;

  assign status_reg[3:0] = status_latched[3:0];
  assign status_reg[4]   = tx_ready_reg_file;
  assign status_reg[5]   = status_latched[4];

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      status_latched <= 5'b00000;
    end else begin
      // Latch hardware events and handle W1C
      // Bit 0: TX Done
      if (tx_done_hw) begin
        status_latched[0] <= 1'b1;
      end else if (reg_write && PADDR == ADDR_STATUS && PWDATA[0]) begin
        status_latched[0] <= 1'b0;
      end

      // Bit 1: Parity Error
      if (rx_valid_hw && rx_parity_error_hw) begin
        status_latched[1] <= 1'b1;
      end else if (reg_write && PADDR == ADDR_STATUS && PWDATA[1]) begin
        status_latched[1] <= 1'b0;
      end

      // Bit 2: Framing Error
      if (rx_valid_hw && rx_framing_error_hw) begin
        status_latched[2] <= 1'b1;
      end else if (reg_write && PADDR == ADDR_STATUS && PWDATA[2]) begin
        status_latched[2] <= 1'b0;
      end

      // Bit 3: RX Done
      if (rx_valid_hw) begin
        status_latched[3] <= 1'b1;
      end else if ((reg_read && PADDR == ADDR_DATA) || (reg_write && PADDR == ADDR_STATUS && PWDATA[3])) begin
        status_latched[3] <= 1'b0;
      end

      // Bit 5: Overrun Error
      if (rx_valid_hw && status_reg[3] && !(reg_read && PADDR == ADDR_DATA)) begin
        status_latched[4] <= 1'b1;
      end else if ((reg_read && PADDR == ADDR_DATA) || (reg_write && PADDR == ADDR_STATUS && PWDATA[5])) begin
        status_latched[4] <= 1'b0;
      end
    end
  end

  // 3. Interrupt Enable Register (IER)
  // [0]: tx_done_ie
  // [1]: parity_error_ie
  // [2]: framing_error_ie
  // [3]: rx_done_ie
  // [4]: tx_ready_ie
  // [5]: overrun_error_ie
  logic [5:0] IER_reg;

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      IER_reg <= 6'b000000; // Disabled by default
    end else if (reg_write && PADDR == ADDR_IER) begin
      IER_reg <= PWDATA[5:0];
    end
  end

  // 4. Interrupt Mask Logic (Internal Wires for Outputs)
  logic [5:0] intr_mask_reg;
  assign intr_mask_reg = status_reg & IER_reg;

  // Interrupt Outputs to Top level
  assign irq_tx_ready    = intr_mask_reg[4];
  assign irq_tx_done     = intr_mask_reg[0];
  assign irq_rx_parity   = intr_mask_reg[1];
  assign irq_rx_framing  = intr_mask_reg[2];
  assign irq_rx_done     = intr_mask_reg[3];
  assign irq_rx_overrun  = intr_mask_reg[5];
  assign irq             = |intr_mask_reg;

  // 5. TX Data Register (TX_DATA)
  // Latches TX data and holds tx_valid_hw using a pending flag until accepted by hardware (tx_ready_hw goes low)
  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      tx_data_hw <= 8'h00;
      tx_pending <= 1'b0;
    end else begin
      if (reg_write && PADDR == ADDR_DATA && tx_ready_reg_file && tx_enable_ctrl) begin
        tx_data_hw <= PWDATA[7:0];
        tx_pending <= 1'b1;
      end else if (tx_pending && !tx_ready_hw) begin
        tx_pending <= 1'b0;
      end
    end
  end

  assign tx_valid_hw = tx_pending;

  // 6. RX Data Register (RX_DATA)
  // Latches rx_data_hw from receiver when valid is asserted
  logic [7:0] rx_data_reg;

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      rx_data_reg <= 8'h00;
    end else if (rx_valid_hw) begin
      rx_data_reg <= rx_data_hw;
    end
  end

  // Register File Read Bus
  always_comb begin
    case (PADDR)
      ADDR_CFG:       PRDATA = {22'b0, cfg_reg};
      ADDR_STATUS:    PRDATA = {26'b0, status_reg};
      ADDR_IER:       PRDATA = {26'b0, IER_reg};
      ADDR_DATA:      PRDATA = {24'b0, rx_data_reg};
      ADDR_BAUD_DIV:  PRDATA = {16'b0, baud_div_reg};
      default:        PRDATA = 32'b0;
    endcase
  end

endmodule
