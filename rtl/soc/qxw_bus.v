`include "qxw_defines.vh"

// 简单地址译码总线
// 根据地址高位路由 CPU 数据端口到 DMEM / UART / Timer
// 指令端口直连 IMEM，不经过总线
module qxw_bus (
    // CPU 数据端口
    input  wire              cpu_dmem_en,
    input  wire [3:0]        cpu_dmem_we,
    input  wire [31:0]       cpu_dmem_addr,
    input  wire [31:0]       cpu_dmem_wdata,
    output reg  [31:0]       cpu_dmem_rdata,

    // ROM 数据读端口（访问 .rodata 等只读数据）
    input  wire [31:0]       rom_rdata,

    // 数据 RAM
    output wire              ram_en,
    output wire [3:0]        ram_we,
    output wire [31:0]       ram_addr,
    output wire [31:0]       ram_wdata,
    input  wire [31:0]       ram_rdata,

    // UART
    output wire              uart_en,
    output wire              uart_we,
    output wire [7:0]        uart_addr,
    output wire [31:0]       uart_wdata,
    input  wire [31:0]       uart_rdata,

    // Timer
    output wire              timer_en,
    output wire              timer_we,
    output wire [7:0]        timer_addr,
    output wire [31:0]       timer_wdata,
    input  wire [31:0]       timer_rdata
);

    // 地址译码
    wire sel_rom   = (cpu_dmem_addr[31:16] == 16'h0000);   // 0x0000_xxxx (ROM)
    wire sel_ram   = (cpu_dmem_addr[31:16] == 16'h0001);   // 0x0001_xxxx
    wire sel_uart  = (cpu_dmem_addr[31:8]  == 24'h100000); // 0x1000_00xx
    wire sel_timer = (cpu_dmem_addr[31:8]  == 24'h100010); // 0x1000_10xx

    // RAM
    assign ram_en    = cpu_dmem_en & sel_ram;
    assign ram_we    = sel_ram ? cpu_dmem_we : 4'd0;
    assign ram_addr  = cpu_dmem_addr;
    assign ram_wdata = cpu_dmem_wdata;

    // UART
    assign uart_en    = cpu_dmem_en & sel_uart;
    assign uart_we    = sel_uart & (|cpu_dmem_we);
    assign uart_addr  = cpu_dmem_addr[7:0];
    assign uart_wdata = cpu_dmem_wdata;

    // Timer
    assign timer_en    = cpu_dmem_en & sel_timer;
    assign timer_we    = sel_timer & (|cpu_dmem_we);
    assign timer_addr  = cpu_dmem_addr[7:0];
    assign timer_wdata = cpu_dmem_wdata;

    // 读数据多路选择
    always @(*) begin
        if (sel_rom)
            cpu_dmem_rdata = rom_rdata;
        else if (sel_ram)
            cpu_dmem_rdata = ram_rdata;
        else if (sel_uart)
            cpu_dmem_rdata = uart_rdata;
        else if (sel_timer)
            cpu_dmem_rdata = timer_rdata;
        else
            cpu_dmem_rdata = 32'd0;
    end

endmodule
