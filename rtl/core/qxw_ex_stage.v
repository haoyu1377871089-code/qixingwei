`include "qxw_defines.vh"

// ================================================================
// 执行阶段（EX Stage）
// ================================================================
// 核心功能：
//   1. ALU 运算：操作数经 src_a/src_b 选择后送入 ALU，结果同拍可用
//   2. 分支判断：基于转发后的 rs1/rs2 比较结果，结合 br_type 生成 taken 信号
//   3. 分支目标计算：JAL/Branch = PC+imm，JALR = (rs1+imm) & ~1
//   4. 误预测检测：比较实际结果与 IF 阶段的预测方向和目标
//   5. MulDiv 接口：转发后的操作数直接送入乘除法单元
//   6. CSR 数据准备：根据 funct3[2] 选择 rs1 值或 zimm 作为写入数据源
//   7. EX/MEM 级间寄存器：stall 时保持，flush 时清零
// ================================================================
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
    // ALU 操作数多路选择
    // ================================================================
    // src_a 选择：0=寄存器值（经转发），1=PC（AUIPC 需要 PC 参与运算）
    // src_b 选择：0=寄存器值（R 型指令），1=立即数（I/S/U 型指令）
    assign alu_op   = id_ex_alu_op;
    assign alu_op_a = id_ex_alu_src_a ? id_ex_pc       : fwd_rs1_data;
    assign alu_op_b = id_ex_alu_src_b ? id_ex_imm      : fwd_rs2_data;

    // ================================================================
    // MulDiv 启动与操作数接口
    // ================================================================
    // md_start 信号在 cpu_top 中被替换为 md_start_pulse 防重复
    // 操作数直接使用转发后的值，确保数据冒险场景下计算正确
    assign md_start = id_ex_is_muldiv & id_ex_valid & !md_busy;
    assign md_op    = id_ex_md_op;
    assign md_op_a  = fwd_rs1_data;
    assign md_op_b  = fwd_rs2_data;

    // 执行结果选择：is_muldiv=1 时取 MulDiv 结果，否则取 ALU 结果
    // 乘法时 md_result 在 start 同拍即有效（组合逻辑）
    // 除法时 md_result 在 valid 信号后稳定
    wire [`XLEN_BUS] ex_result = id_ex_is_muldiv ? md_result : alu_result;

    // ================================================================
    // 分支条件判断
    // ================================================================
    // 三个基础比较结果供后续分支类型选择器使用：
    //   br_eq：相等比较，用于 BEQ/BNE
    //   br_lt：有符号小于，用于 BLT/BGE（$signed 强制有符号比较）
    //   br_ltu：无符号小于，用于 BLTU/BGEU
    // 操作数使用转发后的值，确保数据冒险场景下比较正确
    wire br_eq  = (fwd_rs1_data == fwd_rs2_data);
    wire br_lt  = ($signed(fwd_rs1_data) < $signed(fwd_rs2_data));
    wire br_ltu = (fwd_rs1_data < fwd_rs2_data);

    // 分支条件选择器：根据 br_type 从基础比较结果中选出最终条件
    // BGE 通过 !br_lt 实现（大于等于 = 不小于），BGEU 同理
    // BR_JAL 无条件跳转，直接输出 1
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

    // 当前指令是否为分支类指令（包括条件分支和 JAL）
    wire is_branch = (id_ex_br_type != `BR_NONE) & id_ex_valid;

    // 最终分支判断：是分支指令且条件满足
    assign branch_taken  = is_branch & br_cond;
    // 分支目标地址计算
    // JALR：目标 = (rs1 + imm) & ~1，低位清零保证 2 字节对齐（RISC-V 规范要求）
    // JAL/Branch：目标 = PC + imm，偏移量在 ID 阶段已符号扩展
    assign branch_target = id_ex_is_jalr ?
                           (fwd_rs1_data + id_ex_imm) & 32'hFFFF_FFFE :
                           id_ex_pc + id_ex_imm;

    // 预测错误检测：以下任一条件成立即触发前端冲刷
    // 情况 1：实际跳转但 BPU 未预测跳转 -> 已取了错误的顺序指令
    // 情况 2：实际跳转且 BPU 预测跳转，但目标地址不匹配 -> 跳到了错误位置
    // 情况 3：实际不跳转但 BPU 预测了跳转 -> 已取了错误的目标指令
    // 情况 4：JALR 间接跳转 -> 目标依赖寄存器值，IF 阶段无法预测
    assign branch_mispredict = id_ex_valid & (
        (is_branch & br_cond & !id_ex_pred_taken) |
        (is_branch & br_cond & id_ex_pred_taken & (branch_target != id_ex_pred_target)) |
        (is_branch & !br_cond & id_ex_pred_taken) |
        (id_ex_is_jalr)  // JALR 总是需要冲刷（无法静态预测）
    );

    // CSR 写入数据源选择
    // funct3[2]=0：寄存器型（CSRRW/CSRRS/CSRRC），数据来自转发后的 rs1 值
    // funct3[2]=1：立即数型（CSRRWI/CSRRSI/CSRRCI），数据为零扩展的 5 位 zimm
    // zimm 存放在指令的 rs1 字段（inst[19:15]），复用地址位作为立即数
    wire [`XLEN_BUS] csr_wdata_src = (id_ex_csr_op[2]) ?
                                     {27'd0, id_ex_rs1} :  // CSRRWI/CSRRSI/CSRRCI: zimm
                                     fwd_rs1_data;          // CSRRW/CSRRS/CSRRC: rs1

    // ================================================================
    // EX/MEM 级间寄存器
    // ================================================================
    // flush 时清零：trap 触发时防止异常指令的访存或写回操作传入 MEM
    // stall 时保持不变：MulDiv 忙期间 EX/MEM 不更新，等待结果就绪
    // 正常流动时锁存当前 EX 阶段的计算结果
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
