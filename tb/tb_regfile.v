// ============================================================================
// QXW RISC-V 寄存器堆 (qxw_regfile) 测试平台
// ============================================================================
// 功能：验证 32x32-bit 双读单写寄存器堆的正确性
// 测试项：全寄存器读写、x0 恒零、写优先、复位清除
// ============================================================================
`timescale 1ns / 1ps
`include "qxw_defines.vh"

module tb_regfile;

    // ------------------------------------------------------------------------
    // 时钟与复位
    // ------------------------------------------------------------------------
    reg clk;
    reg rst_n;

    // ------------------------------------------------------------------------
    // 寄存器堆接口信号
    // ------------------------------------------------------------------------
    reg  [`REG_ADDR_BUS] ra1, ra2;      // 读地址
    wire [`XLEN_BUS]     rd1, rd2;      // 读数据
    reg                  we;            // 写使能
    reg  [`REG_ADDR_BUS] wa;            // 写地址
    reg  [`XLEN_BUS]     wd;            // 写数据

    // ------------------------------------------------------------------------
    // 实例化被测模块
    // ------------------------------------------------------------------------
    qxw_regfile u_regfile (
        .clk  (clk),
        .rst_n (rst_n),
        .ra1   (ra1),
        .rd1   (rd1),
        .ra2   (ra2),
        .rd2   (rd2),
        .we    (we),
        .wa    (wa),
        .wd    (wd)
    );

    // ------------------------------------------------------------------------
    // 测试统计
    // ------------------------------------------------------------------------
    integer pass_cnt, fail_cnt;

    // ------------------------------------------------------------------------
    // 时钟生成：10ns 周期
    // ------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // 检查任务：验证读端口数据是否符合预期
    // ------------------------------------------------------------------------
    task check_read;
        input [`XLEN_BUS] exp_rd1;
        input [`XLEN_BUS] exp_rd2;
        input [255:0]    name;
        begin
            if (rd1 !== exp_rd1 || rd2 !== exp_rd2) begin
                $display("FAIL: %0s | rd1: got=%08h exp=%08h | rd2: got=%08h exp=%08h",
                         name, rd1, exp_rd1, rd2, exp_rd2);
                fail_cnt = fail_cnt + 1;
            end else begin
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // 主测试流程
    // ------------------------------------------------------------------------
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;

        // 初始化输入
        ra1 = 5'd0; ra2 = 5'd0; we = 0; wa = 5'd0; wd = 32'd0;

        // -------- 复位 --------
        rst_n = 0;
        #20;
        rst_n = 1;
        #10;

        // -------- 测试 1：写入并读取所有 32 个寄存器 --------
        $display("[测试1] 全寄存器读写");
        repeat(2) @(posedge clk);  // 复位后空跑 2 拍
        we = 1;
        wa = 5'd1; wd = 32'h1001; @(posedge clk); @(posedge clk);  // x1 写两拍（仿真时序）
        wa = 5'd2; wd = 32'h1002; @(posedge clk);
        wa = 5'd3; wd = 32'h1003; @(posedge clk);
        wa = 5'd4; wd = 32'h1004; @(posedge clk);
        wa = 5'd5; wd = 32'h1005; @(posedge clk);
        wa = 5'd6; wd = 32'h1006; @(posedge clk);
        wa = 5'd7; wd = 32'h1007; @(posedge clk);
        wa = 5'd8; wd = 32'h1008; @(posedge clk);
        wa = 5'd9; wd = 32'h1009; @(posedge clk);
        wa = 5'd10; wd = 32'h100A; @(posedge clk);
        wa = 5'd11; wd = 32'h100B; @(posedge clk);
        wa = 5'd12; wd = 32'h100C; @(posedge clk);
        wa = 5'd13; wd = 32'h100D; @(posedge clk);
        wa = 5'd14; wd = 32'h100E; @(posedge clk);
        wa = 5'd15; wd = 32'h100F; @(posedge clk);
        wa = 5'd16; wd = 32'h1010; @(posedge clk);
        wa = 5'd17; wd = 32'h1011; @(posedge clk);
        wa = 5'd18; wd = 32'h1012; @(posedge clk);
        wa = 5'd19; wd = 32'h1013; @(posedge clk);
        wa = 5'd20; wd = 32'h1014; @(posedge clk);
        wa = 5'd21; wd = 32'h1015; @(posedge clk);
        wa = 5'd22; wd = 32'h1016; @(posedge clk);
        wa = 5'd23; wd = 32'h1017; @(posedge clk);
        wa = 5'd24; wd = 32'h1018; @(posedge clk);
        wa = 5'd25; wd = 32'h1019; @(posedge clk);
        wa = 5'd26; wd = 32'h101A; @(posedge clk);
        wa = 5'd27; wd = 32'h101B; @(posedge clk);
        wa = 5'd28; wd = 32'h101C; @(posedge clk);
        wa = 5'd29; wd = 32'h101D; @(posedge clk);
        wa = 5'd30; wd = 32'h101E; @(posedge clk);
        wa = 5'd31; wd = 32'h101F; @(posedge clk);
        we = 0;
        @(posedge clk);
        #10;

        // 读取验证
        ra1 = 5'd1; ra2 = 5'd2; #2;
        if (rd1 !== 32'h1001) begin $display("FAIL: x1"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd2; ra2 = 5'd3; #2;
        if (rd1 !== 32'h1002) begin $display("FAIL: x2"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd3; ra2 = 5'd4; #2;
        if (rd1 !== 32'h1003) begin $display("FAIL: x3"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd4; ra2 = 5'd5; #2;
        if (rd1 !== 32'h1004) begin $display("FAIL: x4"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd5; ra2 = 5'd6; #2;
        if (rd1 !== 32'h1005) begin $display("FAIL: x5"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd6; ra2 = 5'd7; #2;
        if (rd1 !== 32'h1006) begin $display("FAIL: x6"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd7; ra2 = 5'd8; #2;
        if (rd1 !== 32'h1007) begin $display("FAIL: x7"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd8; ra2 = 5'd9; #2;
        if (rd1 !== 32'h1008) begin $display("FAIL: x8"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd9; ra2 = 5'd10; #2;
        if (rd1 !== 32'h1009) begin $display("FAIL: x9"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd10; ra2 = 5'd11; #2;
        if (rd1 !== 32'h100A) begin $display("FAIL: x10"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd11; ra2 = 5'd12; #2;
        if (rd1 !== 32'h100B) begin $display("FAIL: x11"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd12; ra2 = 5'd13; #2;
        if (rd1 !== 32'h100C) begin $display("FAIL: x12"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd13; ra2 = 5'd14; #2;
        if (rd1 !== 32'h100D) begin $display("FAIL: x13"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd14; ra2 = 5'd15; #2;
        if (rd1 !== 32'h100E) begin $display("FAIL: x14"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd15; ra2 = 5'd16; #2;
        if (rd1 !== 32'h100F) begin $display("FAIL: x15"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd16; ra2 = 5'd17; #2;
        if (rd1 !== 32'h1010) begin $display("FAIL: x16"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd17; ra2 = 5'd18; #2;
        if (rd1 !== 32'h1011) begin $display("FAIL: x17"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd18; ra2 = 5'd19; #2;
        if (rd1 !== 32'h1012) begin $display("FAIL: x18"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd19; ra2 = 5'd20; #2;
        if (rd1 !== 32'h1013) begin $display("FAIL: x19"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd20; ra2 = 5'd21; #2;
        if (rd1 !== 32'h1014) begin $display("FAIL: x20"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd21; ra2 = 5'd22; #2;
        if (rd1 !== 32'h1015) begin $display("FAIL: x21"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd22; ra2 = 5'd23; #2;
        if (rd1 !== 32'h1016) begin $display("FAIL: x22"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd23; ra2 = 5'd24; #2;
        if (rd1 !== 32'h1017) begin $display("FAIL: x23"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd24; ra2 = 5'd25; #2;
        if (rd1 !== 32'h1018) begin $display("FAIL: x24"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd25; ra2 = 5'd26; #2;
        if (rd1 !== 32'h1019) begin $display("FAIL: x25"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd26; ra2 = 5'd27; #2;
        if (rd1 !== 32'h101A) begin $display("FAIL: x26"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd27; ra2 = 5'd28; #2;
        if (rd1 !== 32'h101B) begin $display("FAIL: x27"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd28; ra2 = 5'd29; #2;
        if (rd1 !== 32'h101C) begin $display("FAIL: x28"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd29; ra2 = 5'd30; #2;
        if (rd1 !== 32'h101D) begin $display("FAIL: x29"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd30; ra2 = 5'd31; #2;
        if (rd1 !== 32'h101E) begin $display("FAIL: x30"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;
        ra1 = 5'd31; ra2 = 5'd1; #2;
        if (rd1 !== 32'h101F) begin $display("FAIL: x31"); fail_cnt = fail_cnt + 1; end else pass_cnt = pass_cnt + 1;

        // -------- 测试 2：x0 恒为零 --------
        $display("[测试2] x0 恒零");
        we = 1; wa = 5'd0; wd = 32'hDEAD_BEEF;  // 尝试写入 x0
        @(posedge clk);
        we = 0;
        ra1 = 5'd0; ra2 = 5'd0;
        #2;
        if (rd1 !== 32'd0 || rd2 !== 32'd0) begin
            $display("FAIL: x0 应恒为 0, rd1=%08h rd2=%08h", rd1, rd2);
            fail_cnt = fail_cnt + 1;
        end else
            pass_cnt = pass_cnt + 1;

        // -------- 测试 3：写优先（同周期写读同一寄存器） --------
        $display("[测试3] 写优先");
        we = 1; wa = 5'd5; wd = 32'h1234_5678;
        ra1 = 5'd5; ra2 = 5'd5;  // 同时读 x5
        #2;  // 组合逻辑，应直接得到写入值
        if (rd1 !== 32'h1234_5678 || rd2 !== 32'h1234_5678) begin
            $display("FAIL: 写优先, rd1=%08h rd2=%08h exp=12345678", rd1, rd2);
            fail_cnt = fail_cnt + 1;
        end else
            pass_cnt = pass_cnt + 1;
        we = 0;

        // -------- 测试 4：复位清除 --------
        $display("[测试4] 复位清除");
        we = 1;
        wa = 5'd7; wd = 32'hCAFE_BABE;
        @(posedge clk);
        we = 0;
        rst_n = 0;
        #20;
        rst_n = 1;
        #10;
        ra1 = 5'd7; ra2 = 5'd1;
        #2;
        if (rd1 !== 32'd0 || rd2 !== 32'd0) begin
            $display("FAIL: 复位后应全为 0, rd1=%08h rd2=%08h", rd1, rd2);
            fail_cnt = fail_cnt + 1;
        end else
            pass_cnt = pass_cnt + 1;

        // -------- 结果汇总 --------
        #20;
        $display("========================================");
        $display("寄存器堆测试: %0d 通过, %0d 失败", pass_cnt, fail_cnt);
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
        $dumpfile("tb_regfile.vcd");
        $dumpvars(0, tb_regfile);
    end

endmodule
