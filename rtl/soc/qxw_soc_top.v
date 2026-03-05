`include "qxw_defines.vh"

// SoC 顶层：集成 CPU + 存储器 + 总线 + 外设
module qxw_soc_top #(
    parameter IMEM_INIT_FILE = "firmware.hex"
)(
    input  wire        clk,
    input  wire        rst_n,

    // 外部接口
    output wire        uart_tx,
    output wire [3:0]  led
);

    // ================================================================
    // CPU 接口信号
    // ================================================================
    wire [31:0] cpu_imem_addr;
    wire [31:0] cpu_imem_rdata;

    wire        cpu_dmem_en;
    wire [3:0]  cpu_dmem_we;
    wire [31:0] cpu_dmem_addr;
    wire [31:0] cpu_dmem_wdata;
    wire [31:0] cpu_dmem_rdata;

    wire        timer_irq;

    // ================================================================
    // 总线 -> 外设接口信号
    // ================================================================
    wire        ram_en;
    wire [3:0]  ram_we;
    wire [31:0] ram_addr;
    wire [31:0] ram_wdata;
    wire [31:0] ram_rdata;

    wire        uart_en;
    wire        uart_we_sig;
    wire [7:0]  uart_addr;
    wire [31:0] uart_wdata;
    wire [31:0] uart_rdata;

    wire        timer_en;
    wire        timer_we_sig;
    wire [7:0]  timer_addr;
    wire [31:0] timer_wdata;
    wire [31:0] timer_rdata;

    // ================================================================
    // CPU 核心
    // ================================================================
    qxw_cpu_top u_cpu (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (cpu_imem_addr),
        .imem_rdata (cpu_imem_rdata),
        .dmem_en    (cpu_dmem_en),
        .dmem_we    (cpu_dmem_we),
        .dmem_addr  (cpu_dmem_addr),
        .dmem_wdata (cpu_dmem_wdata),
        .dmem_rdata (cpu_dmem_rdata),
        .timer_irq  (timer_irq)
    );

    // ================================================================
    // 指令存储器（直连 CPU）
    // ================================================================
    qxw_imem #(
        .INIT_FILE(IMEM_INIT_FILE)
    ) u_imem (
        .clk  (clk),
        .addr (cpu_imem_addr),
        .rdata(cpu_imem_rdata)
    );

    // ================================================================
    // 总线
    // ================================================================
    qxw_bus u_bus (
        .cpu_dmem_en   (cpu_dmem_en),
        .cpu_dmem_we   (cpu_dmem_we),
        .cpu_dmem_addr (cpu_dmem_addr),
        .cpu_dmem_wdata(cpu_dmem_wdata),
        .cpu_dmem_rdata(cpu_dmem_rdata),
        .ram_en        (ram_en),
        .ram_we        (ram_we),
        .ram_addr      (ram_addr),
        .ram_wdata     (ram_wdata),
        .ram_rdata     (ram_rdata),
        .uart_en       (uart_en),
        .uart_we       (uart_we_sig),
        .uart_addr     (uart_addr),
        .uart_wdata    (uart_wdata),
        .uart_rdata    (uart_rdata),
        .timer_en      (timer_en),
        .timer_we      (timer_we_sig),
        .timer_addr    (timer_addr),
        .timer_wdata   (timer_wdata),
        .timer_rdata   (timer_rdata)
    );

    // ================================================================
    // 数据存储器
    // ================================================================
    qxw_dmem u_dmem (
        .clk  (clk),
        .en   (ram_en),
        .we   (ram_we),
        .addr (ram_addr),
        .wdata(ram_wdata),
        .rdata(ram_rdata)
    );

    // ================================================================
    // UART
    // ================================================================
    qxw_uart u_uart (
        .clk     (clk),
        .rst_n   (rst_n),
        .en      (uart_en),
        .we      (uart_we_sig),
        .addr    (uart_addr),
        .wdata   (uart_wdata),
        .rdata   (uart_rdata),
        .uart_tx (uart_tx)
    );

    // ================================================================
    // Timer
    // ================================================================
    qxw_timer u_timer (
        .clk       (clk),
        .rst_n     (rst_n),
        .en        (timer_en),
        .we        (timer_we_sig),
        .addr      (timer_addr),
        .wdata     (timer_wdata),
        .rdata     (timer_rdata),
        .timer_irq (timer_irq)
    );

    // ================================================================
    // LED: 数据 RAM 最后一个字映射到 LED
    // ================================================================
    reg [3:0] led_reg;
    assign led = led_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            led_reg <= 4'd0;
        else if (cpu_dmem_en && (|cpu_dmem_we) && cpu_dmem_addr == 32'h0001_3FFC)
            led_reg <= cpu_dmem_wdata[3:0];
    end

endmodule
