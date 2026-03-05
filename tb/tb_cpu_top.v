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
    parameter MAX_CYCLES = 10_000_000;
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

    // 波形输出（可通过 +DUMP 命令行参数启用）
    initial begin
        if ($test$plusargs("DUMP")) begin
            $dumpfile("tb_cpu_top.vcd");
            $dumpvars(0, tb_cpu_top);
        end
    end

    // 监控所有 RAM 写入，最后 200 周期
    `ifdef DEBUG_TRACE
    reg [31:0] last_ram_writes [0:15];
    reg [31:0] last_ram_addrs  [0:15];
    reg [31:0] last_ram_pcs    [0:15];
    integer wr_idx;
    initial wr_idx = 0;
    always @(posedge clk) begin
        if (u_soc.u_bus.ram_en && (|u_soc.u_bus.ram_we) && u_soc.u_dmem.addr[13:2] >= 12'hFF0) begin
            $display("[cyc %0d] RAM STORE: addr=%08h data=%08h we=%b ex_mem_pc=%08h ex_mem_valid=%b ex_mem_mem_we=%b fwd_rs2=%08h ex_mem_rs2=%08h",
                     cycle_cnt, u_soc.u_dmem.addr, u_soc.u_dmem.wdata,
                     u_soc.u_dmem.we,
                     u_soc.u_cpu.ex_mem_pc,
                     u_soc.u_cpu.u_ex_stage.ex_mem_valid,
                     u_soc.u_cpu.u_ex_stage.ex_mem_mem_we,
                     u_soc.u_cpu.u_forwarding.fwd_rs2_data,
                     u_soc.u_cpu.u_ex_stage.ex_mem_rs2_data);
        end
    end
    `endif

    `ifdef DEBUG_TRACE
    always @(posedge clk) begin
        if (rst_n && u_soc.u_cpu.u_wb_stage.rf_we)
            $display("[%0t] PC=%08h WB: x%0d = %08h",
                     $time,
                     u_soc.u_cpu.mem_wb_pc,
                     u_soc.u_cpu.u_wb_stage.rf_wa,
                     u_soc.u_cpu.u_wb_stage.rf_wd);
    end
    // 跟踪除法相关信号（连续 5 拍）
    reg [3:0] div_trace_cnt;
    initial div_trace_cnt = 0;
    always @(posedge clk) begin
        if (rst_n && u_soc.u_cpu.md_start_pulse)
            div_trace_cnt <= 5;
        else if (div_trace_cnt > 0)
            div_trace_cnt <= div_trace_cnt - 1;

        if (div_trace_cnt > 0 || (rst_n && u_soc.u_cpu.md_start_pulse))
            $display("[%0t] DIV: stall_id=%b stall_ex=%b busy=%b pulse=%b started_r=%b is_md=%b valid=%b ex_mem_we=%b md_result=%08h div_q=%08h",
                     $time,
                     u_soc.u_cpu.stall_id,
                     u_soc.u_cpu.stall_ex,
                     u_soc.u_cpu.md_busy,
                     u_soc.u_cpu.md_start_pulse,
                     u_soc.u_cpu.md_started_r,
                     u_soc.u_cpu.u_ex_stage.id_ex_is_muldiv,
                     u_soc.u_cpu.u_ex_stage.id_ex_valid,
                     u_soc.u_cpu.u_ex_stage.ex_mem_reg_we,
                     u_soc.u_cpu.md_result,
                     u_soc.u_cpu.u_muldiv.div_result_q);
    end
    `endif

endmodule
