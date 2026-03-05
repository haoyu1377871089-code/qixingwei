`include "qxw_defines.vh"

// EX/MEM/WB 三路旁路转发单元
// 优先级：EX > MEM > WB（最新值优先）
module qxw_forwarding (
    // EX 阶段源寄存器
    input  wire [`REG_ADDR_BUS] id_ex_rs1,
    input  wire [`REG_ADDR_BUS] id_ex_rs2,
    input  wire [`XLEN_BUS]     id_ex_rs1_data,
    input  wire [`XLEN_BUS]     id_ex_rs2_data,

    // EX/MEM 阶段结果
    input  wire [`REG_ADDR_BUS] ex_mem_rd,
    input  wire                 ex_mem_reg_we,
    input  wire [`XLEN_BUS]     ex_mem_alu_result,
    input  wire                 ex_mem_valid,

    // MEM/WB 阶段结果
    input  wire [`REG_ADDR_BUS] mem_wb_rd,
    input  wire                 mem_wb_reg_we,
    input  wire [`XLEN_BUS]     mem_wb_wd,      // 最终写回数据
    input  wire                 mem_wb_valid,

    // 转发后的操作数
    output reg  [`XLEN_BUS]     fwd_rs1_data,
    output reg  [`XLEN_BUS]     fwd_rs2_data,

    // 转发选择信号（供调试）
    output reg  [1:0]           fwd_sel_a,
    output reg  [1:0]           fwd_sel_b
);

    // fwd_sel: 00=无转发, 01=EX/MEM转发, 10=MEM/WB转发

    // RS1 转发
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

    // RS2 转发
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
