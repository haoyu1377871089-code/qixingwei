# QXW 应用构建 Makefile
# 将 matmul 和 qsort 编译为 .hex 固件，供 SoC 测试台加载

CROSS   = riscv32-unknown-elf-
CC      = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy
OBJDUMP = $(CROSS)objdump

# 编译选项：裸机、无标准库
CFLAGS  = -march=rv32im -mabi=ilp32 -O2 -nostdlib -ffreestanding -Wall
LDFLAGS = -T ../linker.ld -nostdlib

# 源文件路径（start.S 和 linker.ld 在上级目录）
START   = ../start.S
LINKER  = ../linker.ld

# 应用列表
APPS    = matmul qsort
ELFS    = $(addsuffix .elf, $(APPS))
HEXS    = $(addsuffix .hex, $(APPS))
DIS     = $(addsuffix .dis, $(APPS))

.PHONY: all clean

all: $(HEXS)

# 通用规则：app.c -> app.elf -> app.hex
%.elf: %.c $(START) $(LINKER)
	$(CC) $(CFLAGS) -o $@ $(START) $< $(LDFLAGS)

%.hex: %.elf
	$(OBJCOPY) -O verilog $< $@
	$(OBJDUMP) -d $< > $(basename $<).dis

clean:
	rm -f $(ELFS) $(HEXS) $(DIS)
