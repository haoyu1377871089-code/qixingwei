`include "qxw_defines.vh"

// ================================================================
// M-mode CSR 寄存器模块
// ================================================================
// 实现 RISC-V Machine 模式的控制状态寄存器：
//   mstatus：全局中断使能（MIE=bit[3]）和中断前使能备份（MPIE=bit[7]）
//   mie/mip：中断使能与中断挂起（仅实现 MTIE/MTIP=bit[7]）
//   mtvec：异常入口地址（直接模式，不支持向量模式）
//   mepc：异常返回地址
//   mcause：异常原因编码（bit[31]=1 为中断）
//   mcycle/minstret：性能计数器（64 位，分高低 32 位访问）
//
// CSR 读写协议：
//   读端口为组合逻辑，写端口在时钟上升沿生效
//   CSRRW：新值直接写入 | CSRRS：按位置位 | CSRRC：按位清除
//   CSRRWI/CSRRSI/CSRRCI：同上但数据源为零扩展的 5 位立即数（zimm）
//
// Trap 入口时序：
//   ecall 或 timer_int_pending 触发 trap 信号
//   同拍保存 mepc=epc, mcause=原因码, MPIE=MIE, MIE=0（关中断）
//   PC 跳转到 mtvec，流水线冲刷
// ================================================================
module qxw_csr (
    input  wire              clk,
    input  wire              rst_n,

    // CSR 读端口（WB 阶段读取旧值写回寄存器堆）
    input  wire [11:0]       raddr,
    output reg  [`XLEN_BUS]  rdata,

    // CSR 写端口（WB 阶段写入）
    input  wire              we,
    input  wire [2:0]        wop,       // funct3: CSRRW/CSRRS/CSRRC/CSRRWI/CSRRSI/CSRRCI
    input  wire [11:0]       waddr,
    input  wire [`XLEN_BUS]  wdata,

    // 异常接口
    input  wire              ecall,     // ECALL 异常
    input  wire              mret,      // MRET 返回
    input  wire [`XLEN_BUS]  epc,       // 异常指令 PC
    input  wire              timer_irq, // Timer 中断

    // 输出
    output wire [`XLEN_BUS]  mtvec_o,   // 异常入口
    output wire [`XLEN_BUS]  mepc_o,    // MRET 返回地址
    output wire              trap,      // 进入异常
    output wire              retire     // 指令退休计数使能
);

    // CSR 寄存器声明
    // 注意：mstatus 仅实现 MIE(bit3) 和 MPIE(bit7)，其余位硬连线为 0
    reg [`XLEN_BUS] mstatus;
    // mie：中断使能寄存器，仅 MTIE(bit7) 有效
    reg [`XLEN_BUS] mie;
    // mtvec：异常入口向量地址，trap 时 PC 跳转到此地址
    reg [`XLEN_BUS] mtvec;
    // mepc：异常返回 PC，由硬件在 trap 入口时自动保存
    reg [`XLEN_BUS] mepc;
    // mcause：异常原因码，bit[31]=1 为中断，=0 为异常
    reg [`XLEN_BUS] mcause;
    // mtval：异常附加信息（当前简化实现中未使用）
    reg [`XLEN_BUS] mtval;
    // mip：中断挂起寄存器，MTIP(bit7) 由 timer_irq 硬件驱动，软件只读
    reg [`XLEN_BUS] mip;
    // mcycle：64 位周期计数器，每时钟周期递增
    reg [63:0]      mcycle;
    // minstret：64 位指令退休计数器
    reg [63:0]      minstret;

    // 将内部 CSR 寄存器值输出到端口，供 PC 寄存器使用
    assign mtvec_o = mtvec;
    assign mepc_o  = mepc;

    // Timer 中断判定：三个条件同时满足才挂起
    //   mstatus[3]（MIE）：全局中断使能
    //   mie[7]（MTIE）：Machine Timer 中断使能
    //   mip[7]（MTIP）：Timer 中断挂起（由 timer_irq 硬件信号设置）
    wire timer_int_pending = mstatus[3] & mie[7] & mip[7];

    // trap 触发条件：ECALL 同步异常或 Timer 中断异步挂起（任一成立即触发）
    assign trap = ecall | timer_int_pending;
    // retire 信号用于 minstret 计数，当前简化为每周期计一次
    assign retire = 1'b1;

    // ================================================================
    // CSR 读端口（组合逻辑多路选择）
    // ================================================================
    // 根据读地址 raddr 选择对应 CSR 寄存器的当前值
    // mcycle/minstret 为 64 位，通过 MCYCLE/MCYCLEH 分别访问低/高 32 位
    // 未定义地址返回 0，不会产生异常（简化实现）
    always @(*) begin
        case (raddr)
            `CSR_MSTATUS:  rdata = mstatus;
            `CSR_MIE:      rdata = mie;
            `CSR_MTVEC:    rdata = mtvec;
            `CSR_MEPC:     rdata = mepc;
            `CSR_MCAUSE:   rdata = mcause;
            `CSR_MTVAL:    rdata = mtval;
            `CSR_MIP:      rdata = mip;
            `CSR_MCYCLE:   rdata = mcycle[31:0];
            `CSR_MCYCLEH:  rdata = mcycle[63:32];
            `CSR_MINSTRET: rdata = minstret[31:0];
            `CSR_MINSTRETH:rdata = minstret[63:32];
            default:       rdata = 32'd0;
        endcase
    end

    // ================================================================
    // CSR 写入值计算（组合逻辑）
    // ================================================================
    // 先读出目标 CSR 的旧值，再根据操作类型计算新值
    // CSRRW/CSRRWI：直接替换（new = wdata）
    // CSRRS/CSRRSI：按位置位（new = old | wdata）
    // CSRRC/CSRRCI：按位清除（new = old & ~wdata）
    reg [`XLEN_BUS] csr_old_val;
    always @(*) begin
        case (waddr)
            `CSR_MSTATUS:  csr_old_val = mstatus;
            `CSR_MIE:      csr_old_val = mie;
            `CSR_MTVEC:    csr_old_val = mtvec;
            `CSR_MEPC:     csr_old_val = mepc;
            `CSR_MCAUSE:   csr_old_val = mcause;
            `CSR_MTVAL:    csr_old_val = mtval;
            `CSR_MIP:      csr_old_val = mip;
            default:       csr_old_val = 32'd0;
        endcase
    end

    reg [`XLEN_BUS] csr_new_val;
    always @(*) begin
        case (wop)
            `FUNCT3_CSRRW, `FUNCT3_CSRRWI:
                csr_new_val = wdata;
            `FUNCT3_CSRRS, `FUNCT3_CSRRSI:
                csr_new_val = csr_old_val | wdata;
            `FUNCT3_CSRRC, `FUNCT3_CSRRCI:
                csr_new_val = csr_old_val & ~wdata;
            default:
                csr_new_val = wdata;
        endcase
    end

    // ================================================================
    // CSR 时序写入逻辑
    // ================================================================
    // 写入优先级（同一拍只执行一个分支）：
    //   1. ecall：保存异常现场（mepc/mcause/mstatus），关全局中断
    //   2. timer_int_pending：同 ecall 流程，但 mcause 标记为中断（bit[31]=1）
    //   3. mret：恢复中断使能（MIE = MPIE, MPIE = 1）
    //   4. CSR 写指令：按操作类型更新目标 CSR
    // mcycle 每周期无条件自增，mip[7] 由硬件信号 timer_irq 实时更新
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus  <= 32'd0;
            mie      <= 32'd0;
            mtvec    <= 32'd0;
            mepc     <= 32'd0;
            mcause   <= 32'd0;
            mtval    <= 32'd0;
            mip      <= 32'd0;
            mcycle   <= 64'd0;
            minstret <= 64'd0;
        end else begin
            // mip[7]（MTIP）由硬件信号直接驱动，软件不可写
            // timer_irq 在 mtime >= mtimecmp 时拉高
            mip[7] <= timer_irq;

            // mcycle 每周期无条件递增，不受 stall 或 trap 影响
            mcycle <= mcycle + 64'd1;

            // ECALL 异常处理：保存异常现场
            // mepc 保存触发异常的指令 PC，用于 MRET 返回
            // mcause=11 表示 M-mode 环境调用（Environment call from M-mode）
            // MPIE 备份当前中断使能状态，然后关闭全局中断（MIE=0）
            if (ecall) begin
                mepc         <= epc;
                mcause       <= 32'd11;
                mstatus[7]   <= mstatus[3];
                mstatus[3]   <= 1'b0;
            end
            // Timer 中断处理：与 ECALL 流程类似
            // mcause 最高位为 1 表示中断（而非异常），低 31 位 =7 表示 Machine Timer
            else if (timer_int_pending) begin
                mepc         <= epc;
                mcause       <= {1'b1, 31'd7};
                mstatus[7]   <= mstatus[3];
                mstatus[3]   <= 1'b0;
            end
            // MRET 异常返回：恢复中断使能
            // MIE 恢复为 trap 前的值（从 MPIE 取回），MPIE 置 1
            else if (mret) begin
                mstatus[3]   <= mstatus[7];
                mstatus[7]   <= 1'b1;
            end
            // CSR 写指令（最低优先级，确保不与 trap 冲突）
            else if (we) begin
                case (waddr)
                    `CSR_MSTATUS:  mstatus <= csr_new_val;
                    `CSR_MIE:      mie     <= csr_new_val;
                    `CSR_MTVEC:    mtvec   <= csr_new_val;
                    `CSR_MEPC:     mepc    <= csr_new_val;
                    `CSR_MCAUSE:   mcause  <= csr_new_val;
                    `CSR_MTVAL:    mtval   <= csr_new_val;
                    default: ;
                endcase
            end

            // 指令退休计数（minstret）：每周期递增
            // 当前简化实现为每周期计一次，精确实现需配合 valid 信号
            if (retire)
                minstret <= minstret + 64'd1;
        end
    end

endmodule
