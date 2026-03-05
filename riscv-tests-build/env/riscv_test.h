// Custom riscv_test.h for QXW RV32IM CPU
// Simplified environment adapted for the QXW SoC memory map:
//   IMEM: 0x00000000, 16KB (code)
//   DMEM: 0x00010000, 16KB (data)
//   tohost: 0x00013FF8

#ifndef _QXW_RISCV_TEST_H
#define _QXW_RISCV_TEST_H

#include "../encoding.h"

#define RVTEST_RV64U \
  .macro init; \
  .endm

#define RVTEST_RV64UF \
  .macro init; \
  .endm

#define RVTEST_RV32U \
  .macro init; \
  .endm

#define RVTEST_RV32UF \
  .macro init; \
  .endm

#define RVTEST_RV64M \
  .macro init; \
  .endm

#define RVTEST_RV32M \
  .macro init; \
  .endm

#define CHECK_XLEN li a0, 1; slli a0, a0, 31; bltz a0, 1f; RVTEST_PASS; 1:

#define INIT_XREG \
  li x1, 0; li x2, 0; li x3, 0; li x4, 0; \
  li x5, 0; li x6, 0; li x7, 0; li x8, 0; \
  li x9, 0; li x10, 0; li x11, 0; li x12, 0; \
  li x13, 0; li x14, 0; li x15, 0; li x16, 0; \
  li x17, 0; li x18, 0; li x19, 0; li x20, 0; \
  li x21, 0; li x22, 0; li x23, 0; li x24, 0; \
  li x25, 0; li x26, 0; li x27, 0; li x28, 0; \
  li x29, 0; li x30, 0; li x31, 0;

#define EXTRA_TVEC_USER
#define EXTRA_TVEC_MACHINE
#define EXTRA_INIT
#define EXTRA_INIT_TIMER
#define FILTER_TRAP
#define FILTER_PAGE_FAULT

#define INTERRUPT_HANDLER j other_exception

#define RVTEST_CODE_BEGIN                                               \
        .section .text.init;                                            \
        .align  6;                                                      \
        .weak stvec_handler;                                            \
        .weak mtvec_handler;                                            \
        .globl _start;                                                  \
_start:                                                                 \
        j reset_vector;                                                 \
        .align 2;                                                       \
trap_vector:                                                            \
        csrr t5, mcause;                                                \
        li t6, CAUSE_USER_ECALL;                                        \
        beq t5, t6, write_tohost;                                       \
        li t6, CAUSE_SUPERVISOR_ECALL;                                  \
        beq t5, t6, write_tohost;                                       \
        li t6, CAUSE_MACHINE_ECALL;                                     \
        beq t5, t6, write_tohost;                                       \
        la t5, mtvec_handler;                                           \
        beqz t5, 1f;                                                    \
        jr t5;                                                          \
  1:    csrr t5, mcause;                                                \
        bgez t5, handle_exception;                                      \
        INTERRUPT_HANDLER;                                              \
handle_exception:                                                       \
  other_exception:                                                      \
  1:    ori TESTNUM, TESTNUM, 1337;                                     \
  write_tohost:                                                         \
        sw TESTNUM, tohost, t5;                                         \
        sw zero, tohost + 4, t5;                                        \
        j write_tohost;                                                 \
reset_vector:                                                           \
        INIT_XREG;                                                      \
        /* Copy .data from ROM to RAM */                                \
        la t0, __data_load_start;                                       \
        la t1, __data_start;                                            \
        la t2, __data_end;                                              \
data_copy:                                                              \
        bge t1, t2, data_done;                                          \
        lw t3, 0(t0);                                                   \
        sw t3, 0(t1);                                                   \
        addi t0, t0, 4;                                                 \
        addi t1, t1, 4;                                                 \
        j data_copy;                                                    \
data_done:                                                              \
        li TESTNUM, 0;                                                  \
        la t0, trap_vector;                                             \
        csrw mtvec, t0;                                                 \
        CHECK_XLEN;                                                     \
        csrwi mstatus, 0;                                               \
        init;                                                           \
        EXTRA_INIT;                                                     \
        EXTRA_INIT_TIMER;                                               \

#define RVTEST_CODE_END                                                 \
        unimp

#define RVTEST_PASS                                                     \
        fence;                                                          \
        li TESTNUM, 1;                                                  \
        li a7, 93;                                                      \
        li a0, 0;                                                       \
        ecall

#define TESTNUM gp
#define RVTEST_FAIL                                                     \
        fence;                                                          \
1:      beqz TESTNUM, 1b;                                               \
        sll TESTNUM, TESTNUM, 1;                                        \
        or TESTNUM, TESTNUM, 1;                                         \
        li a7, 93;                                                      \
        addi a0, TESTNUM, 0;                                            \
        ecall

#define EXTRA_DATA

#define RVTEST_DATA_BEGIN                                               \
        EXTRA_DATA                                                      \
        .pushsection .tohost,"aw",@progbits;                            \
        .align 2; .global tohost; tohost: .word 0; .word 0;            \
        .popsection;                                                    \
        .global fromhost; fromhost: .word 0; .word 0;                   \
        .align 4; .global begin_signature; begin_signature:

#define RVTEST_DATA_END .align 4; .global end_signature; end_signature:

#endif
