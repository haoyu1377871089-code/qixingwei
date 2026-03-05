`include "qxw_defines.vh"

// ================================================================
// 写回阶段（WB Stage）
// ================================================================
// 流水线最后一级，根据 wb_sel 从四种数据源中选择写回寄存器堆的值
// 纯组合逻辑选择 + 写使能门控，无级间寄存器
//
// 写回数据源：
//   WB_SEL_ALU：算术/逻辑运算结果（大部分 R 型和 I 型指令）
//   WB_SEL_MEM：Load 指令从内存读取的数据（经 MEM 阶段对齐和扩展）
//   WB_SEL_PC4：JAL/JALR 的链接地址（当前 PC + 4）
//   WB_SEL_CSR：CSR 的旧值（CSRRW/CSRRS/CSRRC 需要将旧值存入 rd）
// ================================================================
module qxw_wb_stage (
    // MEM/WB 级间寄存器输入
    input  wire [`XLEN_BUS]     mem_wb_pc,
    input  wire [`XLEN_BUS]     mem_wb_alu_result,
    input  wire [`XLEN_BUS]     mem_wb_mem_data,
    input  wire [`REG_ADDR_BUS] mem_wb_rd,
    input  wire                 mem_wb_reg_we,
    input  wire [`WB_SEL_BUS]   mem_wb_wb_sel,
    input  wire                 mem_wb_valid,

    // CSR 读取值（用于 WB_SEL_CSR）
    input  wire [`XLEN_BUS]     csr_rdata,

    // 写回寄存器堆信号
    output wire                 rf_we,
    output wire [`REG_ADDR_BUS] rf_wa,
    output reg  [`XLEN_BUS]     rf_wd
);

    // 写使能门控：仅在指令有效且译码时标记了 reg_we 时才写入寄存器堆
    assign rf_we = mem_wb_reg_we & mem_wb_valid;
    assign rf_wa = mem_wb_rd;

    // 写回数据四选一多路选择器（纯组合逻辑）
    always @(*) begin
        case (mem_wb_wb_sel)
            `WB_SEL_ALU: rf_wd = mem_wb_alu_result;
            `WB_SEL_MEM: rf_wd = mem_wb_mem_data;
            `WB_SEL_PC4: rf_wd = mem_wb_pc + 32'd4;
            `WB_SEL_CSR: rf_wd = csr_rdata;
            default:     rf_wd = mem_wb_alu_result;
        endcase
    end

endmodule
