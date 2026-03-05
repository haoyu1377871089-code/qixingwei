# QXW RISC-V CPU Vivado FPGA 综合与验证操作指南

本文档描述如何使用 Xilinx Vivado 对 QXW RISC-V CPU 进行 FPGA 综合、实现、仿真及下板验证。目标开发板为 **ALINX AX7020**（Xilinx Zynq-7020，器件型号 XC7Z020CLG400-2）。

**设计约束：**
- 目标频率：≥ 50 MHz
- 资源约束：< 5000 LUTs

---

## 1. 环境准备

### 1.1 Vivado 版本要求

- **推荐版本**：Vivado 2020.2 或更高
- 支持器件：需包含 Artix-7 / Zynq-7000 系列
- 安装时选择 **Vivado HL Design Edition** 或 **Vivado HL WebPACK**（免费版即可）

### 1.2 确认目标器件

- **Part Number**：`xc7z020clg400-2`
- **封装**：CLG400
- **速度等级**：-2

在 Vivado 中可通过以下命令验证器件是否可用：

```tcl
get_parts xc7z020clg400-2
```

### 1.3 安装 RISC-V 交叉编译工具链

用于编译固件并生成 `firmware.hex` 供指令存储器初始化使用。

**安装方式一：预编译工具链**

```bash
# 下载 riscv64-unknown-elf-gcc（以 SiFive 为例）
wget https://static.dev.sifive.com/dev-tools/freedom-tools/v2020.12.0/riscv64-unknown-elf-gcc-10.1.0-2020.12.0-x86_64-linux-ubuntu14.tar.gz
tar -xzf riscv64-unknown-elf-gcc-*.tar.gz
export PATH=$PATH:$(pwd)/riscv64-unknown-elf-gcc-10.1.0-2020.12.0-x86_64-linux-ubuntu14/bin
```

**安装方式二：从源码编译**

```bash
git clone https://github.com/riscv/riscv-gnu-toolchain
cd riscv-gnu-toolchain
./configure --prefix=/opt/riscv --with-arch=rv32im --with-abi=ilp32
make
export PATH=$PATH:/opt/riscv/bin
```

**验证安装：**

```bash
riscv64-unknown-elf-gcc --version
```

**编译固件：**

```bash
cd sw
make firmware
# 生成的 firmware.hex 会复制到 sim/firmware.hex
# 综合前需将其复制到 fpga 工程可访问的路径（如 fpga/output/ 或工程根目录）
```

---

## 2. 创建 Vivado 工程

### 2.1 新建工程

1. 启动 Vivado，选择 **Create Project**
2. 工程类型：**RTL Project**，勾选 **Do not specify sources at this time**
3. 器件选择：
   - **Family**：Zynq-7000
   - **Package**：clg400
   - **Part**：xc7z020clg400-2

### 2.2 添加 RTL 源文件

在 **Add Sources** 中添加以下文件（按顺序或分组添加）：

**rtl/core/（核心模块）：**

| 文件名 | 说明 |
|--------|------|
| qxw_defines.vh | 头文件/宏定义 |
| qxw_alu.v | ALU |
| qxw_regfile.v | 寄存器堆 |
| qxw_pc_reg.v | PC 寄存器 |
| qxw_if_stage.v | 取指阶段 |
| qxw_id_stage.v | 译码阶段 |
| qxw_ex_stage.v | 执行阶段 |
| qxw_mem_stage.v | 访存阶段 |
| qxw_wb_stage.v | 写回阶段 |
| qxw_forwarding.v | 数据前递 |
| qxw_hazard_ctrl.v | 冒险控制 |
| qxw_branch_pred.v | 分支预测 |
| qxw_csr.v | CSR 寄存器 |
| qxw_muldiv.v | 乘除法单元 |
| qxw_cpu_top.v | CPU 顶层 |

**rtl/soc/（SoC 模块）：**

| 文件名 | 说明 |
|--------|------|
| qxw_bus.v | 总线 |
| qxw_uart.v | UART |
| qxw_timer.v | 定时器 |
| qxw_soc_top.v | SoC 顶层 |

**rtl/mem/（存储器）：**

| 文件名 | 说明 |
|--------|------|
| qxw_imem.v | 指令存储器 |
| qxw_dmem.v | 数据存储器 |

**添加方式：**

- 将 `rtl/core/` 设为 **Include Directories**（用于 `qxw_defines.vh`）
- 所有 `.v` 和 `.vh` 文件设为 **Design Sources**

### 2.3 设置顶层模块

1. 在 **Sources** 窗口中右键 `qxw_soc_top.v`
2. 选择 **Set as Top**
3. 或在 **Flow Navigator → Synthesis → Synthesis Settings** 中设置 **Top** 为 `qxw_soc_top`

### 2.4 添加约束文件

1. **Add Sources** → **Add or create constraints**
2. 添加 `fpga/constraints/ax7020.xdc`
3. 该约束包含：50 MHz 时钟、复位、UART TX、LED、I/O 标准等

### 2.5 设置 IMEM_INIT_FILE 参数

指令存储器通过 `$readmemh` 加载 hex 文件，需在顶层设置参数：

**方式一：在 qxw_soc_top 实例化时（若通过包装模块）**

在工程中若有包装层，可传递参数。否则需修改源文件或通过综合属性设置。

**方式二：在源文件中设置默认值**

确保 `qxw_soc_top` 的 `IMEM_INIT_FILE` 参数指向正确的 hex 路径。默认值为 `"firmware.hex"`，综合时 Vivado 会从工程目录或指定路径查找。

**方式三：Tcl 设置（非工程模式）**

```tcl
# 在 synth_design 之前设置顶层参数
set_property generic {IMEM_INIT_FILE=firmware.hex} [current_fileset]
# 或使用绝对路径
set_property generic {IMEM_INIT_FILE=/path/to/firmware.hex} [current_fileset]
```

**注意**：`firmware.hex` 需为 32 位字格式（每行 8 个十六进制字符），可使用 `sw/byte2word.py` 将 objcopy 输出的字节序 hex 转换为字格式。

---

## 3. 综合（Synthesis）

### 3.1 运行综合

1. 在 **Flow Navigator** 中点击 **Run Synthesis**
2. 等待综合完成

### 3.2 查看资源利用率报告

综合完成后，打开 **Report Utilization**：

- **LUT**：应 < 5000（设计约束）
- **FF**：触发器数量
- **BRAM**：块 RAM（IMEM、DMEM 应推断为 BRAM）
- **DSP**：DSP48（乘法器应推断为 DSP）

**关键指标示例：**

| 资源类型 | 预期范围 | 说明 |
|----------|----------|------|
| LUT | < 5000 | 逻辑单元 |
| FF | 约 2000~4000 | 触发器 |
| BRAM_18K | 2~4 | IMEM + DMEM |
| DSP48E1 | 1~2 | 乘法器 |

### 3.3 检查警告

重点关注：

- **Latch 推断**：可能导致非预期行为，应修复 RTL 使所有分支有明确赋值
- **未连接端口**：检查是否有悬空端口
- **多驱动**：同一信号被多个 always 驱动
- **时序约束**：未约束的时钟域

### 3.4 常见问题与解决方案

**BRAM 未推断**

- 检查 `qxw_imem`、`qxw_dmem` 的读写模式：同步写、同步读或地址寄存模式
- 确保存储器描述符合 Vivado 推断规则（见 UG901）
- 可添加 `(* ram_style = "block" *)` 属性强制推断

**DSP 未用于乘法器**

- `qxw_muldiv` 中乘法为组合逻辑，应自动推断为 DSP48
- 若被综合为 LUT，可添加 `(* use_dsp = "yes" *)` 或检查乘法位宽是否超出 32×32

**资源超预算（>5000 LUT）**

- 关闭部分功能（如分支预测、CoreMark 等）
- 优化关键路径，减少冗余逻辑
- 使用 `-retiming` 或 `-directive Default` 等综合策略

---

## 4. 实现（Implementation）

### 4.1 运行实现

1. 综合完成后，在 **Flow Navigator** 中点击 **Run Implementation**
2. 包含 **Place Design** 和 **Route Design**

### 4.2 查看时序报告

实现完成后，打开 **Report Timing Summary**：

- **Setup Slack**：应 ≥ 0（满足 50 MHz，周期 20 ns）
- **Hold Slack**：应 ≥ 0
- **WNS（Worst Negative Slack）**：若为负则时序违例

**50 MHz 约束**：`create_clock -period 20.000`（20 ns 周期）

### 4.3 时序违例时的建议

1. **寄存器重定时（Retiming）**：在综合设置中启用
2. **降低时钟频率**：若设计无法满足 50 MHz，可尝试 40 MHz 或 25 MHz
3. **流水线关键路径**：在 ALU、乘除法等关键路径插入流水级
4. **物理优化**：使用 `place_design -directive ExtraNetDelay_high` 等策略
5. **检查组合逻辑深度**：减少单周期内组合逻辑级数

---

## 5. 后仿真（Post-Synthesis / Post-Implementation Simulation）

### 5.1 综合后功能仿真（Post-Synthesis Functional）

用于验证综合网表与 RTL 行为一致。

**步骤：**

1. **Open Synthesized Design**
   - Flow Navigator → **Open Synthesized Design**

2. **导出综合后网表**
   - **File → Export → Export Simulation**
   - 选择 **Post-Synthesis**，格式 **Verilog**
   - 或使用 Tcl：
   ```tcl
   write_verilog -mode funcsim -force post_synth_netlist.v
   ```

3. **创建仿真工程**
   - 新建仿真工程或使用现有 `tb_cpu_top.v`
   - 添加：`post_synth_netlist.v`、`tb/tb_cpu_top.v`
   - 设置 include 路径：`rtl/core/`
   - 确保 `firmware.hex` 在仿真工作目录

4. **运行仿真**
   - 使用与 RTL 仿真相同的 testbench
   - 验证 tohost、UART 等行为与 RTL 一致

**注意事项：**

- 综合后网表为门级，无时序信息，仅做功能验证
- 若存在仿真不匹配，重点检查：未初始化寄存器、latch、多驱动

### 5.2 布线后时序仿真（Post-Implementation Timing）

用于验证设计在目标频率下时序正确。

**步骤：**

1. **Open Implemented Design**
   - Flow Navigator → **Open Implemented Design**

2. **导出布线后网表与 SDF**
   ```tcl
   write_verilog -mode timesim -sdf_anno true -force post_impl_netlist.v
   write_sdf post_impl.sdf
   ```

3. **仿真脚本示例（Verilog）**
   ```verilog
   `timescale 1ns/1ps
   module tb_timing;
       // ... 时钟、复位等 ...
       initial begin
           $sdf_annotate("post_impl.sdf", u_soc, "", "", "");
       end
       // 实例化 post_impl_netlist 中的 qxw_soc_top
   endmodule
   ```

4. **运行时序仿真**
   - 时钟周期设为 20 ns（50 MHz）
   - 对比 RTL 仿真结果，验证功能正确
   - 若因时序违例导致错误，需返回实现阶段优化

---

## 6. 生成比特流与下板验证

### 6.1 生成比特流

1. 在 **Flow Navigator** 中点击 **Generate Bitstream**
2. 等待生成完成，得到 `*.bit` 文件

### 6.2 连接开发板

1. 用 USB 线连接 AX7020 的 JTAG 口到 PC
2. 上电，打开 **Hardware Manager**
3. **Open target** → **Auto Connect**，识别到 xc7z020 器件

### 6.3 下载比特流

1. **Program device** → 选择生成的 `.bit` 文件
2. 点击 **Program**
3. 下载完成后 FPGA 将运行固件

### 6.4 验证方式

**UART 输出**

- 波特率：115200，8N1
- 使用串口终端（如 minicom、PuTTY）连接 PL UART
- 引脚：`uart_tx` → K14（见 ax7020.xdc）

```bash
minicom -D /dev/ttyUSB1 -b 115200
```

**LED 指示**

- LED[3:0] 映射到数据 RAM 地址 `0x0001_3FFC`
- 程序可写该地址控制 LED 状态

**ILA 调试（可选）**

- 在设计中插入 ILA IP，抓取 PC、指令、数据等信号
- 通过 Vivado Hardware Manager 观察波形

---

## 7. Tcl 批处理脚本

项目提供 `fpga/scripts/build.tcl` 用于非工程模式一键构建。

### 7.1 使用方法

```bash
cd fpga/scripts
vivado -mode batch -source build.tcl
```

### 7.2 脚本关键命令

```tcl
# 读入 RTL
read_verilog -sv [glob ${CORE_DIR}/*.v]
read_verilog -sv [glob ${SOC_DIR}/*.v]
read_verilog -sv [glob ${MEM_DIR}/*.v]
set_property include_dirs [list ${CORE_DIR}] [current_fileset]

# 读入约束
read_xdc ${XDC_FILE}

# 综合
synth_design -top ${TOP} -part ${PART} -flatten_hierarchy rebuilt -directive Default

# 综合后报告与网表
report_timing_summary -file ${OUTPUT_DIR}/post_synth_timing.rpt
report_utilization     -file ${OUTPUT_DIR}/post_synth_util.rpt
write_verilog -force -mode funcsim ${OUTPUT_DIR}/post_synth_netlist.v

# 布局布线
opt_design
place_design -directive Default
route_design -directive Default

# 实现后报告与网表
report_timing_summary -file ${OUTPUT_DIR}/post_impl_timing.rpt
report_utilization     -file ${OUTPUT_DIR}/post_impl_util.rpt
write_verilog -force -mode timesim ${OUTPUT_DIR}/post_impl_netlist.v
write_sdf      -force ${OUTPUT_DIR}/post_impl.sdf

# 生成比特流
write_bitstream -force ${OUTPUT_DIR}/${PROJ_NAME}.bit
```

### 7.3 设置 IMEM_INIT_FILE（Tcl 模式）

在 `synth_design` 之前添加：

```tcl
# 设置固件路径（相对于脚本运行目录或使用绝对路径）
set_property generic {IMEM_INIT_FILE=../../sim/firmware.hex} [current_fileset]
```

---

## 8. 常见问题与解决方案

### 8.1 50 MHz 时序违例

| 现象 | 可能原因 | 解决方案 |
|------|----------|----------|
| WNS 为负 | 关键路径过长 | 插入流水线、寄存器重定时 |
| 组合逻辑过深 | ALU 或乘法路径 | 检查 qxw_alu、qxw_muldiv 结构 |
| 布局布线拥塞 | 资源利用率高 | 优化面积、使用不同 directive |

### 8.2 资源超预算（>5000 LUT）

| 现象 | 可能原因 | 解决方案 |
|------|----------|----------|
| LUT 过多 | 分支预测、前递等逻辑 | 简化或移除非必要功能 |
| 乘法用 LUT | 未推断 DSP | 检查乘法描述、添加 use_dsp |
| 存储器用 LUT | 未推断 BRAM | 检查 ram 描述、添加 ram_style |

### 8.3 BRAM 未推断

- 确保存储器为同步写、同步读或地址寄存读
- 检查 `qxw_imem`、`qxw_dmem` 的 always 块结构
- 参考 UG901 的 RAM 推断指南
- 可添加 `(* ram_style = "block" *)` 强制推断

### 8.4 DSP 未用于乘法器

- 32×32 乘法应自动映射到 DSP48E1
- 若被综合为 LUT，检查是否被优化掉或位宽异常
- 可添加 `(* use_dsp = "yes" *)` 属性

### 8.5 RTL 与综合后仿真不一致

| 现象 | 可能原因 | 解决方案 |
|------|----------|----------|
| 结果不同 | 未初始化寄存器 | 所有 reg 赋初值或复位 |
| 行为异常 | Latch 推断 | 补全 if-else 分支 |
| 多驱动 | 同一信号多处赋值 | 合并驱动源 |
| 仿真顺序 | 阻塞/非阻塞混用 | 统一使用非阻塞赋值 |

---

## 附录：文件清单速查

**RTL 源文件（按目录）：**

```
rtl/core/
  qxw_defines.vh, qxw_alu.v, qxw_regfile.v, qxw_pc_reg.v,
  qxw_if_stage.v, qxw_id_stage.v, qxw_ex_stage.v, qxw_mem_stage.v,
  qxw_wb_stage.v, qxw_forwarding.v, qxw_hazard_ctrl.v, qxw_branch_pred.v,
  qxw_csr.v, qxw_muldiv.v, qxw_cpu_top.v

rtl/soc/
  qxw_bus.v, qxw_uart.v, qxw_timer.v, qxw_soc_top.v

rtl/mem/
  qxw_imem.v, qxw_dmem.v
```

**约束文件：** `fpga/constraints/ax7020.xdc`  
**构建脚本：** `fpga/scripts/build.tcl`  
**顶层模块：** `qxw_soc_top`  
**参数：** `IMEM_INIT_FILE`（默认 `firmware.hex`）
