// ================================================================
// 指令存储器（IMEM）16KB
// ================================================================
// 4096 x 32-bit 组合读存储器
// 地址由 PC 寄存器驱动，PC 本身是时序寄存器，因此 IMEM 的组合读
// 在综合时可被推断为 BRAM 的地址寄存模式（address-registered）
// 双端口设计：指令端口供 IF 阶段取指，数据端口供总线读取 .rodata 段
// 仿真初始化通过 $readmemh 加载 hex 固件文件
// ================================================================
module qxw_imem #(
    parameter DEPTH = 4096,  // 16KB / 4 bytes
    parameter INIT_FILE = "firmware.hex"
)(
    input  wire        clk,
    // 指令端口（IF 阶段直连）
    input  wire [31:0] addr,
    output wire [31:0] rdata,
    // 数据端口（总线读 .rodata）
    input  wire [31:0] daddr,
    output wire [31:0] drdata
);

    reg [31:0] mem [0:DEPTH-1];

    initial begin
        $readmemh(INIT_FILE, mem);
    end

    // 字地址提取：丢弃低 2 位（字节偏移）和高位，取 12 位字索引
    wire [11:0] word_addr  = addr[13:2];
    wire [11:0] dword_addr = daddr[13:2];

    assign rdata  = mem[word_addr];
    assign drdata = mem[dword_addr];

endmodule
