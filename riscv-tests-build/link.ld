/* QXW RV32IM CPU - riscv-tests linker script */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    RAM (rwx) : ORIGIN = 0x00010000, LENGTH = 16K
}

SECTIONS
{
    .text : {
        *(.text.init)
        *(.text .text.*)
    } > ROM

    __data_load_start = .;

    .data : AT(__data_load_start) {
        __data_start = .;
        *(.data .data.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
        __data_end = .;
    } > RAM

    .bss : {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    .tohost 0x00013FF8 : {
        *(.tohost)
    } > RAM

    _end = .;
}
