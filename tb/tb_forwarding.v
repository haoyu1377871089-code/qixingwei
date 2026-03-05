// ============================================================================
// QXW RISC-V 转发单元 (qxw_forwarding) 测试平台
// ============================================================================
// 功能：验证 EX/MEM/WB 三路旁路转发逻辑
// 测试项：无转发、EX/MEM 优先、MEM/WB 次之、x0 不转发、同时匹配时 EX 优先、rs1/rs2 独立
// ============================================================================
`timescale 1ns / 1ps
`include "qxw_defines.vh"

module tb_forwarding;

    // ------------------------------------------------------------------------
    // 转发单元接口
    // ------------------------------------------------------------------------
    reg  [`REG_ADDR_BUS] id_ex_rs1, id_ex_rs2;
    reg  [`XLEN_BUS]     id_ex_rs1_data, id_ex_rs2_data;
    reg  [`REG_ADDR_BUS] ex_mem_rd, mem_wb_rd;
    reg                  ex_mem_reg_we, mem_wb_reg_we;
    reg  [`XLEN_BUS]     ex_mem_alu_result, mem_wb_wd;
    reg                  ex_mem_valid, mem_wb_valid;
    wire [`XLEN_BUS]     fwd_rs1_data, fwd_rs2_data;
    wire [1:0]           fwd_sel_a, fwd_sel_b;

    // ------------------------------------------------------------------------
    // 实例化被测模块
    // ------------------------------------------------------------------------
    qxw_forwarding u_forwarding (
        .id_ex_rs1       (id_ex_rs1),
        .id_ex_rs2       (id_ex_rs2),
        .id_ex_rs1_data  (id_ex_rs1_data),
        .id_ex_rs2_data  (id_ex_rs2_data),
        .ex_mem_rd       (ex_mem_rd),
        .ex_mem_reg_we   (ex_mem_reg_we),
        .ex_mem_alu_result (ex_mem_alu_result),
        .ex_mem_valid    (ex_mem_valid),
        .mem_wb_rd       (mem_wb_rd),
        .mem_wb_reg_we   (mem_wb_reg_we),
        .mem_wb_wd       (mem_wb_wd),
        .mem_wb_valid    (mem_wb_valid),
        .fwd_rs1_data    (fwd_rs1_data),
        .fwd_rs2_data    (fwd_rs2_data),
        .fwd_sel_a       (fwd_sel_a),
        .fwd_sel_b       (fwd_sel_b)
    );

    // ------------------------------------------------------------------------
    // 测试统计
    // ------------------------------------------------------------------------
    integer pass_cnt, fail_cnt;

    // ------------------------------------------------------------------------
    // 检查任务：验证转发结果与选择信号
    // ------------------------------------------------------------------------
    task check_fwd;
        input [`XLEN_BUS] exp_rs1, exp_rs2;
        input [1:0]       exp_sel_a, exp_sel_b;
        input [255:0]     name;
        begin
            #1;  // 组合逻辑稳定
            if (fwd_rs1_data !== exp_rs1 || fwd_rs2_data !== exp_rs2 ||
                fwd_sel_a !== exp_sel_a || fwd_sel_b !== exp_sel_b) begin
                $display("FAIL: %0s", name);
                $display("  rs1: got=%08h exp=%08h sel_a=%b exp=%b",
                         fwd_rs1_data, exp_rs1, fwd_sel_a, exp_sel_a);
                $display("  rs2: got=%08h exp=%08h sel_b=%b exp=%b",
                         fwd_rs2_data, exp_rs2, fwd_sel_b, exp_sel_b);
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
        id_ex_rs1 = 5'd0; id_ex_rs2 = 5'd0;
        id_ex_rs1_data = 32'd0; id_ex_rs2_data = 32'd0;
        ex_mem_rd = 5'd0; ex_mem_reg_we = 0; ex_mem_alu_result = 32'd0; ex_mem_valid = 0;
        mem_wb_rd = 5'd0; mem_wb_reg_we = 0; mem_wb_wd = 32'd0; mem_wb_valid = 0;

        // -------- 测试 1：无转发 --------
        $display("[测试1] 无转发");
        id_ex_rs1 = 5'd3; id_ex_rs2 = 5'd5;
        id_ex_rs1_data = 32'h1111_1111; id_ex_rs2_data = 32'h2222_2222;
        ex_mem_reg_we = 0; mem_wb_reg_we = 0;
        check_fwd(32'h1111_1111, 32'h2222_2222, 2'b00, 2'b00, "无转发应使用原始数据");

        // -------- 测试 2：EX/MEM 转发 rs1 --------
        $display("[测试2] EX/MEM 转发 rs1");
        id_ex_rs1 = 5'd4; id_ex_rs2 = 5'd5;
        id_ex_rs1_data = 32'h1111_1111; id_ex_rs2_data = 32'h2222_2222;
        ex_mem_rd = 5'd4; ex_mem_reg_we = 1; ex_mem_alu_result = 32'hAAAA_AAAA; ex_mem_valid = 1;
        mem_wb_reg_we = 0;
        check_fwd(32'hAAAA_AAAA, 32'h2222_2222, 2'b01, 2'b00, "EX/MEM 转发 rs1");

        // -------- 测试 3：EX/MEM 转发 rs2 --------
        $display("[测试3] EX/MEM 转发 rs2");
        id_ex_rs1 = 5'd3; id_ex_rs2 = 5'd6;
        id_ex_rs1_data = 32'h1111_1111; id_ex_rs2_data = 32'h2222_2222;
        ex_mem_rd = 5'd6; ex_mem_reg_we = 1; ex_mem_alu_result = 32'hBBBB_BBBB; ex_mem_valid = 1;
        mem_wb_reg_we = 0;
        check_fwd(32'h1111_1111, 32'hBBBB_BBBB, 2'b00, 2'b01, "EX/MEM 转发 rs2");

        // -------- 测试 4：MEM/WB 转发 rs1 --------
        $display("[测试4] MEM/WB 转发 rs1");
        id_ex_rs1 = 5'd7; id_ex_rs2 = 5'd5;
        id_ex_rs1_data = 32'h1111_1111; id_ex_rs2_data = 32'h2222_2222;
        ex_mem_reg_we = 0; ex_mem_valid = 0;
        mem_wb_rd = 5'd7; mem_wb_reg_we = 1; mem_wb_wd = 32'hCCCC_CCCC; mem_wb_valid = 1;
        check_fwd(32'hCCCC_CCCC, 32'h2222_2222, 2'b10, 2'b00, "MEM/WB 转发 rs1");

        // -------- 测试 5：x0 永不转发 --------
        $display("[测试5] x0 不转发");
        id_ex_rs1 = 5'd0; id_ex_rs2 = 5'd0;
        id_ex_rs1_data = 32'd0; id_ex_rs2_data = 32'd0;
        ex_mem_rd = 5'd0; ex_mem_reg_we = 1; ex_mem_alu_result = 32'hDEAD_BEEF; ex_mem_valid = 1;
        mem_wb_rd = 5'd0; mem_wb_reg_we = 1; mem_wb_wd = 32'hCAFE_BABE; mem_wb_valid = 1;
        check_fwd(32'd0, 32'd0, 2'b00, 2'b00, "x0 应使用原始 0 不转发");

        // -------- 测试 6：EX/MEM 与 MEM/WB 同时匹配，EX/MEM 优先 --------
        $display("[测试6] EX/MEM 优先于 MEM/WB");
        id_ex_rs1 = 5'd8; id_ex_rs2 = 5'd8;
        id_ex_rs1_data = 32'h1111_1111; id_ex_rs2_data = 32'h2222_2222;
        ex_mem_rd = 5'd8; ex_mem_reg_we = 1; ex_mem_alu_result = 32'hEEEE_EEEE; ex_mem_valid = 1;
        mem_wb_rd = 5'd8; mem_wb_reg_we = 1; mem_wb_wd = 32'hDDDD_DDDD; mem_wb_valid = 1;
        check_fwd(32'hEEEE_EEEE, 32'hEEEE_EEEE, 2'b01, 2'b01, "EX/MEM 应优先");

        // -------- 测试 7：rs1 与 rs2 独立转发 --------
        $display("[测试7] rs1/rs2 独立");
        id_ex_rs1 = 5'd1; id_ex_rs2 = 5'd2;
        id_ex_rs1_data = 32'h1111_1111; id_ex_rs2_data = 32'h2222_2222;
        ex_mem_rd = 5'd1; ex_mem_reg_we = 1; ex_mem_alu_result = 32'hF1F1_F1F1; ex_mem_valid = 1;
        mem_wb_rd = 5'd2; mem_wb_reg_we = 1; mem_wb_wd = 32'hF2F2_F2F2; mem_wb_valid = 1;
        check_fwd(32'hF1F1_F1F1, 32'hF2F2_F2F2, 2'b01, 2'b10, "rs1 走 EX/MEM, rs2 走 MEM/WB");

        // -------- 结果汇总 --------
        #20;
        $display("========================================");
        $display("转发单元测试: %0d 通过, %0d 失败", pass_cnt, fail_cnt);
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
        $dumpfile("tb_forwarding.vcd");
        $dumpvars(0, tb_forwarding);
    end

endmodule
