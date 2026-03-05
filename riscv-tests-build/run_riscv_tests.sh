#!/bin/bash
# Build and run official riscv-tests on QXW RV32IM CPU
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RISCV_TESTS_SRC="${SCRIPT_DIR}/../riscv-tests"
BUILD_DIR="${SCRIPT_DIR}/build"
SIM_DIR="${SCRIPT_DIR}/../sim"
SW_DIR="${SCRIPT_DIR}/../sw"

CROSS=riscv64-unknown-elf-
CC=${CROSS}gcc
OBJCOPY=${CROSS}objcopy
OBJDUMP=${CROSS}objdump

CFLAGS="-march=rv32im -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding"
CFLAGS="${CFLAGS} -I${SCRIPT_DIR}/env -I${RISCV_TESTS_SRC}/env -I${RISCV_TESTS_SRC}/isa/macros/scalar"
LDFLAGS="-T ${SCRIPT_DIR}/link.ld -nostdlib"

mkdir -p "${BUILD_DIR}"

# RV32UI tests (skip fence_i, ma_data)
RV32UI_TESTS="simple add addi and andi auipc beq bge bgeu blt bltu bne \
    jal jalr lb lbu lh lhu lui lw or ori sb sh sll slli slt slti sltiu \
    sltu sra srai srl srli sub sw xor xori ld_st st_ld"

# RV32UM tests
RV32UM_TESTS="mul mulh mulhsu mulhu div divu rem remu"

PASS_COUNT=0
FAIL_COUNT=0
TIMEOUT_COUNT=0
TOTAL_COUNT=0
FAIL_LIST=""

compile_test() {
    local suite=$1
    local test=$2
    local src_dir="${RISCV_TESTS_SRC}/isa/${suite}"
    local src_file="${src_dir}/${test}.S"
    local elf_file="${BUILD_DIR}/${suite}-${test}.elf"
    local hex_file="${BUILD_DIR}/${suite}-${test}.hex"

    if [ ! -f "${src_file}" ]; then
        echo "  [SKIP] ${suite}-${test}: source not found"
        return 1
    fi

    ${CC} ${CFLAGS} -o "${elf_file}" "${src_file}" ${LDFLAGS} 2>/dev/null
    ${OBJCOPY} -O verilog "${elf_file}" "${BUILD_DIR}/${suite}-${test}_bytes.hex"
    python3 "${SW_DIR}/byte2word.py" "${BUILD_DIR}/${suite}-${test}_bytes.hex" "${hex_file}"
    ${OBJDUMP} -d "${elf_file}" > "${BUILD_DIR}/${suite}-${test}.dis" 2>/dev/null
    return 0
}

run_test() {
    local suite=$1
    local test=$2
    local hex_file="${BUILD_DIR}/${suite}-${test}.hex"
    local test_name="${suite}-${test}"

    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    cp "${hex_file}" "${SIM_DIR}/firmware.hex"
    OUTPUT=$(cd "${SIM_DIR}" && vvp -n tb_cpu_top.vvp 2>&1) || true

    if echo "${OUTPUT}" | grep -q "TEST PASSED"; then
        CYCLES=$(echo "${OUTPUT}" | grep -oP 'after \K[0-9]+')
        printf "  %-25s PASS  (%s cycles)\n" "${test_name}" "${CYCLES}"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif echo "${OUTPUT}" | grep -q "TEST FAILED"; then
        TEST_ID=$(echo "${OUTPUT}" | grep -oP 'test_id = \K[0-9]+')
        CYCLES=$(echo "${OUTPUT}" | grep -oP 'after \K[0-9]+')
        printf "  %-25s FAIL  (test_id=%s, %s cycles)\n" "${test_name}" "${TEST_ID}" "${CYCLES}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAIL_LIST="${FAIL_LIST} ${test_name}(id=${TEST_ID})"
    elif echo "${OUTPUT}" | grep -q "TIMEOUT"; then
        printf "  %-25s TIMEOUT\n" "${test_name}"
        TIMEOUT_COUNT=$((TIMEOUT_COUNT + 1))
        FAIL_LIST="${FAIL_LIST} ${test_name}(timeout)"
    else
        printf "  %-25s ERROR (unknown output)\n" "${test_name}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAIL_LIST="${FAIL_LIST} ${test_name}(error)"
    fi
}

echo "============================================"
echo "  QXW RV32IM - Official riscv-tests Runner"
echo "============================================"
echo ""

# Compile the testbench VVP if not present
if [ ! -f "${SIM_DIR}/tb_cpu_top.vvp" ]; then
    echo "[INFO] Compiling testbench..."
    cd "${SIM_DIR}" && make tb_cpu_top.vvp
fi

echo "[1/4] Compiling RV32UI tests..."
for test in ${RV32UI_TESTS}; do
    compile_test rv32ui "${test}" || true
done

echo "[2/4] Compiling RV32UM tests..."
for test in ${RV32UM_TESTS}; do
    compile_test rv32um "${test}" || true
done

echo "[3/4] Running RV32UI tests..."
echo ""
for test in ${RV32UI_TESTS}; do
    if [ -f "${BUILD_DIR}/rv32ui-${test}.hex" ]; then
        run_test rv32ui "${test}"
    fi
done

echo ""
echo "[4/4] Running RV32UM tests..."
echo ""
for test in ${RV32UM_TESTS}; do
    if [ -f "${BUILD_DIR}/rv32um-${test}.hex" ]; then
        run_test rv32um "${test}"
    fi
done

echo ""
echo "============================================"
echo "  Test Results Summary"
echo "============================================"
echo "  Total:   ${TOTAL_COUNT}"
echo "  Passed:  ${PASS_COUNT}"
echo "  Failed:  ${FAIL_COUNT}"
echo "  Timeout: ${TIMEOUT_COUNT}"
if [ -n "${FAIL_LIST}" ]; then
    echo "  Failed tests:${FAIL_LIST}"
fi
echo "============================================"
