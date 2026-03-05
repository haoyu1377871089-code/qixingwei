// ================================================================
// UART 发送模块（仅 TX，用于调试输出）
// ================================================================
// 寄存器映射：
//   0x00: TX_DATA   -- 写入低 8 位触发一帧发送
//   0x04: TX_STATUS -- bit[0] = tx_busy（只读，发送中为 1）
//
// 帧格式：1 起始位 + 8 数据位 + 1 停止位，LSB 先发，无校验
// 波特率通过参数配置，BAUD_DIV = CLK_FREQ / BAUD_RATE
// SIMULATION 模式下跳过实际波特率延时，用 $write 直接打印字符
// ================================================================
module qxw_uart #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire        clk,
    input  wire        rst_n,

    // 总线接口
    input  wire        en,
    input  wire        we,
    input  wire [7:0]  addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,

    // 物理接口
    output reg         uart_tx
);

    // 波特率分频系数：每 BAUD_DIV 个时钟周期输出一个串行位
    // 例如 50MHz / 115200 ≈ 434，即每 434 个时钟周期发送一位
    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;

    reg [15:0] baud_cnt;    // 波特率计数器，计满 BAUD_DIV-1 时输出下一位
    reg [3:0]  bit_cnt;    // 位计数器，0~9 对应 start + 8 data + stop
    reg [9:0]  shift_reg;  // 发送移位寄存器：{stop, data[7:0], start}，右移 LSB 先发
    reg        tx_busy;    // 发送忙标志，软件轮询此位等待发送完成

    // 总线读
    always @(*) begin
        case (addr)
            8'h04:   rdata = {31'd0, tx_busy};
            default: rdata = 32'd0;
        endcase
    end

    // UART 发送状态机：空闲 -> 装载帧 -> 逐位发送 -> 发送完成 -> 空闲
    // 发送过程中 tx_busy=1，软件需轮询等待 busy=0 后才能发送下一字节
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_tx   <= 1'b1;
            tx_busy   <= 1'b0;
            baud_cnt  <= 16'd0;
            bit_cnt   <= 4'd0;
            shift_reg <= 10'h3FF;
        end else begin
`ifdef SIMULATION
            // SIMULATION 模式：跳过波特率延时，仅用 tx_busy 做单拍握手，实际输出由 $write 完成
            if (tx_busy) begin
                tx_busy <= 1'b0;
            end else if (en && we && addr == 8'h00) begin
                tx_busy <= 1'b1;
            end
`else
            // 正常模式：baud_cnt 计数到 BAUD_DIV-1 时输出一位，shift_reg 右移
            if (tx_busy) begin
                if (baud_cnt == BAUD_DIV - 1) begin
                    baud_cnt <= 16'd0;
                    uart_tx  <= shift_reg[0];           // LSB 先发（start 位）
                    shift_reg <= {1'b1, shift_reg[9:1]};  // 右移，高位补 1（空闲）
                    if (bit_cnt == 4'd9) begin
                        tx_busy <= 1'b0;
                        bit_cnt <= 4'd0;
                    end else begin
                        bit_cnt <= bit_cnt + 4'd1;
                    end
                end else begin
                    baud_cnt <= baud_cnt + 16'd1;
                end
            end else if (en && we && addr == 8'h00) begin
                // 装载帧：start=0, data[7:0], stop=1，共 10 位
                shift_reg <= {1'b1, wdata[7:0], 1'b0};
                tx_busy   <= 1'b1;
                baud_cnt  <= 16'd0;
                bit_cnt   <= 4'd0;
                uart_tx   <= 1'b1;
            end
`endif
        end
    end

    // 仿真辅助：打印发送的字符
    `ifdef SIMULATION
    always @(posedge clk) begin
        if (en && we && addr == 8'h00)
            $write("%c", wdata[7:0]);
    end
    `endif

endmodule
