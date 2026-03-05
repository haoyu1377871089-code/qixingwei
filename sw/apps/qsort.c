/*
 * QXW 快速排序应用 - 整数数组排序
 * 自包含 C 程序，无外部库依赖，内联所有 I/O 函数
 */

/* UART 外设地址 */
#define UART_DATA   (*(volatile unsigned int *)0x10000000)
#define UART_STATUS (*(volatile unsigned int *)0x10000004)

/* 定时器 mtime 地址 */
#define TIMER_MTIME_LO (*(volatile unsigned int *)0x10001000)
#define TIMER_MTIME_HI (*(volatile unsigned int *)0x10001004)

/* tohost：写 1 表示 PASS */
#define TOHOST (*(volatile unsigned int *)0x00013FF8)

/* 内联 putchar：轮询 UART 状态，空闲后发送 */
static void putchar(int c)
{
    while (UART_STATUS & 1)  /* tx_busy 为 1 则等待 */
        ;
    UART_DATA = (unsigned char)c;
}

/* 内联 puts */
static void puts(const char *s)
{
    while (*s)
        putchar(*s++);
    putchar('\n');
}

/* 内联 print_dec：无符号整数转十进制输出 */
static void print_dec(unsigned int val)
{
    char buf[12];
    int i = 0;
    if (val == 0) {
        putchar('0');
        return;
    }
    while (val > 0) {
        buf[i++] = '0' + (val % 10);  /* 从低位到高位存入 */
        val /= 10;
    }
    while (i > 0)
        putchar(buf[--i]);  /* 逆序输出得到正确数字 */
}

/* 读取 64 位 mtime */
static unsigned long long get_timer(void)
{
    unsigned int hi1, hi2, lo;
    do {
        hi1 = TIMER_MTIME_HI;
        lo  = TIMER_MTIME_LO;
        hi2 = TIMER_MTIME_HI;
    } while (hi1 != hi2);
    return ((unsigned long long)hi1 << 32) | lo;
}

/* 交换两整数 */
static void swap(int *a, int *b)
{
    int t = *a;
    *a = *b;
    *b = t;
}

/* 快速排序分区：以 arr[hi] 为 pivot，将小于等于 pivot 的放左侧 */
static int partition(int arr[], int lo, int hi)
{
    int pivot = arr[hi];
    int i = lo - 1;  /* 小于等于 pivot 的区域的右边界 */
    int j;
    for (j = lo; j < hi; j++) {
        if (arr[j] <= pivot) {
            i++;
            swap(&arr[i], &arr[j]);  /* 将小元素交换到左侧 */
        }
    }
    swap(&arr[i + 1], &arr[hi]);  /* pivot 归位 */
    return i + 1;
}

/* 快速排序递归实现：分区后对左右子数组递归排序 */
static void quicksort(int arr[], int lo, int hi)
{
    int p;
    if (lo < hi) {
        p = partition(arr, lo, hi);   /* 分区，p 为 pivot 最终位置 */
        quicksort(arr, lo, p - 1);    /* 左半部分 */
        quicksort(arr, p + 1, hi);    /* 右半部分 */
    }
}

/* 打印数组为 [a, b, c, ...] 格式 */
static void print_array(int arr[], int n)
{
    int i;
    putchar('[');
    for (i = 0; i < n; i++) {
        print_dec((unsigned int)arr[i]);
        if (i < n - 1) {
            putchar(',');
            putchar(' ');
        }
    }
    putchar(']');
    putchar('\n');
}

/* 验证数组是否升序排列 */
static int is_sorted(int arr[], int n)
{
    int i;
    for (i = 1; i < n; i++)
        if (arr[i] < arr[i - 1])  /* 发现逆序则未排序 */
            return 0;
    return 1;
}

int main(void)
{
    /* 20 个伪随机整数（硬编码），排序后应为 2,3,5,8,9,11,12,19,22,23,25,34,41,45,55,64,67,77,88,90 */
    int arr[20] = {
        64, 34, 25, 12, 22, 11, 90, 5, 77, 3,
        88, 45, 23, 9, 67, 2, 55, 41, 19, 8
    };
    unsigned long long t0, t1;
    int ok;

    t0 = get_timer();

    putchar('B');
    putchar('e');
    putchar('f');
    putchar('o');
    putchar('r');
    putchar('e');
    putchar(':');
    putchar(' ');
    print_array(arr, 20);

    quicksort(arr, 0, 19);

    putchar('A');
    putchar('f');
    putchar('t');
    putchar('e');
    putchar('r');
    putchar(':');
    putchar(' ');
    print_array(arr, 20);

    ok = is_sorted(arr, 20);  /* 检查是否升序 */

    t1 = get_timer();  /* 记录结束时刻 */

    if (ok) {
        puts("PASS");
        TOHOST = 1;
    } else {
        puts("FAIL");
        TOHOST = 3;
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
