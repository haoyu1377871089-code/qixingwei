#define TOHOST (*(volatile unsigned int *)0x00013FF8)

extern int printf(const char *fmt, ...);
extern void pass(void);

int main(void)
{
    printf("Hello RISC-V!\n");
    printf("num=%d\n", 42);
    pass();
    __builtin_unreachable();
}
