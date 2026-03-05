`include "qxw_defines.vh"

// ================================================================
// 通用寄存器堆（Register File）
// ================================================================
// 32 个 32 位寄存器（x0~x31），x0 硬连线为 0（读出始终为 0，写入忽略）
// 双读端口 + 单写端口，支持 ID 阶段同时读取两个源寄存器
// 写优先读（Write-First）：当同一周期对同一地址既写又读时，
// 读端口直接旁路写入数据，避免一拍延迟
// 这种设计消除了 WB->ID 的数据冒险（同周期写后读）
// ================================================================
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

    // 寄存器数组：索引从 1 开始，x0 不占存储空间
    reg [`XLEN_BUS] regs [1:`REG_NUM-1];

    // 写优先读：三路优先级选择 x0常量 > 写旁路 > 寄存器值
    assign rd1 = (ra1 == 5'd0) ? 32'd0 :
                 (we && wa == ra1) ? wd : regs[ra1];

    assign rd2 = (ra2 == 5'd0) ? 32'd0 :
                 (we && wa == ra2) ? wd : regs[ra2];

    // 同步写入：上升沿写入，异步复位清零所有寄存器
    // wa=x0 时忽略写入，防止意外修改硬连线零值
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
