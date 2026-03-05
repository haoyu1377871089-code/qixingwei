`include "qxw_defines.vh"

// ================================================================
// 译码阶段（ID Stage）
// ================================================================
// 功能：将 32 位 RISC-V 指令解码为流水线控制信号
//   1. 指令字段提取：opcode, funct3, funct7, rd, rs1, rs2
//   2. 立即数生成：根据指令格式（I/S/B/U/J）符号扩展为 32 位
//   3. 控制信号生成：ALU 操作码、操作数来源、访存/写回/分支类型等
//   4. ID/EX 级间寄存器管理：支持 flush（冲刷）、stall+bubble（气泡）、hold（保持）
//
// stall 与 hold 的区别：
//   stall && !hold：Load-Use 气泡，将 ID/EX 的控制信号清零（无副作用的 NOP），
//                   但数据字段可保留（不影响功能因为控制信号已清）
//   stall && hold：MulDiv 忙导致的 EX 级 stall，ID/EX 全部保持不变，
//                  确保正在等待 MulDiv 结果的指令不被覆盖
// ================================================================
module qxw_id_stage (
    input  wire              clk,
    input  wire              rst_n,
    // stall：流水线暂停（来自 hazard_ctrl），阻止 ID/EX 更新
    input  wire              stall,
    // flush：冲刷（分支误预测或 trap），将 ID/EX 清零
    input  wire              flush,
    // hold：完全保持（EX 阶段 stall 时使用），区别于 stall 的 bubble 行为
    input  wire              hold,

    // IF/ID 级间寄存器输入
    input  wire [`XLEN_BUS]  if_id_pc,
    input  wire [`INST_BUS]  if_id_inst,
    input  wire              if_id_pred_taken,
    input  wire [`XLEN_BUS]  if_id_pred_target,
    input  wire              if_id_valid,

    // 寄存器堆读端口
    output wire [`REG_ADDR_BUS] rs1_addr,
    output wire [`REG_ADDR_BUS] rs2_addr,
    input  wire [`XLEN_BUS]     rs1_data,
    input  wire [`XLEN_BUS]     rs2_data,

    // ID/EX 级间寄存器输出
    output reg  [`XLEN_BUS]  id_ex_pc,
    output reg  [`XLEN_BUS]  id_ex_rs1_data,
    output reg  [`XLEN_BUS]  id_ex_rs2_data,
    output reg  [`XLEN_BUS]  id_ex_imm,
    output reg  [`REG_ADDR_BUS] id_ex_rd,
    output reg  [`REG_ADDR_BUS] id_ex_rs1,
    output reg  [`REG_ADDR_BUS] id_ex_rs2,
    output reg  [`ALU_OP_BUS]   id_ex_alu_op,
    output reg               id_ex_alu_src_a,   // 0=rs1, 1=pc
    output reg               id_ex_alu_src_b,   // 0=rs2, 1=imm
    output reg               id_ex_reg_we,
    output reg               id_ex_mem_re,
    output reg               id_ex_mem_we,
    output reg  [2:0]        id_ex_funct3,
    output reg  [`WB_SEL_BUS]   id_ex_wb_sel,
    output reg  [`BR_TYPE_BUS]  id_ex_br_type,
    output reg               id_ex_is_jalr,
    output reg               id_ex_is_muldiv,
    output reg  [`MD_OP_BUS]    id_ex_md_op,
    output reg               id_ex_csr_we,
    output reg  [2:0]        id_ex_csr_op,      // funct3 for CSR ops
    output reg  [11:0]       id_ex_csr_addr,
    output reg               id_ex_ecall,
    output reg               id_ex_ebreak,
    output reg               id_ex_mret,
    output reg               id_ex_pred_taken,
    output reg  [`XLEN_BUS]  id_ex_pred_target,
    output reg               id_ex_valid
);

    // ================================================================
    // 指令字段提取
    // ================================================================
    // RISC-V 指令编码格式中各字段位置固定，可直接通过位切片提取
    // funct12 是 I 型立即数的 12 位，在 SYSTEM 指令中区分 ECALL/EBREAK/MRET
    wire [6:0]  opcode = if_id_inst[6:0];
    wire [2:0]  funct3 = if_id_inst[14:12];
    wire [6:0]  funct7 = if_id_inst[31:25];
    wire [4:0]  rd     = if_id_inst[11:7];
    wire [4:0]  rs1    = if_id_inst[19:15];
    wire [4:0]  rs2    = if_id_inst[24:20];
    wire [11:0] funct12 = if_id_inst[31:20];

    // 寄存器堆读地址由指令字段直接驱动（组合逻辑）
    assign rs1_addr = rs1;
    assign rs2_addr = rs2;

    // ================================================================
    // 立即数生成（RISC-V 五种立即数格式）
    // ================================================================
    // RISC-V 设计立即数格式时将符号位固定在 inst[31]，简化了符号扩展硬件
    // 各格式的立即数位排列不同，但符号扩展逻辑统一：高位复制 inst[31]
    //
    // I 型立即数：用于 LOAD、OP-IMM（ADDI/SLTI 等）、JALR，12 位符号扩展
    wire [31:0] imm_i = {{20{if_id_inst[31]}}, if_id_inst[31:20]};
    // S 型立即数：用于 STORE（SB/SH/SW），高 7 位与低 5 位拼接，12 位符号扩展
    wire [31:0] imm_s = {{20{if_id_inst[31]}}, if_id_inst[31:25], if_id_inst[11:7]};
    // B 型立即数：用于条件分支，13 位（含隐含的 bit[0]=0），保证 2 字节对齐
    wire [31:0] imm_b = {{20{if_id_inst[31]}}, if_id_inst[7], if_id_inst[30:25],
                          if_id_inst[11:8], 1'b0};
    // U 型立即数：用于 LUI/AUIPC，高 20 位有效，低 12 位为 0
    wire [31:0] imm_u = {if_id_inst[31:12], 12'd0};
    // J 型立即数：用于 JAL，21 位（含隐含的 bit[0]=0），跳转范围 ±1MB
    wire [31:0] imm_j = {{12{if_id_inst[31]}}, if_id_inst[19:12], if_id_inst[20],
                          if_id_inst[30:21], 1'b0};

    reg [31:0] imm;

    // ================================================================
    // 控制信号解码
    // ================================================================
    // dec_* 前缀表示译码器组合逻辑输出，在时钟上升沿锁存到 id_ex_* 寄存器
    // 各控制信号含义：
    //   alu_op：ALU 操作码，选择 ADD/SUB/SLL/SLT/XOR 等运算
    //   alu_src_a/b：操作数来源选择，0=寄存器值，1=PC（src_a）或立即数（src_b）
    //   reg_we：目标寄存器写使能
    //   mem_re/mem_we：数据存储器读/写使能
    //   wb_sel：写回数据来源选择（ALU/MEM/PC+4/CSR）
    //   br_type：分支类型编码（NONE/BEQ/BNE/BLT/BGE/BLTU/BGEU/JAL）
    //   is_muldiv：标识 M 扩展乘除法指令，走 MulDiv 单元而非 ALU
    //   csr_we/csr_op：CSR 写使能与操作类型（RW/RS/RC/RWI/RSI/RCI）
    reg [`ALU_OP_BUS]   dec_alu_op;
    reg                 dec_alu_src_a;
    reg                 dec_alu_src_b;
    reg                 dec_reg_we;
    reg                 dec_mem_re;
    reg                 dec_mem_we;
    reg [`WB_SEL_BUS]   dec_wb_sel;
    reg [`BR_TYPE_BUS]  dec_br_type;
    reg                 dec_is_jalr;
    reg                 dec_is_muldiv;
    reg [`MD_OP_BUS]    dec_md_op;
    reg                 dec_csr_we;
    reg [2:0]           dec_csr_op;
    reg                 dec_ecall;
    reg                 dec_ebreak;
    reg                 dec_mret;

    // 主译码器：按 opcode 七位字段进行一级译码，再按 funct3/funct7 进行二级译码
    // 默认值设计为"无操作"状态，未识别的指令不会产生任何副作用
    always @(*) begin
        imm            = 32'd0;
        dec_alu_op     = `ALU_ADD;
        dec_alu_src_a  = 1'b0;
        dec_alu_src_b  = 1'b0;
        dec_reg_we     = 1'b0;
        dec_mem_re     = 1'b0;
        dec_mem_we     = 1'b0;
        dec_wb_sel     = `WB_SEL_ALU;
        dec_br_type    = `BR_NONE;
        dec_is_jalr    = 1'b0;
        dec_is_muldiv  = 1'b0;
        dec_md_op      = 3'd0;
        dec_csr_we     = 1'b0;
        dec_csr_op     = 3'd0;
        dec_ecall      = 1'b0;
        dec_ebreak     = 1'b0;
        dec_mret       = 1'b0;

        case (opcode)
            // LUI（Load Upper Immediate）：将 U 型立即数直接写入 rd
            // ALU 选择 PASS_B 模式，将 op_b（即 imm_u）直通输出
            `OPCODE_LUI: begin
                imm           = imm_u;
                dec_alu_op    = `ALU_PASS_B;
                dec_alu_src_b = 1'b1;
                dec_reg_we    = 1'b1;
            end

            // AUIPC（Add Upper Immediate to PC）：rd = PC + imm_u
            // 常用于 PIC（位置无关代码）中构造全局地址：AUIPC+ADDI 组合寻址
            // src_a=PC, src_b=imm，ALU 执行加法
            `OPCODE_AUIPC: begin
                imm           = imm_u;
                dec_alu_op    = `ALU_ADD;
                dec_alu_src_a = 1'b1;  // PC
                dec_alu_src_b = 1'b1;  // imm
                dec_reg_we    = 1'b1;
            end

            // JAL（Jump And Link）：无条件跳转，rd 写入 PC+4 作为返回地址
            // 跳转目标 = PC + imm_j，在 EX 阶段由分支逻辑计算
            // br_type 设为 BR_JAL，EX 阶段无条件产生 taken
            `OPCODE_JAL: begin
                imm           = imm_j;
                dec_reg_we    = 1'b1;
                dec_wb_sel    = `WB_SEL_PC4;
                dec_br_type   = `BR_JAL;
            end

            // JALR（Jump And Link Register）：间接跳转，目标 = (rs1 + imm_i) & ~1
            // 用于函数返回（配合 ra 寄存器）和间接跳转表
            // is_jalr 标志告知 EX 阶段使用 rs1+imm 而非 PC+imm 计算目标
            // JALR 总是触发 mispredict flush，因为目标依赖寄存器值无法静态预测
            `OPCODE_JALR: begin
                imm           = imm_i;
                dec_reg_we    = 1'b1;
                dec_wb_sel    = `WB_SEL_PC4;
                dec_is_jalr   = 1'b1;
                dec_br_type   = `BR_JAL;
            end

            // BRANCH：条件分支指令族，不写回寄存器
            // funct3 编码六种比较方式：
            //   BEQ(000)/BNE(001)：相等/不等比较
            //   BLT(100)/BGE(101)：有符号小于/大于等于
            //   BLTU(110)/BGEU(111)：无符号小于/大于等于
            // 目标地址 = PC + imm_b，在 EX 阶段与 BPU 预测结果比较
            // 注意：分支指令不设置 reg_we，也不使用 ALU 计算结果
            // ALU 在此时处于默认 ADD 状态，但其结果不会被写回
            `OPCODE_BRANCH: begin
                imm = imm_b;
                case (funct3)
                    `FUNCT3_BEQ:  dec_br_type = `BR_BEQ;   // rs1 == rs2 时跳转
                    `FUNCT3_BNE:  dec_br_type = `BR_BNE;   // rs1 != rs2 时跳转
                    `FUNCT3_BLT:  dec_br_type = `BR_BLT;   // signed(rs1) < signed(rs2) 时跳转
                    `FUNCT3_BGE:  dec_br_type = `BR_BGE;   // signed(rs1) >= signed(rs2) 时跳转
                    `FUNCT3_BLTU: dec_br_type = `BR_BLTU;  // unsigned(rs1) < unsigned(rs2) 时跳转
                    `FUNCT3_BGEU: dec_br_type = `BR_BGEU;  // unsigned(rs1) >= unsigned(rs2) 时跳转
                    default:      dec_br_type = `BR_NONE;
                endcase
            end

            // LOAD：基址 + I 型偏移计算访存地址，ALU 执行地址加法
            // funct3 区分 LB/LH/LW/LBU/LHU，MEM 阶段做字节对齐和扩展
            // wb_sel 设为 WB_SEL_MEM，写回数据来自数据存储器
            `OPCODE_LOAD: begin
                imm           = imm_i;
                dec_alu_op    = `ALU_ADD;
                dec_alu_src_b = 1'b1;
                dec_reg_we    = 1'b1;
                dec_mem_re    = 1'b1;
                dec_wb_sel    = `WB_SEL_MEM;
            end

            // STORE：基址 + S 型偏移计算访存地址，无寄存器写回
            // funct3 区分 SB/SH/SW，MEM 阶段生成字节使能和数据对齐
            `OPCODE_STORE: begin
                imm           = imm_s;
                dec_alu_op    = `ALU_ADD;
                dec_alu_src_b = 1'b1;
                dec_mem_we    = 1'b1;
            end

            // OP-IMM：寄存器-立即数运算（ADDI/SLTI/XORI/ORI/ANDI/SLLI/SRLI/SRAI）
            // src_b=1 选择立即数作为 ALU 第二操作数
            // 注意：SLLI/SRLI/SRAI 的移位量取 imm[4:0]，funct7[5] 区分逻辑/算术右移
            // ADDI 无 SUB 变体（没有 SUBI 指令），用 ADDI 加负立即数实现
            `OPCODE_OP_IMM: begin
                imm           = imm_i;
                dec_alu_src_b = 1'b1;
                dec_reg_we    = 1'b1;
                case (funct3)
                    `FUNCT3_ADD_SUB: dec_alu_op = `ALU_ADD;
                    `FUNCT3_SLL:     dec_alu_op = `ALU_SLL;
                    `FUNCT3_SLT:     dec_alu_op = `ALU_SLT;
                    `FUNCT3_SLTU:    dec_alu_op = `ALU_SLTU;
                    `FUNCT3_XOR:     dec_alu_op = `ALU_XOR;
                    `FUNCT3_SRL_SRA: dec_alu_op = funct7[5] ? `ALU_SRA : `ALU_SRL;
                    `FUNCT3_OR:      dec_alu_op = `ALU_OR;
                    `FUNCT3_AND:     dec_alu_op = `ALU_AND;
                    default:         dec_alu_op = `ALU_ADD;
                endcase
            end

            // OP：R 型寄存器-寄存器运算
            // funct7=0000001 为 M 扩展（MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU）
            // 其他 funct7 值为基础 ALU 运算，funct7[5] 区分 ADD/SUB 和 SRL/SRA
            `OPCODE_OP: begin
                dec_reg_we = 1'b1;
                // funct7=0000001 标识 M 扩展指令，走 MulDiv 单元
                if (funct7 == `FUNCT7_MULDIV) begin
                    dec_is_muldiv = 1'b1;
                    dec_md_op     = funct3;
                end else begin
                    // 普通 R 型 ALU 运算：ADD/SUB 和 SRL/SRA 通过 funct7[5] 区分
                    case (funct3)
                        `FUNCT3_ADD_SUB: dec_alu_op = funct7[5] ? `ALU_SUB : `ALU_ADD;
                        `FUNCT3_SLL:     dec_alu_op = `ALU_SLL;
                        `FUNCT3_SLT:     dec_alu_op = `ALU_SLT;
                        `FUNCT3_SLTU:    dec_alu_op = `ALU_SLTU;
                        `FUNCT3_XOR:     dec_alu_op = `ALU_XOR;
                        `FUNCT3_SRL_SRA: dec_alu_op = funct7[5] ? `ALU_SRA : `ALU_SRL;
                        `FUNCT3_OR:      dec_alu_op = `ALU_OR;
                        `FUNCT3_AND:     dec_alu_op = `ALU_AND;
                        default:         dec_alu_op = `ALU_ADD;
                    endcase
                end
            end

            // SYSTEM 指令：funct3=000 为特权指令，其他为 CSR 操作
            // 特权指令通过 funct12 区分：ECALL(0x000)、EBREAK(0x001)、MRET(0x302)
            // CSR 操作通过 funct3 区分读写类型，wb_sel=CSR 将旧值写回 rd
            // CSR 的实际写入延迟到 WB 阶段，避免与 trap 冲突
            `OPCODE_SYSTEM: begin
                if (funct3 == `FUNCT3_PRIV) begin
                    case (funct12)
                        `FUNCT12_ECALL:  dec_ecall  = 1'b1;
                        `FUNCT12_EBREAK: dec_ebreak = 1'b1;
                        `FUNCT12_MRET:   dec_mret   = 1'b1;
                        default: ;
                    endcase
                end else begin
                    dec_csr_we  = 1'b1;
                    dec_csr_op  = funct3;
                    dec_reg_we  = 1'b1;
                    dec_wb_sel  = `WB_SEL_CSR;
                end
            end

            default: ;
        endcase
    end

    // ================================================================
    // ID/EX 级间寄存器
    // ================================================================
    // 三种更新模式按优先级排列：
    //   1. flush（最高优先级）：分支误预测或 trap 时，将所有字段清零
    //      确保 EX 阶段下一拍不会执行任何有副作用的操作
    //   2. stall && !hold：Load-Use 气泡，仅清除控制信号（reg_we/mem_re/mem_we/
    //      br_type/csr_we/ecall/ebreak/mret/is_muldiv/valid），数据字段保留
    //      这比全清零更节省功耗（减少不必要的位翻转）
    //   3. stall && hold：MulDiv 忙期间保持 ID/EX 完全不变，
    //      等 MulDiv 完成后 EX 阶段继续使用这些信号
    //   4. !stall（正常流动）：将组合逻辑译码结果锁存到 ID/EX
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            id_ex_pc          <= 32'd0;
            id_ex_rs1_data    <= 32'd0;
            id_ex_rs2_data    <= 32'd0;
            id_ex_imm         <= 32'd0;
            id_ex_rd          <= 5'd0;
            id_ex_rs1         <= 5'd0;
            id_ex_rs2         <= 5'd0;
            id_ex_alu_op      <= `ALU_ADD;
            id_ex_alu_src_a   <= 1'b0;
            id_ex_alu_src_b   <= 1'b0;
            id_ex_reg_we      <= 1'b0;
            id_ex_mem_re      <= 1'b0;
            id_ex_mem_we      <= 1'b0;
            id_ex_funct3      <= 3'd0;
            id_ex_wb_sel      <= `WB_SEL_ALU;
            id_ex_br_type     <= `BR_NONE;
            id_ex_is_jalr     <= 1'b0;
            id_ex_is_muldiv   <= 1'b0;
            id_ex_md_op       <= 3'd0;
            id_ex_csr_we      <= 1'b0;
            id_ex_csr_op      <= 3'd0;
            id_ex_csr_addr    <= 12'd0;
            id_ex_ecall       <= 1'b0;
            id_ex_ebreak      <= 1'b0;
            id_ex_mret        <= 1'b0;
            id_ex_pred_taken  <= 1'b0;
            id_ex_pred_target <= 32'd0;
            id_ex_valid       <= 1'b0;
        end else if (stall && !hold) begin
            // Load-Use 气泡：清除所有可能产生副作用的控制信号
            // 保留数据路径字段（pc/rs1_data/rs2_data/imm 等）以节省翻转功耗
            id_ex_reg_we      <= 1'b0;
            id_ex_mem_re      <= 1'b0;
            id_ex_mem_we      <= 1'b0;
            id_ex_br_type     <= `BR_NONE;
            id_ex_csr_we      <= 1'b0;
            id_ex_ecall       <= 1'b0;
            id_ex_ebreak      <= 1'b0;
            id_ex_mret        <= 1'b0;
            id_ex_is_muldiv   <= 1'b0;
            id_ex_valid       <= 1'b0;
        end else if (!stall) begin
            // 正常流动：将译码结果和寄存器堆读出数据锁存到 ID/EX
            id_ex_pc          <= if_id_pc;
            id_ex_rs1_data    <= rs1_data;
            id_ex_rs2_data    <= rs2_data;
            id_ex_imm         <= imm;
            id_ex_rd          <= rd;
            id_ex_rs1         <= rs1;
            id_ex_rs2         <= rs2;
            id_ex_alu_op      <= dec_alu_op;
            id_ex_alu_src_a   <= dec_alu_src_a;
            id_ex_alu_src_b   <= dec_alu_src_b;
            id_ex_reg_we      <= dec_reg_we;
            id_ex_mem_re      <= dec_mem_re;
            id_ex_mem_we      <= dec_mem_we;
            id_ex_funct3      <= funct3;
            id_ex_wb_sel      <= dec_wb_sel;
            id_ex_br_type     <= dec_br_type;
            id_ex_is_jalr     <= dec_is_jalr;
            id_ex_is_muldiv   <= dec_is_muldiv;
            id_ex_md_op       <= dec_md_op;
            id_ex_csr_we      <= dec_csr_we;
            id_ex_csr_op      <= dec_csr_op;
            id_ex_csr_addr    <= if_id_inst[31:20];
            id_ex_ecall       <= dec_ecall;
            id_ex_ebreak      <= dec_ebreak;
            id_ex_mret        <= dec_mret;
            id_ex_pred_taken  <= if_id_pred_taken;
            id_ex_pred_target <= if_id_pred_target;
            id_ex_valid       <= if_id_valid;
        end
    end

endmodule
