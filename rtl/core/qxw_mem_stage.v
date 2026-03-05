`include "qxw_defines.vh"

// ================================================================
// 访存阶段（MEM Stage）—— BRAM 同步读适配版
// ================================================================
// DMEM 使用 BRAM 同步读，地址在 T 拍采样，数据在 T+1 拍输出。
// 因此 DMEM 的读数据在 WB 阶段才可用，load 的字节提取和符号扩展
// 移至 WB 阶段处理。MEM/WB 级间寄存器传递 funct3 和 byte_offset。
//
// Store 逻辑不受影响：写地址和数据在 MEM 阶段即可确定。
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

    // MEM/WB 级间寄存器输出
    output reg  [`XLEN_BUS]  mem_wb_pc,
    output reg  [`XLEN_BUS]  mem_wb_alu_result,
    output reg  [`REG_ADDR_BUS] mem_wb_rd,
    output reg               mem_wb_reg_we,
    output reg  [`WB_SEL_BUS]   mem_wb_wb_sel,
    output reg  [2:0]        mem_wb_funct3,
    output reg  [1:0]        mem_wb_byte_offset,
    output reg               mem_wb_csr_we,
    output reg  [2:0]        mem_wb_csr_op,
    output reg  [11:0]       mem_wb_csr_addr,
    output reg  [`XLEN_BUS]  mem_wb_csr_wdata,
    output reg               mem_wb_valid
);

    wire [1:0] byte_offset = ex_mem_alu_result[1:0];

    // ================================================================
    // Store 数据对齐与字节使能生成
    // ================================================================
    assign dmem_en   = (ex_mem_mem_re | ex_mem_mem_we) & ex_mem_valid;
    assign dmem_addr = {ex_mem_alu_result[31:2], 2'b00};

    reg [3:0]  store_we;
    reg [31:0] store_data;

    always @(*) begin
        store_we   = 4'b0000;
        store_data = 32'd0;
        if (ex_mem_mem_we) begin
            case (ex_mem_funct3)
                `FUNCT3_SB: begin
                    case (byte_offset)
                        2'd0: begin store_we = 4'b0001; store_data = {24'd0, ex_mem_rs2_data[7:0]};         end
                        2'd1: begin store_we = 4'b0010; store_data = {16'd0, ex_mem_rs2_data[7:0], 8'd0};   end
                        2'd2: begin store_we = 4'b0100; store_data = {8'd0,  ex_mem_rs2_data[7:0], 16'd0};  end
                        2'd3: begin store_we = 4'b1000; store_data = {ex_mem_rs2_data[7:0], 24'd0};          end
                    endcase
                end
                `FUNCT3_SH: begin
                    case (byte_offset[1])
                        1'b0: begin store_we = 4'b0011; store_data = {16'd0, ex_mem_rs2_data[15:0]};         end
                        1'b1: begin store_we = 4'b1100; store_data = {ex_mem_rs2_data[15:0], 16'd0};         end
                    endcase
                end
                `FUNCT3_SW: begin
                    store_we   = 4'b1111;
                    store_data = ex_mem_rs2_data;
                end
                default: ;
            endcase
        end
    end

    assign dmem_we    = store_we;
    assign dmem_wdata = store_data;

    // ================================================================
    // MEM/WB 级间寄存器
    // ================================================================
    // funct3 和 byte_offset 传递到 WB 阶段，供 load 数据字节提取使用
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_pc          <= 32'd0;
            mem_wb_alu_result  <= 32'd0;
            mem_wb_rd          <= 5'd0;
            mem_wb_reg_we      <= 1'b0;
            mem_wb_wb_sel      <= `WB_SEL_ALU;
            mem_wb_funct3      <= 3'd0;
            mem_wb_byte_offset <= 2'd0;
            mem_wb_csr_we      <= 1'b0;
            mem_wb_csr_op      <= 3'd0;
            mem_wb_csr_addr    <= 12'd0;
            mem_wb_csr_wdata   <= 32'd0;
            mem_wb_valid       <= 1'b0;
        end else if (!stall) begin
            mem_wb_pc          <= ex_mem_pc;
            mem_wb_alu_result  <= ex_mem_alu_result;
            mem_wb_rd          <= ex_mem_rd;
            mem_wb_reg_we      <= ex_mem_reg_we;
            mem_wb_wb_sel      <= ex_mem_wb_sel;
            mem_wb_funct3      <= ex_mem_funct3;
            mem_wb_byte_offset <= byte_offset;
            mem_wb_csr_we      <= ex_mem_csr_we;
            mem_wb_csr_op      <= ex_mem_csr_op;
            mem_wb_csr_addr    <= ex_mem_csr_addr;
            mem_wb_csr_wdata   <= ex_mem_csr_wdata;
            mem_wb_valid       <= ex_mem_valid;
        end
    end

endmodule
