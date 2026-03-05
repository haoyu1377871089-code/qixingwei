// 简化 UART 发送模块（调试用）
// 寄存器映射：
//   0x00: TX_DATA  -- 写入触发发送（低8位）
//   0x04: TX_STATUS -- [0] tx_busy (只读)
// 可配置波特率，默认 115200 @ 50MHz
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

    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;

    reg [15:0] baud_cnt;
    reg [3:0]  bit_cnt;
    reg [9:0]  shift_reg;  // {stop, data[7:0], start}
    reg        tx_busy;

    // 总线读
    always @(*) begin
        case (addr)
            8'h04:   rdata = {31'd0, tx_busy};
            default: rdata = 32'd0;
        endcase
    end

    // 发送状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_tx   <= 1'b1;  // idle = high
            tx_busy   <= 1'b0;
            baud_cnt  <= 16'd0;
            bit_cnt   <= 4'd0;
            shift_reg <= 10'h3FF;
        end else if (tx_busy) begin
            if (baud_cnt == BAUD_DIV - 1) begin
                baud_cnt <= 16'd0;
                uart_tx  <= shift_reg[0];
                shift_reg <= {1'b1, shift_reg[9:1]};
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
            // 写 TX_DATA: 启动发送
            shift_reg <= {1'b1, wdata[7:0], 1'b0};  // stop + data + start
            tx_busy   <= 1'b1;
            baud_cnt  <= 16'd0;
            bit_cnt   <= 4'd0;
            uart_tx   <= 1'b1;
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
