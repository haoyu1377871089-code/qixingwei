`include "qxw_defines.vh"

// ================================================================
// 取指阶段（IF Stage）—— BRAM 同步读适配版
// ================================================================
// IMEM 使用 BRAM 同步读，地址在 T 拍采样，数据在 T+1 拍输出。
// 因此 BRAM 输出寄存器天然充当 IF/ID 级间寄存器的 inst 字段。
//
// 时序模型：
//   T 拍上升沿：PC 更新为 addr_A，BRAM 采样 addr_A
//   T+1 拍：BRAM 输出 mem[addr_A]，即 imem_rdata = 指令 A
//   T+1 拍上升沿：IF/ID 锁存 PC_A 和 imem_rdata（指令 A）
//
// 为此 IF/ID 的 PC 也需要延迟一拍（pc_r），与 BRAM 输出对齐。
// 分支预测的 B-type 偏移量从 imem_rdata（已延迟一拍的指令）中提取，
// 预测目标 = pc_r + b_imm，与指令对应的 PC 一致。
//
// stall 时 BRAM en=0 保持输出不变，pc_r 也保持不变。
// flush 时将 if_id_inst 替换为 NOP，清除预测信息。
// ================================================================
module qxw_if_stage (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              stall,
    input  wire              flush,

    input  wire [`XLEN_BUS]  pc,

    // 指令存储器接口（BRAM 同步读）
    output wire [`XLEN_BUS]  imem_addr,
    output wire              imem_en,
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

    assign imem_addr = pc;
    assign imem_en   = !stall;

    // 延迟一拍的 PC，与 BRAM 输出对齐
    reg [`XLEN_BUS] pc_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc_r <= `RST_PC;
        else if (!stall)
            pc_r <= pc;
    end

    // BRAM 就绪标志：复位后和 flush 后需要一拍等待 BRAM 输出有效数据
    // flush/trap/mret 改变 PC 后，BRAM 需要一拍采样新地址并输出指令
    // 在此期间 IF/ID 必须保持无效，避免锁存旧指令
    reg bram_valid;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bram_valid <= 1'b0;
        else if (flush)
            bram_valid <= 1'b0;
        else
            bram_valid <= 1'b1;
    end

    assign bpu_idx = pc[`BHT_IDX_W+1:2];

    wire [31:0] b_imm = {{20{imem_rdata[31]}}, imem_rdata[7],
                          imem_rdata[30:25], imem_rdata[11:8], 1'b0};

    assign bpu_pred_target = 32'd0;

    // IF/ID 级间寄存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc          <= 32'd0;
            if_id_inst        <= 32'h0000_0013;
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
            if_id_pc          <= pc_r;
            if_id_inst        <= imem_rdata;
            if_id_pred_taken  <= 1'b0;
            if_id_pred_target <= 32'd0;
            if_id_valid       <= bram_valid;
        end
    end

endmodule
