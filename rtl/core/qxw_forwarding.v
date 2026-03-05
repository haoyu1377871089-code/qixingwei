`include "qxw_defines.vh"

// ================================================================
// 数据转发单元（Forwarding Unit）
// ================================================================
// 解决 RAW（Read-After-Write）数据冒险，避免因流水线寄存器延迟导致读到旧值
// 
// 转发路径与优先级（高到低）：
//   1. EX/MEM 转发：上一条指令的 ALU 结果（1 周期前写入），延迟最短
//   2. MEM/WB 转发：上上条指令的最终写回值（2 周期前写入），包含 Load 数据
//   3. 无转发：使用 ID/EX 寄存器中的原始寄存器值
//
// 转发条件：目标寄存器非 x0 且地址匹配且写使能有效且指令有效
// x0 排除是因为 x0 硬连线为 0，任何"写入 x0"都不应被转发
// ================================================================
module qxw_forwarding (
    // EX 阶段的源寄存器地址和原始数据（来自 ID/EX 级间寄存器）
    input  wire [`REG_ADDR_BUS] id_ex_rs1,
    input  wire [`REG_ADDR_BUS] id_ex_rs2,
    input  wire [`XLEN_BUS]     id_ex_rs1_data,
    input  wire [`XLEN_BUS]     id_ex_rs2_data,

    // EX/MEM 阶段的写回信息（1 周期前的指令）
    // alu_result 可直接转发，因为 ALU 结果在 EX 级已确定
    input  wire [`REG_ADDR_BUS] ex_mem_rd,
    input  wire                 ex_mem_reg_we,
    input  wire [`XLEN_BUS]     ex_mem_alu_result,
    input  wire                 ex_mem_valid,

    // MEM/WB 阶段的写回信息（2 周期前的指令）
    // mem_wb_wd 是 WB 阶段最终选择的数据，包含 Load/CSR 等非 ALU 结果
    input  wire [`REG_ADDR_BUS] mem_wb_rd,
    input  wire                 mem_wb_reg_we,
    input  wire [`XLEN_BUS]     mem_wb_wd,
    input  wire                 mem_wb_valid,

    // 转发后的操作数
    output reg  [`XLEN_BUS]     fwd_rs1_data,
    output reg  [`XLEN_BUS]     fwd_rs2_data,

    // 转发选择信号（供调试）
    output reg  [1:0]           fwd_sel_a,
    output reg  [1:0]           fwd_sel_b
);

    // fwd_sel 编码：00=无转发（使用原始值），01=EX/MEM 转发，10=MEM/WB 转发
    // fwd_sel 信号仅供调试观测，不参与功能逻辑

    // RS1 转发逻辑：检查 EX/MEM 和 MEM/WB 两级是否有对 rs1 的写入
    always @(*) begin
        if (ex_mem_reg_we && ex_mem_valid && ex_mem_rd != 5'd0 && ex_mem_rd == id_ex_rs1) begin
            fwd_rs1_data = ex_mem_alu_result;
            fwd_sel_a    = 2'b01;
        end else if (mem_wb_reg_we && mem_wb_valid && mem_wb_rd != 5'd0 && mem_wb_rd == id_ex_rs1) begin
            fwd_rs1_data = mem_wb_wd;
            fwd_sel_a    = 2'b10;
        end else begin
            fwd_rs1_data = id_ex_rs1_data;
            fwd_sel_a    = 2'b00;
        end
    end

    // RS2 转发逻辑：与 RS1 完全对称，独立判断
    // RS1 和 RS2 可能同时被不同级别转发（如 rs1 来自 EX/MEM，rs2 来自 MEM/WB）
    always @(*) begin
        if (ex_mem_reg_we && ex_mem_valid && ex_mem_rd != 5'd0 && ex_mem_rd == id_ex_rs2) begin
            fwd_rs2_data = ex_mem_alu_result;
            fwd_sel_b    = 2'b01;
        end else if (mem_wb_reg_we && mem_wb_valid && mem_wb_rd != 5'd0 && mem_wb_rd == id_ex_rs2) begin
            fwd_rs2_data = mem_wb_wd;
            fwd_sel_b    = 2'b10;
        end else begin
            fwd_rs2_data = id_ex_rs2_data;
            fwd_sel_b    = 2'b00;
        end
    end

endmodule
