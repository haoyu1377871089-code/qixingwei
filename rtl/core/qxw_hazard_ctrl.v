`include "qxw_defines.vh"

// ================================================================
// 冒险控制单元（Hazard Control Unit）
// ================================================================
// 集中管理五级流水线的所有冒险场景，生成 stall 和 flush 信号
//
// 冒险类型与处理策略：
//   1. Load-Use 数据冒险：EX 级的 Load 指令目标寄存器与 ID 级的源寄存器匹配
//      处理：stall IF/ID 一拍 + 在 EX 级插入气泡，等待 Load 数据从 MEM 返回
//   2. 分支误预测：EX 级分支判断结果与 IF 级预测不一致
//      处理：flush IF/ID 和 ID/EX，丢弃错误路径上的指令
//   3. MulDiv 忙：除法运算进行中（含启动首拍的 div_start_stall）
//      处理：stall 全流水线前三级（IF/ID/EX），保持指令不流动
//   4. Trap/MRET：异常进入或异常返回
//      处理：flush 前三级的级间寄存器，确保异常处理前清空流水线
// ================================================================
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

    // MulDiv 忙（含启动周期）
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

    // Load-Use 冒险检测：EX 级是 Load 指令且 rd 非零且与 ID 级的 rs1 或 rs2 匹配
    // rd=x0 排除：Load 到 x0 不产生有效数据，不构成冒险
    wire load_use_hazard = id_ex_mem_re & id_ex_valid & (id_ex_rd != 5'd0) &
                           ((id_ex_rd == id_rs1) | (id_ex_rd == id_rs2));

    // 统一 stall 源：Load-Use 和 MulDiv 忙均需暂停前端流水线
    wire pipeline_stall = load_use_hazard | md_busy;

    // stall_if/id 统一暂停前端：Load-Use 或 MulDiv 忙时均需冻结
    assign stall_if  = pipeline_stall;
    assign stall_id  = pipeline_stall;
    // stall_ex 仅在 MulDiv 忙时有效：Load-Use 时 EX 不需要 stall
    // 因为 EX 中的指令可以继续执行（它不依赖 Load 结果）
    assign stall_ex  = md_busy;
    // stall_mem 预留扩展用：当前无多周期访存，始终为 0
    assign stall_mem = 1'b0;

    // flush 信号：误预测和 trap/mret 均需冲刷已取的错误/无效指令
    // flush_ex_mem 仅 trap 时需要：防止触发异常的指令影响传入 MEM 级
    assign flush_if_id  = branch_mispredict | trap | mret;
    assign flush_id_ex  = branch_mispredict | load_use_hazard | trap | mret;
    assign flush_ex_mem = trap;

endmodule
