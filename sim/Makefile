# QXW RISC-V CPU 仿真 Makefile (iverilog)

# 工具
IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave

# 目录
RTL_DIR  = ../rtl
CORE_DIR = $(RTL_DIR)/core
SOC_DIR  = $(RTL_DIR)/soc
MEM_DIR  = $(RTL_DIR)/mem
TB_DIR   = ../tb

# include path
INCS = -I$(CORE_DIR)

# RTL 文件
CORE_SRC = $(CORE_DIR)/qxw_regfile.v \
           $(CORE_DIR)/qxw_alu.v \
           $(CORE_DIR)/qxw_muldiv.v \
           $(CORE_DIR)/qxw_pc_reg.v \
           $(CORE_DIR)/qxw_if_stage.v \
           $(CORE_DIR)/qxw_id_stage.v \
           $(CORE_DIR)/qxw_ex_stage.v \
           $(CORE_DIR)/qxw_mem_stage.v \
           $(CORE_DIR)/qxw_wb_stage.v \
           $(CORE_DIR)/qxw_forwarding.v \
           $(CORE_DIR)/qxw_hazard_ctrl.v \
           $(CORE_DIR)/qxw_branch_pred.v \
           $(CORE_DIR)/qxw_csr.v \
           $(CORE_DIR)/qxw_cpu_top.v

SOC_SRC  = $(SOC_DIR)/qxw_bus.v \
           $(SOC_DIR)/qxw_uart.v \
           $(SOC_DIR)/qxw_timer.v \
           $(SOC_DIR)/qxw_soc_top.v

MEM_SRC  = $(MEM_DIR)/qxw_imem.v \
           $(MEM_DIR)/qxw_dmem.v

ALL_RTL  = $(CORE_SRC) $(SOC_SRC) $(MEM_SRC)

# 编译选项
IVFLAGS = -g2012 $(INCS) -DSIMULATION

# 默认目标
.PHONY: all sim wave alu regfile muldiv branch_pred forwarding clean

all: sim

# ---------- CPU 系统级仿真 ----------
sim: tb_cpu_top.vvp firmware.hex
	$(VVP) $<

tb_cpu_top.vvp: $(TB_DIR)/tb_cpu_top.v $(ALL_RTL)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

# 带调试 trace 的仿真
sim_debug: IVFLAGS += -DDEBUG_TRACE
sim_debug: tb_cpu_top.vvp firmware.hex
	$(VVP) $<

# 查看波形
wave: sim
	$(GTKWAVE) tb_cpu_top.vcd &

# ---------- ALU 单元测试 ----------
alu: tb_alu.vvp
	$(VVP) $<

tb_alu.vvp: $(TB_DIR)/tb_alu.v $(CORE_DIR)/qxw_alu.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

# ---------- 单元测试：寄存器堆、乘除法、分支预测、转发 ----------
regfile: tb_regfile.vvp
	$(VVP) $<

tb_regfile.vvp: $(TB_DIR)/tb_regfile.v $(CORE_DIR)/qxw_regfile.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

muldiv: tb_muldiv.vvp
	$(VVP) $<

tb_muldiv.vvp: $(TB_DIR)/tb_muldiv.v $(CORE_DIR)/qxw_muldiv.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

branch_pred: tb_branch_pred.vvp
	$(VVP) $<

tb_branch_pred.vvp: $(TB_DIR)/tb_branch_pred.v $(CORE_DIR)/qxw_branch_pred.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

forwarding: tb_forwarding.vvp
	$(VVP) $<

tb_forwarding.vvp: $(TB_DIR)/tb_forwarding.v $(CORE_DIR)/qxw_forwarding.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

# ---------- riscv-tests 批量测试 ----------
# 使用方法: make test HEX=path/to/test.hex
HEX ?= firmware.hex
test: tb_cpu_top.vvp
	cp $(HEX) firmware.hex
	$(VVP) $<

# ---------- 生成空白 firmware ----------
firmware.hex:
	@echo "// 空白固件 - NOP 循环" > $@
	@echo "00000013" >> $@
	@echo "00000013" >> $@
	@echo "00000013" >> $@
	@echo "0000006F" >> $@

# ---------- 清理 ----------
clean:
	rm -f *.vvp *.vcd *.hex

