`timescale 1ns / 1ps
`include "qxw_defines.vh"

// ALU 单元测试：遍历所有 ALU 操作，验证边界值
module tb_alu;

    reg  [`ALU_OP_BUS] alu_op;
    reg  [31:0]        op_a, op_b;
    wire [31:0]        result;
    wire               zero;

    qxw_alu u_alu (
        .alu_op (alu_op),
        .op_a   (op_a),
        .op_b   (op_b),
        .result (result),
        .zero   (zero)
    );

    integer pass_cnt, fail_cnt;

    task check;
        input [31:0] expected;
        input [255:0] name;  // 测试名称
        begin
            if (result !== expected) begin
                $display("FAIL: %0s | op_a=%08h op_b=%08h | got=%08h exp=%08h",
                         name, op_a, op_b, result, expected);
                fail_cnt = fail_cnt + 1;
            end else begin
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    initial begin
        pass_cnt = 0;
        fail_cnt = 0;

        // ---- ADD ----
        alu_op = `ALU_ADD;
        op_a = 32'd10;       op_b = 32'd20;       #10; check(32'd30, "ADD basic");
        op_a = 32'hFFFF_FFFF; op_b = 32'd1;        #10; check(32'd0, "ADD overflow");
        op_a = 32'h7FFF_FFFF; op_b = 32'd1;        #10; check(32'h8000_0000, "ADD signed overflow");

        // ---- SUB ----
        alu_op = `ALU_SUB;
        op_a = 32'd30;       op_b = 32'd10;       #10; check(32'd20, "SUB basic");
        op_a = 32'd0;        op_b = 32'd1;        #10; check(32'hFFFF_FFFF, "SUB underflow");

        // ---- SLL ----
        alu_op = `ALU_SLL;
        op_a = 32'd1;        op_b = 32'd4;        #10; check(32'd16, "SLL by 4");
        op_a = 32'h8000_0000; op_b = 32'd1;       #10; check(32'd0, "SLL overflow");

        // ---- SLT ----
        alu_op = `ALU_SLT;
        op_a = 32'hFFFF_FFFF; op_b = 32'd0;       #10; check(32'd1, "SLT -1 < 0");
        op_a = 32'd0;        op_b = 32'hFFFF_FFFF; #10; check(32'd0, "SLT 0 > -1");
        op_a = 32'd5;        op_b = 32'd5;        #10; check(32'd0, "SLT equal");

        // ---- SLTU ----
        alu_op = `ALU_SLTU;
        op_a = 32'd0;        op_b = 32'hFFFF_FFFF; #10; check(32'd1, "SLTU 0 < max");
        op_a = 32'hFFFF_FFFF; op_b = 32'd0;       #10; check(32'd0, "SLTU max > 0");

        // ---- XOR ----
        alu_op = `ALU_XOR;
        op_a = 32'hAAAA_AAAA; op_b = 32'h5555_5555; #10; check(32'hFFFF_FFFF, "XOR");
        op_a = 32'hFFFF_FFFF; op_b = 32'hFFFF_FFFF; #10; check(32'd0, "XOR same");

        // ---- SRL ----
        alu_op = `ALU_SRL;
        op_a = 32'h8000_0000; op_b = 32'd1;       #10; check(32'h4000_0000, "SRL");
        op_a = 32'hFF00_0000; op_b = 32'd8;       #10; check(32'h00FF_0000, "SRL by 8");

        // ---- SRA ----
        alu_op = `ALU_SRA;
        op_a = 32'h8000_0000; op_b = 32'd1;       #10; check(32'hC000_0000, "SRA sign ext");
        op_a = 32'h4000_0000; op_b = 32'd1;       #10; check(32'h2000_0000, "SRA positive");

        // ---- OR ----
        alu_op = `ALU_OR;
        op_a = 32'hF0F0_F0F0; op_b = 32'h0F0F_0F0F; #10; check(32'hFFFF_FFFF, "OR");

        // ---- AND ----
        alu_op = `ALU_AND;
        op_a = 32'hF0F0_F0F0; op_b = 32'h0F0F_0F0F; #10; check(32'd0, "AND");
        op_a = 32'hFFFF_FFFF; op_b = 32'hAAAA_AAAA; #10; check(32'hAAAA_AAAA, "AND mask");

        // ---- PASS_B (LUI) ----
        alu_op = `ALU_PASS_B;
        op_a = 32'h1234_5678; op_b = 32'hABCD_0000; #10; check(32'hABCD_0000, "PASS_B");

        // ---- Zero flag ----
        alu_op = `ALU_SUB;
        op_a = 32'd42;       op_b = 32'd42;       #10;
        if (zero !== 1'b1) begin
            $display("FAIL: zero flag not set on equal SUB");
            fail_cnt = fail_cnt + 1;
        end else
            pass_cnt = pass_cnt + 1;

        // ---- 结果汇总 ----
        $display("========================================");
        $display("ALU Test: %0d PASSED, %0d FAILED", pass_cnt, fail_cnt);
        $display("========================================");
        if (fail_cnt == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        $finish;
    end

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);
    end

endmodule
