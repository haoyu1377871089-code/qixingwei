# QXW RISC-V CPU 验证计划文档

## 1. 验证策略

### 1.1 验证层次

采用**自底向上**的验证策略，分为三个层次：

```
┌─────────────────────────────────────────────────────────────────┐
│  Level 3: FPGA 后仿真（Post-Implementation Timing Simulation）   │
│  - 加载 SDF 延时，验证实际时序下功能正确                          │
└─────────────────────────────────────────────────────────────────┘
                                    ▲
┌─────────────────────────────────────────────────────────────────┐
│  Level 2: 系统级验证（System-level）                             │
│  - riscv-tests 全部通过                                          │
│  - 自定义冒险场景、异常处理测试                                    │
└─────────────────────────────────────────────────────────────────┘
                                    ▲
┌─────────────────────────────────────────────────────────────────┐
│  Level 1: 模块级验证（Module-level）                              │
│  - 各子模块独立 Testbench 仿真                                    │
│  - 覆盖边界值、异常输入、状态转换                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 验证工具

| 阶段 | 工具 | 用途 |
|------|------|------|
| 模块级 | Icarus Verilog (iverilog) + GTKWave | 快速 RTL 仿真、波形分析 |
| 系统级 | iverilog / Vivado Simulator | SoC 全系统仿真 |
| FPGA | Vivado | 综合、实现、后仿真 |

### 1.3 验证流程

1. **模块级**：每个核心模块编写独立 TB，验证通过后再集成
2. **系统级**：CPU 顶层 + SoC 集成，运行 riscv-tests 及自定义程序
3. **FPGA**：综合 → 实现 → 导出网表 → 后仿真（功能 + 时序）

---

## 2. 模块级验证计划

### 2.1 tb_alu

**被测模块**：`qxw_alu`

| 测试项 | 覆盖场景 | 预期结果 |
|--------|----------|----------|
| ADD | 基本加法、溢出、有符号溢出 | 结果正确 |
| SUB | 基本减法、下溢 | 结果正确 |
| SLL | 左移 4 位、溢出清零 | 结果正确 |
| SLT | -1<0, 0>-1, 相等 | 0/1 正确 |
| SLTU | 0<max, max>0 | 0/1 正确 |
| XOR | 异或、相同异或 | 结果正确 |
| SRL | 逻辑右移、高位零扩展 | 结果正确 |
| SRA | 算术右移、符号扩展 | 结果正确 |
| OR / AND | 按位或/与 | 结果正确 |
| PASS_B | LUI 直通 | 输出 op_b |
| zero 标志 | SUB 相等时 | zero=1 |

### 2.2 tb_regfile

**被测模块**：`qxw_regfile`

| 测试项 | 覆盖场景 | 预期结果 |
|--------|----------|----------|
| 全寄存器读写 | 写入 x1~x31 唯一值，双端口读取验证 | 数据一致 |
| x0 恒零 | 尝试写 x0，读 x0 | 始终为 0 |
| 写优先 | 同周期写读同一寄存器 | 读得写入值 |
| 复位清除 | 写入后复位，再读 | 全为 0 |

### 2.3 tb_muldiv

**被测模块**：`qxw_muldiv`

| 测试项 | 覆盖场景 | 预期结果 |
|--------|----------|----------|
| MUL | 有符号乘法，正负组合 | 低 32 位正确 |
| MULH | 有符号×有符号 | 高 32 位正确 |
| MULHSU | 有符号×无符号 | 高 32 位正确 |
| MULHU | 无符号×无符号 | 高 32 位正确 |
| DIV | 有符号除法，整除/余数 | 商正确 |
| DIVU | 无符号除法 | 商正确 |
| REM / REMU | 取余 | 余数正确 |
| 除以零 | 除数为 0 | 商=-1(有符号)/max(无符号)，余数=被除数 |
| busy/valid 握手 | 除法启动后等待 busy 清零 | valid 在完成时拉高 |

### 2.4 tb_forwarding

**被测模块**：`qxw_forwarding`

| 测试项 | 覆盖场景 | 预期结果 |
|--------|----------|----------|
| 无转发 | rs1/rs2 与 EX/MEM/WB 目标均不匹配 | 使用原始 id_ex_rs1/rs2_data |
| EX/MEM 转发 | ex_mem_rd == id_ex_rs1 | fwd_rs1_data = ex_mem_alu_result |
| MEM/WB 转发 | mem_wb_rd == id_ex_rs2 | fwd_rs2_data = mem_wb_wd |
| 优先级 | EX 与 WB 同时匹配 | EX 优先 |
| x0 不转发 | ex_mem_rd = 0 | 不转发 |
| rs1/rs2 独立 | rs1 转发 EX，rs2 转发 WB | 各自正确 |

### 2.5 tb_branch_pred

**被测模块**：`qxw_branch_pred`

| 测试项 | 覆盖场景 | 预期结果 |
|--------|----------|----------|
| 初始状态 | 复位后 | WN(01)，pred_taken=0 |
| 训练 taken | 多次 update_taken=1 | WN→WT→ST |
| 训练 not-taken | 多次 update_taken=0 | WT→WN→SN |
| 饱和 | ST 时再 taken / SN 时再 not-taken | 状态不变 |
| 索引独立性 | 不同 update_idx | 互不影响 |

### 2.6 其他模块（建议补充）

| 模块 | 建议测试项 |
|------|------------|
| qxw_pc_reg | 复位、stall、branch_taken、flush、trap、mret 优先级 |
| qxw_csr | CSR 读写、ECALL/MRET、timer_irq、mcause/mepc 更新 |
| qxw_id_stage | 各指令类型解码、立即数生成、控制信号 |
| qxw_mem_stage | LB/LH/LW/LBU/LHU、SB/SH/SW 对齐与扩展 |

---

## 3. 系统级验证计划

### 3.1 riscv-tests 流程

1. **环境**：安装 `riscv32-unknown-elf-gcc` 交叉编译工具链
2. **编译**：使用 riscv-tests 仓库，编译 RV32I 与 RV32M 测试
3. **加载**：生成 `.hex` 文件，通过 `IMEM_INIT_FILE` 参数加载到 `qxw_imem`
4. **运行**：`tb_cpu_top` 仿真，监控 `tohost` 地址 (0x0001_3FF8)
5. **判定**：`tohost == 1` → PASS；`tohost != 0` 且 `!= 1` → FAIL (test_id = tohost>>1)

### 3.2 riscv-tests 测试集

| 类别 | 测试程序 | 覆盖内容 |
|------|----------|----------|
| RV32I | rv32ui-p-* | 算术、逻辑、分支、跳转、Load/Store |
| RV32M | rv32um-p-* | MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU |

### 3.3 自定义测试

| 测试 | 目的 |
|------|------|
| 数据转发 | 连续 ADD 依赖链，验证 EX/MEM/WB 转发 |
| Load-Use | Load 后立即使用，验证 1 周期 stall |
| 分支预测 | 循环内分支，验证 BHT 预测与错误冲刷 |
| JALR | 间接跳转，验证冲刷与目标计算 |
| ECALL/MRET | 异常进入与返回 |
| Timer 中断 | mtimecmp 设置，验证中断响应 |
| UART 输出 | 写 UART TX_DATA，验证字符输出 |
| CSR 读写 | mstatus、mie、mtvec、mcycle 等 |

### 3.4 tb_cpu_top 机制

- **tohost**：数据 RAM 地址 0x0001_3FF8，测试程序写 1 表示 PASS，其他非零表示 FAIL
- **超时**：MAX_CYCLES = 100,000，防止死循环
- **波形**：`$dumpvars` 输出 VCD，便于调试

---

## 4. FPGA 验证计划

### 4.1 综合约束

- **器件**：XC7Z020CLG400-2
- **时钟**：50 MHz（周期 20 ns），约束到 `clk` 端口
- **复位**：异步复位，约束为异步输入
- **引脚**：UART TX、LED 等按 AX7020 原理图约束

### 4.2 综合步骤

1. 创建 Vivado 工程，添加 `rtl/` 下所有 `.v`、`.vh`
2. 设置顶层为 `qxw_soc_top`
3. 添加约束文件 `ax7020.xdc`
4. Run Synthesis
5. 检查资源报告：LUT < 5,000，BRAM/DSP 合理

### 4.3 实现步骤

1. Run Implementation
2. 检查时序报告：Setup/Hold 满足 50 MHz
3. 若时序违例：优化关键路径或降频

### 4.4 后仿真步骤

#### 4.4.1 综合后功能仿真（Post-Synthesis Functional）

1. 导出综合后网表（EDIF/Verilog）
2. 创建仿真工程，添加网表 + 仿真库
3. 使用与 RTL 相同的 Testbench（tb_cpu_top）
4. 运行仿真，验证功能与 RTL 一致
5. **目的**：确认综合优化未改变逻辑

#### 4.4.2 布线后时序仿真（Post-Implementation Timing）

1. 导出布线后网表 + SDF 延时文件
2. 仿真时加载 SDF（`$sdf_annotate`）
3. 使用 50 MHz 时钟，验证建立/保持时间满足
4. **目的**：验证实际布线延时下功能正确

### 4.5 上板验证（可选）

1. 生成比特流，下载到 AX7020
2. 通过 UART 观察程序输出
3. LED 显示运行状态

---

## 5. 验证通过标准

### 5.1 模块级

- 所有已有 TB（tb_alu、tb_regfile、tb_muldiv、tb_forwarding、tb_branch_pred）无 FAIL
- 新增 TB（如 tb_csr、tb_mem_stage）按计划完成并通过

### 5.2 系统级

- **riscv-tests**：RV32I 与 RV32M 全部 PASS
- **自定义测试**：数据转发、Load-Use、分支、异常、外设等场景通过

### 5.3 FPGA

- **综合**：无错误，LUT < 5,000
- **时序**：50 MHz 收敛，无 Setup/Hold 违例
- **后仿真**：综合后功能仿真与 RTL 一致；布线后时序仿真通过

### 5.4 签收标准

| 检查项 | 标准 |
|--------|------|
| 模块仿真 | 全部 TB PASS |
| riscv-tests | 100% PASS |
| 综合资源 | LUT < 5,000 |
| 时序 | ≥ 50 MHz |
| 后仿真 | 功能正确 |
