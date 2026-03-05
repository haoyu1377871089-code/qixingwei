extern int printf(const char *fmt, ...);
extern void pass(void);

int main(void)
{
    printf("Hi\n");
    pass();
    __builtin_unreachable();
}
