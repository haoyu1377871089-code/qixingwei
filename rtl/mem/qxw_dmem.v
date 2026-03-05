// ================================================================
// 数据存储器（DMEM）16KB
// ================================================================
// 4096 x 32-bit，同步写 + 同步读，综合为 BRAM
// 支持 4 位字节使能（we[3:0]）：SB/SH/SW
// 同步读：地址在时钟上升沿采样，数据在下一拍输出（write-first 模式）
// ================================================================
module qxw_dmem #(
    parameter DEPTH = 4096  // 16KB / 4 bytes
)(
    input  wire        clk,
    input  wire        en,
    input  wire [3:0]  we,      // 字节使能
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata
);

    (* ram_style = "block" *) reg [31:0] mem [0:DEPTH-1];

    wire [11:0] word_addr = addr[13:2];

    // 同步写入
    always @(posedge clk) begin
        if (en) begin
            if (we[0]) mem[word_addr][ 7: 0] <= wdata[ 7: 0];
            if (we[1]) mem[word_addr][15: 8] <= wdata[15: 8];
            if (we[2]) mem[word_addr][23:16] <= wdata[23:16];
            if (we[3]) mem[word_addr][31:24] <= wdata[31:24];
        end
    end

    // 同步读：read-first 模式，BRAM 输出寄存器
    always @(posedge clk) begin
        rdata <= mem[word_addr];
    end

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'd0;
    end

endmodule
