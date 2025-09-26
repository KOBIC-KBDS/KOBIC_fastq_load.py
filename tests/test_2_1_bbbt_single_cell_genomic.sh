#!/bin/bash

# =============================================================================
# SRA Build Directory Configuration
# =============================================================================
# Set your SRA build directory path here
# Example: export SRA_BUILD_DIR="/path/to/your/sra-tools/build"
# Example: export SRA_BUILD_DIR="/BiO/scratch/KOBIC/kbds/tools/sra-tools-3.2.1"
export SRA_BUILD_DIR=""

# Set your VDB build directory path here
# Example: export VDB_BUILD_DIR="/path/to/your/vdb-build"
# Example: export VDB_BUILD_DIR="/BiO/scratch/KOBIC/kbds/tools/ncbi-vdb"
export VDB_BUILD_DIR=""

# =============================================================================
# Python Environment Configuration
# =============================================================================
export PYTHONPATH="${SRA_BUILD_DIR}/shared/python:${SRA_BUILD_DIR}/tools/loaders/python/fastq-load:$PYTHONPATH"

# Exit immediately if a command exits with a non-zero status.
set -e

# =============================================================================
# Schema Dependencies Setup
# =============================================================================
# Create schema directory and symlinks
SCHEMA_TARGET_DIR="${SRA_BUILD_DIR}/libs/schema"
NCBI_INCLUDE_DIR="${VDB_BUILD_DIR}/interfaces"

echo "Setting up schema dependencies..."
mkdir -p "${SCHEMA_TARGET_DIR}"

# Create symlinks for schema dependencies
if [ -d "${NCBI_INCLUDE_DIR}" ]; then
    for item in "${NCBI_INCLUDE_DIR}"/*; do
        if [ -d "${item}" ]; then
            item_name=$(basename "${item}")
            target_path="${SCHEMA_TARGET_DIR}/${item_name}"
            if [ ! -e "${target_path}" ]; then
                ln -s "${item}" "${target_path}" 2>/dev/null || true
            fi
        fi
    done
    echo "✓ Schema dependencies setup completed"
else
    echo "⚠ NCBI include directory not found: ${NCBI_INCLUDE_DIR}"
fi

# =============================================================================
# Tool Paths Configuration
# =============================================================================
FASTQ_LOAD_SCRIPT="${SRA_BUILD_DIR}/tools/loaders/python/fastq-load/fastq-load.py"
GENERAL_LOADER="${SRA_BUILD_DIR}/bin/general-loader"
KAR="${SRA_BUILD_DIR}/bin/kar"
VDB_VALIDATE="${SRA_BUILD_DIR}/bin/vdb-validate"
SRA_STAT="${SRA_BUILD_DIR}/bin/sra-stat"
INCLUDE_PATH="${VDB_BUILD_DIR}/interfaces"

# Test configuration
TEST_NAME="2_1_bbbt_single_cell_genomic"
READ_TYPES="BBBT"
PLATFORM="Illumina"
INPUT_FILES="./data/test_2_1/P2--AGCCCTTT_S4_L004_R1_001.fastq.gz ./data/test_2_1/P2--AGCCCTTT_S4_L004_R2_001.fastq.gz ./data/test_2_1/P2--AGCCCTTT_S4_L004_R3_001.fastq.gz ./data/test_2_1/P2--AGCCCTTT_S4_L004_I1_001.fastq.gz"
OUTPUT_DIR="test_${TEST_NAME}_sra_archive"
OUTPUT_FILE="${OUTPUT_DIR}.sra"
SRA_FILE="${OUTPUT_FILE}"
VALIDATE_LOG="results/validate/${TEST_NAME}/validate.log"
STATS_FILE="results/stats/${TEST_NAME}/stats.xml"

echo "=== Test: ${TEST_NAME} ==="
echo "Cleaning up previous runs..."
rm -rf "${OUTPUT_DIR}" "${OUTPUT_FILE}"
rm -rf "results/validate/${TEST_NAME}"
rm -rf "results/stats/${TEST_NAME}"

echo "=== Step 1: Run fastq-load.py piped to general-loader ==="
echo "Command: python3 -u ${FASTQ_LOAD_SCRIPT} --readTypes=${READ_TYPES} --platform=${PLATFORM} ${INPUT_FILES} | ${GENERAL_LOADER} -I ${INCLUDE_PATH} --target ${OUTPUT_DIR}"

# Run fastq-load.py piped to general-loader
python3 -u "${FASTQ_LOAD_SCRIPT}" --readTypes="${READ_TYPES}" --platform="${PLATFORM}" ${INPUT_FILES} | "${GENERAL_LOADER}" -I "${INCLUDE_PATH}" --target "${OUTPUT_DIR}" 2>pipeline_stderr.log

echo "=== Step 2: Verify output directory structure ==="
if [ -d "${OUTPUT_DIR}" ]; then
    echo "✓ Output directory created"
    ls -la "${OUTPUT_DIR}"
else
    echo "✗ Output directory not created"
    exit 1
fi


echo "=== Step 3: Create archive with KAR ==="
if [ -f "${KAR}" ]; then
    echo "✓ KAR found"
    "${KAR}" --create "${SRA_FILE}" --directory "${OUTPUT_DIR}" --md5
    if [ -f "${SRA_FILE}" ]; then
        echo "✓ Archive created: ${SRA_FILE}"
        ls -lh "${SRA_FILE}"
    else
        echo "✗ Archive creation failed"
        exit 1
    fi
else
    echo "✗ KAR not found at ${KAR}"
    exit 1
fi

echo "=== Step 4: Validate with vdb-validate ==="
if [ -f "${SRA_FILE}" ]; then
    if [ -f "${VDB_VALIDATE}" ]; then
        echo "✓ vdb-validate found"
        
        # Create validate output directory
        mkdir -p "$(dirname "${VALIDATE_LOG}")"
        
        echo "Running vdb-validate..."
        "${VDB_VALIDATE}" "${SRA_FILE}" > "${VALIDATE_LOG}" 2>&1
        
        # Check validation result
        if [ -f "${VALIDATE_LOG}" ]; then
            echo "✓ Validation log created: ${VALIDATE_LOG}"
            if grep -q "ok" "${VALIDATE_LOG}" && ! grep -q "error" "${VALIDATE_LOG}"; then
                echo "✓ SRA file validation successful"
            else
                echo "⚠ SRA file validation issues detected"
                echo "Validation log content:"
                cat "${VALIDATE_LOG}"
            fi
        else
            echo "✗ Validation log not created"
        fi
    else
        echo "✗ vdb-validate not found at ${VDB_VALIDATE}"
    fi
else
    echo "✗ No SRA file to validate"
fi

echo "=== Step 5: Generate statistics with sra-stat ==="
if [ -f "${SRA_FILE}" ]; then
    if [ -f "${SRA_STAT}" ]; then
        echo "✓ sra-stat found"
        
        # Create stats output directory
        mkdir -p "$(dirname "${STATS_FILE}")"
        
        echo "Running sra-stat..."
        "${SRA_STAT}" -x "${SRA_FILE}" > "${STATS_FILE}" 2>sra_stat_error.log
        
        # Check stats result
        if [ -f "${STATS_FILE}" ]; then
            echo "✓ Statistics file created: ${STATS_FILE}"
            if [ -s "${STATS_FILE}" ] && head -1 "${STATS_FILE}" | grep -q "<Run"; then
                echo "✓ SRA statistics generated successfully"
                echo "Statistics file size: $(wc -l < "${STATS_FILE}") lines"
            else
                echo "⚠ SRA statistics file may be invalid"
                echo "Statistics file content (first 10 lines):"
                head -10 "${STATS_FILE}"
            fi
        else
            echo "✗ Statistics file not created"
        fi
        
        # Check for errors
        if [ -f "sra_stat_error.log" ] && [ -s "sra_stat_error.log" ]; then
            echo "sra-stat error log:"
            cat sra_stat_error.log
        fi
    else
        echo "✗ sra-stat not found at ${SRA_STAT}"
    fi
else
    echo "✗ No SRA file for statistics"
fi

echo "=== Test completed successfully ===" 