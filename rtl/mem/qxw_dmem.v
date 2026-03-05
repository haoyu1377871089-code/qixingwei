// 数据存储器 16KB (4096 x 32-bit)
// 同步写 + 组合读，支持字节使能写入
// 组合读确保 MEM 阶段同周期获取 Load 数据
// FPGA 综合时可配合 output register 推断 BRAM
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

    wire [11:0] word_addr = addr[13:2];

    // 组合读
    assign rdata = mem[word_addr];

    // 同步字节使能写入
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
