`include "qxw_defines.vh"

// ================================================================
// M 扩展乘除法单元
// ================================================================
// 乘法实现：纯组合逻辑，综合器自动推断 DSP48E1 硬件乘法器
//   MUL：取 64 位乘积的低 32 位
//   MULH/MULHSU/MULHU：取高 32 位，区分有符号×有符号/有符号×无符号/无符号×无符号
//
// 除法实现：32 周期恢复余数（restoring division）迭代算法
//   核心思想：每次迭代将余数左移一位，尝试减去除数（trial subtraction）
//   若差 >= 0（trial[32]=0），则商位为 1，保留差值作为新余数
//   若差 < 0（trial[32]=1），则商位为 0，恢复原余数（不更新）
//   最终在第 32 次迭代时同步计算商和余数的最终值
//
// 除零处理：组合旁路，不进入迭代状态机
//   DIV/DIVU 除零返回全 1（0xFFFFFFFF）
//   REM/REMU 除零返回被除数（op_a）
// ================================================================
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
    // 乘法：纯组合逻辑（三种符号性组合）
    // ================================================================
    // mul_ss：有符号×有符号，用于 MUL/MULH
    // mul_su：有符号×无符号，用于 MULHSU（op_b 前补 0 转为有符号正数）
    // mul_uu：无符号×无符号，用于 MULHU
    // 综合器会将 32x32 乘法映射到 FPGA 的 DSP48E1 硬件资源
    wire signed [63:0] mul_ss = $signed(op_a) * $signed(op_b);
    wire signed [63:0] mul_su = $signed(op_a) * $signed({1'b0, op_b});
    wire        [63:0] mul_uu = {32'd0, op_a} * {32'd0, op_b};

    // ================================================================
    // 除法状态机：恢复余数法（restoring division），32 周期迭代
    // ================================================================
    // 算法核心：维护 64 位移位寄存器 div_sr
    //   高 32 位为当前余数，低 32 位为部分商
    //   每次迭代左移一位，尝试减去除数
    //   若减成功（trial >= 0）则商位为 1，否则恢复余数商位为 0
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

    // 操作类型判断：md_op >= 4 为除法/取余，否则为乘法
    wire is_div_op   = (md_op >= `MD_DIV);
    // 有符号除法判断：DIV/REM 为有符号，DIVU/REMU 为无符号
    wire is_signed_d = (md_op == `MD_DIV || md_op == `MD_REM);

    // 有符号除法先取绝对值再迭代，最后根据 div_neg_q/r 恢复符号
    wire [31:0] abs_a = (op_a[31] && is_signed_d) ? (~op_a + 32'd1) : op_a;
    wire [31:0] abs_b = (op_b[31] && is_signed_d) ? (~op_b + 32'd1) : op_b;

    // 试减法（trial subtraction）：将左移后的余数减去除数
    // div_sr[62:31] 是上一轮余数左移一位后的结果（33 位宽以检测借位）
    // trial[32]=0 表示差值非负，商位置 1；trial[32]=1 表示差值为负，恢复原余数
    wire [32:0] div_trial = {1'b0, div_sr[62:31]} - {1'b0, div_divisor};

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

                // 第 32 次迭代（cnt=31）：直接在当前 trial 结果上计算最终商和余数
                // 避免额外一拍延迟，将最后一轮的 trial 结果内联到输出寄存器
                if (div_cnt == 6'd31) begin
                    div_running <= 1'b0;
                    div_done    <= 1'b1;
                    if (!div_trial[32]) begin
                        div_result_q <= div_neg_q ? (~{div_sr[30:0], 1'b1} + 32'd1)
                                                  :  {div_sr[30:0], 1'b1};
                        div_result_r <= div_neg_r ? (~div_trial[31:0] + 32'd1)
                                                  :  div_trial[31:0];
                    end else begin
                        div_result_q <= div_neg_q ? (~{div_sr[30:0], 1'b0} + 32'd1)
                                                  :  {div_sr[30:0], 1'b0};
                        div_result_r <= div_neg_r ? (~div_sr[62:31] + 32'd1)
                                                  :  div_sr[62:31];
                    end
                end
                div_cnt <= div_cnt + 6'd1;
            end else if (start && is_div_op) begin
                // 除零特殊处理：不进入迭代，直接在下一拍输出结果
                if (op_b == 32'd0) begin
                    div_result_q <= 32'hFFFF_FFFF;
                    div_result_r <= op_a;
                    div_done     <= 1'b1;
                end else begin
                    // 除法启动初始化：将被除数放入移位寄存器低 32 位
                    // div_neg_q/r 记录结果符号：商的符号由两操作数异或决定，余数符号跟被除数
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


    // ================================================================
    // valid 信号：标记结果可用的单拍脉冲
    // ================================================================
    // 乘法在 start 同拍即 valid（组合逻辑，单周期）
    // 除法在 div_done 后的下一拍 valid
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
    // 结果多路选择器
    // ================================================================
    // 除零检测使用组合旁路：直接检查当前输入 op_b 是否为零
    // 这样即使在 start 脉冲同拍，结果选择器也能正确输出除零结果
    // 无需等待 div_done 信号和 div_result_q/r 的 NBA 更新
    wire div_by_zero = is_div_op & (op_b == 32'd0);

    always @(*) begin
        case (md_op)
            `MD_MUL:    result = mul_ss[31:0];
            `MD_MULH:   result = mul_ss[63:32];
            `MD_MULHSU: result = mul_su[63:32];
            `MD_MULHU:  result = mul_uu[63:32];
            `MD_DIV:    result = div_by_zero ? 32'hFFFF_FFFF : div_result_q;
            `MD_DIVU:   result = div_by_zero ? 32'hFFFF_FFFF : div_result_q;
            `MD_REM:    result = div_by_zero ? op_a           : div_result_r;
            `MD_REMU:   result = div_by_zero ? op_a           : div_result_r;
            default:    result = 32'd0;
        endcase
    end

endmodule
