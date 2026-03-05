// ================================================================
// 64 位定时器（RISC-V Machine Timer）
// ================================================================
// 符合 RISC-V 特权规范的 Machine Timer 实现
// mtime 每周期自增 1，当 mtime >= mtimecmp 时产生 timer_irq
// 软件通过设置 mtimecmp 来控制下一次中断时机
// 清除中断的方法：将 mtimecmp 设置为大于当前 mtime 的值
//
// 寄存器映射（32 位访问，64 位寄存器分高低半）：
//   0x00: mtime[31:0]      (R/W)
//   0x04: mtime[63:32]     (R/W)
//   0x08: mtimecmp[31:0]   (R/W)
//   0x0C: mtimecmp[63:32]  (R/W)
// mtimecmp 初始值为全 1，确保复位后不会立即触发中断
// ================================================================
module qxw_timer (
    input  wire        clk,
    input  wire        rst_n,

    // 总线接口
    input  wire        en,
    input  wire        we,
    input  wire [7:0]  addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,

    // 中断输出
    output wire        timer_irq
);

    reg [63:0] mtime;       // 自由运行计数器，每周期加 1
    reg [63:0] mtimecmp;    // 中断比较值，mtime >= mtimecmp 时触发中断

    // 中断条件：无符号 64 位比较，持续电平输出
    // 软件通过写 mtimecmp > mtime 来清除中断
    assign timer_irq = (mtime >= mtimecmp);

    // 总线读
    always @(*) begin
        case (addr)
            8'h00:   rdata = mtime[31:0];
            8'h04:   rdata = mtime[63:32];
            8'h08:   rdata = mtimecmp[31:0];
            8'h0C:   rdata = mtimecmp[63:32];
            default: rdata = 32'd0;
        endcase
    end

    // mtime 自增与总线写入逻辑
    // mtime 每周期无条件递增，总线写入可覆盖 mtime 和 mtimecmp 的值
    // 注意：同一周期内先递增再判断总线写入，总线写入会覆盖递增结果
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime    <= 64'd0;
            mtimecmp <= 64'hFFFF_FFFF_FFFF_FFFF;  // 默认不触发
        end else begin
            mtime <= mtime + 64'd1;

            if (en && we) begin
                case (addr)
                    8'h00: mtime[31:0]     <= wdata;
                    8'h04: mtime[63:32]    <= wdata;
                    8'h08: mtimecmp[31:0]  <= wdata;
                    8'h0C: mtimecmp[63:32] <= wdata;
                    default: ;
                endcase
            end
        end
    end

endmodule
