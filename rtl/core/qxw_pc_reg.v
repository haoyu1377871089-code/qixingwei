`include "qxw_defines.vh"

// ================================================================
// 程序计数器寄存器（PC Register）
// ================================================================
// 维护当前指令地址，通过优先级链选择下一 PC 值
// 复位时 PC 初始化为 RST_PC（通常为 0x0000_0000）
// stall 信号冻结 PC 更新，用于 Load-Use 和 MulDiv 等待
//
// next_pc 优先级链设计考量：
//   trap 最高优先级：异常/中断必须立即响应，不可被预测或分支覆盖
//   mret 次高：异常返回需要恢复到 mepc，优先于分支恢复
//   flush（误预测恢复）高于 pred：确保正确的 PC 不被新的错误预测覆盖
//   pred_taken：正常取指时若 BPU 预测跳转则使用预测目标
//   PC+4：默认顺序执行
// ================================================================
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

    // 下一 PC 选择优先级链（高到低）：
    // 1. trap：异常/中断入口，跳转 mtvec
    // 2. mret：从异常返回，跳转 mepc
    // 3. flush：分支预测错误恢复，跳转正确目标
    // 4. pred_taken：BPU 预测跳转，使用预测目标
    // 5. 默认：顺序取指 PC+4
    assign next_pc = trap        ? trap_target  :
                     mret        ? mepc         :
                     flush       ? flush_target :
                     pred_taken  ? pred_target  :
                                   pc + 32'd4;

    // PC 寄存器更新逻辑
    // 异步低电平复位：PC 回到复位向量 RST_PC
    // stall 时保持当前 PC 不变，确保重发相同的取指请求
    // 正常情况下每拍更新为 next_pc 选择的值
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= `RST_PC;
        else if (!stall)
            pc <= next_pc;
    end

endmodule
