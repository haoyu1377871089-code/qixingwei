`include "qxw_defines.vh"

// ================================================================
// 访存阶段（MEM Stage）
// ================================================================
// 处理 Load/Store 指令的数据存储器交互：
//   Store：根据 funct3（SB/SH/SW）将写数据对齐到 32 位字的正确位置，
//          生成 4 位字节使能信号 dmem_we[3:0]
//   Load：从 dmem 返回的 32 位字中按 byte_offset 提取目标字节/半字，
//         LB/LH 做符号扩展，LBU/LHU 做零扩展
//
// DMEM 接口设计：
//   dmem_addr 始终字对齐（低 2 位清零），子字寻址通过 byte_offset 实现
//   dmem_en 在 Load 或 Store 时拉高，dmem_we 仅 Store 时非零
//   dmem 为组合读，同拍返回数据，无需额外等待周期
// ================================================================
module qxw_mem_stage (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              stall,

    // EX/MEM 级间寄存器输入
    input  wire [`XLEN_BUS]  ex_mem_pc,
    input  wire [`XLEN_BUS]  ex_mem_alu_result,
    input  wire [`XLEN_BUS]  ex_mem_rs2_data,
    input  wire [`REG_ADDR_BUS] ex_mem_rd,
    input  wire              ex_mem_reg_we,
    input  wire              ex_mem_mem_re,
    input  wire              ex_mem_mem_we,
    input  wire [2:0]        ex_mem_funct3,
    input  wire [`WB_SEL_BUS]   ex_mem_wb_sel,
    input  wire              ex_mem_csr_we,
    input  wire [2:0]        ex_mem_csr_op,
    input  wire [11:0]       ex_mem_csr_addr,
    input  wire [`XLEN_BUS]  ex_mem_csr_wdata,
    input  wire              ex_mem_valid,

    // 数据存储器接口
    output wire              dmem_en,
    output wire [3:0]        dmem_we,
    output wire [`XLEN_BUS]  dmem_addr,
    output wire [`XLEN_BUS]  dmem_wdata,
    input  wire [`XLEN_BUS]  dmem_rdata,

    // MEM/WB 级间寄存器输出
    output reg  [`XLEN_BUS]  mem_wb_pc,
    output reg  [`XLEN_BUS]  mem_wb_alu_result,
    output reg  [`XLEN_BUS]  mem_wb_mem_data,
    output reg  [`REG_ADDR_BUS] mem_wb_rd,
    output reg               mem_wb_reg_we,
    output reg  [`WB_SEL_BUS]   mem_wb_wb_sel,
    output reg               mem_wb_csr_we,
    output reg  [2:0]        mem_wb_csr_op,
    output reg  [11:0]       mem_wb_csr_addr,
    output reg  [`XLEN_BUS]  mem_wb_csr_wdata,
    output reg               mem_wb_valid
);

    // 字节偏移提取：ALU 结果的低 2 位指示字内字节位置
    // byte_offset=0 对应最低字节，=3 对应最高字节
    // SH 指令仅使用 byte_offset[1] 区分低/高半字
    wire [1:0] byte_offset = ex_mem_alu_result[1:0];

    // ================================================================
    // Store 数据对齐与字节使能生成
    // ================================================================
    // dmem_en 在任何访存操作且指令有效时拉高，作为存储器片选
    // dmem_addr 强制字对齐：丢弃低 2 位，因为字节选择通过 we 实现
    assign dmem_en   = (ex_mem_mem_re | ex_mem_mem_we) & ex_mem_valid;
    assign dmem_addr = {ex_mem_alu_result[31:2], 2'b00};

    reg [3:0]  store_we;     // 字节写使能：每位对应 32 位字中的一个字节
    reg [31:0] store_data;   // 对齐后的写数据：rs2 数据移位到正确字节位置

    // Store 数据对齐逻辑：根据 funct3 和 byte_offset 生成 we 和 data
    // SB：写 1 字节，we 为 4 选 1；SH：写 2 字节，we 为 2 选 1；SW：写全字
    always @(*) begin
        store_we   = 4'b0000;
        store_data = 32'd0;
        if (ex_mem_mem_we) begin
            case (ex_mem_funct3)
                // SB：按 byte_offset 选 4 字节中哪一字节写入
                `FUNCT3_SB: begin
                    case (byte_offset)
                        2'd0: begin store_we = 4'b0001; store_data = {24'd0, ex_mem_rs2_data[7:0]};         end
                        2'd1: begin store_we = 4'b0010; store_data = {16'd0, ex_mem_rs2_data[7:0], 8'd0};   end
                        2'd2: begin store_we = 4'b0100; store_data = {8'd0,  ex_mem_rs2_data[7:0], 16'd0};  end
                        2'd3: begin store_we = 4'b1000; store_data = {ex_mem_rs2_data[7:0], 24'd0};          end
                    endcase
                end
                // SH：半字对齐，offset[1] 选低/高半字
                `FUNCT3_SH: begin
                    case (byte_offset[1])
                        1'b0: begin store_we = 4'b0011; store_data = {16'd0, ex_mem_rs2_data[15:0]};         end
                        1'b1: begin store_we = 4'b1100; store_data = {ex_mem_rs2_data[15:0], 16'd0};         end
                    endcase
                end
                // SW：全字写入
                `FUNCT3_SW: begin
                    store_we   = 4'b1111;
                    store_data = ex_mem_rs2_data;
                end
                default: ;
            endcase
        end
    end

    // 将组合逻辑生成的字节使能和对齐数据连接到 DMEM 接口
    assign dmem_we    = store_we;
    assign dmem_wdata = store_data;

    // ================================================================
    // Load 数据提取与扩展
    // ================================================================
    // 从 dmem 返回的 32 位字中根据 byte_offset 和 funct3 提取目标数据
    // 符号扩展（LB/LH）：高位复制数据的最高有效位（MSB），用于有符号数
    // 零扩展（LBU/LHU）：高位补 0，用于无符号数
    // LW 直接使用完整 32 位字，无需额外处理
    reg [31:0] load_data;

    always @(*) begin
        load_data = 32'd0;
        case (ex_mem_funct3)
            // LB：选字节，高 24 位符号扩展
            `FUNCT3_LB: begin
                case (byte_offset)
                    2'd0: load_data = {{24{dmem_rdata[7]}},  dmem_rdata[7:0]};
                    2'd1: load_data = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                    2'd2: load_data = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                    2'd3: load_data = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                endcase
            end
            // LH：选半字，高 16 位符号扩展
            `FUNCT3_LH: begin
                case (byte_offset[1])
                    1'b0: load_data = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
                    1'b1: load_data = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
                endcase
            end
            `FUNCT3_LW:  load_data = dmem_rdata;
            // LBU：选字节，零扩展
            `FUNCT3_LBU: begin
                case (byte_offset)
                    2'd0: load_data = {24'd0, dmem_rdata[7:0]};
                    2'd1: load_data = {24'd0, dmem_rdata[15:8]};
                    2'd2: load_data = {24'd0, dmem_rdata[23:16]};
                    2'd3: load_data = {24'd0, dmem_rdata[31:24]};
                endcase
            end
            // LHU：选半字，零扩展
            `FUNCT3_LHU: begin
                case (byte_offset[1])
                    1'b0: load_data = {16'd0, dmem_rdata[15:0]};
                    1'b1: load_data = {16'd0, dmem_rdata[31:16]};
                endcase
            end
            default: load_data = dmem_rdata;
        endcase
    end

    // ================================================================
    // MEM/WB 级间寄存器
    // ================================================================
    // 将访存结果锁存到 WB 阶段，包括 ALU 结果和 Load 数据
    // stall_mem 当前固定为 0（无多周期访存），预留扩展接口
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_pc         <= 32'd0;
            mem_wb_alu_result <= 32'd0;
            mem_wb_mem_data   <= 32'd0;
            mem_wb_rd         <= 5'd0;
            mem_wb_reg_we     <= 1'b0;
            mem_wb_wb_sel     <= `WB_SEL_ALU;
            mem_wb_csr_we     <= 1'b0;
            mem_wb_csr_op     <= 3'd0;
            mem_wb_csr_addr   <= 12'd0;
            mem_wb_csr_wdata  <= 32'd0;
            mem_wb_valid      <= 1'b0;
        end else if (!stall) begin
            mem_wb_pc         <= ex_mem_pc;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data   <= load_data;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_reg_we     <= ex_mem_reg_we;
            mem_wb_wb_sel     <= ex_mem_wb_sel;
            mem_wb_csr_we     <= ex_mem_csr_we;
            mem_wb_csr_op     <= ex_mem_csr_op;
            mem_wb_csr_addr   <= ex_mem_csr_addr;
            mem_wb_csr_wdata  <= ex_mem_csr_wdata;
            mem_wb_valid      <= ex_mem_valid;
        end
    end

endmodule
