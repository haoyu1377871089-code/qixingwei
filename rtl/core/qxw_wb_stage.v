`include "qxw_defines.vh"

// 写回阶段：结果选择与寄存器写回
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

    assign rf_we = mem_wb_reg_we & mem_wb_valid;
    assign rf_wa = mem_wb_rd;

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
