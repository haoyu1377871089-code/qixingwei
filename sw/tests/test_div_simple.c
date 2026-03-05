extern void putchar(int c);
extern void print_dec(unsigned int val);
extern void pass(void);
extern void fail(int test_id);

int main(void)
{
    volatile unsigned int a = 42;
    volatile unsigned int b = 10;
    unsigned int q = a / b;
    unsigned int r = a % b;

    if (q == 4 && r == 2) {
        putchar('O');
        putchar('K');
        putchar('\n');
        pass();
    } else {
        putchar('E');
        putchar('R');
        putchar('\n');
        fail(1);
    }
    __builtin_unreachable();
}
