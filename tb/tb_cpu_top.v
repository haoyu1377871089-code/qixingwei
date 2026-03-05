`timescale 1ns / 1ps
`include "qxw_defines.vh"

// CPU 系统级测试
// 加载 hex 程序到指令存储器，运行并检查结果
// 支持 riscv-tests 风格判断：
//   写 0x0001_3FF8 (tohost) 非零值表示测试结束
//   tohost == 1 -> PASS, 其它 -> FAIL (test_id = tohost >> 1)
module tb_cpu_top;

    reg         clk;
    reg         rst_n;
    wire        uart_tx;
    wire [3:0]  led;

    // 50MHz 时钟
    parameter CLK_PERIOD = 20;
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // SoC 实例化
    qxw_soc_top #(
        .IMEM_INIT_FILE("firmware.hex")
    ) u_soc (
        .clk     (clk),
        .rst_n   (rst_n),
        .uart_tx (uart_tx),
        .led     (led)
    );

    // tohost 地址在数据 RAM 中: 0x0001_3FF8
    // 对应 DMEM word_addr = (0x3FF8 >> 2) = 0xFFE
    wire [31:0] tohost = u_soc.u_dmem.mem[12'hFFE];

    // 最大仿真周期
    parameter MAX_CYCLES = 100_000;
    integer cycle_cnt;

    // 复位 + 运行
    initial begin
        rst_n = 0;
        cycle_cnt = 0;
        #(CLK_PERIOD * 5);
        rst_n = 1;

        // 等待测试完成
        while (cycle_cnt < MAX_CYCLES) begin
            @(posedge clk);
            cycle_cnt = cycle_cnt + 1;

            if (tohost != 32'd0) begin
                if (tohost == 32'd1) begin
                    $display("========================================");
                    $display("TEST PASSED after %0d cycles", cycle_cnt);
                    $display("========================================");
                end else begin
                    $display("========================================");
                    $display("TEST FAILED: test_id = %0d (tohost = 0x%08h) after %0d cycles",
                             tohost >> 1, tohost, cycle_cnt);
                    $display("========================================");
                end
                $finish;
            end
        end

        $display("========================================");
        $display("TIMEOUT after %0d cycles", MAX_CYCLES);
        $display("========================================");
        $finish;
    end

    // 波形输出
    initial begin
        $dumpfile("tb_cpu_top.vcd");
        $dumpvars(0, tb_cpu_top);
    end

    // 定期打印 PC（调试用）
    `ifdef DEBUG_TRACE
    always @(posedge clk) begin
        if (rst_n && u_soc.u_cpu.u_wb_stage.rf_we)
            $display("[%0t] PC=%08h WB: x%0d = %08h",
                     $time,
                     u_soc.u_cpu.mem_wb_pc,
                     u_soc.u_cpu.u_wb_stage.rf_wa,
                     u_soc.u_cpu.u_wb_stage.rf_wd);
    end
    `endif

endmodule
