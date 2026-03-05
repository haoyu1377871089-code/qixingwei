`include "qxw_defines.vh"

// 两位饱和计数器 BHT（Branch History Table）
// 256 项，PC[9:2] 索引
// 状态：SN(00) -> WN(01) -> WT(10) -> ST(11)
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

    // BHT: 256 项 x 2-bit 饱和计数器
    reg [1:0] bht [`BHT_ENTRIES-1:0];

    // 预测：计数器 >= 2 (WT/ST) 时预测 taken
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
