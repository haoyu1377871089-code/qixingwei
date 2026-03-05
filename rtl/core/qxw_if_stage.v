`include "qxw_defines.vh"

// ================================================================
// 取指阶段（IF Stage）
// ================================================================
// 职责：驱动指令存储器地址，接收指令数据，管理 IF/ID 级间寄存器
// 
// 与分支预测器的交互：
//   IF 阶段从当前 PC 的低位提取 BHT 索引，查询预测结果
//   同时从指令的 B-type 编码中提取偏移量，计算预测跳转目标 = PC + b_imm
//   仅当指令确实是 BRANCH 类型且 BPU 预测 taken 时，才记录 pred_taken=1
//   预测信息随指令一起传递到 EX 阶段，用于误预测检测
//
// flush 优先于 stall：即使流水线暂停，冲刷请求仍会清除 IF/ID 内容
// ================================================================
module qxw_if_stage (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              stall,
    input  wire              flush,

    // 来自 PC
    input  wire [`XLEN_BUS]  pc,

    // 指令存储器接口
    output wire [`XLEN_BUS]  imem_addr,
    input  wire [`XLEN_BUS]  imem_rdata,

    // 分支预测器接口
    output wire [`BHT_IDX_W-1:0] bpu_idx,
    input  wire              bpu_pred_taken,
    output wire [`XLEN_BUS]  bpu_pred_target,

    // IF/ID 级间寄存器输出
    output reg  [`XLEN_BUS]  if_id_pc,
    output reg  [`INST_BUS]  if_id_inst,
    output reg               if_id_pred_taken,
    output reg  [`XLEN_BUS]  if_id_pred_target,
    output reg               if_id_valid
);

    // 指令存储器地址直接由 PC 驱动，组合读取
    assign imem_addr = pc;
    // BHT 索引取 PC[9:2]（跳过低 2 位的字节对齐位）
    assign bpu_idx   = pc[`BHT_IDX_W+1:2];

    // B-type 偏移量提取：从当前取到的指令中解码 B 型立即数
    // 用于在 IF 阶段就计算分支预测目标（PC + b_imm），无需等到 ID 阶段
    wire [31:0] b_imm = {{20{imem_rdata[31]}}, imem_rdata[7],
                          imem_rdata[30:25], imem_rdata[11:8], 1'b0};
    // 检查当前指令是否为 BRANCH 类型，仅 BRANCH 指令才使用 BPU 预测
    wire is_branch = (imem_rdata[6:0] == `OPCODE_BRANCH);

    assign bpu_pred_target = pc + b_imm;

    // IF/ID 级间寄存器：锁存当前取指结果供 ID 阶段使用
    // flush 时插入 NOP（addi x0, x0, 0 = 0x00000013），清除预测信息
    // stall 时完全保持，确保 ID 阶段看到的指令不丢失
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc          <= 32'd0;
            if_id_inst        <= 32'h0000_0013; // NOP (addi x0, x0, 0)
            if_id_pred_taken  <= 1'b0;
            if_id_pred_target <= 32'd0;
            if_id_valid       <= 1'b0;
        end else if (flush) begin
            if_id_pc          <= 32'd0;
            if_id_inst        <= 32'h0000_0013;
            if_id_pred_taken  <= 1'b0;
            if_id_pred_target <= 32'd0;
            if_id_valid       <= 1'b0;
        end else if (!stall) begin
            if_id_pc          <= pc;
            if_id_inst        <= imem_rdata;
            if_id_pred_taken  <= is_branch & bpu_pred_taken;
            if_id_pred_target <= pc + b_imm;
            if_id_valid       <= 1'b1;
        end
    end

endmodule
