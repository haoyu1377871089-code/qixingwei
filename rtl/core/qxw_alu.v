`include "qxw_defines.vh"

// RV32I 算术逻辑单元，纯组合逻辑
module qxw_alu (
    input  wire [`ALU_OP_BUS]  alu_op,
    input  wire [`XLEN_BUS]    op_a,
    input  wire [`XLEN_BUS]    op_b,
    output reg  [`XLEN_BUS]    result,
    output wire                zero
);

    assign zero = (result == 32'd0);

    always @(*) begin
        case (alu_op)
            `ALU_ADD:    result = op_a + op_b;
            `ALU_SUB:    result = op_a - op_b;
            `ALU_SLL:    result = op_a << op_b[4:0];
            `ALU_SLT:    result = {31'd0, $signed(op_a) < $signed(op_b)};
            `ALU_SLTU:   result = {31'd0, op_a < op_b};
            `ALU_XOR:    result = op_a ^ op_b;
            `ALU_SRL:    result = op_a >> op_b[4:0];
            `ALU_SRA:    result = $signed(op_a) >>> op_b[4:0];
            `ALU_OR:     result = op_a | op_b;
            `ALU_AND:    result = op_a & op_b;
            `ALU_PASS_B: result = op_b;
            default:     result = 32'd0;
        endcase
    end

endmodule
