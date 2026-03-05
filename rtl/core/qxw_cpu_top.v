`include "qxw_defines.vh"

// CPU 核心顶层：实例化五级流水线所有模块并连接数据通路
// 对外暴露指令/数据存储器接口和中断接口
module qxw_cpu_top (
    input  wire              clk,
    input  wire              rst_n,

    // 指令存储器接口
    output wire [`XLEN_BUS]  imem_addr,
    input  wire [`XLEN_BUS]  imem_rdata,

    // 数据存储器接口
    output wire              dmem_en,
    output wire [3:0]        dmem_we,
    output wire [`XLEN_BUS]  dmem_addr,
    output wire [`XLEN_BUS]  dmem_wdata,
    input  wire [`XLEN_BUS]  dmem_rdata,

    // 中断
    input  wire              timer_irq
);

    // ================================================================
    // 内部连线声明
    // ================================================================

    // PC
    wire [`XLEN_BUS] pc;
    wire [`XLEN_BUS] next_pc;

    // 冒险控制
    wire stall_if, stall_id, stall_ex, stall_mem;
    wire flush_if_id, flush_id_ex, flush_ex_mem;

    // 分支
    wire              branch_taken;
    wire [`XLEN_BUS]  branch_target;
    wire              branch_mispredict;

    // 分支预测
    wire [`BHT_IDX_W-1:0] bpu_pred_idx;
    wire              bpu_pred_taken;

    // IF/ID 级间
    wire [`XLEN_BUS]  if_id_pc;
    wire [`INST_BUS]  if_id_inst;
    wire              if_id_pred_taken;
    wire [`XLEN_BUS]  if_id_pred_target;
    wire              if_id_valid;

    // 寄存器堆
    wire [`REG_ADDR_BUS] rs1_addr, rs2_addr;
    wire [`XLEN_BUS]     rs1_data, rs2_data;
    wire                 rf_we;
    wire [`REG_ADDR_BUS] rf_wa;
    wire [`XLEN_BUS]     rf_wd;

    // ID/EX 级间
    wire [`XLEN_BUS]     id_ex_pc;
    wire [`XLEN_BUS]     id_ex_rs1_data, id_ex_rs2_data;
    wire [`XLEN_BUS]     id_ex_imm;
    wire [`REG_ADDR_BUS] id_ex_rd, id_ex_rs1, id_ex_rs2;
    wire [`ALU_OP_BUS]   id_ex_alu_op;
    wire                 id_ex_alu_src_a, id_ex_alu_src_b;
    wire                 id_ex_reg_we, id_ex_mem_re, id_ex_mem_we;
    wire [2:0]           id_ex_funct3;
    wire [`WB_SEL_BUS]   id_ex_wb_sel;
    wire [`BR_TYPE_BUS]  id_ex_br_type;
    wire                 id_ex_is_jalr;
    wire                 id_ex_is_muldiv;
    wire [`MD_OP_BUS]    id_ex_md_op;
    wire                 id_ex_csr_we;
    wire [2:0]           id_ex_csr_op;
    wire [11:0]          id_ex_csr_addr;
    wire                 id_ex_ecall, id_ex_ebreak, id_ex_mret;
    wire                 id_ex_pred_taken;
    wire [`XLEN_BUS]     id_ex_pred_target;
    wire                 id_ex_valid;

    // 转发
    wire [`XLEN_BUS]     fwd_rs1_data, fwd_rs2_data;
    wire [1:0]           fwd_sel_a, fwd_sel_b;

    // ALU
    wire [`ALU_OP_BUS]   alu_op;
    wire [`XLEN_BUS]     alu_op_a, alu_op_b, alu_result;
    wire                 alu_zero;

    // MulDiv
    wire                 md_start;
    wire [`MD_OP_BUS]    md_op;
    wire [`XLEN_BUS]     md_op_a, md_op_b, md_result;
    wire                 md_busy, md_valid;

    // EX/MEM 级间
    wire [`XLEN_BUS]     ex_mem_pc;
    wire [`XLEN_BUS]     ex_mem_alu_result;
    wire [`XLEN_BUS]     ex_mem_rs2_data;
    wire [`REG_ADDR_BUS] ex_mem_rd;
    wire                 ex_mem_reg_we;
    wire                 ex_mem_mem_re, ex_mem_mem_we;
    wire [2:0]           ex_mem_funct3;
    wire [`WB_SEL_BUS]   ex_mem_wb_sel;
    wire                 ex_mem_csr_we;
    wire [2:0]           ex_mem_csr_op;
    wire [11:0]          ex_mem_csr_addr;
    wire [`XLEN_BUS]     ex_mem_csr_wdata;
    wire                 ex_mem_valid;

    // MEM/WB 级间
    wire [`XLEN_BUS]     mem_wb_pc;
    wire [`XLEN_BUS]     mem_wb_alu_result;
    wire [`XLEN_BUS]     mem_wb_mem_data;
    wire [`REG_ADDR_BUS] mem_wb_rd;
    wire                 mem_wb_reg_we;
    wire [`WB_SEL_BUS]   mem_wb_wb_sel;
    wire                 mem_wb_csr_we;
    wire [2:0]           mem_wb_csr_op;
    wire [11:0]          mem_wb_csr_addr;
    wire [`XLEN_BUS]     mem_wb_csr_wdata;
    wire                 mem_wb_valid;

    // CSR
    wire [`XLEN_BUS]     csr_rdata;
    wire [`XLEN_BUS]     csr_mtvec;
    wire [`XLEN_BUS]     csr_mepc;
    wire                 csr_trap;

    // ID 阶段 rs1/rs2（从 IF/ID 指令字段提取，用于冒险检测）
    wire [`REG_ADDR_BUS] id_rs1_for_hazard = if_id_inst[19:15];
    wire [`REG_ADDR_BUS] id_rs2_for_hazard = if_id_inst[24:20];

    // BPU 预测目标（从 IF stage 内部计算）
    wire [`XLEN_BUS] bpu_pred_target;

    // MulDiv 启动跟踪：防止 stall 解除后重复触发除法
    reg md_started_r;
    wire md_start_pulse = id_ex_is_muldiv & id_ex_valid & !md_busy & !md_started_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            md_started_r <= 1'b0;
        else if (!stall_ex)
            md_started_r <= 1'b0;
        else if (md_start_pulse)
            md_started_r <= 1'b1;
    end

    // ================================================================
    // 模块实例化
    // ================================================================

    // --- PC 寄存器 ---
    qxw_pc_reg u_pc_reg (
        .clk           (clk),
        .rst_n         (rst_n),
        .stall         (stall_if),
        .branch_taken  (branch_taken),
        .branch_target (branch_target),
        .pred_taken    (bpu_pred_taken & ~flush_if_id),
        .pred_target   (bpu_pred_target),
        .flush         (branch_mispredict),
        .flush_target  (branch_taken ? branch_target : (id_ex_pc + 32'd4)),
        .trap          (csr_trap),
        .trap_target   (csr_mtvec),
        .mret          (id_ex_mret & id_ex_valid),
        .mepc          (csr_mepc),
        .pc            (pc),
        .next_pc       (next_pc)
    );

    // --- 分支预测器 ---
    qxw_branch_pred u_bpu (
        .clk           (clk),
        .rst_n         (rst_n),
        .pred_idx      (bpu_pred_idx),
        .pred_taken    (bpu_pred_taken),
        .update_en     (id_ex_valid & (id_ex_br_type != `BR_NONE) & (id_ex_br_type != `BR_JAL)),
        .update_idx    (id_ex_pc[`BHT_IDX_W+1:2]),
        .update_taken  (branch_taken)
    );

    // --- 取指阶段 ---
    qxw_if_stage u_if_stage (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall            (stall_if),
        .flush            (flush_if_id),
        .pc               (pc),
        .imem_addr        (imem_addr),
        .imem_rdata       (imem_rdata),
        .bpu_idx          (bpu_pred_idx),
        .bpu_pred_taken   (bpu_pred_taken),
        .bpu_pred_target  (bpu_pred_target),
        .if_id_pc         (if_id_pc),
        .if_id_inst       (if_id_inst),
        .if_id_pred_taken (if_id_pred_taken),
        .if_id_pred_target(if_id_pred_target),
        .if_id_valid      (if_id_valid)
    );

    // --- 寄存器堆 ---
    qxw_regfile u_regfile (
        .clk  (clk),
        .rst_n(rst_n),
        .ra1  (rs1_addr),
        .rd1  (rs1_data),
        .ra2  (rs2_addr),
        .rd2  (rs2_data),
        .we   (rf_we),
        .wa   (rf_wa),
        .wd   (rf_wd)
    );

    // --- 译码阶段 ---
    qxw_id_stage u_id_stage (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall            (stall_id),
        .flush            (flush_id_ex),
        .if_id_pc         (if_id_pc),
        .if_id_inst       (if_id_inst),
        .if_id_pred_taken (if_id_pred_taken),
        .if_id_pred_target(if_id_pred_target),
        .if_id_valid      (if_id_valid),
        .rs1_addr         (rs1_addr),
        .rs2_addr         (rs2_addr),
        .rs1_data         (rs1_data),
        .rs2_data         (rs2_data),
        .id_ex_pc         (id_ex_pc),
        .id_ex_rs1_data   (id_ex_rs1_data),
        .id_ex_rs2_data   (id_ex_rs2_data),
        .id_ex_imm        (id_ex_imm),
        .id_ex_rd         (id_ex_rd),
        .id_ex_rs1        (id_ex_rs1),
        .id_ex_rs2        (id_ex_rs2),
        .id_ex_alu_op     (id_ex_alu_op),
        .id_ex_alu_src_a  (id_ex_alu_src_a),
        .id_ex_alu_src_b  (id_ex_alu_src_b),
        .id_ex_reg_we     (id_ex_reg_we),
        .id_ex_mem_re     (id_ex_mem_re),
        .id_ex_mem_we     (id_ex_mem_we),
        .id_ex_funct3     (id_ex_funct3),
        .id_ex_wb_sel     (id_ex_wb_sel),
        .id_ex_br_type    (id_ex_br_type),
        .id_ex_is_jalr    (id_ex_is_jalr),
        .id_ex_is_muldiv  (id_ex_is_muldiv),
        .id_ex_md_op      (id_ex_md_op),
        .id_ex_csr_we     (id_ex_csr_we),
        .id_ex_csr_op     (id_ex_csr_op),
        .id_ex_csr_addr   (id_ex_csr_addr),
        .id_ex_ecall      (id_ex_ecall),
        .id_ex_ebreak     (id_ex_ebreak),
        .id_ex_mret       (id_ex_mret),
        .id_ex_pred_taken (id_ex_pred_taken),
        .id_ex_pred_target(id_ex_pred_target),
        .id_ex_valid      (id_ex_valid)
    );

    // --- 转发单元 ---
    qxw_forwarding u_forwarding (
        .id_ex_rs1        (id_ex_rs1),
        .id_ex_rs2        (id_ex_rs2),
        .id_ex_rs1_data   (id_ex_rs1_data),
        .id_ex_rs2_data   (id_ex_rs2_data),
        .ex_mem_rd        (ex_mem_rd),
        .ex_mem_reg_we    (ex_mem_reg_we),
        .ex_mem_alu_result(ex_mem_alu_result),
        .ex_mem_valid     (ex_mem_valid),
        .mem_wb_rd        (mem_wb_rd),
        .mem_wb_reg_we    (mem_wb_reg_we),
        .mem_wb_wd        (rf_wd),
        .mem_wb_valid     (mem_wb_valid),
        .fwd_rs1_data     (fwd_rs1_data),
        .fwd_rs2_data     (fwd_rs2_data),
        .fwd_sel_a        (fwd_sel_a),
        .fwd_sel_b        (fwd_sel_b)
    );

    // --- ALU ---
    qxw_alu u_alu (
        .alu_op (alu_op),
        .op_a   (alu_op_a),
        .op_b   (alu_op_b),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // --- 乘除法单元 ---
    qxw_muldiv u_muldiv (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (md_start_pulse),
        .md_op  (md_op),
        .op_a   (md_op_a),
        .op_b   (md_op_b),
        .result (md_result),
        .busy   (md_busy),
        .valid  (md_valid)
    );

    // --- 执行阶段 ---
    qxw_ex_stage u_ex_stage (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall            (stall_ex),
        .flush            (flush_ex_mem),
        .id_ex_pc         (id_ex_pc),
        .id_ex_rs1_data   (id_ex_rs1_data),
        .id_ex_rs2_data   (id_ex_rs2_data),
        .id_ex_imm        (id_ex_imm),
        .id_ex_rd         (id_ex_rd),
        .id_ex_rs1        (id_ex_rs1),
        .id_ex_rs2        (id_ex_rs2),
        .id_ex_alu_op     (id_ex_alu_op),
        .id_ex_alu_src_a  (id_ex_alu_src_a),
        .id_ex_alu_src_b  (id_ex_alu_src_b),
        .id_ex_reg_we     (id_ex_reg_we),
        .id_ex_mem_re     (id_ex_mem_re),
        .id_ex_mem_we     (id_ex_mem_we),
        .id_ex_funct3     (id_ex_funct3),
        .id_ex_wb_sel     (id_ex_wb_sel),
        .id_ex_br_type    (id_ex_br_type),
        .id_ex_is_jalr    (id_ex_is_jalr),
        .id_ex_is_muldiv  (id_ex_is_muldiv),
        .id_ex_md_op      (id_ex_md_op),
        .id_ex_csr_we     (id_ex_csr_we),
        .id_ex_csr_op     (id_ex_csr_op),
        .id_ex_csr_addr   (id_ex_csr_addr),
        .id_ex_ecall      (id_ex_ecall),
        .id_ex_ebreak     (id_ex_ebreak),
        .id_ex_mret       (id_ex_mret),
        .id_ex_pred_taken (id_ex_pred_taken),
        .id_ex_pred_target(id_ex_pred_target),
        .id_ex_valid      (id_ex_valid),
        .fwd_rs1_data     (fwd_rs1_data),
        .fwd_rs2_data     (fwd_rs2_data),
        .alu_op           (alu_op),
        .alu_op_a         (alu_op_a),
        .alu_op_b         (alu_op_b),
        .alu_result       (alu_result),
        .md_start         (md_start),
        .md_op            (md_op),
        .md_op_a          (md_op_a),
        .md_op_b          (md_op_b),
        .md_result        (md_result),
        .md_busy          (md_busy),
        .md_valid         (md_valid),
        .branch_taken     (branch_taken),
        .branch_target    (branch_target),
        .branch_mispredict(branch_mispredict),
        .ex_mem_pc        (ex_mem_pc),
        .ex_mem_alu_result(ex_mem_alu_result),
        .ex_mem_rs2_data  (ex_mem_rs2_data),
        .ex_mem_rd        (ex_mem_rd),
        .ex_mem_reg_we    (ex_mem_reg_we),
        .ex_mem_mem_re    (ex_mem_mem_re),
        .ex_mem_mem_we    (ex_mem_mem_we),
        .ex_mem_funct3    (ex_mem_funct3),
        .ex_mem_wb_sel    (ex_mem_wb_sel),
        .ex_mem_csr_we    (ex_mem_csr_we),
        .ex_mem_csr_op    (ex_mem_csr_op),
        .ex_mem_csr_addr  (ex_mem_csr_addr),
        .ex_mem_csr_wdata (ex_mem_csr_wdata),
        .ex_mem_valid     (ex_mem_valid)
    );

    // --- 访存阶段 ---
    qxw_mem_stage u_mem_stage (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall            (stall_mem),
        .ex_mem_pc        (ex_mem_pc),
        .ex_mem_alu_result(ex_mem_alu_result),
        .ex_mem_rs2_data  (ex_mem_rs2_data),
        .ex_mem_rd        (ex_mem_rd),
        .ex_mem_reg_we    (ex_mem_reg_we),
        .ex_mem_mem_re    (ex_mem_mem_re),
        .ex_mem_mem_we    (ex_mem_mem_we),
        .ex_mem_funct3    (ex_mem_funct3),
        .ex_mem_wb_sel    (ex_mem_wb_sel),
        .ex_mem_csr_we    (ex_mem_csr_we),
        .ex_mem_csr_op    (ex_mem_csr_op),
        .ex_mem_csr_addr  (ex_mem_csr_addr),
        .ex_mem_csr_wdata (ex_mem_csr_wdata),
        .ex_mem_valid     (ex_mem_valid),
        .dmem_en          (dmem_en),
        .dmem_we          (dmem_we),
        .dmem_addr        (dmem_addr),
        .dmem_wdata       (dmem_wdata),
        .dmem_rdata       (dmem_rdata),
        .mem_wb_pc        (mem_wb_pc),
        .mem_wb_alu_result(mem_wb_alu_result),
        .mem_wb_mem_data  (mem_wb_mem_data),
        .mem_wb_rd        (mem_wb_rd),
        .mem_wb_reg_we    (mem_wb_reg_we),
        .mem_wb_wb_sel    (mem_wb_wb_sel),
        .mem_wb_csr_we    (mem_wb_csr_we),
        .mem_wb_csr_op    (mem_wb_csr_op),
        .mem_wb_csr_addr  (mem_wb_csr_addr),
        .mem_wb_csr_wdata (mem_wb_csr_wdata),
        .mem_wb_valid     (mem_wb_valid)
    );

    // --- 写回阶段 ---
    qxw_wb_stage u_wb_stage (
        .mem_wb_pc        (mem_wb_pc),
        .mem_wb_alu_result(mem_wb_alu_result),
        .mem_wb_mem_data  (mem_wb_mem_data),
        .mem_wb_rd        (mem_wb_rd),
        .mem_wb_reg_we    (mem_wb_reg_we),
        .mem_wb_wb_sel    (mem_wb_wb_sel),
        .mem_wb_valid     (mem_wb_valid),
        .csr_rdata        (csr_rdata),
        .rf_we            (rf_we),
        .rf_wa            (rf_wa),
        .rf_wd            (rf_wd)
    );

    // --- CSR ---
    qxw_csr u_csr (
        .clk       (clk),
        .rst_n     (rst_n),
        .raddr     (mem_wb_csr_addr),
        .rdata     (csr_rdata),
        .we        (mem_wb_csr_we & mem_wb_valid),
        .wop       (mem_wb_csr_op),
        .waddr     (mem_wb_csr_addr),
        .wdata     (mem_wb_csr_wdata),
        .ecall     (id_ex_ecall & id_ex_valid),
        .mret      (id_ex_mret & id_ex_valid),
        .epc       (id_ex_pc),
        .timer_irq (timer_irq),
        .mtvec_o   (csr_mtvec),
        .mepc_o    (csr_mepc),
        .trap      (csr_trap),
        .retire    ()
    );

    // --- 冒险控制 ---
    qxw_hazard_ctrl u_hazard_ctrl (
        .id_rs1            (id_rs1_for_hazard),
        .id_rs2            (id_rs2_for_hazard),
        .id_ex_rd          (id_ex_rd),
        .id_ex_mem_re      (id_ex_mem_re),
        .id_ex_valid       (id_ex_valid),
        .branch_mispredict (branch_mispredict),
        .md_busy           (md_busy),
        .trap              (csr_trap),
        .mret              (id_ex_mret & id_ex_valid),
        .stall_if          (stall_if),
        .stall_id          (stall_id),
        .stall_ex          (stall_ex),
        .stall_mem         (stall_mem),
        .flush_if_id       (flush_if_id),
        .flush_id_ex       (flush_id_ex),
        .flush_ex_mem      (flush_ex_mem)
    );

endmodule
