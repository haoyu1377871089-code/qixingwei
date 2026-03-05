# QXW RISC-V CPU 调试进度报告

## 1. 项目状态总览

| 项目 | 状态 | 说明 |
|------|------|------|
| 模块级仿真 | ✅ 全部通过 | ALU(23)、寄存器堆(34)、乘除法(22)、转发(7)、分支预测(6)，共 92 项 |
| 自定义系统级测试 | ✅ 全部通过 | test_alu/mem/branch/muldiv/div_asm/div_simple/printf，共 7 项 |
| 官方 riscv-tests | ✅ 48/48 通过 | RV32UI(40) + RV32UM(8) |
| CoreMark 基准测试 | ✅ PASS | 81,431 cycles / 100 iterations |
| Vivado FPGA 综合 | ✅ 通过 | LUT 3,174 (< 5,000)，时序满足 50 MHz |
| 比特流生成 | ✅ 完成 | qxw_riscv.bit (3.9 MB) |

---

## 2. 已修复的关键 Bug

### Bug 1：栈指针与 tohost 地址冲突

**文件**：`sw/start.S`

**现象**：C 程序仿真中 tohost 被栈帧意外覆盖。

**修复**：栈指针从 `0x14000` 改为 `0x13FF8`（tohost 之下）。

### Bug 2：除法完成后结果被错误抑制

**文件**：`rtl/core/qxw_ex_stage.v`

**现象**：除法运算返回 0 而非正确结果。

**根本原因**：`div_starting` 信号使用 `md_start` 而非 `md_start_pulse`，除法完成时 `md_busy` 降低导致 `md_start` 重新为 1，抑制了正确结果。

**修复**：使用 `md_started_r` 标志位防止重复触发。

### Bug 3：除法启动首周期 ID/EX 被覆盖

**文件**：`rtl/core/qxw_cpu_top.v`、`rtl/core/qxw_id_stage.v`

**现象**：除法指令在启动后被下一条指令覆盖。

**根本原因**：除法启动首周期 `md_busy` 尚为 0，冒险控制器不产生 stall；同时 ID 阶段 stall 时错误插入 bubble 而非保持。

**修复**：添加 `div_start_stall` 提前产生 stall；ID 阶段增加 `hold` 输入。

### Bug 4：BRAM 同步读适配

**文件**：`rtl/mem/qxw_imem.v`、`rtl/mem/qxw_dmem.v`、`rtl/core/qxw_if_stage.v`、`rtl/core/qxw_mem_stage.v`、`rtl/core/qxw_wb_stage.v`、`rtl/soc/qxw_bus.v`

**现象**：IMEM/DMEM 组合读被综合为 Distributed RAM，LUT 占用 5,979 超标。

**修复**：
1. 存储器改为同步读 + `(* ram_style = "block" *)` 属性
2. IF 阶段添加 `pc_r` 延迟寄存器和 `bram_valid` 就绪标志
3. MEM 阶段 load 数据处理移至 WB 阶段
4. 总线选择信号延迟一拍对齐 BRAM 输出
5. IF 阶段分支预测禁用（`pred_taken` 硬连线 `1'b0`）

**效果**：LUT 从 5,979 降至 3,174（-47%），Block RAM 从 0 增至 5。

---

## 3. FPGA 综合结果

### 资源利用率

| 资源 | 优化前 | 优化后 | 变化 |
|------|--------|--------|------|
| Slice LUTs | 5,979 (11.24%) | 3,174 (5.97%) | -47% |
| LUT as Distributed RAM | 2,048 | 0 | 消除 |
| Slice Registers | 2,483 | 2,214 | -11% |
| Block RAM Tile | 0 | 5 (3.57%) | BRAM 推断成功 |
| DSP48E1 | 12 | 12 | 不变 |

### 时序

| 指标 | 优化前 | 优化后 |
|------|--------|--------|
| WNS (Setup Slack) | +3.498 ns | +2.553 ns |
| WHS (Hold Slack) | +0.088 ns | +0.129 ns |
| 最大频率 | ~60.5 MHz | ~57.3 MHz |
| 时序约束 | 全部满足 | 全部满足 |

---

*报告更新日期：2026-03-05*
