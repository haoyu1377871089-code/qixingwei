# QXW RISC-V CPU

基于 RISC-V RV32IM 指令集的五级流水线 CPU 软核，采用 Verilog 独立设计，面向 Xilinx Zynq-7020 FPGA。

## 项目特性

- **指令集**：完整 RV32I 基础整数 + M 扩展（乘除法）
- **流水线**：经典五级流水线 IF/ID/EX/MEM/WB
- **冒险处理**：三路全数据转发 + 256 项 BHT 分支预测
- **SoC 集成**：16KB IMEM + 16KB DMEM + UART + Timer
- **FPGA 资源**：3,174 LUTs / 5 Block RAM / 12 DSP48E1
- **时序**：50 MHz 时序收敛（WNS +2.553 ns）
- **验证**：148 项测试全部通过（含官方 riscv-tests 48/48 + CoreMark）

## 目录结构

```
qixingwei/
├── rtl/                        # RTL 源代码
│   ├── core/                   # CPU 核心模块
│   │   ├── qxw_defines.vh      #   宏定义与参数
│   │   ├── qxw_pc_reg.v        #   PC 寄存器
│   │   ├── qxw_if_stage.v      #   取指阶段
│   │   ├── qxw_id_stage.v      #   译码阶段
│   │   ├── qxw_ex_stage.v      #   执行阶段
│   │   ├── qxw_mem_stage.v     #   访存阶段
│   │   ├── qxw_wb_stage.v      #   写回阶段
│   │   ├── qxw_alu.v           #   ALU
│   │   ├── qxw_muldiv.v        #   乘除法单元
│   │   ├── qxw_regfile.v       #   寄存器堆
│   │   ├── qxw_forwarding.v    #   数据前递
│   │   ├── qxw_hazard_ctrl.v   #   冒险控制
│   │   ├── qxw_branch_pred.v   #   分支预测器
│   │   ├── qxw_csr.v           #   CSR 寄存器
│   │   └── qxw_cpu_top.v       #   CPU 顶层
│   ├── mem/                    # 存储器
│   │   ├── qxw_imem.v          #   指令存储器 (16KB BRAM)
│   │   └── qxw_dmem.v          #   数据存储器 (16KB BRAM)
│   └── soc/                    # SoC 外设
│       ├── qxw_bus.v           #   总线地址译码
│       ├── qxw_uart.v          #   UART 串口
│       ├── qxw_timer.v         #   64 位定时器
│       └── qxw_soc_top.v       #   SoC 顶层
├── tb/                         # Testbench
│   ├── tb_cpu_top.v            #   系统级测试平台
│   ├── tb_alu.v                #   ALU 单元测试
│   ├── tb_regfile.v            #   寄存器堆单元测试
│   ├── tb_muldiv.v             #   乘除法单元测试
│   ├── tb_forwarding.v         #   转发单元测试
│   └── tb_branch_pred.v        #   分支预测单元测试
├── sim/                        # 仿真工作目录
│   └── Makefile                #   仿真构建脚本
├── sw/                         # 软件
│   ├── start.S                 #   启动代码
│   ├── linker.ld               #   链接脚本
│   ├── Makefile                #   软件构建脚本
│   ├── byte2word.py            #   hex 格式转换工具
│   ├── tests/                  #   自定义测试程序
│   ├── coremark/               #   CoreMark 基准测试
│   ├── lib/                    #   运行时库 (printf, syscalls)
│   └── apps/                   #   应用程序 (矩阵乘法等)
├── riscv-tests/                # 官方 riscv-tests 源码
├── riscv-tests-build/          # riscv-tests 编译框架
│   ├── run_riscv_tests.sh      #   自动化测试脚本
│   ├── env/riscv_test.h        #   适配 QXW SoC 的测试头文件
│   ├── link.ld                 #   riscv-tests 链接脚本
│   └── encoding.h              #   RISC-V CSR 编码定义
├── fpga/                       # FPGA 相关
│   ├── constraints/ax7020.xdc  #   引脚约束 (ALINX AX7020)
│   └── scripts/build.tcl       #   Vivado 非工程模式构建脚本
└── doc/                        # 文档
    ├── architecture.md         #   架构设计说明书
    ├── module_signals.md       #   子模块信号列表
    ├── simulation_report.md    #   仿真验证报告
    ├── performance_report.md   #   性能分析报告
    ├── debug_progress.md       #   调试进度报告
    ├── verification_plan.md    #   验证计划
    └── vivado_guide.md         #   Vivado 操作指南
```

## 快速开始

### 1. 环境准备（Ubuntu）

#### 1.1 安装 Icarus Verilog（仿真器）

```bash
sudo apt update
sudo apt install -y iverilog
```

验证安装：

```bash
iverilog -V
# 应输出版本信息，如 Icarus Verilog version 12.0
```

#### 1.2 安装 RISC-V 交叉编译工具链

**方式一：通过包管理器安装（推荐）**

```bash
sudo apt install -y gcc-riscv64-unknown-elf
```

如果包名不同，尝试：

```bash
sudo apt install -y gcc-riscv64-linux-gnu
```

**方式二：下载预编译工具链**

```bash
# 从 SiFive 下载 (推荐 GCC 10.x)
wget https://static.dev.sifive.com/dev-tools/freedom-tools/v2020.12.0/riscv64-unknown-elf-gcc-10.1.0-2020.12.0-x86_64-linux-ubuntu14.tar.gz
tar -xzf riscv64-unknown-elf-gcc-*.tar.gz
export PATH=$PATH:$(pwd)/riscv64-unknown-elf-gcc-10.1.0-2020.12.0-x86_64-linux-ubuntu14/bin
# 建议将上面的 export 添加到 ~/.bashrc
```

验证安装：

```bash
riscv64-unknown-elf-gcc --version
# 应输出版本信息
```

#### 1.3 安装 Python 3（hex 转换工具需要）

```bash
sudo apt install -y python3
```

#### 1.4 安装 GTKWave（可选，查看波形）

```bash
sudo apt install -y gtkwave
```

### 2. 克隆项目

```bash
git clone --recursive <仓库地址> qixingwei
cd qixingwei

# 如果克隆时未加 --recursive，需手动初始化子模块
git submodule update --init --recursive
```

### 3. 编译并运行自定义测试

#### 3.1 编译测试固件

```bash
cd sw
make tests        # 编译所有测试程序
make firmware     # 编译默认测试 (test_alu) 并复制到 sim/
cd ..
```

#### 3.2 运行仿真

```bash
cd sim
make              # 编译 testbench 并运行仿真
```

预期输出：

```
========================================
TEST PASSED after XXX cycles
========================================
```

#### 3.3 运行指定测试

```bash
cd sim

# 运行 test_branch
make test HEX=../sw/build/test_branch.hex

# 运行 test_muldiv
make test HEX=../sw/build/test_muldiv.hex

# 运行 CoreMark
cd ../sw && make coremark && cd ../sim && make
```

#### 3.4 查看波形（可选）

```bash
cd sim
make wave         # 运行仿真并打开 GTKWave
```

### 4. 运行官方 riscv-tests

```bash
# 一键编译并运行全部 48 项测试
bash riscv-tests-build/run_riscv_tests.sh
```

预期输出：

```
============================================
  QXW RV32IM - Official riscv-tests Runner
============================================

[1/4] Compiling RV32UI tests...
[2/4] Compiling RV32UM tests...
[3/4] Running RV32UI tests...

  rv32ui-simple             PASS  (120 cycles)
  rv32ui-add                PASS  (592 cycles)
  ...（共 40 项全部 PASS）

[4/4] Running RV32UM tests...

  rv32um-mul                PASS  (586 cycles)
  ...（共 8 项全部 PASS）

============================================
  Test Results Summary
============================================
  Total:   48
  Passed:  48
  Failed:  0
  Timeout: 0
============================================
```

### 5. 运行 CoreMark 基准测试

```bash
cd sw
make coremark     # 编译 CoreMark 并复制到 sim/
cd ../sim
make              # 运行仿真
```

预期输出：

```
CoreMark matrix
C[0][0]=1
list sum=136
state machine count=1000
iterations=100
total cycles=81431
========================================
TEST PASSED after 84592 cycles
========================================
```

### 6. FPGA 综合（需要 Vivado）

#### 6.1 安装 Vivado

从 [Xilinx 官网](https://www.xilinx.com/support/download.html) 下载并安装 Vivado（WebPACK 免费版即可），需包含 Zynq-7000 系列支持。

#### 6.2 编译固件

```bash
cd sw
make firmware     # 生成 sim/firmware.hex
```

将 `sim/firmware.hex` 复制到 `fpga/scripts/` 目录：

```bash
cp sim/firmware.hex fpga/scripts/firmware.hex
```

#### 6.3 运行综合

```bash
cd fpga/scripts
vivado -mode batch -source build.tcl
```

构建完成后，输出文件位于 `fpga/scripts/output/`：

| 文件 | 说明 |
|------|------|
| `qxw_riscv.bit` | FPGA 比特流 |
| `post_impl_timing.rpt` | 时序报告 |
| `post_impl_util.rpt` | 资源利用率报告 |

#### 6.4 下板验证

1. 连接 ALINX AX7020 开发板
2. 在 Vivado Hardware Manager 中下载 `qxw_riscv.bit`
3. 通过串口终端（115200 8N1）观察 UART 输出

## SoC 地址映射

| 组件 | 基地址 | 大小 | 说明 |
|------|--------|------|------|
| 指令 ROM (IMEM) | 0x0000_0000 | 16 KB | BRAM，直连 CPU |
| 数据 RAM (DMEM) | 0x0001_0000 | 16 KB | BRAM，经总线 |
| UART | 0x1000_0000 | 256 B | 串口调试 |
| Timer | 0x1000_1000 | 256 B | 64-bit mtime/mtimecmp |
| tohost | 0x0001_3FF8 | 4 B | 仿真测试结果标志 |

## 验证结果汇总

| 验证项 | 结果 |
|--------|------|
| 模块级 Testbench (92 项) | 100% 通过 |
| 自定义汇编/C 测试 (7 项) | 100% 通过 |
| 官方 riscv-tests RV32UI (40 项) | 100% 通过 |
| 官方 riscv-tests RV32UM (8 项) | 100% 通过 |
| CoreMark 基准测试 | PASS (81,431 cycles) |
| FPGA 综合 (Vivado) | LUT 3,174 < 5,000 |
| 时序 | 50 MHz 满足 (WNS +2.553 ns) |

## 技术文档

详细设计文档位于 `doc/` 目录：

- [架构设计说明书](doc/architecture.md) — CPU 微架构、指令集、流水线设计
- [子模块信号列表](doc/module_signals.md) — 所有 RTL 模块端口定义
- [仿真验证报告](doc/simulation_report.md) — 完整测试结果与 Bug 修复记录
- [性能分析报告](doc/performance_report.md) — CPI、资源利用率、时序分析
- [Vivado 操作指南](doc/vivado_guide.md) — FPGA 综合与下板步骤
- [验证计划](doc/verification_plan.md) — 验证策略与测试用例
- [调试进度报告](doc/debug_progress.md) — 项目完成状态

## 常见问题

### Q: `riscv64-unknown-elf-gcc` 命令找不到

确保工具链已安装并添加到 `PATH`。如果使用的是 `riscv64-linux-gnu-gcc`，需要修改 `sw/Makefile` 和 `riscv-tests-build/run_riscv_tests.sh` 中的 `CROSS` 变量。

### Q: 仿真报 `$readmemh` 地址越界警告

这是正常现象。`objcopy -O verilog` 会输出所有段的数据，包括 `.data` 和 `.tohost` 段，它们的地址超出了 IMEM 范围。IMEM 会忽略越界地址，不影响功能。

### Q: CoreMark 仿真超时

默认 `MAX_CYCLES` 为 200,000，对 CoreMark 足够。如需更多周期，可在编译 testbench 时指定：

```bash
cd sim
iverilog -g2012 -I../rtl/core -DSIMULATION -DMAX_CYC=500000 -o tb_cpu_top.vvp ../tb/tb_cpu_top.v ../rtl/core/*.v ../rtl/soc/*.v ../rtl/mem/*.v
```

### Q: Vivado 综合时 BRAM 未推断

确保 `qxw_imem.v` 和 `qxw_dmem.v` 中包含 `(* ram_style = "block" *)` 属性，且读操作为同步读（`always @(posedge clk)`）。

## 许可证

本项目为七星微企业命题赛作品。
