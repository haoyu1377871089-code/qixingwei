/* QXW RISC-V CPU 链接脚本 */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    /* 指令 ROM: 16KB @ 0x0000_0000 */
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K

    /* 数据 RAM: 16KB @ 0x0001_0000 */
    RAM (rwx) : ORIGIN = 0x00010000, LENGTH = 16K
}

SECTIONS
{
    /* 代码段 -> ROM */
    .text : {
        *(.text.init)
        *(.text .text.*)
    } > ROM

    /* data + rodata 合并放入 RAM，加载地址在 ROM */
    __data_load_start = .;

    .data : AT(__data_load_start) {
        __data_start = .;
        *(.rodata .rodata.*)
        *(.data .data.*)
        . = ALIGN(4);
        __data_end = .;
    } > RAM

    /* BSS 段 -> RAM */
    .bss : {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    } > RAM

    /* tohost 符号 (riscv-tests 兼容) */
    .tohost 0x00013FF8 : {
        *(.tohost)
    } > RAM

    /* 栈在 RAM 顶部向下增长 */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
