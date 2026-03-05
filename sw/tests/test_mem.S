# Load/Store 指令测试
# 测试 SW/LW, SH/LH/LHU, SB/LB/LBU

    .section .text
    .global main

main:
    # 使用数据 RAM 起始处做测试: 0x00010000
    li      s0, 0x00010000

    # ---- TEST 1: SW + LW ----
    li      a0, 1
    li      t0, 0xDEADBEEF
    sw      t0, 0(s0)
    lw      t1, 0(s0)
    bne     t0, t1, fail

    # ---- TEST 2: SH + LH (positive) ----
    li      a0, 2
    li      t0, 0x1234
    sh      t0, 4(s0)
    lh      t1, 4(s0)
    bne     t0, t1, fail

    # ---- TEST 3: SH + LH (negative / sign extend) ----
    li      a0, 3
    li      t0, 0xFFFF8000   # -32768
    sh      t0, 8(s0)
    lh      t1, 8(s0)
    li      t2, 0xFFFF8000
    bne     t1, t2, fail

    # ---- TEST 4: SH + LHU (zero extend) ----
    li      a0, 4
    li      t0, 0x8000
    sh      t0, 8(s0)
    lhu     t1, 8(s0)
    li      t2, 0x00008000
    bne     t1, t2, fail

    # ---- TEST 5: SB + LB ----
    li      a0, 5
    li      t0, 0x42
    sb      t0, 12(s0)
    lb      t1, 12(s0)
    li      t2, 0x42
    bne     t1, t2, fail

    # ---- TEST 6: SB + LB (sign extend) ----
    li      a0, 6
    li      t0, 0x80
    sb      t0, 16(s0)
    lb      t1, 16(s0)
    li      t2, 0xFFFFFF80
    bne     t1, t2, fail

    # ---- TEST 7: SB + LBU (zero extend) ----
    li      a0, 7
    li      t0, 0x80
    sb      t0, 16(s0)
    lbu     t1, 16(s0)
    li      t2, 0x00000080
    bne     t1, t2, fail

    # ---- TEST 8: 非对齐半字访问 (offset=2) ----
    li      a0, 8
    li      t0, 0xAABBCCDD
    sw      t0, 20(s0)
    lh      t1, 22(s0)     # 读高半字
    li      t2, 0xFFFFAABB
    bne     t1, t2, fail

    # 全部通过
    j       pass
