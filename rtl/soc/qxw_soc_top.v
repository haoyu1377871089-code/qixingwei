`include "qxw_defines.vh"

// ================================================================
// SoC 顶层模块
// ================================================================
// 集成 RV32IM CPU 核心、指令/数据存储器、总线和外设
// 系统架构：哈佛结构（指令和数据端口分离）
//   CPU 指令端口 -> IMEM（直连，组合读）
//   CPU 数据端口 -> 总线 -> RAM / UART / Timer / ROM数据端口
// 外部接口：uart_tx 串行输出、led[3:0] 指示灯
// IMEM_INIT_FILE 参数指定固件 hex 文件路径
// ================================================================
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
    // CPU 与总线之间的接口信号
    // ================================================================
    // imem 接口：指令端口，直连 IMEM，不经过总线（哈佛架构）
    // dmem 接口：数据端口，经总线路由到 RAM/UART/Timer/ROM
    wire [31:0] cpu_imem_addr;
    wire        cpu_imem_en;
    wire [31:0] cpu_imem_rdata;

    wire        cpu_dmem_en;
    wire [3:0]  cpu_dmem_we;
    wire [31:0] cpu_dmem_addr;
    wire [31:0] cpu_dmem_wdata;
    wire [31:0] cpu_dmem_rdata;

    wire        timer_irq;

    // ================================================================
    // 总线到各从设备的接口信号
    // ================================================================
    // 每个从设备有独立的 en/we/addr/wdata/rdata 信号
    // 总线根据地址高位选择激活哪个从设备
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
        .imem_en    (cpu_imem_en),
        .imem_rdata (cpu_imem_rdata),
        .dmem_en    (cpu_dmem_en),
        .dmem_we    (cpu_dmem_we),
        .dmem_addr  (cpu_dmem_addr),
        .dmem_wdata (cpu_dmem_wdata),
        .dmem_rdata (cpu_dmem_rdata),
        .timer_irq  (timer_irq)
    );

    // ================================================================
    // 指令存储器
    // ================================================================
    // 双端口设计：指令端口由 CPU 的 PC 直连，数据端口经总线访问
    // 数据端口用于读取存放在代码段中的只读数据（如字符串常量、查找表）
    wire [31:0] imem_drdata;

    qxw_imem #(
        .INIT_FILE(IMEM_INIT_FILE)
    ) u_imem (
        .clk   (clk),
        .en    (cpu_imem_en),
        .addr  (cpu_imem_addr),
        .rdata (cpu_imem_rdata),
        .daddr (cpu_dmem_addr),
        .drdata(imem_drdata)
    );

    // ================================================================
    // 总线
    // ================================================================
    qxw_bus u_bus (
        .clk           (clk),
        .rst_n         (rst_n),
        .cpu_dmem_en   (cpu_dmem_en),
        .cpu_dmem_we   (cpu_dmem_we),
        .cpu_dmem_addr (cpu_dmem_addr),
        .cpu_dmem_wdata(cpu_dmem_wdata),
        .cpu_dmem_rdata(cpu_dmem_rdata),
        .rom_rdata     (imem_drdata),
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
    // LED 输出：将数据 RAM 地址空间末尾的特定地址映射为 LED 控制
    // 软件写入 0x0001_3FFC 的低 4 位直接驱动 LED
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
