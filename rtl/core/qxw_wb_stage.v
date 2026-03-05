`include "qxw_defines.vh"

// ================================================================
// 写回阶段（WB Stage）—— BRAM 同步读适配版
// ================================================================
// DMEM 使用 BRAM 同步读，读数据在 WB 阶段才可用（dmem_rdata_wb）。
// Load 的字节提取和符号扩展在此阶段完成。
// ================================================================
module qxw_wb_stage (
    // MEM/WB 级间寄存器输入
    input  wire [`XLEN_BUS]     mem_wb_pc,
    input  wire [`XLEN_BUS]     mem_wb_alu_result,
    input  wire [`REG_ADDR_BUS] mem_wb_rd,
    input  wire                 mem_wb_reg_we,
    input  wire [`WB_SEL_BUS]   mem_wb_wb_sel,
    input  wire [2:0]           mem_wb_funct3,
    input  wire [1:0]           mem_wb_byte_offset,
    input  wire                 mem_wb_valid,

    // DMEM 同步读数据（BRAM 输出，在 WB 阶段可用）
    input  wire [`XLEN_BUS]     dmem_rdata_wb,

    // CSR 读取值（用于 WB_SEL_CSR）
    input  wire [`XLEN_BUS]     csr_rdata,

    // 写回寄存器堆信号
    output wire                 rf_we,
    output wire [`REG_ADDR_BUS] rf_wa,
    output reg  [`XLEN_BUS]     rf_wd
);

    assign rf_we = mem_wb_reg_we & mem_wb_valid;
    assign rf_wa = mem_wb_rd;

    // Load 数据字节提取与符号/零扩展
    reg [31:0] load_data;
    always @(*) begin
        load_data = 32'd0;
        case (mem_wb_funct3)
            `FUNCT3_LB: begin
                case (mem_wb_byte_offset)
                    2'd0: load_data = {{24{dmem_rdata_wb[7]}},  dmem_rdata_wb[7:0]};
                    2'd1: load_data = {{24{dmem_rdata_wb[15]}}, dmem_rdata_wb[15:8]};
                    2'd2: load_data = {{24{dmem_rdata_wb[23]}}, dmem_rdata_wb[23:16]};
                    2'd3: load_data = {{24{dmem_rdata_wb[31]}}, dmem_rdata_wb[31:24]};
                endcase
            end
            `FUNCT3_LH: begin
                case (mem_wb_byte_offset[1])
                    1'b0: load_data = {{16{dmem_rdata_wb[15]}}, dmem_rdata_wb[15:0]};
                    1'b1: load_data = {{16{dmem_rdata_wb[31]}}, dmem_rdata_wb[31:16]};
                endcase
            end
            `FUNCT3_LW:  load_data = dmem_rdata_wb;
            `FUNCT3_LBU: begin
                case (mem_wb_byte_offset)
                    2'd0: load_data = {24'd0, dmem_rdata_wb[7:0]};
                    2'd1: load_data = {24'd0, dmem_rdata_wb[15:8]};
                    2'd2: load_data = {24'd0, dmem_rdata_wb[23:16]};
                    2'd3: load_data = {24'd0, dmem_rdata_wb[31:24]};
                endcase
            end
            `FUNCT3_LHU: begin
                case (mem_wb_byte_offset[1])
                    1'b0: load_data = {16'd0, dmem_rdata_wb[15:0]};
                    1'b1: load_data = {16'd0, dmem_rdata_wb[31:16]};
                endcase
            end
            default: load_data = dmem_rdata_wb;
        endcase
    end

    // 写回数据四选一
    always @(*) begin
        case (mem_wb_wb_sel)
            `WB_SEL_ALU: rf_wd = mem_wb_alu_result;
            `WB_SEL_MEM: rf_wd = load_data;
            `WB_SEL_PC4: rf_wd = mem_wb_pc + 32'd4;
            `WB_SEL_CSR: rf_wd = csr_rdata;
            default:     rf_wd = mem_wb_alu_result;
        endcase
    end

endmodule
