    .section .text
    .global main
main:
    # 确保操作数稳定（排除流水线时序问题）
    li      a0, 42
    li      a1, 10
    nop
    nop
    nop
    nop
    divu    a2, a0, a1      # a2 = 42 / 10 = 4
    nop
    nop
    nop
    nop

    # 保存结果到内存用于调试
    li      t3, 0x00010100
    sw      a2, 0(t3)       # 保存商

    # 检查商
    li      t0, 4
    beq     a2, t0, check_rem
    # 商不对，输出商值
    li      t1, 0x10000000
    addi    t2, a2, 0x30
    sw      t2, 0(t1)       # 输出商的 ASCII
    li      a0, 1
    j       fail

check_rem:
    remu    a3, a0, a1
    nop
    nop
    nop
    nop
    li      t0, 2
    beq     a3, t0, pass_label
    li      a0, 2
    j       fail

pass_label:
    li      t1, 0x10000000
    li      t2, 0x4F        # 'O'
    sw      t2, 0(t1)
    li      t2, 0x4B        # 'K'
    sw      t2, 0(t1)
    j       pass
