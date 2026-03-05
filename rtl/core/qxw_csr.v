`include "qxw_defines.vh"

// M-mode 基础 CSR 寄存器
// 支持：mstatus, mie, mtvec, mepc, mcause, mtval, mip,
//       mcycle/mcycleh, minstret/minstreth
// CSR 操作：CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI
// 异常：ECALL / MRET
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

    // CSR 寄存器
    reg [`XLEN_BUS] mstatus;    // 只实现 MIE(3) 和 MPIE(7)
    reg [`XLEN_BUS] mie;        // MTIE(7)
    reg [`XLEN_BUS] mtvec;
    reg [`XLEN_BUS] mepc;
    reg [`XLEN_BUS] mcause;
    reg [`XLEN_BUS] mtval;
    reg [`XLEN_BUS] mip;        // MTIP(7) -- 由硬件设置
    reg [63:0]      mcycle;
    reg [63:0]      minstret;

    assign mtvec_o = mtvec;
    assign mepc_o  = mepc;

    // Timer 中断使能且 pending
    wire timer_int_pending = mstatus[3] & mie[7] & mip[7];

    // trap 条件：ECALL 或 timer 中断
    assign trap = ecall | timer_int_pending;
    assign retire = 1'b1;  // 简化：每周期计一次

    // ================================================================
    // CSR 读
    // ================================================================
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
    // CSR 写入值计算
    // ================================================================
    reg [`XLEN_BUS] csr_old_val;  // 被写 CSR 的旧值
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
    // CSR 写入
    // ================================================================
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
            // Timer 中断 pending 位由硬件设置
            mip[7] <= timer_irq;

            // Cycle 计数器
            mcycle <= mcycle + 64'd1;

            // ECALL 异常处理
            if (ecall) begin
                mepc         <= epc;
                mcause       <= 32'd11;  // Environment call from M-mode
                mstatus[7]   <= mstatus[3];  // MPIE = MIE
                mstatus[3]   <= 1'b0;         // MIE = 0
            end
            // Timer 中断处理
            else if (timer_int_pending) begin
                mepc         <= epc;
                mcause       <= {1'b1, 31'd7};  // Machine timer interrupt
                mstatus[7]   <= mstatus[3];
                mstatus[3]   <= 1'b0;
            end
            // MRET
            else if (mret) begin
                mstatus[3]   <= mstatus[7];  // MIE = MPIE
                mstatus[7]   <= 1'b1;         // MPIE = 1
            end
            // CSR 写指令
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

            // 指令退休计数
            if (retire)
                minstret <= minstret + 64'd1;
        end
    end

endmodule
