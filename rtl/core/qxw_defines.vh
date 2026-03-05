`ifndef QXW_DEFINES_VH
`define QXW_DEFINES_VH

// ============================================================================
// QXW RV32IM 处理器全局宏定义
// ============================================================================
// 本文件定义了处理器设计中所有共享的常量和编码，包括：
//   - 数据宽度与总线位宽
//   - RISC-V 指令编码（opcode, funct3, funct7, funct12）
//   - ALU/MulDiv/分支/写回等内部控制信号编码
//   - 地址映射与 CSR 地址
//   - 分支预测器参数
//   - 复位向量

// ============================================================================
// 数据宽度与寄存器配置
// ============================================================================
// XLEN=32 对应 RV32 架构，所有数据通路和寄存器均为 32 位
// REG_NUM=32 为 RISC-V 标准的 32 个通用寄存器（x0~x31）
`define XLEN        32
`define XLEN_BUS    31:0
`define REG_ADDR_W  5
`define REG_ADDR_BUS 4:0
`define REG_NUM     32
`define INST_W      32
`define INST_BUS    31:0

// ============================================================================
// RV32I 操作码 Opcode (inst[6:0])
// ============================================================================
// RISC-V 指令的低 7 位为操作码，用于一级译码确定指令大类
// 操作码编码遵循 RISC-V 规范 Table 19.1
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
// funct3 编码 -- 条件分支指令
// ============================================================================
// 六种条件分支：BEQ/BNE 判相等，BLT/BGE 有符号比较，BLTU/BGEU 无符号比较
`define FUNCT3_BEQ      3'b000
`define FUNCT3_BNE      3'b001
`define FUNCT3_BLT      3'b100
`define FUNCT3_BGE      3'b101
`define FUNCT3_BLTU     3'b110
`define FUNCT3_BGEU     3'b111

// ============================================================================
// funct3 编码 -- Load 指令
// ============================================================================
// LB/LH 带符号扩展，LBU/LHU 零扩展，LW 加载完整字
`define FUNCT3_LB       3'b000
`define FUNCT3_LH       3'b001
`define FUNCT3_LW       3'b010
`define FUNCT3_LBU      3'b100
`define FUNCT3_LHU      3'b101

// ============================================================================
// funct3 编码 -- Store 指令
// ============================================================================
// SB 存字节，SH 存半字，SW 存全字
`define FUNCT3_SB       3'b000
`define FUNCT3_SH       3'b001
`define FUNCT3_SW       3'b010

// ============================================================================
// funct3 编码 -- 算术逻辑运算（OP-IMM / OP 共用）
// ============================================================================
// ADD_SUB 在 OP 指令中通过 funct7[5] 区分加法和减法
// SRL_SRA 同理区分逻辑右移和算术右移
`define FUNCT3_ADD_SUB  3'b000
`define FUNCT3_SLL      3'b001
`define FUNCT3_SLT      3'b010
`define FUNCT3_SLTU     3'b011
`define FUNCT3_XOR      3'b100
`define FUNCT3_SRL_SRA  3'b101
`define FUNCT3_OR       3'b110
`define FUNCT3_AND      3'b111

// ============================================================================
// funct7 编码（inst[31:25]）
// ============================================================================
// NORMAL：普通 ALU 运算 | SUB_SRA：减法或算术右移 | MULDIV：M 扩展乘除法
`define FUNCT7_NORMAL   7'b0000000
`define FUNCT7_SUB_SRA  7'b0100000
`define FUNCT7_MULDIV   7'b0000001

// ============================================================================
// funct3 编码 -- M 扩展乘除法指令
// ============================================================================
// MUL 系列（0~3）：乘法，区分结果取低/高 32 位及操作数符号性
// DIV 系列（4~7）：除法/取余，区分有符号和无符号
`define FUNCT3_MUL      3'b000
`define FUNCT3_MULH     3'b001
`define FUNCT3_MULHSU   3'b010
`define FUNCT3_MULHU    3'b011
`define FUNCT3_DIV      3'b100
`define FUNCT3_DIVU     3'b101
`define FUNCT3_REM      3'b110
`define FUNCT3_REMU     3'b111

// ============================================================================
// funct3 编码 -- SYSTEM 指令（CSR 操作与特权指令）
// ============================================================================
// PRIV(000)：特权指令（ECALL/EBREAK/MRET），由 funct12 进一步区分
// CSR 操作分寄存器型（RW/RS/RC）和立即数型（RWI/RSI/RCI）
`define FUNCT3_PRIV     3'b000
`define FUNCT3_CSRRW    3'b001
`define FUNCT3_CSRRS    3'b010
`define FUNCT3_CSRRC    3'b011
`define FUNCT3_CSRRWI   3'b101
`define FUNCT3_CSRRSI   3'b110
`define FUNCT3_CSRRCI   3'b111

// funct12 编码（inst[31:20]）：用于区分 SYSTEM 特权指令
`define FUNCT12_ECALL   12'b000000000000
`define FUNCT12_EBREAK  12'b000000000001
`define FUNCT12_MRET    12'b001100000010

// ============================================================================
// ALU 内部操作码（4 位编码，由 ID 阶段译码生成）
// ============================================================================
// 编码 0~9 对应 RV32I 的十种运算，PASS_B(10) 用于 LUI 直通立即数
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
// MulDiv 操作码（3 位编码，与 funct3 编码一致）
// ============================================================================
// 编码 0~3 为乘法，4~7 为除法/取余
// md_op >= MD_DIV 用于判断是否需要启动多周期除法迭代
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
// 写回结果来源选择（2 位编码）
// ============================================================================
// WB 阶段根据此编码从四种数据源中选择写入寄存器堆的值
`define WB_SEL_W        2
`define WB_SEL_BUS      1:0
`define WB_SEL_ALU      2'd0
`define WB_SEL_MEM      2'd1
`define WB_SEL_PC4      2'd2
`define WB_SEL_CSR      2'd3

// ============================================================================
// 立即数类型编码（ID 阶段内部使用）
// ============================================================================
// 五种立即数格式对应不同的指令类型
// I: Load/OP-IMM/JALR | S: Store | B: Branch | U: LUI/AUIPC | J: JAL
`define IMM_TYPE_W      3
`define IMM_TYPE_BUS    2:0
`define IMM_I           3'd0
`define IMM_S           3'd1
`define IMM_B           3'd2
`define IMM_U           3'd3
`define IMM_J           3'd4

// ============================================================================
// 分支类型编码（3 位，由 ID 阶段根据 opcode 和 funct3 生成）
// ============================================================================
// NONE 表示非分支指令，JAL 表示无条件跳转
// EX 阶段根据此编码选择对应的比较逻辑
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
// SoC 地址映射（总线地址译码使用）
// ============================================================================
// MASK 用于地址空间大小检查，BASE 为起始地址
// IMEM 和 DMEM 各 16KB，UART 和 Timer 各 256B 寄存器空间
`define ADDR_IMEM_BASE  32'h0000_0000
`define ADDR_IMEM_MASK  32'hFFFF_C000   // 16KB
`define ADDR_DMEM_BASE  32'h0001_0000
`define ADDR_DMEM_MASK  32'hFFFF_C000   // 16KB
`define ADDR_UART_BASE  32'h1000_0000
`define ADDR_UART_MASK  32'hFFFF_FF00   // 256B
`define ADDR_TIMER_BASE 32'h1000_1000
`define ADDR_TIMER_MASK 32'hFFFF_FF00   // 256B

// ============================================================================
// CSR 寄存器地址（12 位编码，符合 RISC-V 特权规范）
// ============================================================================
// 0x300~0x344：Machine 模式陷阱相关寄存器
// 0xB00~0xB82：Machine 模式性能计数器（mcycle/minstret，64 位分高低访问）
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
// 分支预测器 BHT（Branch History Table）参数
// ============================================================================
// BHT_ENTRIES=256 项，使用 PC[9:2] 的 8 位索引
// 两位饱和计数器：SN/WN 预测不跳转，WT/ST 预测跳转
`define BHT_ENTRIES     256
`define BHT_IDX_W      8

// 两位饱和计数器状态
`define BHT_SN          2'b00   // strongly not-taken
`define BHT_WN          2'b01   // weakly not-taken
`define BHT_WT          2'b10   // weakly taken
`define BHT_ST          2'b11   // strongly taken

// ============================================================================
// 复位向量（PC 初始值）
// ============================================================================
// 处理器复位后从此地址开始取指执行，通常指向 bootloader 或 firmware 入口
`define RST_PC          32'h0000_0000

`endif
