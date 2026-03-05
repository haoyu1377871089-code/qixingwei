# RV32I 基础算术逻辑指令测试
# 每个测试设置 test_id, 失败时跳转 fail

    .section .text
    .global main

main:
    # ---- TEST 1: ADDI ----
    li      a0, 1
    li      t0, 10
    addi    t1, t0, 20
    li      t2, 30
    bne     t1, t2, fail

    # ---- TEST 2: ADD ----
    li      a0, 2
    li      t0, 100
    li      t1, 200
    add     t2, t0, t1
    li      t3, 300
    bne     t2, t3, fail

    # ---- TEST 3: SUB ----
    li      a0, 3
    li      t0, 50
    li      t1, 30
    sub     t2, t0, t1
    li      t3, 20
    bne     t2, t3, fail

    # ---- TEST 4: AND ----
    li      a0, 4
    li      t0, 0xFF
    li      t1, 0x0F
    and     t2, t0, t1
    li      t3, 0x0F
    bne     t2, t3, fail

    # ---- TEST 5: OR ----
    li      a0, 5
    li      t0, 0xF0
    li      t1, 0x0F
    or      t2, t0, t1
    li      t3, 0xFF
    bne     t2, t3, fail

    # ---- TEST 6: XOR ----
    li      a0, 6
    li      t0, 0xFF
    li      t1, 0xFF
    xor     t2, t0, t1
    bne     t2, zero, fail

    # ---- TEST 7: SLL ----
    li      a0, 7
    li      t0, 1
    li      t1, 4
    sll     t2, t0, t1
    li      t3, 16
    bne     t2, t3, fail

    # ---- TEST 8: SRL ----
    li      a0, 8
    li      t0, 256
    li      t1, 4
    srl     t2, t0, t1
    li      t3, 16
    bne     t2, t3, fail

    # ---- TEST 9: SRA (positive) ----
    li      a0, 9
    li      t0, 256
    li      t1, 4
    sra     t2, t0, t1
    li      t3, 16
    bne     t2, t3, fail

    # ---- TEST 10: SRA (negative) ----
    li      a0, 10
    li      t0, -256
    li      t1, 4
    sra     t2, t0, t1
    li      t3, -16
    bne     t2, t3, fail

    # ---- TEST 11: SLT ----
    li      a0, 11
    li      t0, -1
    li      t1, 1
    slt     t2, t0, t1
    li      t3, 1
    bne     t2, t3, fail

    # ---- TEST 12: SLTU ----
    li      a0, 12
    li      t0, 1
    li      t1, -1       # 0xFFFFFFFF unsigned
    sltu    t2, t0, t1
    li      t3, 1
    bne     t2, t3, fail

    # ---- TEST 13: LUI ----
    li      a0, 13
    lui     t0, 0xABCDE
    srli    t0, t0, 12
    li      t1, 0xABCDE
    bne     t0, t1, fail

    # ---- TEST 14: AUIPC ----
    li      a0, 14
    auipc   t0, 0
    # t0 应该等于当前 PC
    # 简单验证 t0 非零
    beq     t0, zero, fail

    # 全部通过
    j       pass
