// =============================================================================
// MIPS_SoC.v
// Top-Level System-on-Chip (SoC) Architecture
// Integrates:
//   - 5-Stage Pipelined MIPS Core (with Dynamic Branch Predictor & CP0)
//   - AHB-Lite Bus Decoder & Master Adapter
//   - AHB-Lite Data Memory (RAM) Slave (4-bank BRAM with byte-enables)
//   - AHB-Lite GPIO Peripheral (cmsdk_ahb_gpio)
//   - AHB-to-APB Subsystem Bridge (ahb_to_apb)
//   - APB Timer Peripheral (cmsdk_apb_timer)
//   - APB UART Peripheral (Custom Configurable UART with UVM verification)
//   - AHB-Lite Default Slave
//   - AHB-Lite Slave Multiplexer
//   - Bidirectional IO Pad Buffers (JB pin-io, Switch, LEDs)
// =============================================================================

module MIPS_SoC #(
    parameter IM_START_ADDR = 32'h0000_0000,
    parameter IM_END_ADDR   = 32'h0000_0FFF,
    parameter DM_START_ADDR = 32'h0000_0000,
    parameter DM_END_ADDR   = 32'h0000_7FFF,
    parameter FAST_TIMER    = 0
)(
    input  wire        CLK_PAD,
    input  wire        RST_PAD,
    inout  wire [6:0]  PAD,
    output wire        UART_TX,
    input  wire        UART_RX,
    output wire [15:0] TestValue,
    input  wire        ext_interrupt
);

    // =========================================================================
    // 1. Core Memory Interface Wires & Interrupts
    // =========================================================================
    wire [31:0] core_mem_addr;
    wire [31:0] core_mem_wdata;
    wire        core_mem_write;
    wire        core_mem_read;
    wire [1:0]  core_mem_size;
    wire        core_mem_unsigned;
    wire [31:0] hrdata_mux;

    wire        gpio_int;
    wire        tim_int;
    wire        uart_int;

    // Combine GPIO interrupt, Timer interrupt, UART interrupt, and external interrupt into CP0
    wire effective_interrupt = gpio_int | tim_int | uart_int | ext_interrupt;

    // =========================================================================
    // 2. MIPS Pipelined Processor Core Instance
    // =========================================================================
    Pipelined_MIPS_Microprocessor #(
        .IM_START_ADDR(IM_START_ADDR),
        .IM_END_ADDR(IM_END_ADDR)
    ) core (
        .clock(CLK_PAD),
        .reset(RST_PAD),
        .hardware_interrupt(effective_interrupt),

        .MemAddrM(core_mem_addr),
        .MemWriteDataM(core_mem_wdata),
        .MemWriteM_out(core_mem_write),
        .MemReadM_out(core_mem_read),
        .MemSizeM_out(core_mem_size),
        .MemUnsignedM_out(core_mem_unsigned),

        .MemReadDataW(hrdata_mux)
    );

    // =========================================================================
    // 3. AHB Bus Signals
    // =========================================================================
    wire [31:0] haddr_bus;
    wire [31:0] hwdata_bus;
    wire        hwrite_bus;
    wire [2:0]  hsize_bus;
    wire [1:0]  htrans_bus;
    wire        huser_bus;
    wire        hready_bus;

    wire        hsel_dm;
    wire        hsel_gpio;
    wire        hsel_apb;
    wire        hsel_def;

    // =========================================================================
    // 4. AHB Decoder Instance
    // =========================================================================
    ahb_decoder u_ahb_decoder (
        .HCLK(CLK_PAD),
        .HRESETn(RST_PAD),

        .MemAddrM(core_mem_addr),
        .MemWriteDataM(core_mem_wdata),
        .MemWriteM(core_mem_write),
        .MemReadM(core_mem_read),
        .MemSizeM(core_mem_size),
        .MemUnsignedM(core_mem_unsigned),

        .HREADY(hready_bus),

        .HADDR(haddr_bus),
        .HWDATA(hwdata_bus),
        .HWRITE(hwrite_bus),
        .HSIZE(hsize_bus),
        .HTRANS(htrans_bus),
        .HUSER(huser_bus),

        .HSEL_DM(hsel_dm),
        .HSEL_GPIO(hsel_gpio),
        .HSEL_APB(hsel_apb),
        .HSEL_DEF(hsel_def)
    );

    // =========================================================================
    // 5. AHB Data Memory (RAM) Slave Instance
    // =========================================================================
    wire [31:0] hrdata_dm;
    wire        hreadyout_dm;
    wire        hresp_dm;

    Data_Memory #(
        .START_ADDR(DM_START_ADDR),
        .END_ADDR(DM_END_ADDR)
    ) u_data_memory (
        .HCLK(CLK_PAD),
        .HRESETn(RST_PAD),
        .HSEL(hsel_dm),
        .HREADY(hready_bus),
        .HTRANS(htrans_bus),
        .HSIZE(hsize_bus),
        .HWRITE(hwrite_bus),
        .HADDR(haddr_bus),
        .HWDATA(hwdata_bus),
        .HUSER(huser_bus),

        .HREADYOUT(hreadyout_dm),
        .HRESP(hresp_dm),
        .HRDATA(hrdata_dm),
        .TestValue(TestValue)
    );

    // =========================================================================
    // 6. AHB GPIO Peripheral Instance (cmsdk_ahb_gpio)
    // =========================================================================
    wire [31:0] hrdata_gpio;
    wire        hreadyout_gpio;
    wire        hresp_gpio;
    wire [15:0] portout_gpio;
    wire [15:0] porten_gpio;
    wire [15:0] portin_gpio;

    cmsdk_ahb_gpio #(
        .PORTWIDTH(16),
        .ALTERNATE_FUNC_MASK(16'h0000),
        .ALTERNATE_FUNC_DEFAULT(16'h0000)
    ) u_gpio (
        .HCLK(CLK_PAD),
        .HRESETn(RST_PAD),
        .FCLK(CLK_PAD),
        .HSEL(hsel_gpio),
        .HREADY(hready_bus),
        .HTRANS(htrans_bus),
        .HSIZE(hsize_bus),
        .HWRITE(hwrite_bus),
        .HADDR(haddr_bus[11:0]),
        .HWDATA(hwdata_bus),
        .ECOREVNUM(4'b0000),
        .PORTIN(portin_gpio),

        .HREADYOUT(hreadyout_gpio),
        .HRESP(hresp_gpio),
        .HRDATA(hrdata_gpio),

        .PORTOUT(portout_gpio),
        .PORTEN(porten_gpio),
        .PORTFUNC(),
        .ALT_FUNC(),
        .GPIOINT(),
        .COMBINT(gpio_int)
    );

    // =========================================================================
    // 7. AHB-to-APB Subsystem Bridge Instance
    // =========================================================================
    wire [31:0] hrdata_apb;
    wire        hreadyout_apb;
    wire        hresp_apb;

    // APB wires for Timer
    wire        psel_timer;
    wire        penable_timer;
    wire        pwrite_timer;
    wire [11:2] paddr_timer;
    wire [31:0] pwdata_timer;
    wire [31:0] prdata_timer;
    wire        pready_timer;
    wire        pslverr_timer;

    // APB wires for UART
    wire        psel_uart;
    wire        penable_uart;
    wire        pwrite_uart;
    wire [4:0]  paddr_uart;
    wire [31:0] pwdata_uart;
    wire [31:0] prdata_uart;
    wire        pready_uart;
    wire        pslverr_uart;

    ahb_to_apb u_ahb_to_apb (
        .HCLK(CLK_PAD),
        .HRESETn(RST_PAD),
        .HSEL(hsel_apb),
        .HREADY(hready_bus),
        .HTRANS(htrans_bus),
        .HSIZE(hsize_bus),
        .HWRITE(hwrite_bus),
        .HADDR(haddr_bus),
        .HWDATA(hwdata_bus),

        .HREADYOUT(hreadyout_apb),
        .HRESP(hresp_apb),
        .HRDATA(hrdata_apb),

        // Timer APB Interface
        .PSEL_TIMER(psel_timer),
        .PENABLE_TIMER(penable_timer),
        .PWRITE_TIMER(pwrite_timer),
        .PADDR_TIMER(paddr_timer),
        .PWDATA_TIMER(pwdata_timer),
        .PRDATA_TIMER(prdata_timer),
        .PREADY_TIMER(pready_timer),
        .PSLVERR_TIMER(pslverr_timer),

        // UART APB Interface
        .PSEL_UART(psel_uart),
        .PENABLE_UART(penable_uart),
        .PWRITE_UART(pwrite_uart),
        .PADDR_UART(paddr_uart),
        .PWDATA_UART(pwdata_uart),
        .PRDATA_UART(prdata_uart),
        .PREADY_UART(pready_uart),
        .PSLVERR_UART(pslverr_uart)
    );

    // =========================================================================
    // 8. APB Timer Peripheral Instance (cmsdk_apb_timer)
    // =========================================================================
    wire timer_ext_in;

    cmsdk_apb_timer #(
        .FAST_TIMER(FAST_TIMER)
    ) u_timer (
        .PCLK(CLK_PAD),
        .PCLKG(CLK_PAD),
        .PRESETn(RST_PAD),

        .PSEL(psel_timer),
        .PADDR(paddr_timer),
        .PENABLE(penable_timer),
        .PWRITE(pwrite_timer),
        .PWDATA(pwdata_timer),

        .ECOREVNUM(4'b0000),

        .PRDATA(prdata_timer),
        .PREADY(pready_timer),
        .PSLVERR(pslverr_timer),

        .EXTIN(timer_ext_in),
        .TIMERINT(tim_int)
    );

    // =========================================================================
    // 9. APB UART Peripheral Instance (Custom Configurable UART)
    // =========================================================================
    wire uart_tx_serial;
    wire uart_rx_serial;

    // Export dedicated UART TX port
    assign UART_TX = uart_tx_serial;

    // UART RX reception:
    // Receives externally either from dedicated UART_RX pin or from PAD[1].
    // If UART_RX pin is driven, prioritize it; otherwise read from PAD[1].
    // When floating/unconnected, defaults to idle high (1'b1).
    wire pad1_rx = (PAD[1] === 1'bz || PAD[1] === 1'bx) ? 1'b1 : PAD[1];
    assign uart_rx_serial = (UART_RX !== 1'bz && UART_RX !== 1'bx) ? UART_RX : pad1_rx;

    UART u_uart (
        .PCLK(CLK_PAD),
        .PRESETn(RST_PAD),
        .PADDR(paddr_uart),
        .PSEL(psel_uart),
        .PENABLE(penable_uart),
        .PWRITE(pwrite_uart),
        .PWDATA(pwdata_uart),
        .PREADY(pready_uart),
        .PRDATA(prdata_uart),
        .PSLVERR(pslverr_uart),

        .tx_serial(uart_tx_serial),
        .rx_serial(uart_rx_serial),

        .irq_tx_ready(),
        .irq_tx_done(),
        .irq_rx_done(),
        .irq_rx_parity(),
        .irq_rx_framing(),
        .irq_rx_overrun(),
        .irq(uart_int)
    );

    // =========================================================================
    // 10. AHB Default Slave Instance
    // =========================================================================
    wire [31:0] hrdata_def;
    wire        hreadyout_def;
    wire        hresp_def;

    ahb_default_slave u_def_slave (
        .HCLK(CLK_PAD),
        .HRESETn(RST_PAD),
        .HSEL(hsel_def),
        .HREADY(hready_bus),
        .HTRANS(htrans_bus),
        .HSIZE(hsize_bus),
        .HWRITE(hwrite_bus),
        .HADDR(haddr_bus),
        .HWDATA(hwdata_bus),

        .HREADYOUT(hreadyout_def),
        .HRESP(hresp_def),
        .HRDATA(hrdata_def)
    );

    // =========================================================================
    // 11. AHB Slave Multiplexer Instance
    // =========================================================================
    ahb_slave_mux u_slave_mux (
        .HCLK(CLK_PAD),
        .HRESETn(RST_PAD),

        .HSEL_DM(hsel_dm),
        .HSEL_GPIO(hsel_gpio),
        .HSEL_APB(hsel_apb),
        .HSEL_DEF(hsel_def),

        .HRDATA_DM(hrdata_dm),
        .HREADYOUT_DM(hreadyout_dm),
        .HRESP_DM(hresp_dm),

        .HRDATA_GPIO(hrdata_gpio),
        .HREADYOUT_GPIO(hreadyout_gpio),
        .HRESP_GPIO(hresp_gpio),

        .HRDATA_APB(hrdata_apb),
        .HREADYOUT_APB(hreadyout_apb),
        .HRESP_APB(hresp_apb),

        .HRDATA_DEF(hrdata_def),
        .HREADYOUT_DEF(hreadyout_def),
        .HRESP_DEF(hresp_def),

        .HRDATA(hrdata_mux),
        .HREADY(hready_bus),
        .HRESP()
    );

    // =========================================================================
    // 12. PAD Buffers & Interfacing
    // =========================================================================
    // PAD[0]: JB pin-io (outputs uart_tx_serial or gpio_out)
    assign PAD[0] = porten_gpio[0] ? portout_gpio[0] : uart_tx_serial;
    assign portin_gpio[0] = (PAD[0] === 1'bz) ? 1'b0 : PAD[0];

    // PAD[1]: JB pin-io (bidirectional)
    assign PAD[1] = porten_gpio[1] ? portout_gpio[1] : 1'bz;
    assign portin_gpio[1] = (PAD[1] === 1'bz) ? 1'b0 : PAD[1];

    // PAD[2]: Switch (input connected to GPIO[2] and Timer EXTIN)
    assign PAD[2] = porten_gpio[2] ? portout_gpio[2] : 1'bz;
    assign portin_gpio[2] = (PAD[2] === 1'bz) ? 1'b0 : PAD[2];
    assign timer_ext_in   = (PAD[2] === 1'bz) ? 1'b0 : PAD[2];

    // PAD[3]: LED (output)
    assign PAD[3] = portout_gpio[3];
    assign portin_gpio[3] = portout_gpio[3];

    // PAD[4]: LED (output)
    assign PAD[4] = portout_gpio[4];
    assign portin_gpio[4] = portout_gpio[4];

    // PAD[5]: LED (output)
    assign PAD[5] = portout_gpio[5];
    assign portin_gpio[5] = portout_gpio[5];

    // PAD[6]: LED (output)
    assign PAD[6] = portout_gpio[6];
    assign portin_gpio[6] = portout_gpio[6];

    // Upper bits not bonded to PADs
    assign portin_gpio[15:7] = 9'b0;

endmodule
