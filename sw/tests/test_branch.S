# 分支跳转指令测试
# 测试 BEQ/BNE/BLT/BGE/BLTU/BGEU/JAL/JALR

    .section .text
    .global main

main:
    # ---- TEST 1: BEQ taken ----
    li      a0, 1
    li      t0, 42
    li      t1, 42
    beq     t0, t1, test1_ok
    j       fail
test1_ok:

    # ---- TEST 2: BEQ not taken ----
    li      a0, 2
    li      t0, 1
    li      t1, 2
    beq     t0, t1, fail

    # ---- TEST 3: BNE taken ----
    li      a0, 3
    li      t0, 1
    li      t1, 2
    bne     t0, t1, test3_ok
    j       fail
test3_ok:

    # ---- TEST 4: BLT taken (signed) ----
    li      a0, 4
    li      t0, -1
    li      t1, 0
    blt     t0, t1, test4_ok
    j       fail
test4_ok:

    # ---- TEST 5: BGE taken ----
    li      a0, 5
    li      t0, 5
    li      t1, 5
    bge     t0, t1, test5_ok
    j       fail
test5_ok:

    # ---- TEST 6: BLTU taken (unsigned) ----
    li      a0, 6
    li      t0, 0
    li      t1, -1       # 0xFFFFFFFF unsigned
    bltu    t0, t1, test6_ok
    j       fail
test6_ok:

    # ---- TEST 7: BGEU taken ----
    li      a0, 7
    li      t0, -1       # 0xFFFFFFFF unsigned
    li      t1, 0
    bgeu    t0, t1, test7_ok
    j       fail
test7_ok:

    # ---- TEST 8: JAL ----
    li      a0, 8
    jal     ra, test8_target
    # ra 应指向这里
    j       test8_check
test8_target:
    jr      ra
test8_check:

    # ---- TEST 9: JALR ----
    li      a0, 9
    la      t0, test9_target
    jalr    ra, t0, 0
    j       test9_check
test9_target:
    jr      ra
test9_check:

    # ---- TEST 10: 前向分支 ----
    li      a0, 10
    li      t0, 0
    li      t1, 5
loop:
    addi    t0, t0, 1
    bne     t0, t1, loop
    # t0 应该等于 5
    li      t2, 5
    bne     t0, t2, fail

    # 全部通过
    j       pass
