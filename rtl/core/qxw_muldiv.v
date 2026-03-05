`include "qxw_defines.vh"

// M 扩展乘除法单元
// 乘法：组合逻辑（综合时映射到 DSP48E1）
// 除法：32 周期 restoring division，busy/valid 握手
module qxw_muldiv (
    input  wire                clk,
    input  wire                rst_n,
    input  wire                start,
    input  wire [`MD_OP_BUS]   md_op,
    input  wire [`XLEN_BUS]    op_a,
    input  wire [`XLEN_BUS]    op_b,
    output reg  [`XLEN_BUS]    result,
    output wire                busy,
    output reg                 valid
);

    // ================================================================
    // 乘法：纯组合逻辑
    // ================================================================
    wire signed [63:0] mul_ss = $signed(op_a) * $signed(op_b);
    wire signed [63:0] mul_su = $signed(op_a) * $signed({1'b0, op_b});
    wire        [63:0] mul_uu = {32'd0, op_a} * {32'd0, op_b};

    // ================================================================
    // 除法：restoring division, 32 周期
    // ================================================================
    reg        div_running;
    reg [5:0]  div_cnt;
    reg        div_neg_q;
    reg        div_neg_r;
    reg [31:0] div_divisor;
    reg [63:0] div_sr;       // [63:32]=remainder, [31:0]=quotient
    reg [31:0] div_result_q;
    reg [31:0] div_result_r;
    reg        div_done;     // 除法完成标记，延迟一拍取结果

    assign busy = div_running;

    wire is_div_op   = (md_op >= `MD_DIV);
    wire is_signed_d = (md_op == `MD_DIV || md_op == `MD_REM);

    wire [31:0] abs_a = (op_a[31] && is_signed_d) ? (~op_a + 32'd1) : op_a;
    wire [31:0] abs_b = (op_b[31] && is_signed_d) ? (~op_b + 32'd1) : op_b;

    // restoring division: trial = shifted_remainder - divisor
    wire [32:0] div_trial = {div_sr[62:31], 1'b0} - {1'b0, div_divisor};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_running  <= 1'b0;
            div_cnt      <= 6'd0;
            div_done     <= 1'b0;
            div_result_q <= 32'd0;
            div_result_r <= 32'd0;
        end else begin
            div_done <= 1'b0;

            if (div_running) begin
                // restoring division 迭代步
                if (!div_trial[32]) begin
                    // trial >= 0: 商位为 1
                    div_sr <= {div_trial[31:0], div_sr[30:0], 1'b1};
                end else begin
                    // trial < 0: 恢复，商位为 0
                    div_sr <= {div_sr[62:0], 1'b0};
                end

                if (div_cnt == 6'd31) begin
                    div_running <= 1'b0;
                    div_done    <= 1'b1;
                end
                div_cnt <= div_cnt + 6'd1;
            end else if (start && is_div_op) begin
                if (op_b == 32'd0) begin
                    div_result_q <= 32'hFFFF_FFFF;
                    div_result_r <= op_a;
                    div_done     <= 1'b1;
                end else begin
                    div_running <= 1'b1;
                    div_cnt     <= 6'd0;
                    div_sr      <= {32'd0, abs_a};
                    div_divisor <= abs_b;
                    div_neg_q   <= is_signed_d && (op_a[31] ^ op_b[31]);
                    div_neg_r   <= is_signed_d && op_a[31];
                end
            end
        end
    end

    // 除法完成时锁存修正后的结果
    always @(posedge clk) begin
        if (div_done && !div_running) begin
            // 除以零的结果已直接写入，无需覆盖
        end else if (div_done) begin
            div_result_q <= div_neg_q ? (~div_sr[31:0]  + 32'd1) : div_sr[31:0];
            div_result_r <= div_neg_r ? (~div_sr[63:32] + 32'd1) : div_sr[63:32];
        end
    end

    // ================================================================
    // valid 信号
    // ================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valid <= 1'b0;
        else if (start && !is_div_op)
            valid <= 1'b1;    // 乘法单周期完成
        else if (div_done)
            valid <= 1'b1;
        else
            valid <= 1'b0;
    end

    // ================================================================
    // 结果选择
    // ================================================================
    always @(*) begin
        case (md_op)
            `MD_MUL:    result = mul_ss[31:0];
            `MD_MULH:   result = mul_ss[63:32];
            `MD_MULHSU: result = mul_su[63:32];
            `MD_MULHU:  result = mul_uu[63:32];
            `MD_DIV:    result = div_result_q;
            `MD_DIVU:   result = div_result_q;
            `MD_REM:    result = div_result_r;
            `MD_REMU:   result = div_result_r;
            default:    result = 32'd0;
        endcase
    end

endmodule
