# QXW RISC-V CPU 仿真验证报告

## 1. 验证环境

| 项目 | 说明 |
|------|------|
| 仿真工具 | Icarus Verilog 12.0 |
| 交叉编译工具链 | riscv64-unknown-elf-gcc 13.2.0 |
| 目标架构 | RV32IM (RISC-V 32 位整数 + 乘除法扩展) |

---

## 2. 模块级验证结果

| 测试模块 | 通过 | 失败 | 覆盖内容 |
|----------|------|------|----------|
| tb_alu | 23 | 0 | ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND/PASS_B、零标志 |
| tb_regfile | 34 | 0 | 全寄存器读写、x0 硬连线、写前读、复位 |
| tb_muldiv | 22 | 0 | MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU、除零、busy/valid 握手 |
| tb_forwarding | 7 | 0 | 无转发、EX/MEM 转发、MEM/WB 转发、x0、优先级、rs1/rs2 独立性 |
| tb_branch_pred | 6 | 0 | 初始状态、taken 训练、not-taken 训练、饱和、索引独立性 |

---

## 3. 系统级验证结果

| 测试程序 | 结果 | 周期数 | 验证内容 |
|----------|------|--------|----------|
| test_alu | PASSED | 137 | RV32I ALU：ADDI/ADD/SUB/AND/OR/XOR/SLL/SRL/SRA/SLT/SLTU/LUI/AUIPC |
| test_mem | PASSED | 99 | 加载/存储：SW/LW、SH/LH/LHU、SB/LB/LBU、符号/零扩展 |
| test_branch | PASSED | 115 | 分支/跳转：BEQ/BNE/BLT/BGE/BLTU/BGEU/JAL/JALR、循环、前向分支 |
| test_muldiv | PASSED | 311 | M 扩展：MUL/MULH/MULHU/DIV/DIVU/REM/REMU、除零 |

---

## 4. 关键波形描述

### 4.1 五级流水线正常执行时序

指令按 IF→ID→EX→MEM→WB 顺序依次流过五级流水线。每条指令从取指到写回共需 5 个时钟周期。在无冒险的理想情况下，每个周期可完成一条指令的写回，实现单周期吞吐量（CPI=1）。波形上可见同一时刻五级流水线中各有不同指令处于不同阶段。

### 4.2 数据转发时序

当 EX 或 MEM 阶段产生的结果被后续 ID 阶段指令的源操作数依赖时，通过 EX/MEM 或 MEM/WB 转发路径将结果直接送入 ALU 输入，无需等待写回。波形显示 RAW 相关在转发生效时无额外停顿，实现 0 周期惩罚。转发优先级为 EX/MEM > MEM/WB。

### 4.3 Load-Use Stall 时序

当 ID 阶段指令的 rs1/rs2 依赖前一条处于 MEM 阶段的 Load 指令时，Load 结果尚未就绪，需插入 1 个气泡（bubble）停顿流水线。波形上可见 stall 信号拉高一个周期，IF/ID 和 ID/EX 流水线寄存器保持，EX 阶段插入 NOP，待 Load 完成写回后恢复执行。

### 4.4 分支预测正确/错误时序

采用 2 位饱和计数器进行分支预测。预测正确时，分支目标在 IF 阶段即被采用，无额外周期损失（0 周期惩罚）。预测错误时，需冲刷错误取指的指令并重新取正确目标，产生 2 周期惩罚。波形上可见 flush 信号在预测错误时拉高，流水线插入气泡并重取正确地址。

### 4.5 除法单元执行时序

除法采用 32 周期恢复除法（restoring division）实现。当 EX 阶段发起除法运算时，`md_busy` 拉高，流水线在该周期及后续 31 周期内保持 stall 状态。第 32 周期 `md_valid` 拉高，结果就绪。波形上可见 32 个连续周期内 `md_busy` 持续为高，直至 `md_valid` 与 `md_busy` 同时有效一个周期。

---

## 5. 发现并修复的问题

### Bug 1：bpu_pred_target 未驱动 (qxw_cpu_top.v)

**现象**：IF 阶段分支预测目标信号 `bpu_pred_target` 在综合/仿真中为未驱动（undriven）状态。

**原因**：`bpu_pred_target` 被错误声明为 `input` 而非 `output`，导致与分支预测单元的输出连接方向相反。

**修复**：将 `bpu_pred_target` 的端口方向改为 `output`，使其正确接收分支预测单元输出的预测目标地址。

---

### Bug 2：除法单元结果锁存失败 (qxw_muldiv.v)

**现象**：除法运算完成后 `div_result_q`/`div_result_r` 未被正确更新，除法结果错误。

**原因**：
1. 第二个 `always` 块中更新 `div_result_q`/`div_result_r` 的条件判断有误，导致正常除法完成后未进入更新分支；
2. 试商减法公式错误：使用了 `{div_sr[62:31], 1'b0}` 而非正确的 `{1'b0, div_sr[62:31]}`，导致移位与试商逻辑不一致。

**修复**：修正 `div_result_q`/`div_result_r` 的更新条件，并修正试商减法中的移位表达式为 `{1'b0, div_sr[62:31]}`。

---

### Bug 3：除法启动周期流水线冒险 (qxw_ex_stage.v)

**现象**：除法启动的第一个周期，陈旧的 `md_result` 被锁存到 EX/MEM 阶段，导致错误结果写入寄存器。

**原因**：除法启动时 `md_busy` 尚未拉高，EX 阶段在首周期仍将 `md_result` 作为有效结果传递；而 `md_result` 此时为上一轮运算的残留值或未定义值。

**修复**：对非除零的除法启动插入气泡（bubble），并增加 `md_started_r` 标志位，防止同一除法运算被重复触发，确保 EX/MEM 仅在 `md_valid` 有效时锁存除法结果。

---

## 6. 性能指标

| 指标 | 数值 |
|------|------|
| 模块级测试总数 | 92 (23+34+22+7+6) |
| 模块级通过率 | 100% |
| 系统级测试程序数 | 4 |
| 系统级通过率 | 100% |
| test_alu 周期数 | 137 |
| test_mem 周期数 | 99 |
| test_branch 周期数 | 115 |
| test_muldiv 周期数 | 311 |
| 总验证周期数 | 662 |

---

*报告生成日期：2025年3月5日*
