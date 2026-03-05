// ================================================================
// 指令存储器（IMEM）16KB
// ================================================================
// 4096 x 32-bit 同步读存储器，综合为 BRAM
// 双端口设计：指令端口供 IF 阶段取指，数据端口供总线读取 .rodata 段
// 同步读：地址在时钟上升沿采样，数据在下一拍输出
// en 控制读使能：stall 时 en=0，BRAM 输出保持不变
// 仿真初始化通过 $readmemh 加载 hex 固件文件
// ================================================================
module qxw_imem #(
    parameter DEPTH = 4096,  // 16KB / 4 bytes
    parameter INIT_FILE = "firmware.hex"
)(
    input  wire        clk,
    // 指令端口（IF 阶段直连）
    input  wire        en,
    input  wire [31:0] addr,
    output reg  [31:0] rdata,
    // 数据端口（总线读 .rodata）
    input  wire [31:0] daddr,
    output reg  [31:0] drdata
);

    (* ram_style = "block" *) reg [31:0] mem [0:DEPTH-1];

    initial begin
        $readmemh(INIT_FILE, mem);
    end

    wire [11:0] word_addr  = addr[13:2];
    wire [11:0] dword_addr = daddr[13:2];

    always @(posedge clk) begin
        if (en)
            rdata <= mem[word_addr];
        drdata <= mem[dword_addr];
    end

endmodule
