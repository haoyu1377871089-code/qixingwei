## ============================================================================
## ALINX AX7020 约束文件（XC7Z020CLG400-2）
## ============================================================================

## ---------- 系统时钟 50MHz ----------
set_property PACKAGE_PIN N18 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 20.000 -name sys_clk [get_ports clk]

## ---------- 复位按钮（Active Low, PL KEY1） ----------
set_property PACKAGE_PIN P16 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

## ---------- UART ----------
## PL UART TX -> USB-UART RXD
set_property PACKAGE_PIN K14 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

## ---------- LED ----------
set_property PACKAGE_PIN M14 [get_ports {led[0]}]
set_property PACKAGE_PIN M15 [get_ports {led[1]}]
set_property PACKAGE_PIN K16 [get_ports {led[2]}]
set_property PACKAGE_PIN J16 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

## ---------- 时序约束 ----------
## 所有 I/O 信号相对于 sys_clk 的延迟约束
set_input_delay  -clock sys_clk -max 5.0 [get_ports rst_n]
set_output_delay -clock sys_clk -max 5.0 [get_ports uart_tx]
set_output_delay -clock sys_clk -max 5.0 [get_ports {led[*]}]

## ---------- Bitstream 配置 ----------
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
