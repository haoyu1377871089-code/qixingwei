# QXW RISC-V 子模块交互信号列表

本文档列出所有 RTL 模块的端口信号，格式为：信号名 | 方向 | 位宽 | 描述。

---

## 1. qxw_pc_reg

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 时钟 |
| rst_n | input | 1 | 异步复位（低有效） |
| stall | input | 1 | 流水线暂停 |
| branch_taken | input | 1 | 分支/跳转实际发生 |
| branch_target | input | 32 | 分支/跳转目标地址 |
| pred_taken | input | 1 | BPU 预测跳转 |
| pred_target | input | 32 | BPU 预测目标 |
| flush | input | 1 | 冲刷（预测错误） |
| flush_target | input | 32 | 冲刷后恢复的 PC |
| trap | input | 1 | 异常/中断 |
| trap_target | input | 32 | mtvec 异常入口 |
| mret | input | 1 | MRET 指令 |
| mepc | input | 32 | mepc 返回地址 |
| pc | output | 32 | 当前程序计数器 |
| next_pc | output | 32 | 下一周期 PC（组合逻辑） |

---

## 2. qxw_if_stage

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 时钟 |
| rst_n | input | 1 | 异步复位 |
| stall | input | 1 | 流水线暂停 |
| flush | input | 1 | 冲刷 |
| pc | input | 32 | 来自 PC 寄存器的当前 PC |
| imem_addr | output | 32 | 指令存储器地址 |
| imem_rdata | input | 32 | 指令存储器读数据 |
| bpu_idx | output | 8 | 分支预测器索引 (PC[9:2]) |
| bpu_pred_taken | input | 1 | BPU 预测是否跳转 |
| bpu_pred_target | input | 32 | BPU 预测目标（内部计算） |
| if_id_pc | output | 32 | IF/ID 级间：PC |
| if_id_inst | output | 32 | IF/ID 级间：指令 |
| if_id_pred_taken | output | 1 | IF/ID 级间：预测跳转 |
| if_id_pred_target | output | 32 | IF/ID 级间：预测目标 |
| if_id_valid | output | 1 | IF/ID 级间：有效 |

---

## 3. qxw_id_stage

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 时钟 |
| rst_n | input | 1 | 异步复位 |
| stall | input | 1 | 流水线暂停 |
| flush | input | 1 | 冲刷 |
| if_id_pc | input | 32 | IF/ID 级间：PC |
| if_id_inst | input | 32 | IF/ID 级间：指令 |
| if_id_pred_taken | input | 1 | IF/ID 级间：预测跳转 |
| if_id_pred_target | input | 32 | IF/ID 级间：预测目标 |
| if_id_valid | input | 1 | IF/ID 级间：有效 |
| rs1_addr | output | 5 | 寄存器堆读地址 1 |
| rs2_addr | output | 5 | 寄存器堆读地址 2 |
| rs1_data | input | 32 | 寄存器堆读数据 1 |
| rs2_data | input | 32 | 寄存器堆读数据 2 |
| id_ex_pc | output | 32 | ID/EX 级间：PC |
| id_ex_rs1_data | output | 32 | ID/EX 级间：rs1 数据 |
| id_ex_rs2_data | output | 32 | ID/EX 级间：rs2 数据 |
| id_ex_imm | output | 32 | ID/EX 级间：立即数 |
| id_ex_rd | output | 5 | ID/EX 级间：目标寄存器 |
| id_ex_rs1 | output | 5 | ID/EX 级间：rs1 地址 |
| id_ex_rs2 | output | 5 | ID/EX 级间：rs2 地址 |
| id_ex_alu_op | output | 4 | ID/EX 级间：ALU 操作码 |
| id_ex_alu_src_a | output | 1 | ID/EX 级间：ALU 源 A (0=rs1, 1=pc) |
| id_ex_alu_src_b | output | 1 | ID/EX 级间：ALU 源 B (0=rs2, 1=imm) |
| id_ex_reg_we | output | 1 | ID/EX 级间：寄存器写使能 |
| id_ex_mem_re | output | 1 | ID/EX 级间：存储器读使能 |
| id_ex_mem_we | output | 1 | ID/EX 级间：存储器写使能 |
| id_ex_funct3 | output | 3 | ID/EX 级间：funct3 |
| id_ex_wb_sel | output | 2 | ID/EX 级间：写回选择 |
| id_ex_br_type | output | 3 | ID/EX 级间：分支类型 |
| id_ex_is_jalr | output | 1 | ID/EX 级间：是否 JALR |
| id_ex_is_muldiv | output | 1 | ID/EX 级间：是否乘除法 |
| id_ex_md_op | output | 3 | ID/EX 级间：乘除法操作码 |
| id_ex_csr_we | output | 1 | ID/EX 级间：CSR 写使能 |
| id_ex_csr_op | output | 3 | ID/EX 级间：CSR 操作类型 |
| id_ex_csr_addr | output | 12 | ID/EX 级间：CSR 地址 |
| id_ex_ecall | output | 1 | ID/EX 级间：ECALL |
| id_ex_ebreak | output | 1 | ID/EX 级间：EBREAK |
| id_ex_mret | output | 1 | ID/EX 级间：MRET |
| id_ex_pred_taken | output | 1 | ID/EX 级间：预测跳转 |
| id_ex_pred_target | output | 32 | ID/EX 级间：预测目标 |
| id_ex_valid | output | 1 | ID/EX 级间：有效 |

---

## 4. qxw_ex_stage

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 时钟 |
| rst_n | input | 1 | 异步复位 |
| stall | input | 1 | 流水线暂停 |
| flush | input | 1 | 冲刷 |
| id_ex_pc | input | 32 | ID/EX 级间：PC |
| id_ex_rs1_data | input | 32 | ID/EX 级间：rs1 数据 |
| id_ex_rs2_data | input | 32 | ID/EX 级间：rs2 数据 |
| id_ex_imm | input | 32 | ID/EX 级间：立即数 |
| id_ex_rd | input | 5 | ID/EX 级间：目标寄存器 |
| id_ex_rs1 | input | 5 | ID/EX 级间：rs1 地址 |
| id_ex_rs2 | input | 5 | ID/EX 级间：rs2 地址 |
| id_ex_alu_op | input | 4 | ID/EX 级间：ALU 操作码 |
| id_ex_alu_src_a | input | 1 | ID/EX 级间：ALU 源 A |
| id_ex_alu_src_b | input | 1 | ID/EX 级间：ALU 源 B |
| id_ex_reg_we | input | 1 | ID/EX 级间：寄存器写使能 |
| id_ex_mem_re | input | 1 | ID/EX 级间：存储器读使能 |
| id_ex_mem_we | input | 1 | ID/EX 级间：存储器写使能 |
| id_ex_funct3 | input | 3 | ID/EX 级间：funct3 |
| id_ex_wb_sel | input | 2 | ID/EX 级间：写回选择 |
| id_ex_br_type | input | 3 | ID/EX 级间：分支类型 |
| id_ex_is_jalr | input | 1 | ID/EX 级间：是否 JALR |
| id_ex_is_muldiv | input | 1 | ID/EX 级间：是否乘除法 |
| id_ex_md_op | input | 3 | ID/EX 级间：乘除法操作码 |
| id_ex_csr_we | input | 1 | ID/EX 级间：CSR 写使能 |
| id_ex_csr_op | input | 3 | ID/EX 级间：CSR 操作类型 |
| id_ex_csr_addr | input | 12 | ID/EX 级间：CSR 地址 |
| id_ex_ecall | input | 1 | ID/EX 级间：ECALL |
| id_ex_ebreak | input | 1 | ID/EX 级间：EBREAK |
| id_ex_mret | input | 1 | ID/EX 级间：MRET |
| id_ex_pred_taken | input | 1 | ID/EX 级间：预测跳转 |
| id_ex_pred_target | input | 32 | ID/EX 级间：预测目标 |
| id_ex_valid | input | 1 | ID/EX 级间：有效 |
| fwd_rs1_data | input | 32 | 转发后的 rs1 数据 |
| fwd_rs2_data | input | 32 | 转发后的 rs2 数据 |
| alu_op | output | 4 | ALU 操作码 |
| alu_op_a | output | 32 | ALU 操作数 A |
| alu_op_b | output | 32 | ALU 操作数 B |
| alu_result | input | 32 | ALU 结果 |
| md_start | output | 1 | 乘除法启动 |
| md_op | output | 3 | 乘除法操作码 |
| md_op_a | output | 32 | 乘除法操作数 A |
| md_op_b | output | 32 | 乘除法操作数 B |
| md_result | input | 32 | 乘除法结果 |
| md_busy | input | 1 | 乘除法忙 |
| md_valid | input | 1 | 乘除法有效 |
| branch_taken | output | 1 | 分支实际发生 |
| branch_target | output | 32 | 分支目标地址 |
| branch_mispredict | output | 1 | 分支预测错误 |
| ex_mem_pc | output | 32 | EX/MEM 级间：PC |
| ex_mem_alu_result | output | 32 | EX/MEM 级间：ALU 结果 |
| ex_mem_rs2_data | output | 32 | EX/MEM 级间：rs2 数据 |
| ex_mem_rd | output | 5 | EX/MEM 级间：目标寄存器 |
| ex_mem_reg_we | output | 1 | EX/MEM 级间：寄存器写使能 |
| ex_mem_mem_re | output | 1 | EX/MEM 级间：存储器读使能 |
| ex_mem_mem_we | output | 1 | EX/MEM 级间：存储器写使能 |
| ex_mem_funct3 | output | 3 | EX/MEM 级间：funct3 |
| ex_mem_wb_sel | output | 2 | EX/MEM 级间：写回选择 |
| ex_mem_csr_we | output | 1 | EX/MEM 级间：CSR 写使能 |
| ex_mem_csr_op | output | 3 | EX/MEM 级间：CSR 操作类型 |
| ex_mem_csr_addr | output | 12 | EX/MEM 级间：CSR 地址 |
| ex_mem_csr_wdata | output | 32 | EX/MEM 级间：CSR 写数据 |
| ex_mem_valid | output | 1 | EX/MEM 级间：有效 |

---

## 5. qxw_mem_stage

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 时钟 |
| rst_n | input | 1 | 异步复位 |
| stall | input | 1 | 流水线暂停 |
| ex_mem_pc | input | 32 | EX/MEM 级间：PC |
| ex_mem_alu_result | input | 32 | EX/MEM 级间：ALU 结果（访存地址） |
| ex_mem_rs2_data | input | 32 | EX/MEM 级间：rs2 数据（Store 数据） |
| ex_mem_rd | input | 5 | EX/MEM 级间：目标寄存器 |
| ex_mem_reg_we | input | 1 | EX/MEM 级间：寄存器写使能 |
| ex_mem_mem_re | input | 1 | EX/MEM 级间：存储器读使能 |
| ex_mem_mem_we | input | 1 | EX/MEM 级间：存储器写使能 |
| ex_mem_funct3 | input | 3 | EX/MEM 级间：funct3 |
| ex_mem_wb_sel | input | 2 | EX/MEM 级间：写回选择 |
| ex_mem_csr_we | input | 1 | EX/MEM 级间：CSR 写使能 |
| ex_mem_csr_op | input | 3 | EX/MEM 级间：CSR 操作类型 |
| ex_mem_csr_addr | input | 12 | EX/MEM 级间：CSR 地址 |
| ex_mem_csr_wdata | input | 32 | EX/MEM 级间：CSR 写数据 |
| ex_mem_valid | input | 1 | EX/MEM 级间：有效 |
| dmem_en | output | 1 | 数据存储器使能 |
| dmem_we | output | 4 | 数据存储器字节写使能 |
| dmem_addr | output | 32 | 数据存储器地址 |
| dmem_wdata | output | 32 | 数据存储器写数据 |
| dmem_rdata | input | 32 | 数据存储器读数据 |
| mem_wb_pc | output | 32 | MEM/WB 级间：PC |
| mem_wb_alu_result | output | 32 | MEM/WB 级间：ALU 结果 |
| mem_wb_mem_data | output | 32 | MEM/WB 级间：Load 数据 |
| mem_wb_rd | output | 5 | MEM/WB 级间：目标寄存器 |
| mem_wb_reg_we | output | 1 | MEM/WB 级间：寄存器写使能 |
| mem_wb_wb_sel | output | 2 | MEM/WB 级间：写回选择 |
| mem_wb_csr_we | output | 1 | MEM/WB 级间：CSR 写使能 |
| mem_wb_csr_op | output | 3 | MEM/WB 级间：CSR 操作类型 |
| mem_wb_csr_addr | output | 12 | MEM/WB 级间：CSR 地址 |
| mem_wb_csr_wdata | output | 32 | MEM/WB 级间：CSR 写数据 |
| mem_wb_valid | output | 1 | MEM/WB 级间：有效 |

---

## 6. qxw_wb_stage

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| mem_wb_pc | input | 32 | MEM/WB 级间：PC |
| mem_wb_alu_result | input | 32 | MEM/WB 级间：ALU 结果 |
| mem_wb_mem_data | input | 32 | MEM/WB 级间：Load 数据 |
| mem_wb_rd | input | 5 | MEM/WB 级间：目标寄存器 |
| mem_wb_reg_we | input | 1 | MEM/WB 级间：寄存器写使能 |
| mem_wb_wb_sel | input | 2 | MEM/WB 级间：写回选择 |
| mem_wb_valid | input | 1 | MEM/WB 级间：有效 |
| csr_rdata | input | 32 | CSR 读数据 |
| rf_we | output | 1 | 寄存器堆写使能 |
| rf_wa | output | 5 | 寄存器堆写地址 |
| rf_wd | output | 32 | 寄存器堆写数据 |

---

## 7. qxw_regfile

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 时钟 |
| rst_n | input | 1 | 异步复位 |
| ra1 | input | 5 | 读地址 1 |
| rd1 | output | 32 | 读数据 1 |
| ra2 | input | 5 | 读地址 2 |
| rd2 | output | 32 | 读数据 2 |
| we | input | 1 | 写使能 |
| wa | input | 5 | 写地址 |
| wd | input | 32 | 写数据 |

---

## 8. qxw_alu

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| alu_op | input | 4 | ALU 操作码 |
| op_a | input | 32 | 操作数 A |
| op_b | input | 32 | 操作数 B |
| result | output | 32 | 运算结果 |
| zero | output | 1 | 结果为零标志 |

---

## 9. qxw_muldiv

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 时钟 |
| rst_n | input | 1 | 异步复位 |
| start | input | 1 | 启动乘除法 |
| md_op | input | 3 | 乘除法操作码 |
| op_a | input | 32 | 操作数 A |
| op_b | input | 32 | 操作数 B |
| result | output | 32 | 运算结果 |
| busy | output | 1 | 忙标志（除法进行中） |
| valid | output | 1 | 结果有效 |

---

## 10. qxw_forwarding

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| id_ex_rs1 | input | 5 | EX 阶段 rs1 地址 |
| id_ex_rs2 | input | 5 | EX 阶段 rs2 地址 |
| id_ex_rs1_data | input | 32 | EX 阶段 rs1 原始数据 |
| id_ex_rs2_data | input | 32 | EX 阶段 rs2 原始数据 |
| ex_mem_rd | input | 5 | EX/MEM 目标寄存器 |
| ex_mem_reg_we | input | 1 | EX/MEM 寄存器写使能 |
| ex_mem_alu_result | input | 32 | EX/MEM ALU 结果 |
| ex_mem_valid | input | 1 | EX/MEM 有效 |
| mem_wb_rd | input | 5 | MEM/WB 目标寄存器 |
| mem_wb_reg_we | input | 1 | MEM/WB 寄存器写使能 |
| mem_wb_wd | input | 32 | MEM/WB 最终写回数据 |
| mem_wb_valid | input | 1 | MEM/WB 有效 |
| fwd_rs1_data | output | 32 | 转发后的 rs1 数据 |
| fwd_rs2_data | output | 32 | 转发后的 rs2 数据 |
| fwd_sel_a | output | 2 | rs1 转发选择 (00=无, 01=EX, 10=WB) |
| fwd_sel_b | output | 2 | rs2 转发选择 (00=无, 01=EX, 10=WB) |

---

## 11. qxw_hazard_ctrl

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| id_rs1 | input | 5 | ID 阶段 rs1 地址 |
| id_rs2 | input | 5 | ID 阶段 rs2 地址 |
| id_ex_rd | input | 5 | EX 阶段目标寄存器 |
| id_ex_mem_re | input | 1 | EX 阶段 Load 使能 |
| id_ex_valid | input | 1 | EX 阶段有效 |
| branch_mispredict | input | 1 | 分支预测错误 |
| md_busy | input | 1 | 乘除法忙 |
| trap | input | 1 | 异常/中断 |
| mret | input | 1 | MRET |
| stall_if | output | 1 | 暂停 IF 阶段 |
| stall_id | output | 1 | 暂停 ID 阶段 |
| stall_ex | output | 1 | 暂停 EX 阶段 |
| stall_mem | output | 1 | 暂停 MEM 阶段 |
| flush_if_id | output | 1 | 冲刷 IF/ID 级间寄存器 |
| flush_id_ex | output | 1 | 冲刷 ID/EX 级间寄存器 |
| flush_ex_mem | output | 1 | 冲刷 EX/MEM 级间寄存器 |

---

## 12. qxw_branch_pred

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 时钟 |
| rst_n | input | 1 | 异步复位 |
| pred_idx | input | 8 | 预测索引 (PC[9:2]) |
| pred_taken | output | 1 | 预测是否跳转 |
| update_en | input | 1 | 更新使能 |
| update_idx | input | 8 | 更新索引 |
| update_taken | input | 1 | 实际是否跳转 |

---

## 13. qxw_csr

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 时钟 |
| rst_n | input | 1 | 异步复位 |
| raddr | input | 12 | CSR 读地址 |
| rdata | output | 32 | CSR 读数据 |
| we | input | 1 | CSR 写使能 |
| wop | input | 3 | CSR 操作类型 (funct3) |
| waddr | input | 12 | CSR 写地址 |
| wdata | input | 32 | CSR 写数据 |
| ecall | input | 1 | ECALL 异常 |
| mret | input | 1 | MRET 返回 |
| epc | input | 32 | 异常指令 PC |
| timer_irq | input | 1 | Timer 中断 |
| mtvec_o | output | 32 | 异常入口 mtvec |
| mepc_o | output | 32 | MRET 返回地址 mepc |
| trap | output | 1 | 进入异常 |
| retire | output | 1 | 指令退休计数使能 |

---

## 14. qxw_cpu_top

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 时钟 |
| rst_n | input | 1 | 异步复位 |
| imem_addr | output | 32 | 指令存储器地址 |
| imem_rdata | input | 32 | 指令存储器读数据 |
| dmem_en | output | 1 | 数据存储器使能 |
| dmem_we | output | 4 | 数据存储器字节写使能 |
| dmem_addr | output | 32 | 数据存储器地址 |
| dmem_wdata | output | 32 | 数据存储器写数据 |
| dmem_rdata | input | 32 | 数据存储器读数据 |
| timer_irq | input | 1 | Timer 中断 |

---

## 15. qxw_bus

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| cpu_dmem_en | input | 1 | CPU 数据存储器使能 |
| cpu_dmem_we | input | 4 | CPU 数据存储器字节写使能 |
| cpu_dmem_addr | input | 32 | CPU 数据存储器地址 |
| cpu_dmem_wdata | input | 32 | CPU 数据存储器写数据 |
| cpu_dmem_rdata | output | 32 | CPU 数据存储器读数据 |
| ram_en | output | 1 | 数据 RAM 使能 |
| ram_we | output | 4 | 数据 RAM 字节写使能 |
| ram_addr | output | 32 | 数据 RAM 地址 |
| ram_wdata | output | 32 | 数据 RAM 写数据 |
| ram_rdata | input | 32 | 数据 RAM 读数据 |
| uart_en | output | 1 | UART 使能 |
| uart_we | output | 1 | UART 写使能 |
| uart_addr | output | 8 | UART 地址 |
| uart_wdata | output | 32 | UART 写数据 |
| uart_rdata | input | 32 | UART 读数据 |
| timer_en | output | 1 | Timer 使能 |
| timer_we | output | 1 | Timer 写使能 |
| timer_addr | output | 8 | Timer 地址 |
| timer_wdata | output | 32 | Timer 写数据 |
| timer_rdata | input | 32 | Timer 读数据 |

---

## 16. qxw_uart

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 时钟 |
| rst_n | input | 1 | 异步复位 |
| en | input | 1 | 总线使能 |
| we | input | 1 | 写使能 |
| addr | input | 8 | 寄存器地址 |
| wdata | input | 32 | 写数据 |
| rdata | output | 32 | 读数据 |
| uart_tx | output | 1 | UART 发送引脚 |

---

## 17. qxw_timer

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 时钟 |
| rst_n | input | 1 | 异步复位 |
| en | input | 1 | 总线使能 |
| we | input | 1 | 写使能 |
| addr | input | 8 | 寄存器地址 |
| wdata | input | 32 | 写数据 |
| rdata | output | 32 | 读数据 |
| timer_irq | output | 1 | 定时器中断 |

---

## 18. qxw_imem

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 时钟 |
| addr | input | 32 | 读地址 |
| rdata | output | 32 | 读数据 |

---

## 19. qxw_dmem

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 时钟 |
| en | input | 1 | 使能 |
| we | input | 4 | 字节写使能 |
| addr | input | 32 | 地址 |
| wdata | input | 32 | 写数据 |
| rdata | output | 32 | 读数据 |

---

## 20. qxw_soc_top

| 信号名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| clk | input | 1 | 时钟 |
| rst_n | input | 1 | 异步复位 |
| uart_tx | output | 1 | UART 发送 |
| led | output | 4 | LED 输出 |

**参数**：`IMEM_INIT_FILE`（默认 "firmware.hex"）
