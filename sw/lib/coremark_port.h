/*
 * QXW RISC-V CoreMark 移植层头文件
 */

#ifndef COREMARK_PORT_H
#define COREMARK_PORT_H

#define ITERATIONS 100
#define CLOCKS_PER_SEC 50000000

void portable_init(void);
unsigned int barebones_clock(void);
unsigned long long get_timer_value(void);
int ee_printf(const char *fmt, ...);

#endif
