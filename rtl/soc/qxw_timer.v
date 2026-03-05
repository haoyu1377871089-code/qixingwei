// 64-bit 定时器（RISC-V Machine Timer）
// 寄存器映射：
//   0x00: mtime_lo      (R/W)
//   0x04: mtime_hi      (R/W)
//   0x08: mtimecmp_lo   (R/W)
//   0x0C: mtimecmp_hi   (R/W)
// 当 mtime >= mtimecmp 时产生中断
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

    reg [63:0] mtime;
    reg [63:0] mtimecmp;

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

    // mtime 自增 + 总线写
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
