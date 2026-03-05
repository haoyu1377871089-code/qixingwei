`include "qxw_defines.vh"

// 冒险控制单元：
// 1. Load-Use 检测 -> stall IF/ID + bubble EX
// 2. 分支预测错误 -> flush IF/ID
// 3. MulDiv busy -> stall 全流水线
// 4. ECALL/MRET -> flush
module qxw_hazard_ctrl (
    // ID 阶段寄存器地址（来自 IF/ID 级间寄存器中的指令）
    input  wire [`REG_ADDR_BUS] id_rs1,
    input  wire [`REG_ADDR_BUS] id_rs2,

    // EX 阶段 Load 信息
    input  wire [`REG_ADDR_BUS] id_ex_rd,
    input  wire                 id_ex_mem_re,
    input  wire                 id_ex_valid,

    // 分支预测错误
    input  wire                 branch_mispredict,

    // MulDiv 忙
    input  wire                 md_busy,

    // 异常
    input  wire                 trap,
    input  wire                 mret,

    // 控制输出
    output wire                 stall_if,
    output wire                 stall_id,
    output wire                 stall_ex,
    output wire                 stall_mem,
    output wire                 flush_if_id,
    output wire                 flush_id_ex,
    output wire                 flush_ex_mem
);

    // Load-Use 冒险检测
    wire load_use_hazard = id_ex_mem_re & id_ex_valid & (id_ex_rd != 5'd0) &
                           ((id_ex_rd == id_rs1) | (id_ex_rd == id_rs2));

    // stall 信号
    wire pipeline_stall = load_use_hazard | md_busy;

    assign stall_if  = pipeline_stall;
    assign stall_id  = pipeline_stall;
    assign stall_ex  = md_busy;         // 只在 muldiv busy 时 stall EX
    assign stall_mem = 1'b0;

    // flush 信号
    assign flush_if_id  = branch_mispredict | trap | mret;
    assign flush_id_ex  = branch_mispredict | load_use_hazard | trap | mret;
    assign flush_ex_mem = trap;

endmodule
