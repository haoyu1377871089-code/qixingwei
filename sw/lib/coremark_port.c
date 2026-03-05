/*
 * QXW RISC-V CoreMark 移植层
 * 提供 ee_printf、barebones_clock、portable_init 等接口，便于集成 CoreMark 或类似基准测试
 */

#include <stdarg.h>

/* 迭代次数，可根据 ROM 空间和测试时长调整 */
#define ITERATIONS 100

/* 系统时钟频率（Hz），与 SoC 主频一致 */
#define CLOCKS_PER_SEC 50000000

/* 种子值，用于可重复的随机数序列（CoreMark 兼容） */
#define SEED1 0
#define SEED2 0
#define SEED3 0

/* 外部 vprintf 实现，用于可变参数透传 */
extern int vprintf(const char *fmt, va_list ap);

/* 外部定时器读取，返回 64 位周期计数 */
extern unsigned long long get_timer_value(void);

/*
 * ee_printf: CoreMark 要求的打印接口，重定向到我们的 printf/vprintf
 */
int ee_printf(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    int ret = vprintf(fmt, ap);
    va_end(ap);
    return ret;
}

/*
 * barebones_clock: 返回当前时钟周期数（低 32 位）
 * CoreMark 用此函数测量执行时间
 */
unsigned int barebones_clock(void)
{
    return (unsigned int)get_timer_value();
}

/*
 * portable_init: 移植层初始化，裸机环境下可为空
 */
void portable_init(void)
{
}
