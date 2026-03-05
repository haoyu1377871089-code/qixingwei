`include "qxw_defines.vh"

// PC 寄存器：管理程序计数器与下一 PC 选择
module qxw_pc_reg (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              stall,          // 流水线暂停
    input  wire              branch_taken,   // 分支/跳转实际发生
    input  wire [`XLEN_BUS]  branch_target,  // 分支/跳转目标地址
    input  wire              pred_taken,     // BPU 预测跳转
    input  wire [`XLEN_BUS]  pred_target,    // BPU 预测目标
    input  wire              flush,          // 冲刷（预测错误）
    input  wire [`XLEN_BUS]  flush_target,   // 冲刷后恢复的 PC
    input  wire              trap,           // 异常/中断
    input  wire [`XLEN_BUS]  trap_target,    // mtvec
    input  wire              mret,           // MRET
    input  wire [`XLEN_BUS]  mepc,           // mepc 返回地址

    output reg  [`XLEN_BUS]  pc,
    output wire [`XLEN_BUS]  next_pc
);

    // 下一 PC 优先级：trap > mret > flush > pred_taken > PC+4
    assign next_pc = trap        ? trap_target  :
                     mret        ? mepc         :
                     flush       ? flush_target :
                     pred_taken  ? pred_target  :
                                   pc + 32'd4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= `RST_PC;
        else if (!stall)
            pc <= next_pc;
    end

endmodule
