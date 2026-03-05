`include "qxw_defines.vh"

// 译码阶段：指令解码 + 立即数生成 + 控制信号生成
// 输出 ID/EX 级间寄存器信号
module qxw_id_stage (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              stall,
    input  wire              flush,

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

    // 指令字段提取
    wire [6:0]  opcode = if_id_inst[6:0];
    wire [2:0]  funct3 = if_id_inst[14:12];
    wire [6:0]  funct7 = if_id_inst[31:25];
    wire [4:0]  rd     = if_id_inst[11:7];
    wire [4:0]  rs1    = if_id_inst[19:15];
    wire [4:0]  rs2    = if_id_inst[24:20];
    wire [11:0] funct12 = if_id_inst[31:20];

    assign rs1_addr = rs1;
    assign rs2_addr = rs2;

    // ================================================================
    // 立即数生成
    // ================================================================
    wire [31:0] imm_i = {{20{if_id_inst[31]}}, if_id_inst[31:20]};
    wire [31:0] imm_s = {{20{if_id_inst[31]}}, if_id_inst[31:25], if_id_inst[11:7]};
    wire [31:0] imm_b = {{20{if_id_inst[31]}}, if_id_inst[7], if_id_inst[30:25],
                          if_id_inst[11:8], 1'b0};
    wire [31:0] imm_u = {if_id_inst[31:12], 12'd0};
    wire [31:0] imm_j = {{12{if_id_inst[31]}}, if_id_inst[19:12], if_id_inst[20],
                          if_id_inst[30:21], 1'b0};

    reg [31:0] imm;

    // ================================================================
    // 控制信号解码
    // ================================================================
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

    always @(*) begin
        // 默认值
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
            `OPCODE_LUI: begin
                imm           = imm_u;
                dec_alu_op    = `ALU_PASS_B;
                dec_alu_src_b = 1'b1;
                dec_reg_we    = 1'b1;
            end

            `OPCODE_AUIPC: begin
                imm           = imm_u;
                dec_alu_op    = `ALU_ADD;
                dec_alu_src_a = 1'b1;  // PC
                dec_alu_src_b = 1'b1;  // imm
                dec_reg_we    = 1'b1;
            end

            `OPCODE_JAL: begin
                imm           = imm_j;
                dec_reg_we    = 1'b1;
                dec_wb_sel    = `WB_SEL_PC4;
                dec_br_type   = `BR_JAL;
            end

            `OPCODE_JALR: begin
                imm           = imm_i;
                dec_reg_we    = 1'b1;
                dec_wb_sel    = `WB_SEL_PC4;
                dec_is_jalr   = 1'b1;
                dec_br_type   = `BR_JAL;
            end

            `OPCODE_BRANCH: begin
                imm = imm_b;
                case (funct3)
                    `FUNCT3_BEQ:  dec_br_type = `BR_BEQ;
                    `FUNCT3_BNE:  dec_br_type = `BR_BNE;
                    `FUNCT3_BLT:  dec_br_type = `BR_BLT;
                    `FUNCT3_BGE:  dec_br_type = `BR_BGE;
                    `FUNCT3_BLTU: dec_br_type = `BR_BLTU;
                    `FUNCT3_BGEU: dec_br_type = `BR_BGEU;
                    default:      dec_br_type = `BR_NONE;
                endcase
            end

            `OPCODE_LOAD: begin
                imm           = imm_i;
                dec_alu_op    = `ALU_ADD;
                dec_alu_src_b = 1'b1;
                dec_reg_we    = 1'b1;
                dec_mem_re    = 1'b1;
                dec_wb_sel    = `WB_SEL_MEM;
            end

            `OPCODE_STORE: begin
                imm           = imm_s;
                dec_alu_op    = `ALU_ADD;
                dec_alu_src_b = 1'b1;
                dec_mem_we    = 1'b1;
            end

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

            `OPCODE_OP: begin
                dec_reg_we = 1'b1;
                if (funct7 == `FUNCT7_MULDIV) begin
                    dec_is_muldiv = 1'b1;
                    dec_md_op     = funct3;
                end else begin
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
        end else if (stall) begin
            // 插入 bubble：清除控制信号但保持数据
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
        end else begin
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
