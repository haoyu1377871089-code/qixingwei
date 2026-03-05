/*
 * QXW RISC-V 简化 CoreMark 基准测试
 * 包含：4x4 矩阵乘法、链表操作、状态机处理
 * 通过 UART 输出结果，写 tohost 供仿真检测
 */

#include "coremark_port.h"

#define TOHOST_ADDR 0x00013FF8
#define TOHOST (*(volatile unsigned int *)TOHOST_ADDR)

/* 4x4 矩阵乘法：C = A * B，典型数值计算负载 */
static void matrix_mul_4x4(const int A[4][4], const int B[4][4], int C[4][4])
{
    int i, j, k;
    for (i = 0; i < 4; i++)
        for (j = 0; j < 4; j++) {
            C[i][j] = 0;
            for (k = 0; k < 4; k++)
                C[i][j] += A[i][k] * B[k][j];
        }
}

/* 链表节点 */
typedef struct list_node {
    struct list_node *next;
    unsigned int val;
} list_node_t;

/* 简化链表：遍历并累加（使用静态节点数组避免 malloc，节省 ROM） */
#define LIST_SIZE 16
static list_node_t nodes[LIST_SIZE];

static unsigned int list_sum(void)
{
    unsigned int sum = 0;
    int i;
    /* 构建链表：节点 0->1->2->...->15->NULL */
    for (i = 0; i < LIST_SIZE - 1; i++)
        nodes[i].next = &nodes[i + 1];
    nodes[LIST_SIZE - 1].next = 0;
    for (i = 0; i < LIST_SIZE; i++)
        nodes[i].val = i + 1;
    /* 遍历链表累加，模拟指针追逐 */
    list_node_t *p = nodes;
    while (p) {
        sum += p->val;
        p = p->next;
    }
    return sum;
}

/* 简单状态机：3 状态循环 */
typedef enum { S0, S1, S2 } state_t;

/* 三状态循环状态机：S0->S1->S2->S0，模拟控制流 */
static unsigned int state_machine_run(int iterations)
{
    state_t s = S0;
    unsigned int count = 0;
    int i;
    for (i = 0; i < iterations; i++) {
        switch (s) {
        case S0: s = S1; count++; break;
        case S1: s = S2; count++; break;
        case S2: s = S0; count++; break;
        }
    }
    return count;
}

int main(void)
{
    portable_init();

    /* 4x4 矩阵乘法：A 为一般矩阵，B 为单位矩阵，结果 C=A */
    int A[4][4] = {{1,2,3,4},{5,6,7,8},{9,10,11,12},{13,14,15,16}};
    int B[4][4] = {{1,0,0,0},{0,1,0,0},{0,0,1,0},{0,0,0,1}};
    int C[4][4];
    int i;

    /* 读取定时器，测量矩阵运算耗时 */
    unsigned long long t0 = get_timer_value();
    for (i = 0; i < ITERATIONS; i++)
        matrix_mul_4x4(A, B, C);
    ee_printf("CoreMark matrix\n");
    ee_printf("C[0][0]=%d\n", C[0][0]);

    /* 链表遍历 */
    unsigned int list_sum_val = list_sum();
    ee_printf("list sum=%u\n", list_sum_val);

    /* 状态机 */
    unsigned int sm_count = state_machine_run(ITERATIONS * 10);
    ee_printf("state machine count=%u\n", sm_count);

    /* 总耗时 = 矩阵运算 + 链表 + 状态机 */
    unsigned long long t2 = get_timer_value();
    unsigned long long total_cycles = t2 - t0;

    ee_printf("iterations=%d\n", ITERATIONS);
    ee_printf("total cycles=%u\n", (unsigned int)total_cycles);

    /* 通过 pass() 写 tohost（避免流水线时序问题） */
    extern void pass(void);
    pass();
    __builtin_unreachable();
}
