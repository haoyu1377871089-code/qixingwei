    .section .text.init, "ax"
    .global _start

_start:
    # 初始化栈指针：数据 RAM 顶部 (0x0001_0000 + 16KB = 0x0001_4000)
    li      sp, 0x00014000

    # 清零 BSS 段
    la      t0, __bss_start
    la      t1, __bss_end
bss_loop:
    bge     t0, t1, bss_done
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       bss_loop
bss_done:

    # 初始化 .data 段（从 ROM 复制到 RAM）
    la      t0, __data_load_start
    la      t1, __data_start
    la      t2, __data_end
data_loop:
    bge     t1, t2, data_done
    lw      t3, 0(t0)
    sw      t3, 0(t1)
    addi    t0, t0, 4
    addi    t1, t1, 4
    j       data_loop
data_done:

    # 跳转到 main
    call    main

    # main 返回后写 tohost
    li      t0, 0x00013FF8   # tohost 地址
    li      t1, 1            # PASS
    sw      t1, 0(t0)

    # 死循环
halt:
    j       halt


    # pass/fail 辅助函数 (riscv-tests 兼容)
    .global pass
pass:
    li      t0, 0x00013FF8
    li      t1, 1
    sw      t1, 0(t0)
    j       halt

    .global fail
fail:
    li      t0, 0x00013FF8
    # a0 包含 test_id
    slli    t1, a0, 1
    ori     t1, t1, 1
    sw      t1, 0(t0)
    j       halt
