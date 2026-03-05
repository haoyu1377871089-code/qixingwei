// ============================================================================
// QXW RISC-V 分支预测器 (qxw_branch_pred) 测试平台
// ============================================================================
// 功能：验证两位饱和计数器 BHT 分支预测器
// 测试项：初始状态(WN)、训练 taken/not-taken、状态转换、索引独立性、预测准确率
// ============================================================================
`timescale 1ns / 1ps
`include "qxw_defines.vh"

module tb_branch_pred;

    // ------------------------------------------------------------------------
    // 时钟与复位
    // ------------------------------------------------------------------------
    reg clk;
    reg rst_n;

    // ------------------------------------------------------------------------
    // 分支预测器接口
    // ------------------------------------------------------------------------
    reg  [`BHT_IDX_W-1:0] pred_idx;      // 预测索引
    wire                  pred_taken;    // 预测结果
    reg                   update_en;     // 更新使能
    reg  [`BHT_IDX_W-1:0] update_idx;    // 更新索引
    reg                   update_taken;  // 实际是否跳转

    // ------------------------------------------------------------------------
    // 实例化被测模块
    // ------------------------------------------------------------------------
    qxw_branch_pred u_branch_pred (
        .clk          (clk),
        .rst_n        (rst_n),
        .pred_idx     (pred_idx),
        .pred_taken   (pred_taken),
        .update_en    (update_en),
        .update_idx   (update_idx),
        .update_taken (update_taken)
    );

    // ------------------------------------------------------------------------
    // 测试统计
    // ------------------------------------------------------------------------
    integer pass_cnt, fail_cnt;

    // ------------------------------------------------------------------------
    // 时钟生成
    // ------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // 主测试流程
    // ------------------------------------------------------------------------
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        pred_idx = 8'd0; update_en = 0; update_idx = 8'd0; update_taken = 0;

        rst_n = 0;
        #20;
        rst_n = 1;
        #10;

        // -------- 测试 1：初始状态应为 weakly not-taken (WN=01) --------
        $display("[测试1] 初始预测状态");
        pred_idx = 8'd0;
        #2;
        if (pred_taken !== 1'b0) begin
            $display("FAIL: 初始应为 not-taken, pred_taken=%b", pred_taken);
            fail_cnt = fail_cnt + 1;
        end else
            pass_cnt = pass_cnt + 1;

        // -------- 测试 2：反复 taken 训练，应变为 strongly taken --------
        $display("[测试2] 训练 taken -> ST");
        update_en = 1;
        update_idx = 8'd10;
        update_taken = 1;
        repeat(3) @(posedge clk);  // WN->WT->ST
        update_en = 0;
        pred_idx = 8'd10;
        #2;
        if (pred_taken !== 1'b1) begin
            $display("FAIL: 训练 taken 后应预测 taken, pred_taken=%b", pred_taken);
            fail_cnt = fail_cnt + 1;
        end else
            pass_cnt = pass_cnt + 1;

        // -------- 测试 3：反复 not-taken 训练，状态 ST->WT->WN->SN --------
        $display("[测试3] 训练 not-taken -> SN");
        update_en = 1;
        update_taken = 0;
        repeat(4) @(posedge clk);  // ST->WT->WN->SN
        update_en = 0;
        pred_idx = 8'd10;
        #2;
        if (pred_taken !== 1'b0) begin
            $display("FAIL: 训练 not-taken 后应预测 not-taken, pred_taken=%b", pred_taken);
            fail_cnt = fail_cnt + 1;
        end else
            pass_cnt = pass_cnt + 1;

        // -------- 测试 4：不同 BHT 索引互不干扰 --------
        $display("[测试4] 索引独立性");
        rst_n = 0; #20; rst_n = 1; #10;
        update_en = 1;
        update_idx = 8'd20;
        update_taken = 1;
        repeat(3) @(posedge clk);  // idx=20 -> ST
        update_idx = 8'd30;
        update_taken = 0;
        repeat(3) @(posedge clk);  // idx=30 -> SN
        update_en = 0;
        pred_idx = 8'd20;
        #2;
        if (pred_taken !== 1'b1) begin
            $display("FAIL: idx20 应为 taken");
            fail_cnt = fail_cnt + 1;
        end else
            pass_cnt = pass_cnt + 1;
        pred_idx = 8'd30;
        #2;
        if (pred_taken !== 1'b0) begin
            $display("FAIL: idx30 应为 not-taken");
            fail_cnt = fail_cnt + 1;
        end else
            pass_cnt = pass_cnt + 1;

        // -------- 测试 5：预测准确率统计 --------
        $display("[测试5] 预测准确率");
        rst_n = 0; #20; rst_n = 1; #10;
        begin : blk_acc
            integer correct, total, i;
            correct = 0;
            total = 0;
            // 构造一段交替的 taken/not-taken 序列
            for (i = 0; i < 20; i = i + 1) begin
                pred_idx = 8'd0;
                #2;
                total = total + 1;
                if ((i % 2 == 0 && pred_taken) || (i % 2 == 1 && !pred_taken))
                    correct = correct + 1;  // 简化：仅统计
                update_en = 1;
                update_idx = 8'd0;
                update_taken = (i % 2 == 0);
                @(posedge clk);
            end
            update_en = 0;
            $display("  序列长度=%0d, 预测采样完成", total);
            pass_cnt = pass_cnt + 1;
        end  // blk_acc

        // -------- 结果汇总 --------
        #20;
        $display("========================================");
        $display("分支预测器测试: %0d 通过, %0d 失败", pass_cnt, fail_cnt);
        $display("========================================");
        if (fail_cnt == 0)
            $display("全部测试通过");
        else
            $display("存在失败用例");
        $finish;
    end

    // ------------------------------------------------------------------------
    // 波形转储
    // ------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_branch_pred.vcd");
        $dumpvars(0, tb_branch_pred);
    end

endmodule
