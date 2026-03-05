# QXW RISC-V 软件构建 Makefile

# 工具链前缀
CROSS = riscv64-unknown-elf-
CC      = $(CROSS)gcc
AS      = $(CROSS)as
LD      = $(CROSS)ld
OBJCOPY = $(CROSS)objcopy
OBJDUMP = $(CROSS)objdump

# 编译选项
ARCH    = -march=rv32im -mabi=ilp32
CFLAGS  = $(ARCH) -O2 -Wall -nostdlib -ffreestanding -Ilib
ASFLAGS = $(ARCH)
LDFLAGS = -T linker.ld -nostdlib

# 目录
BUILD_DIR = build
TEST_DIR  = tests
SIM_DIR   = ../sim
LIB_DIR   = lib
COREMARK_DIR = coremark

# 库源文件（syscalls、printf、coremark_port）
LIB_SRC = $(LIB_DIR)/syscalls.c $(LIB_DIR)/printf.c $(LIB_DIR)/coremark_port.c

# 默认目标：编译所有测试（汇编 + C）
TESTS_S = $(wildcard $(TEST_DIR)/*.S)
TESTS_C = $(wildcard $(TEST_DIR)/*.c)
TEST_HEXS = $(patsubst $(TEST_DIR)/%.S, $(BUILD_DIR)/%.hex, $(TESTS_S)) \
            $(patsubst $(TEST_DIR)/%.c, $(BUILD_DIR)/%.hex, $(TESTS_C))

.PHONY: all clean firmware tests coremark

all: firmware

# 编译固件（默认使用 test_alu.S）
firmware: $(BUILD_DIR)/test_alu.hex
	cp $< $(SIM_DIR)/firmware.hex

# 编译所有测试
tests: $(TEST_HEXS)

# CoreMark 基准测试目标
coremark: $(BUILD_DIR)/coremark.hex
	cp $< $(SIM_DIR)/firmware.hex

$(BUILD_DIR)/coremark.elf: start.S $(LIB_SRC) $(COREMARK_DIR)/core_main.c linker.ld | $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ start.S $(LIB_SRC) $(COREMARK_DIR)/core_main.c -Wl,-T,linker.ld


$(BUILD_DIR)/coremark.hex: $(BUILD_DIR)/coremark.elf
	$(OBJCOPY) -O verilog $< $(BUILD_DIR)/coremark_bytes.hex
	python3 byte2word.py $(BUILD_DIR)/coremark_bytes.hex $@
	$(OBJDUMP) -d $< > $(BUILD_DIR)/coremark.dis

# 通用规则：汇编测试 .S -> .elf -> .hex
$(BUILD_DIR)/%.elf: $(TEST_DIR)/%.S start.S linker.ld | $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ start.S $< -Wl,-T,linker.ld

# 通用规则：C 测试 .c -> .elf -> .hex（链接库文件支持 putchar/printf 等）
$(BUILD_DIR)/%.elf: $(TEST_DIR)/%.c start.S $(LIB_SRC) linker.ld | $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ start.S $(LIB_SRC) $< -Wl,-T,linker.ld

$(BUILD_DIR)/%.hex: $(BUILD_DIR)/%.elf
	$(OBJCOPY) -O verilog $< $(BUILD_DIR)/$*_bytes.hex
	python3 byte2word.py $(BUILD_DIR)/$*_bytes.hex $@
	$(OBJDUMP) -d $< > $(BUILD_DIR)/$*.dis

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)
