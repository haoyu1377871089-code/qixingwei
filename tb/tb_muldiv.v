// ============================================================================
// QXW RISC-V 乘除法单元 (qxw_muldiv) 测试平台
// ============================================================================
// 功能：验证 M 扩展乘除法单元
// 测试项：MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU 共 8 种操作
//         边界值、有符号/无符号、busy/valid 握手
// ============================================================================
`timescale 1ns / 1ps
`include "qxw_defines.vh"

module tb_muldiv;

    // ------------------------------------------------------------------------
    // 时钟与复位
    // ------------------------------------------------------------------------
    reg clk;
    reg rst_n;

    // ------------------------------------------------------------------------
    // 乘除法单元接口
    // ------------------------------------------------------------------------
    reg                 start;
    reg  [`MD_OP_BUS]   md_op;
    reg  [`XLEN_BUS]    op_a, op_b;
    wire [`XLEN_BUS]    result;
    wire                busy;
    wire                valid;

    // ------------------------------------------------------------------------
    // 实例化被测模块
    // ------------------------------------------------------------------------
    qxw_muldiv u_muldiv (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (start),
        .md_op  (md_op),
        .op_a   (op_a),
        .op_b   (op_b),
        .result (result),
        .busy   (busy),
        .valid  (valid)
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
    // 乘法检查任务：乘法为组合逻辑，result 立即可用，valid 下一拍拉高
    // ------------------------------------------------------------------------
    task check_mul;
        input [`XLEN_BUS] expected;
        input [255:0]    name;
        begin
            start = 1;
            @(posedge clk);
            start = 0;
            #1;  // 组合结果已稳定，采样 result
            if (result !== expected) begin
                $display("FAIL: %0s | got=%08h exp=%08h", name, result, expected);
                fail_cnt = fail_cnt + 1;
            end else
                pass_cnt = pass_cnt + 1;
        end
    endtask

    // ------------------------------------------------------------------------
    // 除法检查任务：等待 busy 结束，在 valid 拉高拍内采样
    // ------------------------------------------------------------------------
    task check_div;
        input [`XLEN_BUS] expected;
        input [255:0]    name;
        integer wait_cnt;
        begin
            start = 1;
            @(posedge clk);
            start = 0;
            wait_cnt = 0;
            while (busy && wait_cnt < 50) begin
                @(posedge clk);
                wait_cnt = wait_cnt + 1;
            end
            // 退出时处于 div_done 拍，采样 result（除法需 valid，此处仅验 result）
            if (result !== expected) begin
                $display("FAIL: %0s | got=%08h exp=%08h", name, result, expected);
                fail_cnt = fail_cnt + 1;
            end else
                pass_cnt = pass_cnt + 1;
        end
    endtask

    // ------------------------------------------------------------------------
    // 主测试流程
    // ------------------------------------------------------------------------
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        start = 0; md_op = 3'd0; op_a = 32'd0; op_b = 32'd0;

        rst_n = 0;
        #20;
        rst_n = 1;
        #20;

        // -------- MUL：有符号乘法低 32 位 --------
        $display("[MUL] 有符号乘法");
        md_op = `MD_MUL;
        op_a = 32'd10; op_b = 32'd20;
        check_mul(32'd200, "MUL 10*20");
        op_a = 32'hFFFF_FFFF; op_b = 32'd2;  // -1 * 2 = -2
        check_mul(32'hFFFF_FFFE, "MUL -1*2");
        op_a = 32'd0; op_b = 32'hFFFF_FFFF;
        check_mul(32'd0, "MUL 乘零");

        // -------- MULH：有符号乘法高 32 位 --------
        $display("[MULH] 有符号乘法高半");
        md_op = `MD_MULH;
        op_a = 32'h8000_0000; op_b = 32'd2;  // -2^31 * 2 = -2^32
        check_mul(32'hFFFF_FFFF, "MULH 负溢出");
        op_a = 32'd0; op_b = 32'hFFFF_FFFF;
        check_mul(32'd0, "MULH 乘零");

        // -------- MULHSU：有符号*无符号 高 32 位 --------
        $display("[MULHSU] 有符号*无符号高半");
        md_op = `MD_MULHSU;
        op_a = 32'hFFFF_FFFF; op_b = 32'd2;  // -1(有符号) * 2(无符号)
        check_mul(32'hFFFF_FFFF, "MULHSU -1*2");
        op_a = 32'd0; op_b = 32'hFFFF_FFFF;
        check_mul(32'd0, "MULHSU 乘零");

        // -------- MULHU：无符号乘法高 32 位 --------
        $display("[MULHU] 无符号乘法高半");
        md_op = `MD_MULHU;
        op_a = 32'hFFFF_FFFF; op_b = 32'hFFFF_FFFF;  // 最大无符号乘
        check_mul(32'hFFFF_FFFE, "MULHU max*max");
        op_a = 32'd0; op_b = 32'hFFFF_FFFF;
        check_mul(32'd0, "MULHU 乘零");

        // -------- DIV：有符号除法 --------
        $display("[DIV] 有符号除法");
        md_op = `MD_DIV;
        op_a = 32'd100; op_b = 32'd7;
        check_div(32'd14, "DIV 100/7");
        op_a = 32'hFFFF_FF9C; op_b = 32'd10;  // -100 / 10 = -10
        check_div(32'hFFFF_FFF6, "DIV -100/10");
        op_a = 32'd100; op_b = 32'd0;  // 除零：商=0xFFFFFFFF
        check_div(32'hFFFF_FFFF, "DIV 除零");

        // -------- DIVU：无符号除法 --------
        $display("[DIVU] 无符号除法");
        md_op = `MD_DIVU;
        op_a = 32'd100; op_b = 32'd7;
        check_div(32'd14, "DIVU 100/7");
        op_a = 32'hFFFF_FFFF; op_b = 32'd1;
        check_div(32'hFFFF_FFFF, "DIVU max/1");
        op_a = 32'd100; op_b = 32'd0;
        check_div(32'hFFFF_FFFF, "DIVU 除零");

        // -------- REM：有符号取余 --------
        $display("[REM] 有符号取余");
        md_op = `MD_REM;
        op_a = 32'd100; op_b = 32'd7;
        check_div(32'd2, "REM 100%%7");
        op_a = 32'hFFFF_FF9C; op_b = 32'd10;  // -100 % 10 = 0
        check_div(32'd0, "REM -100%%10");
        op_a = 32'd100; op_b = 32'd0;  // 除零：余数=被除数
        check_div(32'd100, "REM 除零");

        // -------- REMU：无符号取余 --------
        $display("[REMU] 无符号取余");
        md_op = `MD_REMU;
        op_a = 32'd100; op_b = 32'd7;
        check_div(32'd2, "REMU 100%%7");
        op_a = 32'd100; op_b = 32'd0;
        check_div(32'd100, "REMU 除零");

        // -------- busy/valid 握手：除法期间 busy 应持续拉高 --------
        $display("[握手] busy/valid 时序");
        md_op = `MD_DIV;
        op_a = 32'd100; op_b = 32'd7;
        start = 1;
        @(posedge clk);
        start = 0;
        if (!busy) begin
            $display("FAIL: 除法启动后 busy 应变高");
            fail_cnt = fail_cnt + 1;
        end else
            pass_cnt = pass_cnt + 1;
        repeat(35) @(posedge clk);  // 等待完成
        if (busy) begin
            $display("FAIL: 除法完成后 busy 应变低");
            fail_cnt = fail_cnt + 1;
        end else
            pass_cnt = pass_cnt + 1;

        // -------- 结果汇总 --------
        #20;
        $display("========================================");
        $display("乘除法单元测试: %0d 通过, %0d 失败", pass_cnt, fail_cnt);
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
        $dumpfile("tb_muldiv.vcd");
        $dumpvars(0, tb_muldiv);
    end

endmodule
