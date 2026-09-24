import uart_defs::*;

module uart_rx_fsm (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  RX_IN,
  input  logic                  clk_en_16x,
  input  data_size_e            data_size_ctrl,
  input  parity_ctrl_e          parity_ctrl,
  input  stop_bits_e            stop_bits_ctrl,
  input  logic [15:0]           baud_div,
  input  logic [7:0]            deserialized_data,


  output logic                  sample_pulse,
  output logic                  rx_in_sampled,
  output logic                  rx_active,

  output logic [7:0]            P_DATA,
  output logic                  Data_Valid,
  output logic                  parity_error,
  output logic                  framing_error,

  // Latched configs for deserializer/parity
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
    ST_STOP   = 3'b100,
    ST_DONE   = 3'b101
  } state_e;

  state_e state, next_state;

  // 3-Stage Synchronizer to prevent metastability
  logic rx_sync_0, rx_sync_1, rx_sync_2;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_sync_0 <= 1'b1;
      rx_sync_1 <= 1'b1;
      rx_sync_2 <= 1'b1;
    end else begin
      rx_sync_0 <= RX_IN;
      rx_sync_1 <= rx_sync_0;
      rx_sync_2 <= rx_sync_1;
    end
  end

  // Detect falling edge of RX_IN
  logic rx_fall_edge;
  assign rx_fall_edge = (rx_sync_2 == 1'b1 && rx_sync_1 == 1'b0);

  // Internal counters
  logic [3:0] tick_cnt;
  logic [2:0] bit_cnt;
  logic       stop_bit_done_cnt;

  // Latch registers
  data_size_e   latched_data_size_reg;
  parity_ctrl_e latched_parity_ctrl_reg;
  stop_bits_e   latched_stop_bits_reg;
  logic [15:0]  latched_baud_div_reg;

  assign latched_data_size   = latched_data_size_reg;
  assign latched_parity_ctrl = latched_parity_ctrl_reg;
  assign latched_stop_bits   = latched_stop_bits_reg;
  assign latched_baud_div    = latched_baud_div_reg;

  // Sample logic
  assign rx_in_sampled = rx_sync_1;

  // Determine last data bit count based on config
  logic [2:0] max_bit_cnt;
  always_comb begin
    case (latched_data_size_reg)
      DATA_5_BITS: max_bit_cnt = 3'd4;
      DATA_6_BITS: max_bit_cnt = 3'd5;
      DATA_7_BITS: max_bit_cnt = 3'd6;
      DATA_8_BITS: max_bit_cnt = 3'd7;
      default:     max_bit_cnt = 3'd7;
    endcase
  end

  // Parity computation
  logic calculated_parity;
  logic expected_parity;
  always_comb begin
    logic [7:0] mask;
    logic [7:0] masked_data;
    case (latched_data_size_reg)
      DATA_5_BITS: mask = 8'h1F;
      DATA_6_BITS: mask = 8'h3F;
      DATA_7_BITS: mask = 8'h7F;
      DATA_8_BITS: mask = 8'hFF;
      default:     mask = 8'hFF;
    endcase
    masked_data = deserialized_data & mask;
    calculated_parity = ^masked_data;
    expected_parity = (latched_parity_ctrl_reg == PARITY_ODD) ? ~calculated_parity : calculated_parity;
  end

  // rx_active logic: run baud generator when not IDLE
  assign rx_active = (state != ST_IDLE);

  // FSM Next State Logic
  always_comb begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (rx_fall_edge) begin
          next_state = ST_START;
        end
      end

      ST_START: begin
        if (clk_en_16x && tick_cnt == 4'd7) begin
          if (rx_sync_1 == 1'b0) begin
            next_state = ST_DATA;
          end else begin
            next_state = ST_IDLE; // False start, return to IDLE
          end
        end
      end

      ST_DATA: begin
        if (clk_en_16x && tick_cnt == 4'd15) begin
          if (bit_cnt == max_bit_cnt) begin
            if (latched_parity_ctrl_reg == PARITY_ODD || latched_parity_ctrl_reg == PARITY_EVEN) begin
              next_state = ST_PARITY;
            end else begin
              next_state = ST_STOP;
            end
          end
        end
      end

      ST_PARITY: begin
        if (clk_en_16x && tick_cnt == 4'd15) begin
          next_state = ST_STOP;
        end
      end

      ST_STOP: begin
        if (clk_en_16x && tick_cnt == 4'd15) begin
          if (latched_stop_bits_reg == STOP_2_BITS && stop_bit_done_cnt == 1'b0) begin
            next_state = ST_STOP;
          end else begin
            next_state = ST_DONE;
          end
        end
      end

      ST_DONE: begin
        next_state = ST_IDLE;
      end

      default: next_state = ST_IDLE;
    endcase
  end

  // FSM Sequential Logic
  logic parity_err_detected;
  logic framing_err_detected;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state                 <= ST_IDLE;
      tick_cnt              <= 4'd0;
      bit_cnt               <= 3'd0;
      stop_bit_done_cnt     <= 1'b0;
      sample_pulse          <= 1'b0;
      P_DATA                <= 8'b0;
      Data_Valid            <= 1'b0;
      parity_error          <= 1'b0;
      framing_error         <= 1'b0;
      parity_err_detected   <= 1'b0;
      framing_err_detected  <= 1'b0;
      latched_data_size_reg   <= DATA_8_BITS;
      latched_parity_ctrl_reg <= PARITY_NONE;
      latched_stop_bits_reg   <= STOP_1_BIT;
      latched_baud_div_reg    <= 16'd163;
    end else begin
      state <= next_state;
      
      // Default sample pulse
      sample_pulse <= 1'b0;

      // Handle config latching on starting falling edge
      if (state == ST_IDLE && rx_fall_edge) begin
        latched_data_size_reg   <= data_size_ctrl;
        latched_parity_ctrl_reg <= parity_ctrl;
        latched_stop_bits_reg   <= stop_bits_ctrl;
        latched_baud_div_reg    <= baud_div;
        parity_err_detected     <= 1'b0;
        framing_err_detected    <= 1'b0;
      end

      // Counters and state actions
      case (state)
        ST_IDLE: begin
          tick_cnt          <= 4'd0;
          bit_cnt           <= 3'd0;
          stop_bit_done_cnt <= 1'b0;
          Data_Valid        <= 1'b0;
          parity_error      <= 1'b0;
          framing_error     <= 1'b0;
        end

        ST_START: begin
          if (clk_en_16x) begin
            if (tick_cnt == 4'd7) begin
              tick_cnt <= 4'd0; // Reset for data sampling
            end else begin
              tick_cnt <= tick_cnt + 4'd1;
            end
          end
        end

        ST_DATA: begin
          if (clk_en_16x) begin
            if (tick_cnt == 4'd15) begin
              tick_cnt     <= 4'd0;
              sample_pulse <= 1'b1;
              bit_cnt      <= bit_cnt + 3'd1;
            end else begin
              tick_cnt <= tick_cnt + 4'd1;
            end
          end
        end

        ST_PARITY: begin
          if (clk_en_16x) begin
            if (tick_cnt == 4'd15) begin
              tick_cnt <= 4'd0;
              // Check parity
              if (rx_sync_1 !== expected_parity) begin
                parity_err_detected <= 1'b1;
              end
            end else begin
              tick_cnt <= tick_cnt + 4'd1;
            end
          end
        end

        ST_STOP: begin
          if (clk_en_16x) begin
            if (tick_cnt == 4'd15) begin
              tick_cnt <= 4'd0;
              // Check stop bit
              if (rx_sync_1 !== 1'b1) begin
                framing_err_detected <= 1'b1;
                if (!(latched_stop_bits_reg == STOP_2_BITS && stop_bit_done_cnt == 1'b0)) begin
                  framing_error <= 1'b1;
                end
              end
              
              if (latched_stop_bits_reg == STOP_2_BITS && stop_bit_done_cnt == 1'b0) begin
                stop_bit_done_cnt <= 1'b1;
              end
            end else begin
              tick_cnt <= tick_cnt + 4'd1;
            end
          end
        end

        ST_DONE: begin
          P_DATA        <= deserialized_data;
          Data_Valid    <= 1'b1;
          parity_error  <= parity_err_detected;
          framing_error <= framing_err_detected;
        end
      endcase
    end
  end



endmodule
