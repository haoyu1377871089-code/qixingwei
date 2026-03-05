`ifndef QXW_DEFINES_VH
`define QXW_DEFINES_VH

// ============================================================================
// 数据宽度
// ============================================================================
`define XLEN        32
`define XLEN_BUS    31:0
`define REG_ADDR_W  5
`define REG_ADDR_BUS 4:0
`define REG_NUM     32
`define INST_W      32
`define INST_BUS    31:0

// ============================================================================
// RV32I Opcode (inst[6:0])
// ============================================================================
`define OPCODE_LUI      7'b0110111
`define OPCODE_AUIPC    7'b0010111
`define OPCODE_JAL      7'b1101111
`define OPCODE_JALR     7'b1100111
`define OPCODE_BRANCH   7'b1100011
`define OPCODE_LOAD     7'b0000011
`define OPCODE_STORE    7'b0100011
`define OPCODE_OP_IMM   7'b0010011
`define OPCODE_OP       7'b0110011
`define OPCODE_FENCE    7'b0001111
`define OPCODE_SYSTEM   7'b1110011

// ============================================================================
// funct3 -- Branch
// ============================================================================
`define FUNCT3_BEQ      3'b000
`define FUNCT3_BNE      3'b001
`define FUNCT3_BLT      3'b100
`define FUNCT3_BGE      3'b101
`define FUNCT3_BLTU     3'b110
`define FUNCT3_BGEU     3'b111

// ============================================================================
// funct3 -- Load
// ============================================================================
`define FUNCT3_LB       3'b000
`define FUNCT3_LH       3'b001
`define FUNCT3_LW       3'b010
`define FUNCT3_LBU      3'b100
`define FUNCT3_LHU      3'b101

// ============================================================================
// funct3 -- Store
// ============================================================================
`define FUNCT3_SB       3'b000
`define FUNCT3_SH       3'b001
`define FUNCT3_SW       3'b010

// ============================================================================
// funct3 -- OP-IMM / OP
// ============================================================================
`define FUNCT3_ADD_SUB  3'b000
`define FUNCT3_SLL      3'b001
`define FUNCT3_SLT      3'b010
`define FUNCT3_SLTU     3'b011
`define FUNCT3_XOR      3'b100
`define FUNCT3_SRL_SRA  3'b101
`define FUNCT3_OR       3'b110
`define FUNCT3_AND      3'b111

// ============================================================================
// funct7
// ============================================================================
`define FUNCT7_NORMAL   7'b0000000
`define FUNCT7_SUB_SRA  7'b0100000
`define FUNCT7_MULDIV   7'b0000001

// ============================================================================
// funct3 -- M extension
// ============================================================================
`define FUNCT3_MUL      3'b000
`define FUNCT3_MULH     3'b001
`define FUNCT3_MULHSU   3'b010
`define FUNCT3_MULHU    3'b011
`define FUNCT3_DIV      3'b100
`define FUNCT3_DIVU     3'b101
`define FUNCT3_REM      3'b110
`define FUNCT3_REMU     3'b111

// ============================================================================
// funct3 -- SYSTEM (CSR)
// ============================================================================
`define FUNCT3_PRIV     3'b000
`define FUNCT3_CSRRW    3'b001
`define FUNCT3_CSRRS    3'b010
`define FUNCT3_CSRRC    3'b011
`define FUNCT3_CSRRWI   3'b101
`define FUNCT3_CSRRSI   3'b110
`define FUNCT3_CSRRCI   3'b111

// funct12 for ECALL / EBREAK / MRET
`define FUNCT12_ECALL   12'b000000000000
`define FUNCT12_EBREAK  12'b000000000001
`define FUNCT12_MRET    12'b001100000010

// ============================================================================
// ALU 操作码 (4-bit)
// ============================================================================
`define ALU_OP_W        4
`define ALU_OP_BUS      3:0
`define ALU_ADD         4'd0
`define ALU_SUB         4'd1
`define ALU_SLL         4'd2
`define ALU_SLT         4'd3
`define ALU_SLTU        4'd4
`define ALU_XOR         4'd5
`define ALU_SRL         4'd6
`define ALU_SRA         4'd7
`define ALU_OR          4'd8
`define ALU_AND         4'd9
`define ALU_PASS_B      4'd10  // passthrough operand B (LUI)

// ============================================================================
// MulDiv 操作码 (3-bit)
// ============================================================================
`define MD_OP_W         3
`define MD_OP_BUS       2:0
`define MD_MUL          3'd0
`define MD_MULH         3'd1
`define MD_MULHSU       3'd2
`define MD_MULHU        3'd3
`define MD_DIV          3'd4
`define MD_DIVU         3'd5
`define MD_REM          3'd6
`define MD_REMU         3'd7

// ============================================================================
// 写回结果来源
// ============================================================================
`define WB_SEL_W        2
`define WB_SEL_BUS      1:0
`define WB_SEL_ALU      2'd0
`define WB_SEL_MEM      2'd1
`define WB_SEL_PC4      2'd2
`define WB_SEL_CSR      2'd3

// ============================================================================
// 立即数类型
// ============================================================================
`define IMM_TYPE_W      3
`define IMM_TYPE_BUS    2:0
`define IMM_I           3'd0
`define IMM_S           3'd1
`define IMM_B           3'd2
`define IMM_U           3'd3
`define IMM_J           3'd4

// ============================================================================
// 分支类型
// ============================================================================
`define BR_TYPE_W       3
`define BR_TYPE_BUS     2:0
`define BR_NONE         3'd0
`define BR_BEQ          3'd1
`define BR_BNE          3'd2
`define BR_BLT          3'd3
`define BR_BGE          3'd4
`define BR_BLTU         3'd5
`define BR_BGEU         3'd6
`define BR_JAL          3'd7

// ============================================================================
// 地址映射
// ============================================================================
`define ADDR_IMEM_BASE  32'h0000_0000
`define ADDR_IMEM_MASK  32'hFFFF_C000   // 16KB
`define ADDR_DMEM_BASE  32'h0001_0000
`define ADDR_DMEM_MASK  32'hFFFF_C000   // 16KB
`define ADDR_UART_BASE  32'h1000_0000
`define ADDR_UART_MASK  32'hFFFF_FF00   // 256B
`define ADDR_TIMER_BASE 32'h1000_1000
`define ADDR_TIMER_MASK 32'hFFFF_FF00   // 256B

// ============================================================================
// CSR 地址
// ============================================================================
`define CSR_ADDR_W      12
`define CSR_ADDR_BUS    11:0
`define CSR_MSTATUS     12'h300
`define CSR_MIE         12'h304
`define CSR_MTVEC       12'h305
`define CSR_MEPC        12'h341
`define CSR_MCAUSE      12'h342
`define CSR_MTVAL       12'h343
`define CSR_MIP         12'h344
`define CSR_MCYCLE      12'hB00
`define CSR_MINSTRET    12'hB02
`define CSR_MCYCLEH     12'hB80
`define CSR_MINSTRETH   12'hB82

// ============================================================================
// 分支预测 BHT 参数
// ============================================================================
`define BHT_ENTRIES     256
`define BHT_IDX_W      8

// 两位饱和计数器状态
`define BHT_SN          2'b00   // strongly not-taken
`define BHT_WN          2'b01   // weakly not-taken
`define BHT_WT          2'b10   // weakly taken
`define BHT_ST          2'b11   // strongly taken

// ============================================================================
// 复位向量
// ============================================================================
`define RST_PC          32'h0000_0000

`endif
