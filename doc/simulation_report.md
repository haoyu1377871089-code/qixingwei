# QXW RISC-V CPU 仿真验证报告

## 1. 验证环境

| 项目 | 说明 |
|------|------|
| 仿真工具 | Icarus Verilog 12.0 |
| 交叉编译工具链 | riscv64-unknown-elf-gcc 10.2.0 |
| 目标架构 | RV32IM (RISC-V 32 位整数 + 乘除法扩展) |
| 时钟频率 | 50 MHz（仿真时钟周期 20 ns） |

---

## 2. 模块级验证结果

| 测试模块 | 通过 | 失败 | 覆盖内容 |
|----------|------|------|----------|
| tb_alu | 23 | 0 | ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND/PASS_B、零标志 |
| tb_regfile | 34 | 0 | 全寄存器读写、x0 硬连线、写前读、复位 |
| tb_muldiv | 22 | 0 | MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU、除零、busy/valid 握手 |
| tb_forwarding | 7 | 0 | 无转发、EX/MEM 转发、MEM/WB 转发、x0、优先级、rs1/rs2 独立性 |
| tb_branch_pred | 6 | 0 | 初始状态、taken 训练、not-taken 训练、饱和、索引独立性 |

**模块级合计：92 项全部通过**

---

## 3. 系统级验证结果

### 3.1 自定义测试

| 测试程序 | 结果 | 周期数 | 验证内容 |
|----------|------|--------|----------|
| test_alu | PASSED | 138 | RV32I ALU：ADDI/ADD/SUB/AND/OR/XOR/SLL/SRL/SRA/SLT/SLTU/LUI/AUIPC |
| test_mem | PASSED | 100 | 加载/存储：SW/LW、SH/LH/LHU、SB/LB/LBU、符号/零扩展 |
| test_branch | PASSED | 116 | 分支/跳转：BEQ/BNE/BLT/BGE/BLTU/BGEU/JAL/JALR、循环、前向分支 |
| test_muldiv | PASSED | 318 | M 扩展：MUL/MULH/MULHU/DIV/DIVU/REM/REMU、除零 |
| test_div_asm | PASSED | 129 | divu/remu 42÷10 汇编级验证 |
| test_div_simple.c | PASSED | 424 | C 语言 42/10 除法验证 |
| test_printf.c | PASSED | — | printf 格式化输出验证 |

### 3.2 官方 riscv-tests（48/48 全部通过）

#### RV32UI（40 项整数指令测试）

| 测试 | 周期数 | 测试 | 周期数 | 测试 | 周期数 | 测试 | 周期数 |
|------|--------|------|--------|------|--------|------|--------|
| simple | 120 | add | 592 | addi | 342 | and | 612 |
| andi | 298 | auipc | 146 | beq | 451 | bge | 496 |
| bgeu | 521 | blt | 451 | bltu | 476 | bne | 457 |
| jal | 143 | jalr | 233 | lb | 396 | lbu | 396 |
| lh | 412 | lhu | 421 | lui | 147 | lw | 426 |
| or | 615 | ori | 305 | sb | 636 | sh | 729 |
| sll | 620 | slli | 341 | slt | 586 | slti | 337 |
| sltiu | 337 | sltu | 586 | sra | 639 | srai | 356 |
| srl | 633 | srli | 350 | sub | 584 | sw | 776 |
| xor | 614 | xori | 307 | ld_st | 1395 | st_ld | 766 |

#### RV32UM（8 项乘除法测试）

| 测试 | 周期数 | 测试 | 周期数 | 测试 | 周期数 | 测试 | 周期数 |
|------|--------|------|--------|------|--------|------|--------|
| mul | 586 | mulh | 586 | mulhsu | 586 | mulhu | 586 |
| div | 376 | divu | 377 | rem | 376 | remu | 376 |

### 3.3 CoreMark 基准测试

| 项目 | 结果 | 验证 |
|------|------|------|
| 4x4 矩阵乘法 | C[0][0]=1 | 正确（A×I=A） |
| 链表遍历求和 | 136 | 正确（1+2+...+16=136） |
| 状态机计数 | 1000 | 正确（100×10） |
| 总耗时 | 81,431 cycles | 100 次迭代 |
| 仿真总周期 | 84,592 cycles | PASSED |

---

## 4. 关键波形描述

### 4.1 五级流水线正常执行时序

指令按 IF→ID→EX→MEM→WB 顺序依次流过五级流水线。每条指令从取指到写回共需 5 个时钟周期。在无冒险的理想情况下，每个周期可完成一条指令的写回，实现单周期吞吐量（CPI=1）。

### 4.2 数据转发时序

当 EX 或 MEM 阶段产生的结果被后续 ID 阶段指令的源操作数依赖时，通过 EX/MEM 或 MEM/WB 转发路径将结果直接送入 ALU 输入，无需等待写回。RAW 相关在转发生效时无额外停顿，实现 0 周期惩罚。转发优先级为 EX/MEM > MEM/WB。

### 4.3 Load-Use Stall 时序

当 ID 阶段指令的 rs1/rs2 依赖前一条处于 MEM 阶段的 Load 指令时，Load 结果尚未就绪，需插入 1 个气泡（bubble）停顿流水线。stall 信号拉高一个周期，IF/ID 和 ID/EX 流水线寄存器保持，EX 阶段插入 NOP，待 Load 完成写回后恢复执行。

### 4.4 分支预测正确/错误时序

采用 2 位饱和计数器进行分支预测。预测正确时，分支目标在 IF 阶段即被采用，无额外周期损失（0 周期惩罚）。预测错误时，需冲刷错误取指的指令并重新取正确目标，产生 2 周期惩罚。

### 4.5 除法单元执行时序

除法采用 32 周期恢复除法（restoring division）实现。当 EX 阶段发起除法运算时，`md_busy` 拉高，流水线在该周期及后续 31 周期内保持 stall 状态。第 32 周期 `md_valid` 拉高，结果就绪。

---

## 5. 发现并修复的问题

### Bug 1：bpu_pred_target 未驱动 (qxw_cpu_top.v)

**现象**：IF 阶段分支预测目标信号 `bpu_pred_target` 为未驱动状态。

**原因**：`bpu_pred_target` 被错误声明为 `input` 而非 `output`。

**修复**：将端口方向改为 `output`。

### Bug 2：除法单元结果锁存失败 (qxw_muldiv.v)

**现象**：除法运算完成后 `div_result_q`/`div_result_r` 未被正确更新。

**原因**：更新条件判断有误；试商减法公式错误。

**修复**：修正更新条件和试商减法移位表达式。

### Bug 3：除法启动周期流水线冒险 (qxw_ex_stage.v + qxw_cpu_top.v)

**现象**：除法完成后结果被错误抑制，无法写回寄存器。

**原因**：`div_starting` 信号使用 `md_start` 而非 `md_start_pulse`，导致除法完成时仍抑制结果。同时 ID 阶段 stall 时错误插入 bubble 而非保持。

**修复**：添加 `div_start_stall` 信号提前产生 stall；ID 阶段增加 `hold` 输入保持 ID/EX 寄存器。

### Bug 4：BRAM 同步读适配 (多文件)

**现象**：IMEM/DMEM 使用组合读导致被综合为 Distributed RAM，LUT 占用 5,979 超标。

**修复**：改为同步读 + `(* ram_style = "block" *)` 属性，适配 IF/MEM/WB 阶段和总线的 1 周期延迟。LUT 降至 3,174。

---

## 6. 验证通过率总结

| 验证层级 | 通过数 | 总数 | 通过率 |
|----------|--------|------|--------|
| 模块级 Testbench | 92 | 92 | 100% |
| 自定义汇编/C 测试 | 7 | 7 | 100% |
| 官方 riscv-tests (RV32UI) | 40 | 40 | 100% |
| 官方 riscv-tests (RV32UM) | 8 | 8 | 100% |
| CoreMark 基准测试 | 1 | 1 | 100% |
| **合计** | **148** | **148** | **100%** |

---

*报告更新日期：2026-03-05*
