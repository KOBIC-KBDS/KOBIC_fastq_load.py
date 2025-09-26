# Build Guide: NCBI VDB, SRA Toolkit (general-loader) for fastq-load.py

This guide documents the exact sequence, options, and pitfalls observed while building NCBI VDB and SRA Toolkit v3.2.1 (including `general-loader`) to enable fastq-load.py on Linux.

## Summary

- Checkout `ncbi-vdb` and `sra-tools` side-by-side under a common parent directory
- Build order: `ncbi-vdb` → `sra-tools`
- Enable loaders for SRA Toolkit: `BUILD_TOOLS_LOADERS=ON`
- Ensure Flex ≥ 2.6.4

## Prerequisites

- Git, Make, CMake ≥ 3.16
- GCC or Clang (Linux)
- flex ≥ 2.6 (2.6.4 used)
- bison ≥ 3

## Directory layout

```
<BASE_DIR>/
├── ncbi-vdb/        # SDK
└── sra-tools/       # Toolkit (contains loaders and sharq source)
```

## 1) Clone side-by-side

```bash
cd <BASE_DIR>
git clone https://github.com/ncbi/ncbi-vdb.git
git clone https://github.com/ncbi/sra-tools.git
```

## 2) Build ncbi-vdb

Follow `ncbi-vdb` README to configure and build. Example (adjust paths as needed):

```bash
cd <BASE_DIR>/ncbi-vdb
make -j4
# Optionally: make install PREFIX=<install_prefix>
```

Resulting include/lib dirs will be referenced by SRA Toolkit.

## 3) Build sra-tools (with loaders)

From `sra-tools` root, enable loaders and (optionally) pass VDB paths if auto-detection fails.

```bash
cd <BASE_DIR>/sra-tools
make -j4 \
  BUILD_TOOLS_LOADERS=ON \
  VDB_INCDIR=<BASE_DIR>/ncbi-vdb/interfaces \
  VDB_LIBDIR=<BASE_DIR>/ncbi-vdb/linux/gcc/x86_64/rel/lib
```

Artifacts will appear under the CMake build tree (e.g. `.../sra-tools/bulid/bin`).


## 4) Verification

Verify `general-loader`:

```bash
<SRA_BUILD_DIR>/bin/general-loader --help
```
Expected output:

```
Usage:
	general-loader [options] 

Summary:
	Populate a VDB database from standard input


Options:
  -I|--include <path(s)>           Additional directories to search for schema 
                                   include files. Can specify multiple paths 
                                   separated by ':'. 
  -S|--schema <path(s)>            Schema file to use. Can specify multiple 
                                   files separated by ':'. 
  -T|--target <path>               Database file to create. Overrides any 
                                   remote path specifications coming from the 
                                   input stream 
  -z|--xml-log <logfile>           Produce XML-formatted log file. 
  -h|--help                        Output brief explanation for the program. 
  -V|--version                     Display the version of the program then 
                                   quit. 
  -L|--log-level <level>           Logging level as number or enum string. One 
                                   of (fatal|sys|int|err|warn|info|debug) or 
                                   (0-6) Current/default is warn. 
  -v|--verbose                     Increase the verbosity of the program 
                                   status messages. Use multiple times for more 
                                   verbosity. Negates quiet. 
  -q|--quiet                       Turn off all status messages for the 
                                   program. Negated by verbose. 
  --option-file <file>             Read more options and parameters from the 
                                   file. 

general-loader : 3.2.1
```

Verify `fastq-load.py`: 
```
python3  <SRA_BUILD_DIR>/tools/loaders/python/fastq-load/fastq-load.py -help
```

Expected output (usage information from source):

```
fastq-load.py --output=<archive path> <other options> <fastq files> | general-loader

Options:

    output:         Output archive path

    offset:         For interpretation of ascii quality (offset=33 or offset=64) or
                    indicating the presence of numerical quality (offset=0).
                    (accepts PHRED_33 and PHRED_64, too)

    quality:        Same as offset (different from latf due to requirement for '=')

    readLens:       For splitting fixed length sequence/quality from a single fastq
                    Number of values must = # of reads (comma-separated). Must be
                    consistent with number of read types specified

    readTypes:      For specifying read types using B (Biological) or T (Technical)
                    Use sequence like TBBT - no commas. Defaults to BB. Must be
                    consistent with number of values specified for read lengths.
                    If you want the read sequence to be used as the spot group or
                    part of the spot group use G (Group). Multiple reads incorporated
                    into the spot group will be concatenated with an '_' separator.

    spotGroup:      Indicates spot group to associate with all spots that are loaded
                    Overrides barcodes on deflines.

    orphanReads:    File or files contain orphan reads or fragments mixed with non-orphan
                    reads. If all files are either completely fragments or completely
                    paired (e.g. split-3 fastq-dump output) then this option is
                    unnecessary. However, for pre-split 454 this option would probably be
                    necessary.

    logOdds:        Input fastq has log odds quality (set prior to 'offset' or 'quality'
                    option)
    
    discardNames:   For when names repeat, go on position only. Specify eight line fastq
                    if that is the case. Does not work with orphanReads. Does not work
                    for split seq/qual files.
    
    useAndDiscardNames:   Too many names to store but still useful for determination of
                    read pairs. So names are used and then discarded.
                    
    ignoreNames:    Determination of pairs via names will not work but first read name
                    retained.
    
    read1PairFiles: Filenames containing read1 seqs ordered to correspond with read2 pair
                    files. Required with --orphanReads option. Files paths must still be
                    provided on the command line in addition to this option. Must be
                    specified in conjunction with read2PairFiles option. Comma-separated.
                    Also useful if ignoring/discarding names.

    read2PairFiles: Filenames containing read2 seqs. Required for --orphanReads option.
                    Include a filename from the read1 files if read2 is in the same file
                    using corresponding positions. Files paths must still be provided on
                    the command line in addition to this option. Comma-separated. Must
                    be specified in conjunction with read1PairFiles option.
                    Also useful if ignoring/discarding names.

    read1QualFiles: Filenames containing read1 quals ordered to correspond with read2 pair
                    files. Files paths must still be provided on the command line in addition
                    to this option. Must be specified in conjunction with read2QualFiles option.
                    Comma-separated. (Provide only if ignoring or discarding names)

    read2QualFiles: Filenames containing read2 quals ordered to correspond with read1 pair
                    files. Files paths must still be provided on the command line in addition
                    to this option. Must be specified in conjunction with read1QualFiles option.
                    Comma-separated. (Provide only if ignoring or discarding names)

    platform:       454, Pacbio, Illumina, ABI, etc.

    readLabels:     Rev, Fwd, Barcode, etc., comma-separated (no whitespaces)

    mixedDeflines:  Indicates mixed defline types exist in one of the fastq files.
                    Results in slower processing of deflines.

    ignLeadChars:   Set # of leading defline characters to ignore for pairing

    discardBarcodes For cases where too many barcodes exist (>30000)
    
    schema:         Set vdb schema to use during load

    z|xml-log:      XML version of stderr output
```

### Required Environment Variables for general-loader

When using `general-loader` with `fastq-load.py`, these environment variables should be set:

```bash
# Schema directory (for general-loader --include) - this directory already exists in sra-tools
SCHEMA_TARGET_DIR="<SRA_BUILD_DIR>/libs/schema"

# NCBI VDB headers (use this for --include NCBI_INCLUDE_DIR)
NCBI_INCLUDE_DIR="<SRA_BUILD_DIR>/ncbi-vdb/interfaces"
```


## Troubleshooting



## Notes

- Replace `<BASE_DIR>` and `<SRA_BUILD_DIR>` with your actual paths
- `BUILD_TOOLS_LOADERS=ON` is required for loader tools to be built
- `sra-tools` build driver will pass CMake flags such as `-DVDB_INCDIR`/`-DVDB_LIBDIR` when provided via Make variables


