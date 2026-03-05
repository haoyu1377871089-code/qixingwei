# QXW RISC-V CPU 调试进度报告

## 1. 当前工作概要

### 已完成

| 项目 | 状态 | 说明 |
|------|------|------|
| 模块级仿真 | ✅ 全部通过 | ALU(23)、寄存器堆(34)、乘除法(22)、转发(7)、分支预测(6)，共 92 项 |
| 系统级仿真（基础） | ✅ 全部通过 | test_alu(138cyc)、test_mem(100cyc)、test_branch(116cyc)、test_muldiv(312cyc) |
| VCD 波形文件 | ✅ 已生成 | 9 个 VCD 文件位于 `sim/` 目录 |
| 软件工具链 | ✅ 可用 | riscv64-unknown-elf-gcc 10.2.0，firmware 编译和 hex 转换正常 |
| CoreMark 编译 | ✅ 通过 | 代码仅 2.2KB text + 352B data，远小于 16KB ROM 限制 |
| Vivado | ✅ 已安装 | Vivado 2025.2，路径 /tools/Xilinx/2025.2/Vivado/bin/vivado |

### 已发现并修复的问题

#### Bug Fix 1：栈指针与 tohost 地址冲突

**文件**：`sw/start.S`

**现象**：CoreMark 等使用 C 函数的程序在仿真中 FAIL，tohost 被意外写入非 1 值。

**原因**：`start.S` 中栈指针初始化为 `0x14000`（RAM 顶部），而 `main` 函数的栈帧（208 字节）中 `sw s0, 200(sp)` 恰好写入 `0x13FF8`（tohost 地址），覆盖了测试结束标志。

**修复**：将栈指针初始值从 `0x14000` 改为 `0x13FF8`（tohost 之下），避免栈帧与 tohost 区域重叠。

```diff
- li sp, 0x00014000
+ li sp, 0x00013FF8
```

#### Bug Fix 2（进行中）：除法完成后结果被错误抑制

**文件**：`rtl/core/qxw_ex_stage.v`

**现象**：C 代码中使用 `divu`/`remu` 指令（如 `42 / 10`）返回 0 而非正确结果 4。printf 的 `%d` 格式化因依赖除法而死循环。CoreMark 仿真输出乱码后 FAIL。

**根本原因**：

`div_starting` 信号使用了 `md_start`（= `id_ex_is_muldiv & id_ex_valid & !md_busy`），而非仅在首次启动时有效的 `md_start_pulse`。

当 32 周期除法完成、`md_busy` 降低时：
- `md_start` 重新变为 1（因为 `!md_busy` 为真，且 divu 指令仍在 EX 阶段）
- `div_starting` 因此也为 1
- 导致 `ex_mem_reg_we` 和 `ex_mem_valid` 被清零
- **正确的除法结果被抑制，永远无法写回寄存器堆**

**关键代码**：

```verilog
// 原始代码（有 bug）
wire div_starting = md_start & (id_ex_md_op >= `MD_DIV) & (|fwd_rs2_data);

// md_start 在除法完成时仍为 1，因为：
//   md_start = id_ex_is_muldiv & id_ex_valid & !md_busy
//   除法完成后 md_busy=0 → md_start=1 → div_starting=1 → 结果被抑制
```

**当前状态**：

简单设置 `div_starting = 0` 会导致除法启动首周期的旧 `div_result_q` 值泄漏到流水线中，使 test_muldiv 的 TEST 5 失败（第一次除法时 `div_result_q` 为初始值 0）。

**正确修复方案**：

需要让 `div_starting` 仅在除法**首次启动**时为 1（使用 `md_start_pulse` 而非 `md_start`），在除法**完成**时为 0。具体方案：

```verilog
// 方案：将 md_start_pulse 传入 EX 阶段作为 div_starting 的触发信号
// 在 qxw_cpu_top.v 中：md_start_pulse 已有正确定义
// 在 qxw_ex_stage.v 中：新增输入端口或使用等效逻辑
wire div_starting = md_start_pulse_in & (id_ex_md_op >= `MD_DIV) & (|fwd_rs2_data);
```

或者在 EX 阶段内部维护一个等效的 `started` 标志位。

---

## 2. 待完成任务清单

### 高优先级

| # | 任务 | 说明 | 阻塞 |
|---|------|------|------|
| 1 | **修复除法结果抑制 bug** | 正确实现 `div_starting` 信号，使其仅在首次启动时有效 | 阻塞 CoreMark 和所有 C 程序中的除法运算 |
| 2 | **CoreMark 跑分** | 修复 bug 后编译运行 CoreMark，输出性能数据 | 被 #1 阻塞 |
| 3 | **FPGA 综合** | 运行 Vivado 综合+实现，生成资源利用率报告和时序报告 | 不阻塞，可并行 |
| 4 | **后仿真** | 综合后网表仿真 + 布线后时序仿真 | 被 #3 阻塞 |
| 5 | **比特流文件** | 生成 .bit 文件 | 被 #3 阻塞 |

### 中优先级

| # | 任务 | 说明 |
|---|------|------|
| 6 | riscv-tests 官方测试 | 运行官方指令集测试，确认全部通过 |
| 7 | 性能分析报告 | CPI、分支预测准确率、DMIPS/MHz 等量化数据 |
| 8 | 代码注释率 | 验证并补充到 ≥30% |
| 9 | 技术设计文档 | 生成完整 PDF 设计文档（封面、架构说明、建模规范等） |

---

## 3. 仿真结果汇总

### 模块级测试（全部通过）

| 测试模块 | 通过数 | 覆盖内容 |
|----------|--------|----------|
| tb_alu | 23 | ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND/PASS_B、零标志 |
| tb_regfile | 34 | 全寄存器读写、x0 硬连线、写优先、复位 |
| tb_muldiv | 22 | MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU、除零、busy/valid 握手 |
| tb_forwarding | 7 | 无转发、EX/MEM 转发、MEM/WB 转发、x0、优先级、rs1/rs2 独立 |
| tb_branch_pred | 6 | 初始状态、taken 训练、not-taken 训练、饱和、索引独立性 |

### 系统级测试

| 测试程序 | 结果 | 周期数 | 说明 |
|----------|------|--------|------|
| test_alu | ✅ PASSED | 138 | RV32I ALU 全部指令 |
| test_mem | ✅ PASSED | 100 | SW/LW/SH/LH/SB/LB 及符号扩展 |
| test_branch | ✅ PASSED | 116 | BEQ/BNE/BLT/BGE/BLTU/BGEU/JAL/JALR |
| test_muldiv | ✅ PASSED（原版）| 312 | MUL/DIV/REM 系列，含除零 |
| test_div_simple.c | ❌ FAILED | 167 | `42/10` 返回 0（div_starting bug） |
| test_printf.c | ❌ TIMEOUT | 2M | printf `%d` 死循环（同上） |
| CoreMark | ❌ FAILED | 71029 | UART 输出乱码，tohost 值错误 |

### VCD 波形文件

所有模块级和系统级测试均已生成 VCD 文件，位于 `sim/` 目录：

- `tb_alu.vcd`、`tb_regfile.vcd`、`tb_muldiv.vcd`
- `tb_forwarding.vcd`、`tb_branch_pred.vcd`
- `test_alu.vcd`、`test_mem.vcd`、`test_branch.vcd`、`test_muldiv.vcd`

---

## 4. 关键发现：除法流水线交互时序分析

### 问题的根本原因

五级流水线中，除法指令在 EX 阶段启动后占据 32 个周期。由于 `stall_ex = md_busy`，EX 阶段的流水线寄存器（ID/EX）被冻结，除法指令一直停留在 EX 阶段。

当除法完成时（`md_busy` 降低），流水线解除 stall。此时：

1. `md_start = id_ex_is_muldiv & id_ex_valid & !md_busy = 1`（因为 divu 指令仍在 EX）
2. `md_start_pulse = md_start & !md_started_r = 0`（md_started_r 保护防止重复启动）
3. 但 `div_starting` 使用的是 `md_start` 而非 `md_start_pulse`
4. 因此 `div_starting = 1`，抑制了 `ex_mem_reg_we` 和 `ex_mem_valid`
5. 正确的除法结果永远无法到达 WB 阶段写回寄存器

### 时序图

```
Cycle:    |  0  |  1  |  2  | ... | 32  | 33  |
          +-----+-----+-----+-----+-----+-----+
EX:       | div | div | div | ... | div | div → MEM
md_busy:  |  0  |  1  |  1  | ... |  1  |  0  |
md_start: |  1  |  0  |  0  | ... |  0  |  1  | ← 问题！
md_pulse: |  1  |  0  |  0  | ... |  0  |  0  | ← 正确
div_start:|  1  |  0  |  0  | ... |  0  |  1  | ← 错误抑制结果
stall_ex: |  0  |  1  |  1  | ... |  1  |  0  |
reg_we:   |  0  |  -  |  -  | ... |  -  |  0  | ← 应为 1
```

Cycle 0：div_starting=1 正确抑制旧值
Cycle 33：div_starting=1 **错误抑制正确结果**

---

*报告生成日期：2026-03-05*
