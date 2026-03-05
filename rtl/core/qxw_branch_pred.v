`include "qxw_defines.vh"

// ================================================================
// 分支预测器（Branch Predictor）
// ================================================================
// 基于两位饱和计数器的 BHT（Branch History Table）
// 256 项，使用 PC[9:2] 作为索引（8 位，覆盖 1KB 指令地址空间）
// 
// 两位饱和计数器状态转移：
//   SN(00) <-> WN(01) <-> WT(10) <-> ST(11)
//   taken 时递增（直到 ST 饱和），not-taken 时递减（直到 SN 饱和）
//   预测规则：计数器 bit[1]=1（WT 或 ST）时预测 taken
//   初始状态为 WN（weakly not-taken），偏向不跳转
//
// 预测在 IF 阶段读取（组合逻辑），更新在 EX 阶段写入（时序逻辑）
// 读写可能同时命中同一索引，但由于更新是下一拍生效，
// 当前拍的预测使用旧值（这是可接受的一拍学习延迟）
// ================================================================
module qxw_branch_pred (
    input  wire                     clk,
    input  wire                     rst_n,

    // 预测接口（IF 阶段）
    input  wire [`BHT_IDX_W-1:0]   pred_idx,
    output wire                     pred_taken,

    // 更新接口（EX 阶段）
    input  wire                     update_en,
    input  wire [`BHT_IDX_W-1:0]   update_idx,
    input  wire                     update_taken    // 实际是否跳转
);

    // BHT 存储阵列：256 项 x 2-bit 饱和计数器
    reg [1:0] bht [`BHT_ENTRIES-1:0];

    // 预测逻辑：取计数器的高位（bit[1]）作为预测结果
    // bit[1]=1（WT=10 或 ST=11）时预测 taken
    // bit[1]=0（SN=00 或 WN=01）时预测 not-taken
    assign pred_taken = bht[pred_idx][1];

    // 更新：两位饱和计数器状态机
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < `BHT_ENTRIES; i = i + 1)
                bht[i] <= `BHT_WN;  // 初始化为 weakly not-taken
        end else if (update_en) begin
            if (update_taken) begin
                if (bht[update_idx] != `BHT_ST)
                    bht[update_idx] <= bht[update_idx] + 2'd1;
            end else begin
                if (bht[update_idx] != `BHT_SN)
                    bht[update_idx] <= bht[update_idx] - 2'd1;
            end
        end
    end

endmodule
