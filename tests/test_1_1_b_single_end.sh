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
TEST_NAME="1_1_b_single_end"
READ_TYPES="B"
PLATFORM="Illumina"
INPUT_FILES="./data/test_1_1/KOHFDgWAT3.fastq.gz"
OUTPUT_SRA="test_${TEST_NAME}_output"
OUTPUT_KAR="test_${TEST_NAME}_output"
SRA_FILE="${OUTPUT_KAR}.sra"
VALIDATE_LOG="results/validate/${TEST_NAME}/validate.log"
STATS_FILE="results/stats/${TEST_NAME}/stats.xml"

echo "=== Test 1.1: B Single End ==="
echo "Test Name: ${TEST_NAME}"
echo "Read Types: ${READ_TYPES}"
echo "Platform: ${PLATFORM}"
echo "Input Files: ${INPUT_FILES}"
echo "Output SRA: ${OUTPUT_SRA}"
echo "Output KAR: ${OUTPUT_KAR}"
echo "SRA File: ${SRA_FILE}"
echo "Validate Log: ${VALIDATE_LOG}"
echo "Stats File: ${STATS_FILE}"

# Step 1: Clean up any existing output files
echo "=== Step 1: Cleanup ==="
echo "Removing existing output files..."
rm -rf "${OUTPUT_SRA}"
rm -f "${SRA_FILE}"
rm -rf "results/validate/${TEST_NAME}"
rm -rf "results/stats/${TEST_NAME}"
rm -f *.log

# Step 2: Run fastq-load.py piped to general-loader
echo "=== Step 2: Run fastq-load.py piped to general-loader ==="
echo "Command: python3 -u ${FASTQ_LOAD_SCRIPT} --readTypes=${READ_TYPES} --platform=${PLATFORM} ${INPUT_FILES} | ${GENERAL_LOADER} -I ${INCLUDE_PATH} --target ${OUTPUT_SRA}"

# Run fastq-load.py piped to general-loader
python3 -u "${FASTQ_LOAD_SCRIPT}" --readTypes="${READ_TYPES}" --platform="${PLATFORM}" "${INPUT_FILES}" | "${GENERAL_LOADER}" -I "${INCLUDE_PATH}" --target "${OUTPUT_SRA}" 2>pipeline_stderr.log

# Step 3: Check if SRA file was created
echo "=== Step 3: Check if SRA file was created ==="
if [ -d "${OUTPUT_SRA}" ]; then
    echo "✓ SRA database created: ${OUTPUT_SRA}"
    ls -la "${OUTPUT_SRA}"
    echo "Database contents:"
    find "${OUTPUT_SRA}" -type f | head -10
    
    # Check if any .tmp files exist
    echo "Checking for .tmp files:"
    find "${OUTPUT_SRA}" -name "*.tmp" | head -5
else
    echo "✗ SRA database not created: ${OUTPUT_SRA}"
    echo "Checking stderr logs for errors:"
    echo "=== Pipeline stderr ==="
    cat pipeline_stderr.log
    exit 1
fi


# Step 4: Create archive with KAR (if SRA database exists)
echo "=== Step 4: Create archive with KAR ==="
if [ -d "${OUTPUT_SRA}" ]; then
    if [ -f "${KAR}" ]; then
        echo "✓ KAR found"
        echo "Creating KAR archive..."
        "${KAR}" --create "${SRA_FILE}" --directory "${OUTPUT_SRA}" --md5
        if [ -f "${SRA_FILE}" ]; then
            echo "✓ KAR archive created: ${SRA_FILE}"
            ls -la "${SRA_FILE}"
        else
            echo "✗ KAR archive creation failed"
            exit 1
        fi
    else
        echo "✗ KAR not found at ${KAR}"
        exit 1
    fi
else
    echo "✗ No SRA database to archive"
    exit 1
fi

# Step 5: Validate with vdb-validate
echo "=== Step 5: Validate with vdb-validate ==="
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

# Step 6: Generate statistics with sra-stat
echo "=== Step 6: Generate statistics with sra-stat ==="
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

echo "=== Test completed ===" 
echo "=== Test completed successfully ===" 