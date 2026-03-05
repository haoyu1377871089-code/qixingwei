// ================================================================
// 数据存储器（DMEM）16KB
// ================================================================
// 4096 x 32-bit，同步写 + 组合读，支持 4 位字节使能（we[3:0]）
// 组合读设计确保 MEM 阶段在同一时钟周期内获取 Load 数据
// 字节使能写入支持 SB（单字节）、SH（半字）、SW（全字）操作
// 仿真时全部初始化为 0，综合时可推断为 BRAM
// ================================================================
module qxw_dmem #(
    parameter DEPTH = 4096  // 16KB / 4 bytes
)(
    input  wire        clk,
    input  wire        en,
    input  wire [3:0]  we,      // 字节使能
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata
);

    reg [31:0] mem [0:DEPTH-1];

    // 字地址提取：丢弃低 2 位字节偏移，取 12 位字索引寻址 4096 个字
    wire [11:0] word_addr = addr[13:2];

    // 组合读：地址变化后数据立即可用，配合 MEM 阶段同周期获取
    assign rdata = mem[word_addr];

    // 同步字节使能写入：每个 we 位独立控制对应字节是否更新
    // we[0] -> byte[7:0], we[1] -> byte[15:8], we[2] -> byte[23:16], we[3] -> byte[31:24]
    always @(posedge clk) begin
        if (en) begin
            if (we[0]) mem[word_addr][ 7: 0] <= wdata[ 7: 0];
            if (we[1]) mem[word_addr][15: 8] <= wdata[15: 8];
            if (we[2]) mem[word_addr][23:16] <= wdata[23:16];
            if (we[3]) mem[word_addr][31:24] <= wdata[31:24];
        end
    end

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'd0;
    end

endmodule
