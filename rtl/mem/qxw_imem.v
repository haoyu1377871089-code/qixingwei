// 指令存储器 16KB (4096 x 32-bit)
// 组合读：PC 寄存器已提供地址寄存，此处无需再寄存输出
// Vivado 综合时 PC 寄存器 + 组合读会推断为 BRAM 的地址寄存模式
// 仿真时通过 $readmemh 加载 hex 文件
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

    wire [11:0] word_addr  = addr[13:2];
    wire [11:0] dword_addr = daddr[13:2];

    assign rdata  = mem[word_addr];
    assign drdata = mem[dword_addr];

endmodule
