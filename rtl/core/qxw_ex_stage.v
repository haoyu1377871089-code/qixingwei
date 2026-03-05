`include "qxw_defines.vh"

// 执行阶段：ALU 运算 + 分支判断 + 地址计算
// 接收转发后的操作数，输出 EX/MEM 级间寄存器信号
module qxw_ex_stage (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              stall,
    input  wire              flush,

    // ID/EX 级间寄存器输入
    input  wire [`XLEN_BUS]  id_ex_pc,
    input  wire [`XLEN_BUS]  id_ex_rs1_data,
    input  wire [`XLEN_BUS]  id_ex_rs2_data,
    input  wire [`XLEN_BUS]  id_ex_imm,
    input  wire [`REG_ADDR_BUS] id_ex_rd,
    input  wire [`REG_ADDR_BUS] id_ex_rs1,
    input  wire [`REG_ADDR_BUS] id_ex_rs2,
    input  wire [`ALU_OP_BUS]   id_ex_alu_op,
    input  wire              id_ex_alu_src_a,
    input  wire              id_ex_alu_src_b,
    input  wire              id_ex_reg_we,
    input  wire              id_ex_mem_re,
    input  wire              id_ex_mem_we,
    input  wire [2:0]        id_ex_funct3,
    input  wire [`WB_SEL_BUS]   id_ex_wb_sel,
    input  wire [`BR_TYPE_BUS]  id_ex_br_type,
    input  wire              id_ex_is_jalr,
    input  wire              id_ex_is_muldiv,
    input  wire [`MD_OP_BUS]    id_ex_md_op,
    input  wire              id_ex_csr_we,
    input  wire [2:0]        id_ex_csr_op,
    input  wire [11:0]       id_ex_csr_addr,
    input  wire              id_ex_ecall,
    input  wire              id_ex_ebreak,
    input  wire              id_ex_mret,
    input  wire              id_ex_pred_taken,
    input  wire [`XLEN_BUS]  id_ex_pred_target,
    input  wire              id_ex_valid,

    // 转发后的操作数
    input  wire [`XLEN_BUS]  fwd_rs1_data,
    input  wire [`XLEN_BUS]  fwd_rs2_data,

    // ALU 接口
    output wire [`ALU_OP_BUS]  alu_op,
    output wire [`XLEN_BUS]    alu_op_a,
    output wire [`XLEN_BUS]    alu_op_b,
    input  wire [`XLEN_BUS]    alu_result,

    // MulDiv 接口
    output wire              md_start,
    output wire [`MD_OP_BUS] md_op,
    output wire [`XLEN_BUS]  md_op_a,
    output wire [`XLEN_BUS]  md_op_b,
    input  wire [`XLEN_BUS]  md_result,
    input  wire              md_busy,
    input  wire              md_valid,

    // 分支结果
    output wire              branch_taken,
    output wire [`XLEN_BUS]  branch_target,
    output wire              branch_mispredict,

    // EX/MEM 级间寄存器输出
    output reg  [`XLEN_BUS]  ex_mem_pc,
    output reg  [`XLEN_BUS]  ex_mem_alu_result,
    output reg  [`XLEN_BUS]  ex_mem_rs2_data,
    output reg  [`REG_ADDR_BUS] ex_mem_rd,
    output reg               ex_mem_reg_we,
    output reg               ex_mem_mem_re,
    output reg               ex_mem_mem_we,
    output reg  [2:0]        ex_mem_funct3,
    output reg  [`WB_SEL_BUS]   ex_mem_wb_sel,
    output reg               ex_mem_csr_we,
    output reg  [2:0]        ex_mem_csr_op,
    output reg  [11:0]       ex_mem_csr_addr,
    output reg  [`XLEN_BUS]  ex_mem_csr_wdata,
    output reg               ex_mem_valid
);

    // ================================================================
    // ALU 操作数选择
    // ================================================================
    assign alu_op   = id_ex_alu_op;
    assign alu_op_a = id_ex_alu_src_a ? id_ex_pc       : fwd_rs1_data;
    assign alu_op_b = id_ex_alu_src_b ? id_ex_imm      : fwd_rs2_data;

    // ================================================================
    // MulDiv 接口
    // ================================================================
    assign md_start = id_ex_is_muldiv & id_ex_valid & !md_busy;
    assign md_op    = id_ex_md_op;
    assign md_op_a  = fwd_rs1_data;
    assign md_op_b  = fwd_rs2_data;

    // 执行结果选择
    wire [`XLEN_BUS] ex_result = id_ex_is_muldiv ? md_result : alu_result;

    // ================================================================
    // 分支判断
    // ================================================================
    wire br_eq  = (fwd_rs1_data == fwd_rs2_data);
    wire br_lt  = ($signed(fwd_rs1_data) < $signed(fwd_rs2_data));
    wire br_ltu = (fwd_rs1_data < fwd_rs2_data);

    reg  br_cond;
    always @(*) begin
        case (id_ex_br_type)
            `BR_BEQ:  br_cond = br_eq;
            `BR_BNE:  br_cond = !br_eq;
            `BR_BLT:  br_cond = br_lt;
            `BR_BGE:  br_cond = !br_lt;
            `BR_BLTU: br_cond = br_ltu;
            `BR_BGEU: br_cond = !br_ltu;
            `BR_JAL:  br_cond = 1'b1;
            default:  br_cond = 1'b0;
        endcase
    end

    wire is_branch = (id_ex_br_type != `BR_NONE) & id_ex_valid;

    assign branch_taken  = is_branch & br_cond;
    assign branch_target = id_ex_is_jalr ?
                           (fwd_rs1_data + id_ex_imm) & 32'hFFFF_FFFE :
                           id_ex_pc + id_ex_imm;

    // 预测错误检测
    assign branch_mispredict = id_ex_valid & (
        (is_branch & br_cond & !id_ex_pred_taken) |
        (is_branch & br_cond & id_ex_pred_taken & (branch_target != id_ex_pred_target)) |
        (is_branch & !br_cond & id_ex_pred_taken) |
        (id_ex_is_jalr)  // JALR 总是需要冲刷（无法静态预测）
    );

    // CSR 写入数据准备
    wire [`XLEN_BUS] csr_wdata_src = (id_ex_csr_op[2]) ?
                                     {27'd0, id_ex_rs1} :  // CSRRWI/CSRRSI/CSRRCI: zimm
                                     fwd_rs1_data;          // CSRRW/CSRRS/CSRRC: rs1

    // ================================================================
    // EX/MEM 级间寄存器
    // ================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            ex_mem_pc         <= 32'd0;
            ex_mem_alu_result <= 32'd0;
            ex_mem_rs2_data   <= 32'd0;
            ex_mem_rd         <= 5'd0;
            ex_mem_reg_we     <= 1'b0;
            ex_mem_mem_re     <= 1'b0;
            ex_mem_mem_we     <= 1'b0;
            ex_mem_funct3     <= 3'd0;
            ex_mem_wb_sel     <= `WB_SEL_ALU;
            ex_mem_csr_we     <= 1'b0;
            ex_mem_csr_op     <= 3'd0;
            ex_mem_csr_addr   <= 12'd0;
            ex_mem_csr_wdata  <= 32'd0;
            ex_mem_valid      <= 1'b0;
        end else if (!stall) begin
            ex_mem_pc         <= id_ex_pc;
            ex_mem_alu_result <= ex_result;
            ex_mem_rs2_data   <= fwd_rs2_data;
            ex_mem_rd         <= id_ex_rd;
            ex_mem_reg_we     <= id_ex_reg_we;
            ex_mem_mem_re     <= id_ex_mem_re;
            ex_mem_mem_we     <= id_ex_mem_we;
            ex_mem_funct3     <= id_ex_funct3;
            ex_mem_wb_sel     <= id_ex_wb_sel;
            ex_mem_csr_we     <= id_ex_csr_we;
            ex_mem_csr_op     <= id_ex_csr_op;
            ex_mem_csr_addr   <= id_ex_csr_addr;
            ex_mem_csr_wdata  <= csr_wdata_src;
            ex_mem_valid      <= id_ex_valid;
        end
    end

endmodule
