# fastq-load.py : A python-based loader tool for FASTQ to SRA Conversion

## Overview

Although fastq-load.py is an unofficial and incomplete tool, it is a more flexible and powerful Python-based solution designed to overcome the limitations of latf-load. It converts biological sequencing data from FASTQ format into the specialized `fastq-load.py` SRA (Sequence Read Archive) format. 

## Key Features

- **Automated Defline Parser**: Handles dozens of non-standard defline formats from various platforms
(e.g. new/old Illumina, QIIME, 454, PacBio, Nanopore, Helicos, Ion Torrent, AB Solid, Sanger newbler and Undefined/Generic)
- **Robust Error Handling**: Comprehensive fallback mechanisms and recovery procedures

### Prerequisites

**Operating System:**
- Linux (CentOS 7+, Ubuntu 18.04+, Debian 9+)
- Windows (with WSL)

**Build Dependencies:**
- **CMake** (version 3.16 or higher) - Build system
- **Make** - Build automation
- **flex** (version 2.6 or higher) - Lexical analyzer
- **bison** (version 3 or higher) - Parser generator

**Compilers:**
- **Linux**: GCC 7.0+ or Clang 6.0+


### Installation

1. Clone the repository 
```bash
git clone https://github.com/KOBIC-KBDS/KOBIC_fastq_load.py.git
cd KOBIC_fastq_load.py
```

2. Build other repositories

    For detailed instructions on building the required dependencies (ncbi-vdb and sra-tools), please refer to [docs/build-guide.md](docs/build-guide.md).  
    This guide provides step-by-step directions for cloning, build order, and enabling loader tools.

    **Source Repositories:**
    - [ncbi-vdb GitHub](https://github.com/ncbi/ncbi-vdb)
    - [sra-tools GitHub](https://github.com/ncbi/sra-tools)

> **Note:**  
> Loader tool support must be enabled with option when building sra-tools.  
> For exact build options and important details, see [docs/build-guide.md](docs/build-guide.md).


## Quick Start

### Basic Usage with fastq-load.py and general-loader

For a quick test of the core functionality:

```bash
# 1. Set up environment variables
export SRA_BUILD_DIR="/path/to/your/sra-tools/build"
export VDB_BUILD_DIR="/path/to/your/vdb-build"
export PYTHONPATH="${SRA_BUILD_DIR}/shared/python:${SRA_BUILD_DIR}/tools/loaders/python/fastq-load:$PYTHONPATH"

# 2. Run fastq-load.py piped to general-loader
python3 -u "${SRA_BUILD_DIR}/tools/loaders/python/fastq-load/fastq-load.py" \
  --readTypes=B \
  --platform=Illumina \
  your_input.fastq.gz | \
"${SRA_BUILD_DIR}/bin/general-loader" \
  -I "${VDB_BUILD_DIR}/interfaces" \
  --target output_sra_database

# 3. Create SRA archive
"${SRA_BUILD_DIR}/bin/kar" --create output.sra --directory output_sra_database --md5

# 4. Validate the result
"${SRA_BUILD_DIR}/bin/vdb-validate" output.sra
```


## Project Structure

```
/
├── tests/                 # Test scripts and scenarios
│   ├── test_1_1_b_single_end.sh
│   ├── test_1_2_bb_paired_end.sh
│   ├── test_1_3_bbt_10x_single_cell.sh
│   ├── test_1_4_bbtt_10x_sample_barcode.sh
│   └── test_2_1_bbbt_single_cell_genomic.sh
├── docs/                  # Documentation
│   └── build-guide.md    # Build instructions
├── data/                  # Test data (auto-generated)
├── results/               # Test outputs (auto-generated)
│   ├── validate/         # Validation logs
│   └── stats/            # Statistics files
├── .gitignore            # Git ignore rules
└── README.md             # This file
```

## Documentation

- **[Build Guide](docs/build-guide.md)**: VDB and SRA Toolkit build documentation 



## Testing

### Test Suite Overview

The project includes a comprehensive test suite with 5 different test scenarios covering various sequencing data types and formats:

1. **test_1_1_b_single_end.sh** - Single-end Illumina data
2. **test_1_2_bb_paired_end.sh** - Paired-end Illumina data  
3. **test_1_3_bbt_10x_single_cell.sh** - 10X single-cell data
4. **test_1_4_bbtt_10x_sample_barcode.sh** - 10X sample barcode data
5. **test_2_1_bbbt_single_cell_genomic.sh** - Single-cell genomic data

### Test Process

#### 1. Prerequisites Setup

Before running tests, ensure you have:

- Built ncbi-vdb and sra-tools with loader support enabled
- Set correct paths in test scripts:
  ```bash
  export SRA_BUILD_DIR="/path/to/your/sra-tools/build"
  export VDB_BUILD_DIR="/path/to/your/vdb-build"
  ```

#### 2. Test Data Preparation

**test_1_2 data is included in the repository.** For additional test data, copy from the DDBJ SC server:

```bash
# Copy additional test data (for KOBIC users only)
cp -r /home/kobic/fastq-load.py_test_data/data/test_1_1 ./data/
cp -r /home/kobic/fastq-load.py_test_data/data/test_1_3 ./data/
cp -r /home/kobic/fastq-load.py_test_data/data/test_1_4 ./data/
cp -r /home/kobic/fastq-load.py_test_data/data/test_2_1 ./data/
```

Test data structure:
```
data/
├── test_1_1/          # Single-end test data (2.0GB)
├── test_1_2/          # Paired-end test data (38MB) - included in repo
├── test_1_3/          # 10X single-cell test data (19GB)
├── test_1_4/          # 10X sample barcode test data (7.8GB)
└── test_2_1/          # Single-cell genomic test data (11GB)
```

#### 3. Running Tests

Execute individual tests from the project root:

```bash
# Single-end test
./tests/test_1_1_b_single_end.sh

# Paired-end test  
./tests/test_1_2_bb_paired_end.sh

# 10X single-cell test
./tests/test_1_3_bbt_10x_single_cell.sh

# 10X sample barcode test
./tests/test_1_4_bbtt_10x_sample_barcode.sh

# Single-cell genomic test
./tests/test_2_1_bbbt_single_cell_genomic.sh
```

#### 4. Test Pipeline

Each test follows this comprehensive pipeline:

1. **Schema Dependencies Setup** - Creates symlinks for VDB interfaces
2. **FastQ Processing** - `fastq-load.py` processes input files
3. **SRA Generation** - `general-loader` creates SRA database
4. **Archive Creation** - `kar` creates compressed SRA archive
5. **Validation** - `vdb-validate` verifies SRA file integrity
6. **Statistics** - `sra-stat` generates detailed statistics

#### 5. Output Structure

Test results are organized in the `results/` directory:

```
results/
├── validate/
│   ├── 1_1_b_single_end/validate.log
│   ├── 1_2_bb_paired_end/validate.log
│   └── ...
└── stats/
    ├── 1_1_b_single_end/stats.xml
    ├── 1_2_bb_paired_end/stats.xml
    └── ...
```

#### 6. Validation Commands

```bash
# Verify SRA file integrity
vdb-validate test_1_1_b_single_end_output.sra

# Generate detailed statistics
sra-stat -x test_1_1_b_single_end_output.sra

# Check validation logs
cat results/validate/1_1_b_single_end/validate.log

# View statistics
cat results/stats/1_1_b_single_end/stats.xml
```

### Test Results

- **All 5 test scenarios**: Successfully completed
- **Pipeline Integration**: FastQ → SRA → KAR → Validate → Stats
- **Error Handling**: Comprehensive logging and error detection
- **Output Validation**: All SRA files pass vdb-validate checks
- **Performance**: Complete conversion pipeline working correctly

## Support

- **Issues**: [GitHub Issues](https://github.com/kobic//issues)
- **Discussions**: [GitHub Discussions](https://github.com/kobic//discussions)
- **Documentation**: [Wiki](https://github.com/kobic//wiki)

## Acknowledgments

