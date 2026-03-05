`include "qxw_defines.vh"

// ================================================================
// 简单地址译码总线 —— BRAM 同步读适配版
// ================================================================
// 地址路由器，根据访存地址高位将 CPU 数据端口路由到从设备
// ROM/RAM 使用 BRAM 同步读，读数据延迟一拍，因此读数据 MUX
// 使用寄存后的片选信号（sel_*_r）来选择正确的数据源
//
// 地址映射：
//   0x0000_0000 ~ 0x0000_FFFF：ROM（IMEM 数据端口，只读）
//   0x0001_0000 ~ 0x0001_FFFF：RAM（DMEM，读写）
//   0x1000_0000 ~ 0x1000_00FF：UART 寄存器
//   0x1000_1000 ~ 0x1000_10FF：Timer 寄存器
// ================================================================
module qxw_bus (
    input  wire              clk,
    input  wire              rst_n,

    // CPU 数据端口
    input  wire              cpu_dmem_en,
    input  wire [3:0]        cpu_dmem_we,
    input  wire [31:0]       cpu_dmem_addr,
    input  wire [31:0]       cpu_dmem_wdata,
    output reg  [31:0]       cpu_dmem_rdata,

    // ROM 数据读端口
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

    wire sel_rom   = (cpu_dmem_addr[31:16] == 16'h0000);
    wire sel_ram   = (cpu_dmem_addr[31:16] == 16'h0001);
    wire sel_uart  = (cpu_dmem_addr[31:8]  == 24'h100000);
    wire sel_timer = (cpu_dmem_addr[31:8]  == 24'h100010);

    // 写路径：组合逻辑，不受同步读影响
    assign ram_en    = cpu_dmem_en & sel_ram;
    assign ram_we    = sel_ram ? cpu_dmem_we : 4'd0;
    assign ram_addr  = cpu_dmem_addr;
    assign ram_wdata = cpu_dmem_wdata;

    assign uart_en    = cpu_dmem_en & sel_uart;
    assign uart_we    = sel_uart & (|cpu_dmem_we);
    assign uart_addr  = cpu_dmem_addr[7:0];
    assign uart_wdata = cpu_dmem_wdata;

    assign timer_en    = cpu_dmem_en & sel_timer;
    assign timer_we    = sel_timer & (|cpu_dmem_we);
    assign timer_addr  = cpu_dmem_addr[7:0];
    assign timer_wdata = cpu_dmem_wdata;

    // 读路径：ROM/RAM 使用 BRAM 同步读，数据延迟一拍
    // 片选信号寄存一拍，与 BRAM 输出对齐
    // UART/Timer 为组合读，也寄存一拍保持对齐
    reg sel_rom_r, sel_ram_r, sel_uart_r, sel_timer_r;
    reg [31:0] uart_rdata_r, timer_rdata_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sel_rom_r    <= 1'b0;
            sel_ram_r    <= 1'b0;
            sel_uart_r   <= 1'b0;
            sel_timer_r  <= 1'b0;
            uart_rdata_r <= 32'd0;
            timer_rdata_r<= 32'd0;
        end else begin
            sel_rom_r    <= sel_rom;
            sel_ram_r    <= sel_ram;
            sel_uart_r   <= sel_uart;
            sel_timer_r  <= sel_timer;
            uart_rdata_r <= uart_rdata;
            timer_rdata_r<= timer_rdata;
        end
    end

    always @(*) begin
        if (sel_rom_r)
            cpu_dmem_rdata = rom_rdata;
        else if (sel_ram_r)
            cpu_dmem_rdata = ram_rdata;
        else if (sel_uart_r)
            cpu_dmem_rdata = uart_rdata_r;
        else if (sel_timer_r)
            cpu_dmem_rdata = timer_rdata_r;
        else
            cpu_dmem_rdata = 32'd0;
    end

endmodule
