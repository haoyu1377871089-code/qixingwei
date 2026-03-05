`include "qxw_defines.vh"

// ================================================================
// CPU 核心顶层模块
// ================================================================
// 五级流水线 RV32IM 处理器核心，采用经典的 IF-ID-EX-MEM-WB 架构
// 
// 微架构特征：
//   - 全旁路转发（EX/MEM 和 MEM/WB 两级前递），消除大部分 RAW 数据冒险
//   - Load-Use 冒险检测：插入一拍气泡等待数据从 MEM 返回
//   - 两位饱和计数器分支预测（BHT），降低条件分支的 CPI 开销
//   - M 扩展：乘法单周期完成（组合逻辑），除法 32 周期恢复余数法
//   - 基础中断支持：Timer 中断经 CSR 使能后触发 trap 进入 mtvec
//
// 对外接口：
//   - 指令存储器接口（imem）：组合读，地址由 PC 寄存器驱动
//   - 数据存储器接口（dmem）：字节使能写入，组合读，地址由 EX 阶段 ALU 计算
//   - timer_irq：外部 Timer 中断信号，与 CSR mie/mstatus 配合决定是否响应
// ================================================================
module qxw_cpu_top (
    // 全局时钟与异步低电平复位
    input  wire              clk,
    input  wire              rst_n,

    // 指令存储器接口（哈佛架构指令端口，BRAM 同步读）
    // imem_addr 由 PC 寄存器驱动，imem_en 控制 BRAM 读使能
    output wire [`XLEN_BUS]  imem_addr,
    output wire              imem_en,
    input  wire [`XLEN_BUS]  imem_rdata,

    // 数据存储器接口（经 SoC 总线路由到 RAM/外设）
    // dmem_en 为访存使能，dmem_we[3:0] 为字节写使能
    // dmem_addr 由 EX 阶段 ALU 计算，dmem_rdata 为组合读返回
    output wire              dmem_en,
    output wire [3:0]        dmem_we,
    output wire [`XLEN_BUS]  dmem_addr,
    output wire [`XLEN_BUS]  dmem_wdata,
    input  wire [`XLEN_BUS]  dmem_rdata,

    // 外部 Timer 中断请求信号（电平触发）
    input  wire              timer_irq
);

    // ================================================================
    // 内部连线声明（五级流水线数据通路：IF->ID->EX->MEM->WB）
    // ================================================================
    // 数据通路总览：
    //   PC_REG --[pc]--> IF_STAGE --[if_id_*]--> ID_STAGE --[id_ex_*]--> EX_STAGE
    //   EX_STAGE --[ex_mem_*]--> MEM_STAGE --[mem_wb_*]--> WB_STAGE --> REGFILE
    //
    // 控制通路：
    //   HAZARD_CTRL 根据 Load-Use / 分支误预测 / MulDiv 忙 / trap
    //   生成各级 stall 与 flush 信号，协调流水线数据一致性

    // 当前 PC 值与下一拍 PC 的组合逻辑选择结果
    wire [`XLEN_BUS] pc;
    wire [`XLEN_BUS] next_pc;

    // 冒险控制信号：stall 暂停对应级，flush 将对应级间寄存器清零
    // stall_if/id：Load-Use 或 MulDiv 忙时冻结前端取指和译码
    // stall_ex：仅 MulDiv 忙时冻结执行级，保持 ID/EX 内容不变
    // flush_if_id：分支误预测或 trap 时清除已取的错误指令
    // flush_id_ex：同上，外加 Load-Use 气泡时清除 EX 的控制信号
    // flush_ex_mem：仅 trap 时清除，防止异常指令的副作用传入 MEM
    wire stall_if, stall_id, stall_ex, stall_mem;
    wire flush_if_id, flush_id_ex, flush_ex_mem;

    // EX 阶段分支判断结果：taken 表示实际跳转，target 为实际目标地址
    // mispredict 综合了 taken/not-taken 与预测方向/目标的比较
    wire              branch_taken;
    wire [`XLEN_BUS]  branch_target;
    wire              branch_mispredict;

    // BPU 预测接口：IF 阶段用 PC[9:2] 索引 BHT，得到 taken 预测
    // pred_idx 同时传入 BPU 读端口和 IF_STAGE 用于记录到级间寄存器
    wire [`BHT_IDX_W-1:0] bpu_pred_idx;
    wire              bpu_pred_taken;

    // IF/ID 级间寄存器输出：传递取指结果与分支预测信息到译码级
    // if_id_valid 为 0 时表示该级内容无效（刚复位或被 flush），后续不产生副作用
    // pred_taken/pred_target 需保留到 EX 阶段与实际结果比较以判断是否 mispredict
    wire [`XLEN_BUS]  if_id_pc;
    wire [`INST_BUS]  if_id_inst;
    wire              if_id_pred_taken;
    wire [`XLEN_BUS]  if_id_pred_target;
    wire              if_id_valid;

    // 寄存器堆读写接口
    // rs1/rs2 由 ID 阶段从指令字段提取后驱动；写端口由 WB 阶段驱动
    // 寄存器堆内部实现写优先读，同周期写读同地址时直接旁路写数据
    wire [`REG_ADDR_BUS] rs1_addr, rs2_addr;
    wire [`XLEN_BUS]     rs1_data, rs2_data;
    wire                 rf_we;
    wire [`REG_ADDR_BUS] rf_wa;
    wire [`XLEN_BUS]     rf_wd;

    // ID/EX 级间寄存器：传递译码结果到执行级
    // 包含操作数（rs1_data/rs2_data/imm）、ALU 控制（alu_op/src_a/src_b）、
    // 访存控制（mem_re/mem_we）、写回选择（wb_sel）、分支类型（br_type）、
    // 乘除法操作码（md_op）、CSR 操作（csr_we/csr_op/csr_addr）等
    // 当 EX 级 stall 且 ID 无新数据时，hold 信号保持 ID/EX 不变
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

    // 转发单元输出：经过 EX/MEM 和 MEM/WB 两级前递后的操作数
    // fwd_sel_a/b 指示当前选择路径（00=原始值，01=EX/MEM，10=MEM/WB）
    // 转发后的数据直接送入 EX 阶段的 ALU 和分支比较器
    wire [`XLEN_BUS]     fwd_rs1_data, fwd_rs2_data;
    wire [1:0]           fwd_sel_a, fwd_sel_b;

    // ALU 接口：纯组合逻辑，EX 阶段选择操作数后驱动，结果同拍可用
    wire [`ALU_OP_BUS]   alu_op;
    wire [`XLEN_BUS]     alu_op_a, alu_op_b, alu_result;
    wire                 alu_zero;

    // 乘除法单元接口
    // md_start 由 cpu_top 生成的单拍脉冲驱动（md_start_pulse），防止重复触发
    // md_busy 在除法运算期间拉高，作为 stall 信号源
    // md_valid 在结果就绪时拉高一拍，EX 阶段据此锁存结果到 EX/MEM
    wire                 md_start;
    wire [`MD_OP_BUS]    md_op;
    wire [`XLEN_BUS]     md_op_a, md_op_b, md_result;
    wire                 md_busy, md_valid;

    // EX/MEM 级间寄存器：传递执行结果到访存级
    // alu_result 同时用作访存地址（Load/Store）和算术结果（写回）
    // rs2_data 经转发后用于 Store 的写数据
    // csr_we/csr_op/csr_addr/csr_wdata 在 MEM 和 WB 阶段依次传递，最终在 WB 写入 CSR
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

    // MEM/WB 级间寄存器：传递访存结果到写回级
    // wb_sel 决定写回数据来源：ALU 结果 / MEM 数据 / PC+4 / CSR 旧值
    // funct3/byte_offset 传递到 WB 阶段供 load 数据字节提取使用
    wire [`XLEN_BUS]     mem_wb_pc;
    wire [`XLEN_BUS]     mem_wb_alu_result;
    wire [`REG_ADDR_BUS] mem_wb_rd;
    wire                 mem_wb_reg_we;
    wire [`WB_SEL_BUS]   mem_wb_wb_sel;
    wire [2:0]           mem_wb_funct3;
    wire [1:0]           mem_wb_byte_offset;
    wire                 mem_wb_csr_we;
    wire [2:0]           mem_wb_csr_op;
    wire [11:0]          mem_wb_csr_addr;
    wire [`XLEN_BUS]     mem_wb_csr_wdata;
    wire                 mem_wb_valid;

    // CSR 接口：读端口在 WB 阶段提供旧值用于 CSRRW/CSRRS/CSRRC 的写回
    // mtvec 为 trap 入口地址，mepc 为 MRET 返回地址
    // trap 信号在 ECALL 或 timer 中断挂起时拉高，触发 PC 跳转和流水线冲刷
    wire [`XLEN_BUS]     csr_rdata;
    wire [`XLEN_BUS]     csr_mtvec;
    wire [`XLEN_BUS]     csr_mepc;
    wire                 csr_trap;

    // 从 IF/ID 指令字段直接提取 rs1/rs2 地址，用于冒险检测单元
    // 需要在 ID 阶段而非 EX 阶段检测 Load-Use，因为 stall 需要在
    // 下一拍生效前阻止 ID/EX 寄存器更新，提前一级检测才来得及
    wire [`REG_ADDR_BUS] id_rs1_for_hazard = if_id_inst[19:15];
    wire [`REG_ADDR_BUS] id_rs2_for_hazard = if_id_inst[24:20];

    // BPU 预测目标（从 IF stage 内部计算）
    wire [`XLEN_BUS] bpu_pred_target;

    // ================================================================
    // 乘除法启动脉冲生成与 stall 逻辑
    // ================================================================
    // md_started_r 是一个"已启动"标志寄存器，配合 stall 实现单脉冲启动：
    //   - 除法运算需要 32 周期，期间 md_busy=1，流水线 stall
    //   - stall 导致 ID/EX 寄存器内容保持不变（hold），id_ex_is_muldiv 持续为 1
    //   - 若不加限制，md_start 会在每个 stall 拍都为 1，重复启动除法器
    //   - md_started_r 在首次发出 pulse 后置 1，屏蔽后续拍的 start
    //   - 当 stall 解除（stall_ex=0）时 md_started_r 清零，为下条指令做准备
    //
    // 时序关系（以 DIV 为例）：
    //   T0: id_ex_is_muldiv=1, md_busy=0, md_started_r=0 -> pulse=1, 启动除法
    //   T1: md_busy=1, md_started_r=1 -> pulse=0, stall 持续
    //   T2~T32: md_busy=1, pulse=0, 除法迭代
    //   T33: md_busy=0, md_valid=1, stall 解除 -> md_started_r 清零
    reg md_started_r;
    wire md_start_pulse = id_ex_is_muldiv & id_ex_valid & !md_busy & !md_started_r;

    // md_started_r 状态转移：复位清零，stall 解除时清零，首次脉冲时置位
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            md_started_r <= 1'b0;
        else if (!stall_ex)
            md_started_r <= 1'b0;
        else if (md_start_pulse)
            md_started_r <= 1'b1;
    end

    // div_start_stall 解决除法启动的时序空隙问题：
    // 除法器在 start 脉冲的下一拍才拉高 md_busy，而当前拍 md_busy 仍为 0
    // 如果不在当前拍就产生 stall，流水线会在下一拍正常推进，覆盖 ID/EX 中的除法指令
    // 乘法是单周期操作无需 stall；除零时除法器不进入运行态，也无需 stall
    // 条件：是除法操作（md_op >= DIV）且除数非零（|fwd_rs2_data != 0）
    wire div_start_stall = md_start_pulse
                           & (id_ex_md_op >= `MD_DIV) & (|fwd_rs2_data);
    wire md_stall = md_busy | div_start_stall;

    // ================================================================
    // 模块实例化（按流水线级别顺序排列）
    // ================================================================
    // 实例化顺序：PC_REG -> BPU -> IF -> REGFILE -> ID -> FWD -> ALU -> MULDIV
    //            -> EX -> MEM -> WB -> CSR -> HAZARD_CTRL

    // --- PC 寄存器 ---
    // next_pc 优先级链（从高到低）：
    //   trap -> mtvec | mret -> mepc | 分支误预测恢复 -> 正确PC
    //   | BPU 预测跳转 -> 预测目标 | 默认 -> PC+4
    // pred_taken 在 flush 时被屏蔽，避免误预测恢复期间 BPU 预测干扰
    // flush_target 在实际跳转时用 branch_target，否则用 PC+4（不该跳却预测跳）
    qxw_pc_reg u_pc_reg (
        .clk           (clk),
        .rst_n         (rst_n),
        .stall         (stall_if),
        .branch_taken  (branch_taken),
        .branch_target (branch_target),
        .pred_taken    (1'b0),  // BRAM 同步读模式下禁用 IF 阶段预测
        .pred_target   (32'd0),
        .flush         (branch_mispredict),
        .flush_target  (branch_taken ? branch_target : (id_ex_pc + 32'd4)),  // 预测错时跳正确目标
        .trap          (csr_trap),
        .trap_target   (csr_mtvec),
        .mret          (id_ex_mret & id_ex_valid),
        .mepc          (csr_mepc),
        .pc            (pc),
        .next_pc       (next_pc)
    );

    // --- 分支预测器（两位饱和计数器 BHT）---
    // 预测在 IF 阶段完成，更新在 EX 阶段完成（分支结果已知时反馈）
    // JAL 无条件跳转不经过 BPU 更新，因为它总是跳转无需学习
    // update_idx 使用 id_ex_pc 而非 if_id_pc，对应发出分支的指令地址
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
    // IMEM 使用 BRAM 同步读，地址在 T 拍采样，数据在 T+1 拍输出
    // imem_en 控制 BRAM 读使能，stall 时 en=0 保持输出不变
    qxw_if_stage u_if_stage (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall            (stall_if),
        .flush            (flush_if_id),
        .pc               (pc),
        .imem_addr        (imem_addr),
        .imem_en          (imem_en),
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

    // --- 寄存器堆（32x32-bit，x0 硬连线为 0）---
    // 双读端口供 ID 阶段同时读取 rs1 和 rs2
    // 单写端口由 WB 阶段的 rf_we/rf_wa/rf_wd 驱动
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
    // 将 IF/ID 中的指令解码为控制信号和立即数，锁存到 ID/EX 级间寄存器
    // hold 信号区别于 stall：stall 时若 hold=0 则插入气泡（清控制信号），
    // hold=1 则完全保持 ID/EX 内容（用于 MulDiv 忙时保护执行中的指令）
    qxw_id_stage u_id_stage (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall            (stall_id),
        .flush            (flush_id_ex),
        .hold             (stall_ex),
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
    // 两级前递消除 RAW 数据冒险：
    //   EX/MEM 前递：上一条指令的 ALU 结果直接旁路到当前 EX 阶段操作数
    //   MEM/WB 前递：上上条指令的写回结果旁路到当前 EX 阶段操作数
    // 优先级 EX/MEM > MEM/WB，保证使用最新的值
    // mem_wb_wd 使用 WB 阶段最终选择后的数据（rf_wd），包含 Load/CSR 等结果
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

    // --- ALU（纯组合逻辑，无流水线寄存器）---
    // 由 EX 阶段驱动操作码和操作数，结果同拍传入 EX/MEM 级间寄存器
    qxw_alu u_alu (
        .alu_op (alu_op),
        .op_a   (alu_op_a),
        .op_b   (alu_op_b),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // --- 乘除法单元（M 扩展）---
    // 乘法为单周期组合逻辑，除法为 32 周期恢复余数迭代
    // start 使用 md_start_pulse 而非原始 md_start，由 md_started_r 防重复触发
    // busy 信号反馈给 hazard_ctrl 产生全流水线 stall
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
    // 功能：ALU 运算、分支条件判断与目标计算、乘除法接口、CSR 数据准备
    // 转发后的操作数 fwd_rs1/rs2_data 同时送入 ALU、分支比较器和 MulDiv
    // 分支误预测信号直接反馈给 hazard_ctrl，触发前端冲刷
    // stall 时 EX/MEM 保持不变（不清零），flush 时 EX/MEM 全部清零
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
    // Store：将 rs2 数据按 funct3（SB/SH/SW）对齐并生成字节使能
    // DMEM 使用 BRAM 同步读，读数据在 WB 阶段才可用
    // funct3/byte_offset 传递到 WB 阶段供 load 字节提取
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
        .mem_wb_pc        (mem_wb_pc),
        .mem_wb_alu_result(mem_wb_alu_result),
        .mem_wb_rd        (mem_wb_rd),
        .mem_wb_reg_we    (mem_wb_reg_we),
        .mem_wb_wb_sel    (mem_wb_wb_sel),
        .mem_wb_funct3    (mem_wb_funct3),
        .mem_wb_byte_offset(mem_wb_byte_offset),
        .mem_wb_csr_we    (mem_wb_csr_we),
        .mem_wb_csr_op    (mem_wb_csr_op),
        .mem_wb_csr_addr  (mem_wb_csr_addr),
        .mem_wb_csr_wdata (mem_wb_csr_wdata),
        .mem_wb_valid     (mem_wb_valid)
    );

    // --- 写回阶段 ---
    // DMEM 同步读数据在 WB 阶段可用，load 字节提取在此完成
    qxw_wb_stage u_wb_stage (
        .mem_wb_pc         (mem_wb_pc),
        .mem_wb_alu_result (mem_wb_alu_result),
        .mem_wb_rd         (mem_wb_rd),
        .mem_wb_reg_we     (mem_wb_reg_we),
        .mem_wb_wb_sel     (mem_wb_wb_sel),
        .mem_wb_funct3     (mem_wb_funct3),
        .mem_wb_byte_offset(mem_wb_byte_offset),
        .mem_wb_valid      (mem_wb_valid),
        .dmem_rdata_wb     (dmem_rdata),
        .csr_rdata         (csr_rdata),
        .rf_we             (rf_we),
        .rf_wa             (rf_wa),
        .rf_wd             (rf_wd)
    );

    // --- CSR 寄存器模块 ---
    // CSR 的读写时序设计：
    //   读端口（raddr/rdata）：WB 阶段读取 CSR 旧值，写回到寄存器堆的 rd
    //   写端口（waddr/wdata/wop）：WB 阶段写入新值，通过 mem_wb 级间寄存器传递
    //   ECALL/MRET：由 EX 阶段的 id_ex 信号驱动，比写端口早两级
    //   这样设计确保 ECALL 在 EX 阶段就触发 trap，及时冲刷后续错误指令
    // epc 使用 id_ex_pc，记录触发异常的指令地址（EX 阶段的 PC）
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

    // --- 冒险控制单元 ---
    // 集中管理所有流水线冒险的检测与处理：
    //   1. Load-Use 冒险：EX 级 Load 的 rd 与 ID 级 rs1/rs2 匹配 -> stall IF/ID + bubble EX
    //   2. 分支误预测：branch_mispredict=1 -> flush IF/ID 和 ID/EX
    //   3. MulDiv 忙：md_stall 包含 md_busy 和 div_start_stall -> stall 全流水线
    //   4. Trap/MRET：触发三级 flush，清除所有在执行中的指令
    // md_busy 端口连接的是 md_stall（组合了 md_busy 和 div_start_stall），
    // 确保除法启动首拍就能 stall，不等 md_busy 下拍才拉高
    qxw_hazard_ctrl u_hazard_ctrl (
        .id_rs1            (id_rs1_for_hazard),
        .id_rs2            (id_rs2_for_hazard),
        .id_ex_rd          (id_ex_rd),
        .id_ex_mem_re      (id_ex_mem_re),
        .id_ex_valid       (id_ex_valid),
        .branch_mispredict (branch_mispredict),
        .md_busy           (md_stall),  // 含 div_start_stall，除法启动首拍即 stall
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
