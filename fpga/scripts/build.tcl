# ============================================================================
# Vivado 非工程模式构建脚本
# 用法: vivado -mode batch -source build.tcl
# ============================================================================

# 参数
set PART        "xc7z020clg400-2"
set TOP         "qxw_soc_top"
set PROJ_NAME   "qxw_riscv"
set OUTPUT_DIR  "./output"

# 源文件目录
set RTL_DIR     "../../rtl"
set CORE_DIR    "${RTL_DIR}/core"
set SOC_DIR     "${RTL_DIR}/soc"
set MEM_DIR     "${RTL_DIR}/mem"
set XDC_FILE    "../constraints/ax7020.xdc"

# 创建输出目录
file mkdir ${OUTPUT_DIR}

# ============================================================================
# 读入设计文件
# ============================================================================
read_verilog -sv [glob ${CORE_DIR}/*.v]
read_verilog -sv [glob ${SOC_DIR}/*.v]
read_verilog -sv [glob ${MEM_DIR}/*.v]

# 读入 defines
set_property verilog_define {} [current_fileset]
set_property include_dirs [list ${CORE_DIR}] [current_fileset]

# 读入约束
read_xdc ${XDC_FILE}

# ============================================================================
# 综合
# ============================================================================
puts "INFO: Starting synthesis..."
synth_design -top ${TOP} -part ${PART} \
    -flatten_hierarchy rebuilt \
    -directive Default

# 综合后报告
report_timing_summary -file ${OUTPUT_DIR}/post_synth_timing.rpt
report_utilization     -file ${OUTPUT_DIR}/post_synth_util.rpt
write_checkpoint       -force ${OUTPUT_DIR}/post_synth.dcp

# 综合后网表（用于后仿真）
write_verilog -force -mode funcsim ${OUTPUT_DIR}/post_synth_netlist.v

# ============================================================================
# 布局布线
# ============================================================================
puts "INFO: Starting placement..."
opt_design
place_design -directive Default

puts "INFO: Starting routing..."
route_design -directive Default

# 布线后报告
report_timing_summary -file ${OUTPUT_DIR}/post_impl_timing.rpt
report_utilization     -file ${OUTPUT_DIR}/post_impl_util.rpt
report_power           -file ${OUTPUT_DIR}/post_impl_power.rpt
write_checkpoint       -force ${OUTPUT_DIR}/post_impl.dcp

# 布线后网表 + SDF（用于时序后仿真）
write_verilog  -force -mode timesim ${OUTPUT_DIR}/post_impl_netlist.v
write_sdf      -force ${OUTPUT_DIR}/post_impl.sdf

# ============================================================================
# 生成比特流
# ============================================================================
puts "INFO: Generating bitstream..."
write_bitstream -force ${OUTPUT_DIR}/${PROJ_NAME}.bit

puts "INFO: Build complete!"
puts "  Bitstream: ${OUTPUT_DIR}/${PROJ_NAME}.bit"
puts "  Timing:    ${OUTPUT_DIR}/post_impl_timing.rpt"
puts "  Util:      ${OUTPUT_DIR}/post_impl_util.rpt"
