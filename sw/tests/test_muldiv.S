# M 扩展乘除法指令测试

    .section .text
    .global main

main:
    # ---- TEST 1: MUL ----
    li      a0, 1
    li      t0, 7
    li      t1, 6
    mul     t2, t0, t1
    li      t3, 42
    bne     t2, t3, fail

    # ---- TEST 2: MUL (negative) ----
    li      a0, 2
    li      t0, -3
    li      t1, 7
    mul     t2, t0, t1
    li      t3, -21
    bne     t2, t3, fail

    # ---- TEST 3: MULH (signed high) ----
    li      a0, 3
    li      t0, 0x7FFFFFFF
    li      t1, 2
    mulh    t2, t0, t1
    li      t3, 0           # 0x7FFFFFFF * 2 = 0x0_FFFFFFFE -> high = 0
    bne     t2, t3, fail

    # ---- TEST 4: MULHU (unsigned high) ----
    li      a0, 4
    li      t0, -1           # 0xFFFFFFFF
    li      t1, -1           # 0xFFFFFFFF
    mulhu   t2, t0, t1       # 0xFFFFFFFF^2 = 0xFFFFFFFE_00000001 -> high = 0xFFFFFFFE
    li      t3, 0xFFFFFFFE
    bne     t2, t3, fail

    # ---- TEST 5: DIV ----
    li      a0, 5
    li      t0, 42
    li      t1, 7
    div     t2, t0, t1
    li      t3, 6
    bne     t2, t3, fail

    # ---- TEST 6: DIV (negative) ----
    li      a0, 6
    li      t0, -20
    li      t1, 3
    div     t2, t0, t1
    li      t3, -6          # 截断除法: -20/3 = -6 (余 -2)
    bne     t2, t3, fail

    # ---- TEST 7: DIVU ----
    li      a0, 7
    li      t0, 100
    li      t1, 10
    divu    t2, t0, t1
    li      t3, 10
    bne     t2, t3, fail

    # ---- TEST 8: REM ----
    li      a0, 8
    li      t0, 20
    li      t1, 3
    rem     t2, t0, t1
    li      t3, 2
    bne     t2, t3, fail

    # ---- TEST 9: REM (negative) ----
    li      a0, 9
    li      t0, -20
    li      t1, 3
    rem     t2, t0, t1
    li      t3, -2          # 余数符号与被除数相同
    bne     t2, t3, fail

    # ---- TEST 10: REMU ----
    li      a0, 10
    li      t0, 100
    li      t1, 7
    remu    t2, t0, t1
    li      t3, 2           # 100 % 7 = 2
    bne     t2, t3, fail

    # ---- TEST 11: DIV by zero ----
    li      a0, 11
    li      t0, 42
    li      t1, 0
    div     t2, t0, t1
    li      t3, -1          # RISC-V spec: div by 0 -> all ones
    bne     t2, t3, fail

    # 全部通过
    j       pass
