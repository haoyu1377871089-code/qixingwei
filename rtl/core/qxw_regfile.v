`include "qxw_defines.vh"

// 32x32-bit 寄存器堆，双读单写，x0 硬连线为 0
// 写优先：同周期写读同一寄存器时直接转发写入值
module qxw_regfile (
    input  wire                    clk,
    input  wire                    rst_n,

    // 读端口 1
    input  wire [`REG_ADDR_BUS]    ra1,
    output wire [`XLEN_BUS]        rd1,

    // 读端口 2
    input  wire [`REG_ADDR_BUS]    ra2,
    output wire [`XLEN_BUS]        rd2,

    // 写端口
    input  wire                    we,
    input  wire [`REG_ADDR_BUS]    wa,
    input  wire [`XLEN_BUS]        wd
);

    reg [`XLEN_BUS] regs [1:`REG_NUM-1];

    // 写优先读逻辑
    assign rd1 = (ra1 == 5'd0) ? 32'd0 :
                 (we && wa == ra1) ? wd : regs[ra1];

    assign rd2 = (ra2 == 5'd0) ? 32'd0 :
                 (we && wa == ra2) ? wd : regs[ra2];

    // 同步写
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 1; i < `REG_NUM; i = i + 1)
                regs[i] <= 32'd0;
        end else if (we && wa != 5'd0) begin
            regs[wa] <= wd;
        end
    end

endmodule
