/*
 * QXW RISC-V 最小化 printf 实现
 * 支持 %d, %u, %x, %s, %c，不含浮点，代码体积小以适配 16KB ROM
 */

#include <stdarg.h>

/* 外部声明：单字符输出，由 syscalls.c 提供 */
extern void putchar(int c);

/*
 * 将无符号整数转为十进制字符串，写入 buf，返回写入长度
 * 用于 %d 和 %u 的格式化
 */
static int utoa_dec(char *buf, unsigned int val, int is_signed)
{
    int i = 0;
    if (is_signed && (int)val < 0) {
        buf[i++] = '-';
        val = (unsigned int)(-(int)val);
    }
    if (val == 0) {
        buf[i++] = '0';
        return i;
    }
    /* 先逆序写入数字 */
    int start = i;
    while (val > 0) {
        buf[i++] = '0' + (val % 10);
        val /= 10;
    }
    /* 反转数字部分 */
    int j;
    for (j = start; j < (start + i) / 2; j++) {
        char t = buf[j];
        buf[j] = buf[i - 1 - (j - start)];
        buf[i - 1 - (j - start)] = t;
    }
    return i;
}

/*
 * 将无符号整数转为十六进制字符串，写入 buf，返回写入长度
 * 用于 %x 的格式化
 */
static int utoa_hex(char *buf, unsigned int val)
{
    const char hex[] = "0123456789abcdef";
    int i = 0;
    if (val == 0) {
        buf[i++] = '0';
        return i;
    }
    /* 从高位到低位 */
    int started = 0;
    int j;
    for (j = 28; j >= 0; j -= 4) {
        int nibble = (val >> j) & 0xF;
        if (nibble != 0 || started) {
            buf[i++] = hex[nibble];
            started = 1;
        }
    }
    if (i == 0)
        buf[i++] = '0';
    return i;
}

/*
 * vprintf：接受 va_list 的 printf 变体，供 ee_printf 等封装调用
 */
static int vprintf_impl(const char *fmt, va_list ap)
{
    const char *p = fmt;
    int count = 0;
    char buf[16];

    while (*p) {
        if (*p != '%') {
            putchar(*p);
            count++;
            p++;
            continue;
        }
        p++;
        /* 使用 if-else 链代替 switch，避免编译器生成跳转表
         * （跳转表存放在 .rodata → .data，Harvard 架构下
         *  从 RAM 加载的代码地址可能导致间接跳转异常） */
        {
            char ch = *p;
            if (ch == 'c') {
                int c = va_arg(ap, int);
                putchar(c & 0xFF);
                count++;
            } else if (ch == 's') {
                const char *s = va_arg(ap, const char *);
                if (!s) s = "(null)";
                while (*s) { putchar(*s++); count++; }
            } else if (ch == 'd') {
                int val = va_arg(ap, int);
                int n = utoa_dec(buf, (unsigned int)val, 1);
                int i;
                for (i = 0; i < n; i++) { putchar(buf[i]); count++; }
            } else if (ch == 'u') {
                unsigned int val = va_arg(ap, unsigned int);
                int n = utoa_dec(buf, val, 0);
                int i;
                for (i = 0; i < n; i++) { putchar(buf[i]); count++; }
            } else if (ch == 'x') {
                unsigned int val = va_arg(ap, unsigned int);
                int n = utoa_hex(buf, val);
                int i;
                for (i = 0; i < n; i++) { putchar(buf[i]); count++; }
            } else if (ch == '%') {
                putchar('%');
                count++;
            } else {
                putchar('%');
                putchar(ch);
                count += 2;
            }
        }
        p++;
    }
    return count;
}

/*
 * 最小化 printf：支持 %d, %u, %x, %s, %c
 * 通过 va_arg 解析可变参数，调用 putchar 输出
 */
int printf(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    int ret = vprintf_impl(fmt, ap);
    va_end(ap);
    return ret;
}

/*
 * vprintf：可变参数列表版本，供 ee_printf 等使用
 */
int vprintf(const char *fmt, va_list ap)
{
    return vprintf_impl(fmt, ap);
}
