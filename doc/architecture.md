# QXW RISC-V CPU 架构设计说明书

## 1. 项目概述

### 1.1 设计目标

QXW 是一款基于 RISC-V 指令集架构的五级流水线 CPU 软核，采用 Verilog 独立设计，面向 FPGA 实现与验证。设计目标包括：

- **指令集**：完整支持 RV32I 基础整数指令集 + M 扩展（乘除法）
- **流水线**：经典五级流水线（IF/ID/EX/MEM/WB），级间寄存器隔离
- **冒险处理**：全数据转发 + BHT 分支预测，减少流水线停顿
- **SoC 集成**：最小系统包含指令/数据存储器、UART、Timer 等外设

### 1.2 目标器件

- **FPGA**：Xilinx Zynq-7020（XC7Z020CLG400-2）
- **目标板**：ALINX AX7020
- **目标频率**：≥ 50 MHz
- **资源约束**：< 5,000 LUTs

### 1.3 验收标准

| 项目 | 要求 |
|------|------|
| 功能仿真 | riscv-tests 全部通过 |
| FPGA 综合 | Vivado 综合通过，时序收敛 ≥ 50 MHz |
| 后仿真 | 综合后网表仿真功能正确 |
| 资源 | < 5,000 LUTs |

---

## 2. 总体架构

### 2.1 五级流水线框图

```
                    ┌─────────────────────────────────────────────────────────────────┐
                    │                        QXW CPU 五级流水线                         │
                    └─────────────────────────────────────────────────────────────────┘

    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │    IF    │───▶│    ID    │───▶│    EX    │───▶│   MEM    │───▶│    WB    │
    │  取指    │    │  译码    │    │  执行    │    │  访存    │    │  写回    │
    └────┬─────┘    └────┬─────┘    └────┬─────┘    └────┬─────┘    └────┬─────┘
         │               │               │               │               │
         │               │               │               │               │
    ┌────▼─────┐    ┌────▼─────┐    ┌────▼─────┐    ┌────▼─────┐    ┌────▼─────┐
    │  IMEM    │    │ RegFile  │    │ ALU      │    │  DMEM    │    │ RegFile  │
    │ 取指令   │    │ 读 rs1/2 │    │ MulDiv   │    │ Load/St  │    │ 写 rd    │
    └──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
         │               │               │               │               │
         │               │         ┌─────┴─────┐         │               │
         │               │         │ Forwarding│         │               │
         │               │         │ Hazard    │         │               │
         │               │         │ BranchPred│         │               │
         │               │         └───────────┘         │               │
         │               │               │               │               │
         └───────────────┴───────────────┴───────────────┴───────────────┘
                                    stall / flush
```

### 2.2 Harvard 架构

QXW 采用 **Harvard 架构**，指令存储器与数据存储器物理分离：

- **指令端口**：CPU 的 `imem_addr` / `imem_rdata` 直连指令 ROM，不经过总线
- **数据端口**：CPU 的 `dmem_*` 接口经 `qxw_bus` 地址译码后访问数据 RAM、UART、Timer

该设计消除了取指与访存的结构冒险，使 IF 与 MEM 阶段可并行工作。

### 2.3 SoC 结构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           qxw_soc_top                                        │
│  ┌─────────────┐     ┌─────────────┐                                        │
│  │   qxw_imem  │◀────│             │  指令端口直连                            │
│  │   16KB ROM  │     │ qxw_cpu_top │                                        │
│  └─────────────┘     │             │  数据端口                               │
│                      │             │──────▶┌─────────────┐                   │
│                      └─────────────┘       │  qxw_bus    │                   │
│                             │              └──────┬──────┘                   │
│                             │ timer_irq          │ 地址译码                  │
│                             │                    │                          │
│                      ┌──────▼──────┐    ┌────────┼────────┬────────┐        │
│                      │ qxw_timer   │    │        │        │        │        │
│                      │ 64b 计时器  │    ▼        ▼        ▼        │        │
│                      └─────────────┘  qxw_dmem qxw_uart qxw_timer  │        │
│                                       │ 16KB   │ 串口   │ 定时器   │        │
│                                       └────────┴────────┴─────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. 指令集支持

### 3.1 RV32I 完整指令列表（按类型分组）

#### 3.1.1 算术与逻辑（OP-IMM / OP）

| 指令 | 助记符 | funct3 | 说明 |
|------|--------|--------|------|
| ADDI | addi rd, rs1, imm | 000 | 立即数加法 |
| SLTI | slti rd, rs1, imm | 010 | 有符号比较 |
| SLTIU | sltiu rd, rs1, imm | 011 | 无符号比较 |
| XORI | xori rd, rs1, imm | 100 | 立即数异或 |
| ORI | ori rd, rs1, imm | 110 | 立即数或 |
| ANDI | andi rd, rs1, imm | 111 | 立即数与 |
| SLLI | slli rd, rs1, shamt | 001 | 逻辑左移 |
| SRLI | srli rd, rs1, shamt | 101 | 逻辑右移 |
| SRAI | srai rd, rs1, shamt | 101 | 算术右移 |
| ADD | add rd, rs1, rs2 | 000 | 加法 |
| SUB | sub rd, rs1, rs2 | 000 | 减法 |
| SLL | sll rd, rs1, rs2 | 001 | 逻辑左移 |
| SLT | slt rd, rs1, rs2 | 010 | 有符号比较 |
| SLTU | sltu rd, rs1, rs2 | 011 | 无符号比较 |
| XOR | xor rd, rs1, rs2 | 100 | 异或 |
| SRL | srl rd, rs1, rs2 | 101 | 逻辑右移 |
| SRA | sra rd, rs1, rs2 | 101 | 算术右移 |
| OR | or rd, rs1, rs2 | 110 | 或 |
| AND | and rd, rs1, rs2 | 111 | 与 |

#### 3.1.2 立即数加载与 PC 相关

| 指令 | 助记符 | 说明 |
|------|--------|------|
| LUI | lui rd, imm | 加载高位立即数 |
| AUIPC | auipc rd, imm | PC + 立即数 |

#### 3.1.3 分支与跳转

| 指令 | 助记符 | funct3 | 说明 |
|------|--------|--------|------|
| JAL | jal rd, offset | - | 无条件跳转，rd = PC+4 |
| JALR | jalr rd, rs1, imm | 000 | 间接跳转，rd = PC+4 |
| BEQ | beq rs1, rs2, offset | 000 | 相等则分支 |
| BNE | bne rs1, rs2, offset | 001 | 不等则分支 |
| BLT | blt rs1, rs2, offset | 100 | 有符号小于则分支 |
| BGE | bge rs1, rs2, offset | 101 | 有符号大于等于则分支 |
| BLTU | bltu rs1, rs2, offset | 110 | 无符号小于则分支 |
| BGEU | bgeu rs1, rs2, offset | 111 | 无符号大于等于则分支 |

#### 3.1.4 访存

| 指令 | 助记符 | funct3 | 说明 |
|------|--------|--------|------|
| LB | lb rd, offset(rs1) | 000 | 加载有符号字节 |
| LH | lh rd, offset(rs1) | 001 | 加载有符号半字 |
| LW | lw rd, offset(rs1) | 010 | 加载字 |
| LBU | lbu rd, offset(rs1) | 100 | 加载无符号字节 |
| LHU | lhu rd, offset(rs1) | 101 | 加载无符号半字 |
| SB | sb rs2, offset(rs1) | 000 | 存储字节 |
| SH | sh rs2, offset(rs1) | 001 | 存储半字 |
| SW | sw rs2, offset(rs1) | 010 | 存储字 |

#### 3.1.5 系统与 CSR

| 指令 | 助记符 | 说明 |
|------|--------|------|
| ECALL | ecall | 环境调用异常 |
| EBREAK | ebreak | 断点异常 |
| MRET | mret | 从异常返回 |
| CSRRW | csrrw rd, csr, rs1 | 读后写 CSR |
| CSRRS | csrrs rd, csr, rs1 | 读后置位 |
| CSRRC | csrrc rd, csr, rs1 | 读后清除 |
| CSRRWI | csrrwi rd, csr, zimm | 立即数读后写 |
| CSRRSI | csrrsi rd, csr, zimm | 立即数读后置位 |
| CSRRCI | csrrci rd, csr, zimm | 立即数读后清除 |

**注**：FENCE 指令（opcode 0001111）未实现，解码为 NOP。

### 3.2 M 扩展指令列表

| 指令 | 助记符 | funct3 | 说明 |
|------|--------|--------|------|
| MUL | mul rd, rs1, rs2 | 000 | 有符号乘法（低 32 位） |
| MULH | mulh rd, rs1, rs2 | 001 | 有符号×有符号（高 32 位） |
| MULHSU | mulhsu rd, rs1, rs2 | 010 | 有符号×无符号（高 32 位） |
| MULHU | mulhu rd, rs1, rs2 | 011 | 无符号×无符号（高 32 位） |
| DIV | div rd, rs1, rs2 | 100 | 有符号除法 |
| DIVU | divu rd, rs1, rs2 | 101 | 无符号除法 |
| REM | rem rd, rs1, rs2 | 110 | 有符号取余 |
| REMU | remu rd, rs1, rs2 | 111 | 无符号取余 |

---

## 4. 流水线各阶段详细设计

### 4.1 取指阶段（IF）

**模块**：`qxw_if_stage` + `qxw_pc_reg`

#### 4.1.1 PC 管理

- **复位向量**：`RST_PC = 32'h0000_0000`
- **下一 PC 选择优先级**（`qxw_pc_reg`）：
  1. `trap`：异常/中断 → `mtvec`
  2. `mret`：异常返回 → `mepc`
  3. `flush`：分支预测错误 → `flush_target`（实际目标或 PC+4）
  4. `pred_taken`：BHT 预测跳转 → `pred_target`
  5. 默认：`PC + 4`

#### 4.1.2 分支预测器交互

- **索引**：`bpu_idx = pc[9:2]`（8 位，256 项 BHT）
- **预测**：IF 阶段根据 `bpu_pred_taken` 决定是否使用预测目标
- **目标计算**：B-type 立即数在 IF 阶段从 `imem_rdata` 提取，计算 `pc + b_imm` 作为 `if_id_pred_target`
- **更新**：EX 阶段分支指令退休时，根据 `branch_taken` 更新 BHT

### 4.2 译码阶段（ID）

**模块**：`qxw_id_stage`

#### 4.2.1 指令解码

- 从 `if_id_inst` 提取 `opcode`、`funct3`、`funct7`、`funct12`、`rd`、`rs1`、`rs2`
- 组合逻辑生成 `dec_alu_op`、`dec_alu_src_a/b`、`dec_reg_we`、`dec_mem_re/we`、`dec_wb_sel`、`dec_br_type`、`dec_is_jalr`、`dec_is_muldiv`、`dec_md_op`、`dec_csr_*`、`dec_ecall/ebreak/mret`

#### 4.2.2 立即数生成

| 类型 | 编码 | 格式 | 示例字段 |
|------|------|------|----------|
| I-type | IMM_I | {{20{inst[31]}}, inst[31:20]} | JALR, Load, OP-IMM |
| S-type | IMM_S | {{20{inst[31]}}, inst[31:25], inst[11:7]} | Store |
| B-type | IMM_B | {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0} | Branch |
| U-type | IMM_U | {inst[31:12], 12'd0} | LUI, AUIPC |
| J-type | IMM_J | {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0} | JAL |

#### 4.2.3 控制信号

- **ALU 源**：`alu_src_a`（0=rs1, 1=pc）、`alu_src_b`（0=rs2, 1=imm）
- **写回选择**：`wb_sel` → ALU / MEM / PC+4 / CSR
- **分支类型**：`br_type` → NONE / BEQ / BNE / BLT / BGE / BLTU / BGEU / JAL

### 4.3 执行阶段（EX）

**模块**：`qxw_ex_stage` + `qxw_alu` + `qxw_muldiv`

#### 4.3.1 ALU 运算

- **操作数**：`alu_op_a` = `alu_src_a ? pc : fwd_rs1_data`，`alu_op_b` = `alu_src_b ? imm : fwd_rs2_data`
- **ALU 操作码**：ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND, PASS_B（LUI）
- **输出**：`alu_result`、`zero`（用于 BEQ/BNE）

#### 4.3.2 乘除法

- **乘法**：组合逻辑，单周期完成，综合映射到 DSP48E1
- **除法**：32 周期 restoring division，`busy`/`valid` 握手，除法期间流水线 stall
- **结果选择**：`ex_result = id_ex_is_muldiv ? md_result : alu_result`

#### 4.3.3 分支判断

- **条件**：`br_eq`、`br_lt`、`br_ltu` 组合生成 `br_cond`
- **目标**：JALR → `(rs1 + imm) & 32'hFFFF_FFFE`；其他 → `pc + imm`
- **预测错误**：`branch_mispredict` 在以下情况置位：
  - 实际 taken 但未预测 / 预测目标错误
  - 实际 not-taken 但预测 taken
  - JALR 总是冲刷（无法静态预测）

### 4.4 访存阶段（MEM）

**模块**：`qxw_mem_stage`

#### 4.4.1 Load/Store 对齐

- **地址**：`dmem_addr = {ex_mem_alu_result[31:2], 2'b00}`（字对齐）
- **字节偏移**：`byte_offset = ex_mem_alu_result[1:0]`

#### 4.4.2 Store 字节使能

| funct3 | 类型 | 字节使能 |
|--------|------|----------|
| SB | 字节 | 按 byte_offset 选 4'b0001/0010/0100/1000 |
| SH | 半字 | byte_offset[1]=0 → 4'b0011；=1 → 4'b1100 |
| SW | 字 | 4'b1111 |

#### 4.4.3 Load 符号/零扩展

| funct3 | 类型 | 扩展方式 |
|--------|------|----------|
| LB | 有符号字节 | 高 24 位符号扩展 |
| LH | 有符号半字 | 高 16 位符号扩展 |
| LW | 字 | 直接传递 |
| LBU | 无符号字节 | 高 24 位零扩展 |
| LHU | 无符号半字 | 高 16 位零扩展 |

### 4.5 写回阶段（WB）

**模块**：`qxw_wb_stage`

#### 4.5.1 结果选择

| wb_sel | 来源 | 用途 |
|--------|------|------|
| WB_SEL_ALU | mem_wb_alu_result | 算术/逻辑/乘除/LUI/AUIPC |
| WB_SEL_MEM | mem_wb_mem_data | Load |
| WB_SEL_PC4 | mem_wb_pc + 4 | JAL/JALR |
| WB_SEL_CSR | csr_rdata | CSR 读指令 |

- **写使能**：`rf_we = mem_wb_reg_we & mem_wb_valid`
- **写地址**：`rf_wa = mem_wb_rd`

---

## 5. 冒险处理

### 5.1 数据冒险：三路全转发机制

**模块**：`qxw_forwarding`

- **EX/MEM 转发**：当 `ex_mem_rd == id_ex_rs1/rs2` 且写使能有效时，将 `ex_mem_alu_result` 转发给 EX 阶段操作数
- **MEM/WB 转发**：当 `mem_wb_rd == id_ex_rs1/rs2` 且写使能有效时，将 `mem_wb_wd`（最终写回值）转发
- **优先级**：EX > MEM > WB（最新值优先）
- **x0 不转发**：`rd == 5'd0` 时不参与转发

### 5.2 控制冒险：BHT 分支预测 + 冲刷

**模块**：`qxw_branch_pred` + `qxw_hazard_ctrl`

- **BHT**：256 项 × 2-bit 饱和计数器，PC[9:2] 索引
- **状态**：SN(00) → WN(01) → WT(10) → ST(11)，≥WT 预测 taken
- **冲刷**：`branch_mispredict` 时 `flush_if_id`、`flush_id_ex`，丢弃错误路径指令
- **JALR**：不参与 BHT 预测，总是冲刷并等待 EX 阶段目标

### 5.3 结构冒险：Harvard 架构避免

- 指令与数据存储器分离，无取指-访存冲突
- 寄存器堆双读单写，写优先逻辑处理同周期写读

### 5.4 Load-Use 冒险：1 周期 stall

**检测**：`id_ex_mem_re & id_ex_valid & (id_ex_rd == id_rs1 | id_ex_rd == id_rs2)`

- **stall**：`stall_if`、`stall_id` 置位，插入 bubble
- **flush**：`flush_id_ex` 冲刷 ID/EX 级间寄存器中的 Load 指令后的依赖指令，使其在下一周期重新进入 ID

---

## 6. CSR 与异常处理

### 6.1 M-mode CSR 列表

| 地址 | 名称 | 说明 |
|------|------|------|
| 0x300 | mstatus | MIE(3), MPIE(7) |
| 0x304 | mie | MTIE(7) |
| 0x305 | mtvec | 异常入口基地址 |
| 0x341 | mepc | 异常返回地址 |
| 0x342 | mcause | 异常原因 |
| 0x343 | mtval | 异常值 |
| 0x344 | mip | MTIP(7) 由硬件设置 |
| 0xB00 | mcycle | 周期计数器低 32 位 |
| 0xB02 | minstret | 指令退休计数低 32 位 |
| 0xB80 | mcycleh | 周期计数器高 32 位 |
| 0xB82 | minstreth | 指令退休计数高 32 位 |

### 6.2 ECALL 流程

1. EX 阶段检测 `id_ex_ecall`
2. CSR 模块：`mepc <= epc`，`mcause <= 11`，`mstatus[7] <= mstatus[3]`，`mstatus[3] <= 0`
3. `trap` 置位，PC 跳转至 `mtvec`
4. 冒险控制 `flush_if_id`、`flush_id_ex`、`flush_ex_mem`

### 6.3 MRET 流程

1. EX 阶段检测 `id_ex_mret`
2. CSR 模块：`mstatus[3] <= mstatus[7]`，`mstatus[7] <= 1`
3. PC 跳转至 `mepc`
4. 冒险控制 `flush_if_id`、`flush_id_ex`

### 6.4 Timer 中断

- 当 `mtime >= mtimecmp` 时 `timer_irq` 置位
- 若 `mstatus[3] & mie[7] & mip[7]`，产生 trap，`mcause` 高位置 1 表示中断，低 7 位为 7（MTIP）

---

## 7. SoC 最小系统

### 7.1 地址映射表

| 组件 | 基地址 | 掩码 | 大小 | 说明 |
|------|--------|------|------|------|
| 指令 ROM | 0x0000_0000 | 0xFFFF_C000 | 16 KB | BRAM，直连 CPU |
| 数据 RAM | 0x0001_0000 | 0xFFFF_C000 | 16 KB | BRAM，经总线 |
| UART | 0x1000_0000 | 0xFFFF_FF00 | 256 B | 串口调试 |
| Timer | 0x1000_1000 | 0xFFFF_FF00 | 256 B | 64-bit mtime/mtimecmp |

### 7.2 总线设计

**模块**：`qxw_bus`

- **类型**：简单地址译码总线，无仲裁
- **译码**：`sel_ram = (addr[31:16]==16'h0001)`，`sel_uart = (addr[31:8]==24'h100000)`，`sel_timer = (addr[31:8]==24'h100010)`
- **读数据**：多路选择 ram_rdata / uart_rdata / timer_rdata

### 7.3 UART

- **寄存器**：0x00 TX_DATA（写触发发送），0x04 TX_STATUS（tx_busy 只读）
- **波特率**：115200 @ 50 MHz 可配置
- **仿真**：`SIMULATION` 宏下写 TX_DATA 时 `$write` 打印字符

### 7.4 Timer

- **寄存器**：0x00 mtime_lo，0x04 mtime_hi，0x08 mtimecmp_lo，0x0C mtimecmp_hi
- **中断**：`mtime >= mtimecmp` 时 `timer_irq` 置位
- **mtime**：每周期自增

---

## 8. 设计亮点与创新点

1. **三路全转发**：EX/MEM/WB 均可转发，覆盖绝大多数数据冒险，仅 Load-Use 需 stall
2. **BHT 分支预测**：256 项两位饱和计数器，对循环类分支预测准确率高，减少控制冒险惩罚
3. **乘除法分离设计**：乘法单周期组合逻辑（DSP），除法 32 周期迭代，busy 时全流水线 stall
4. **写优先寄存器堆**：同周期写读同一寄存器时直接返回写入值，简化转发逻辑
5. **Harvard 架构**：指令/数据分离，消除取指-访存结构冒险
6. **M-mode 完整 CSR**：支持 ECALL/MRET、Timer 中断、性能计数器，便于软件调试与性能分析

---

## 9. 资源预估

| 资源 | 预估 | 上限 | 芯片总量 |
|------|------|------|---------|
| LUT | 3,000 – 4,500 | 5,000 | 53,200 |
| FF | 1,500 – 2,500 | — | 106,400 |
| BRAM (36Kb) | 8 – 16 | — | 140 |
| DSP48E1 | 4 – 8 | — | 220 |

- **乘法器**：映射到 DSP48E1，减少 LUT 占用
- **存储器**：IMEM/DMEM 推断为 BRAM
- **BHT**：256×2bit = 512 bit，可用分布式 RAM 或 FF
