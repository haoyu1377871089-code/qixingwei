`include "qxw_defines.vh"

// 取指阶段：发出取指地址，接收指令，与分支预测器交互
// 输出 IF/ID 级间寄存器信号
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
    input  wire [`XLEN_BUS]  bpu_pred_target,

    // IF/ID 级间寄存器输出
    output reg  [`XLEN_BUS]  if_id_pc,
    output reg  [`INST_BUS]  if_id_inst,
    output reg               if_id_pred_taken,
    output reg  [`XLEN_BUS]  if_id_pred_target,
    output reg               if_id_valid
);

    assign imem_addr = pc;
    assign bpu_idx   = pc[`BHT_IDX_W+1:2];

    // 快速分支目标计算（用于 BPU 预测）
    // B-type 偏移量从 IF 阶段指令中提取
    wire [31:0] b_imm = {{20{imem_rdata[31]}}, imem_rdata[7],
                          imem_rdata[30:25], imem_rdata[11:8], 1'b0};
    wire is_branch = (imem_rdata[6:0] == `OPCODE_BRANCH);

    // IF/ID 级间寄存器
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
