`include "qxw_defines.vh"

// ================================================================
// RV32I 算术逻辑单元（ALU）
// ================================================================
// 纯组合逻辑实现，支持 RV32I 基础整数指令集的所有运算操作
// 延迟路径：alu_op/op_a/op_b 稳定后，result 和 zero 在组合延迟后有效
// 移位操作仅使用 op_b 的低 5 位，符合 RV32 规范（32 位寄存器最多移 31 位）
// SLT/SLTU 输出 0 或 1，用于条件置位指令
// PASS_B 模式用于 LUI，直接旁路 op_b 不经运算
// ================================================================
module qxw_alu (
    input  wire [`ALU_OP_BUS]  alu_op,
    input  wire [`XLEN_BUS]    op_a,
    input  wire [`XLEN_BUS]    op_b,
    output reg  [`XLEN_BUS]    result,
    output wire                zero
);

    // zero 标志：result 为 0 时置位，可用于条件逻辑
    // 注意：当前设计中分支判断在 EX 阶段独立实现，不依赖此标志
    assign zero = (result == 32'd0);

    // 运算选择器：alu_op 由 ID 阶段译码生成，每种操作对应一条或多条指令
    always @(*) begin
        case (alu_op)
            `ALU_ADD:    result = op_a + op_b;
            `ALU_SUB:    result = op_a - op_b;
            `ALU_SLL:    result = op_a << op_b[4:0];   // 逻辑左移，RV32 仅用低 5 位
            `ALU_SLT:    result = {31'd0, $signed(op_a) < $signed(op_b)};
            `ALU_SLTU:   result = {31'd0, op_a < op_b};
            `ALU_XOR:    result = op_a ^ op_b;
            `ALU_SRL:    result = op_a >> op_b[4:0];  // 逻辑右移
            `ALU_SRA:    result = $signed(op_a) >>> op_b[4:0];  // 算术右移，保持符号
            `ALU_OR:     result = op_a | op_b;
            `ALU_AND:    result = op_a & op_b;
            // PASS_B：直接输出 op_b，用于 LUI（imm 作为结果）等无需 op_a 的指令
            `ALU_PASS_B: result = op_b;
            default:     result = 32'd0;
        endcase
    end

endmodule
