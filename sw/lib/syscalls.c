/*
 * QXW RISC-V 最小化系统调用实现
 * 为裸机/newlib 提供 UART 输出、堆管理、定时器读取等基础功能
 */

/* UART 外设基址与寄存器偏移（与 qxw_uart.v 对应） */
#define UART_BASE  0x10000000
#define UART_DATA  (*(volatile unsigned int *)(UART_BASE + 0x00))
#define UART_STATUS (*(volatile unsigned int *)(UART_BASE + 0x04))

/* 定时器外设基址（与 qxw_timer.v 对应，RISC-V Machine Timer） */
#define TIMER_BASE 0x10001000
#define TIMER_MTIME_LO (*(volatile unsigned int *)(TIMER_BASE + 0x00))
#define TIMER_MTIME_HI (*(volatile unsigned int *)(TIMER_BASE + 0x04))

/* tohost 地址，用于仿真/测试框架检测程序结束状态 */
#define TOHOST_ADDR 0x00013FF8
#define TOHOST (*(volatile unsigned int *)TOHOST_ADDR)

/* 堆顶符号，由链接脚本提供；堆从 __bss_end 向上增长 */
extern char __bss_end[];

/* 当前堆顶指针，_sbrk 每次分配时向上 bump */
static char *heap_end = (char *)0;

/*
 * _write: 将 buf 中 len 字节通过 UART 输出
 * newlib 的 printf/puts 会调用此函数（fd=1 为 stdout）
 * 实现：轮询 UART_STATUS[0] (tx_busy)，空闲时写入 UART_DATA
 */
int _write(int fd, const char *buf, int len)
{
    int i;
    if (fd != 1 && fd != 2)
        return -1;
    for (i = 0; i < len; i++) {
        while (UART_STATUS & 1)  /* 等待 tx_busy 清零 */
            ;
        UART_DATA = (unsigned char)buf[i];
    }
    return len;
}

/*
 * _read: 读取系统输入（裸机无键盘，返回 0 表示无数据）
 */
int _read(int fd, char *buf, int len)
{
    (void)fd;
    (void)buf;
    (void)len;
    return 0;
}

/*
 * _sbrk: 堆扩展，每次请求 incr 字节，返回原堆顶
 * 简单 bump 分配器：heap_end 向上增长，不超过栈
 */
void *_sbrk(int incr)
{
    char *prev;
    if (heap_end == (char *)0)
        heap_end = __bss_end;
    prev = heap_end;
    heap_end += incr;
    /* 简单检查：避免覆盖栈（栈顶约 0x14000） */
    if ((unsigned)heap_end > 0x00013F00)
        return (void *)-1;
    return (void *)prev;
}

/*
 * _close: 关闭文件描述符，裸机无文件系统，返回 -1 表示不支持
 */
int _close(int fd)
{
    (void)fd;
    return -1;
}

/*
 * _fstat: 获取文件状态，裸机无 stat，返回 0 表示“普通文件”
 */
int _fstat(int fd, void *st)
{
    (void)fd;
    (void)st;
    return 0;
}

/*
 * _isatty: 判断是否为终端，stdout/stderr 视为终端
 */
int _isatty(int fd)
{
    return (fd == 1 || fd == 2) ? 1 : 0;
}

/*
 * _lseek: 文件定位，裸机不支持
 */
int _lseek(int fd, int offset, int whence)
{
    (void)fd;
    (void)offset;
    (void)whence;
    return -1;
}

/*
 * _exit: 程序退出，写 tohost 供仿真器检测，然后死循环
 */
void _exit(int code)
{
    TOHOST = (code == 0) ? 1 : ((code << 1) | 1);
    while (1)
        ;
}

/*
 * putchar: 输出单个字符到 UART
 */
void putchar(int c)
{
    while (UART_STATUS & 1)
        ;
    UART_DATA = (unsigned char)c;
}

/*
 * puts: 输出字符串并换行
 */
void puts(const char *s)
{
    while (*s) {
        putchar(*s++);
    }
    putchar('\n');
}

/*
 * print_dec: 将无符号整数以十进制形式输出到 UART
 */
void print_dec(unsigned int val)
{
    char buf[12];
    int i = 0;
    if (val == 0) {
        putchar('0');
        return;
    }
    while (val > 0) {
        buf[i++] = '0' + (val % 10);
        val /= 10;
    }
    while (i > 0)
        putchar(buf[--i]);
}

/*
 * print_hex: 将无符号整数以十六进制形式输出（8 位，前导零）
 */
void print_hex(unsigned int val)
{
    const char hex[] = "0123456789abcdef";
    int i;
    putchar('0');
    putchar('x');
    for (i = 28; i >= 0; i -= 4)
        putchar(hex[(val >> i) & 0xF]);
}

/*
 * get_timer_value: 读取 64 位 mtime 计数值（单位：时钟周期）
 */
unsigned long long get_timer_value(void)
{
    unsigned int lo, hi;
    do {
        hi = TIMER_MTIME_HI;
        lo = TIMER_MTIME_LO;
    } while (hi != TIMER_MTIME_HI);  /* 防止读取时跨越进位 */
    return ((unsigned long long)hi << 32) | lo;
}
