package uart_defs;

  typedef enum logic [1:0] {
    DATA_5_BITS = 2'b00,
    DATA_6_BITS = 2'b01,
    DATA_7_BITS = 2'b10,
    DATA_8_BITS = 2'b11
  } data_size_e;

  typedef enum logic [1:0] {
    PARITY_NONE     = 2'b00,
    PARITY_RESERVED = 2'b01,
    PARITY_EVEN     = 2'b10,
    PARITY_ODD      = 2'b11
  } parity_ctrl_e;

  typedef enum logic {
    STOP_1_BIT  = 1'b0,
    STOP_2_BITS = 1'b1
  } stop_bits_e;

endpackage
