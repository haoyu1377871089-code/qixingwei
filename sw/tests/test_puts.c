extern void putchar(int c);
extern void puts(const char *s);
extern void pass(void);

int main(void)
{
    puts("Hi");
    pass();
    __builtin_unreachable();
}
