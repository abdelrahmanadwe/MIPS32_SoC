import uart_defs::*;

module uart_tx_fsm (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  clk_en,
  input  logic                  Data_Valid,
  input  logic [7:0]            P_DATA,
  input  data_size_e            data_size_ctrl,
  input  parity_ctrl_e          parity_ctrl,
  input  stop_bits_e            stop_bits_ctrl,
  input  logic [15:0]           baud_div,
  input  logic                  ser_done,

  output logic                  ready,
  output logic                  tx_done,
  output logic                  ser_en,
  output logic [2:0]            mux_sel,
  output logic                  tx_active,

  // Outputs to other blocks (latch registers)
  output logic [7:0]            latched_data,
  output data_size_e            latched_data_size,
  output parity_ctrl_e          latched_parity_ctrl,
  output stop_bits_e            latched_stop_bits,
  output logic [15:0]           latched_baud_div
);

  // FSM States
  typedef enum logic [2:0] {
    ST_IDLE   = 3'b000,
    ST_START  = 3'b001,
    ST_DATA   = 3'b010,
    ST_PARITY = 3'b011,
    ST_STOP   = 3'b100
  } state_e;

  state_e state, next_state;

  // Internal counters and flags
  logic stop_cnt; // 0 or 1 for stop bit duration
  logic is_last_stop_cycle;

  // MUX Select constants (align with top-level)
  localparam [2:0] MUX_SEL_IDLE   = 3'd0;
  localparam [2:0] MUX_SEL_START  = 3'd1;
  localparam [2:0] MUX_SEL_DATA   = 3'd2;
  localparam [2:0] MUX_SEL_PARITY = 3'd3;
  localparam [2:0] MUX_SEL_STOP   = 3'd4;

  // Determine if we are in the last cycle of the stop bit(s)
  always_comb begin
    if (latched_stop_bits == STOP_1_BIT) begin
      is_last_stop_cycle = 1'b1;
    end else begin
      is_last_stop_cycle = (stop_cnt == 1'b1);
    end
  end

  // Ready signal logic: we are ready in IDLE, or in the last STOP cycle
  always_comb begin
    if (state == ST_IDLE) begin
      ready = 1'b1;
    end else if (state == ST_STOP && is_last_stop_cycle) begin
      ready = 1'b1;
    end else begin
      ready = 1'b0;
    end
  end

  // FSM State Transitions
  always_comb begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (Data_Valid) begin
          next_state = ST_START;
        end else begin
          next_state = ST_IDLE;
        end
      end

      ST_START: begin
        if (clk_en) begin
          next_state = ST_DATA;
        end
      end

      ST_DATA: begin
        if (clk_en && ser_done) begin
          if (latched_parity_ctrl == PARITY_ODD || latched_parity_ctrl == PARITY_EVEN) begin
            next_state = ST_PARITY;
          end else begin
            next_state = ST_STOP;
          end
        end
      end

      ST_PARITY: begin
        if (clk_en) begin
          next_state = ST_STOP;
        end
      end

      ST_STOP: begin
        if (clk_en && is_last_stop_cycle) begin
          if (Data_Valid) begin
            next_state = ST_START; // Back-to-back transfer
          end else begin
            next_state = ST_IDLE;
          end
        end
      end

      default: next_state = ST_IDLE;
    endcase
  end

  // State register, counter, and outputs
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state                  <= ST_IDLE;
      stop_cnt               <= 1'b0;
      tx_done                <= 1'b0;
      latched_data           <= 8'b0;
      latched_data_size      <= DATA_8_BITS;
      latched_parity_ctrl    <= PARITY_NONE;
      latched_stop_bits      <= STOP_1_BIT;
      latched_baud_div       <= 16'd163;
    end else begin
      state <= next_state;

      // Handle tx_done generation (asserted for 1 cycle after stop state is finished)
      tx_done <= (state == ST_STOP && is_last_stop_cycle && clk_en);

      // Handle Latching of Data and Config
      if (Data_Valid & ready) begin
        latched_data           <= P_DATA;
        latched_data_size      <= data_size_ctrl;
        latched_parity_ctrl    <= parity_ctrl;
        latched_stop_bits      <= stop_bits_ctrl;
        latched_baud_div       <= baud_div;
      end

      // Stop Bit counter
      if (state != ST_STOP) begin
        stop_cnt <= 1'b0;
      end else if (clk_en) begin
        stop_cnt <= stop_cnt + 1'b1;
      end
    end
  end

  // FSM Control Signals for Other Blocks
  always_comb begin
    // Serializer enable is only high in DATA state
    ser_en = (state == ST_DATA);

    tx_active = (state != ST_IDLE);

    // MUX Selection logic
    case (state)
      ST_IDLE:   mux_sel = MUX_SEL_IDLE;
      ST_START:  mux_sel = MUX_SEL_START;
      ST_DATA:   mux_sel = MUX_SEL_DATA;
      ST_PARITY: mux_sel = MUX_SEL_PARITY;
      ST_STOP:   mux_sel = MUX_SEL_STOP;
      default:   mux_sel = MUX_SEL_IDLE;
    endcase
  end

endmodule
