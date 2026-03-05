/*
 * QXW 矩阵乘法应用 - 4x4 整数矩阵乘法
 * 自包含 C 程序，无外部库依赖，内联所有 I/O 函数
 */

/* UART 外设地址 */
#define UART_DATA   (*(volatile unsigned int *)0x10000000)
#define UART_STATUS (*(volatile unsigned int *)0x10000004)

/* 定时器 mtime 地址 (RISC-V Machine Timer) */
#define TIMER_MTIME_LO (*(volatile unsigned int *)0x10001000)
#define TIMER_MTIME_HI (*(volatile unsigned int *)0x10001004)

/* tohost：写 1 表示 PASS，供仿真器检测 */
#define TOHOST (*(volatile unsigned int *)0x00013FF8)

/* 内联 putchar：等待 UART 空闲后发送一字节 */
/* 等待 UART 发送完成，然后写入数据寄存器 */
static void putchar(int c)
{
    while (UART_STATUS & 1)  /* bit0 = tx_busy，忙则等待 */
        ;
    UART_DATA = (unsigned char)c;
}

/* 内联 puts：输出字符串并换行 */
static void puts(const char *s)
{
    while (*s)
        putchar(*s++);
    putchar('\n');
}

/* 内联 print_dec：无符号整数十进制输出 */
/* 将无符号整数转为十进制字符串逆序存入 buf，再正序输出 */
static void print_dec(unsigned int val)
{
    char buf[12];
    int i = 0;
    if (val == 0) {
        putchar('0');
        return;
    }
    while (val > 0) {
        buf[i++] = '0' + (val % 10);  /* 取余得最低位 */
        val /= 10;
    }
    while (i > 0)
        putchar(buf[--i]);  /* 逆序输出即正确顺序 */
}

/* 读取 64 位 mtime 计数值（时钟周期） */
static unsigned long long get_timer(void)
{
    unsigned int hi1, hi2, lo;
    do {
        hi1 = TIMER_MTIME_HI;
        lo  = TIMER_MTIME_LO;
        hi2 = TIMER_MTIME_HI;
    } while (hi1 != hi2);  /* 防止读取时跨越进位 */
    return ((unsigned long long)hi1 << 32) | lo;
}

/* 4x4 矩阵乘法：C = A * B，三重循环实现 */
static void matmul_4x4(int A[4][4], int B[4][4], int C[4][4])
{
    int i, j, k;
    for (i = 0; i < 4; i++) {
        for (j = 0; j < 4; j++) {
            C[i][j] = 0;
            for (k = 0; k < 4; k++)
                C[i][j] += A[i][k] * B[k][j];  /* 累加 A 行与 B 列的点积 */
        }
    }
}

/* 打印 4x4 矩阵 */
static void print_matrix(int M[4][4])
{
    int i, j;
    for (i = 0; i < 4; i++) {
        for (j = 0; j < 4; j++) {
            print_dec((unsigned int)M[i][j]);
            putchar(j < 3 ? ' ' : '\n');
        }
    }
}

int main(void)
{
    /* 测试矩阵 A: 1~16 按行排列 */
    int A[4][4] = {
        {1, 2, 3, 4},
        {5, 6, 7, 8},
        {9, 10, 11, 12},
        {13, 14, 15, 16}
    };
    /* 测试矩阵 B: 全 1 */
    int B[4][4] = {
        {1, 1, 1, 1},
        {1, 1, 1, 1},
        {1, 1, 1, 1},
        {1, 1, 1, 1}
    };
    /* 期望结果 C = A*B: 每行和为 10, 26, 42, 58 */
    int expected[4][4] = {
        {10, 10, 10, 10},
        {26, 26, 26, 26},
        {42, 42, 42, 42},
        {58, 58, 58, 58}
    };
    int C[4][4];
    unsigned long long t0, t1;  /* 计时起止点 */
    int i, j, ok;

    t0 = get_timer();  /* 记录开始时刻 */

    puts("Matrix A:");
    print_matrix(A);
    puts("Matrix B:");
    print_matrix(B);

    matmul_4x4(A, B, C);

    puts("Result C:");
    print_matrix(C);

    /* 验证结果 */
    ok = 1;
    for (i = 0; i < 4 && ok; i++)
        for (j = 0; j < 4 && ok; j++)
            if (C[i][j] != expected[i][j])
                ok = 0;

    t1 = get_timer();  /* 记录结束时刻，计算周期数 */

    if (ok) {
        puts("PASS");
        TOHOST = 1;
    } else {
        puts("FAIL");
        TOHOST = 3;  /* fail 编码 */
    }

    putchar('C');
    putchar('y');
    putchar('c');
    putchar('l');
    putchar('e');
    putchar('s');
    putchar(':');
    putchar(' ');
    print_dec((unsigned int)(t1 - t0));  /* 输出执行周期数 */
    putchar('\n');

    return 0;
}
