# oDIAFlow

An Open Nextflow pipeline for analyzing DIA-MS (Data-Independent Acquisition Mass Spectrometry) data.

## Overview

oDIAFlow is a modular Nextflow pipeline for processing DIA proteomics data. The pipeline architecture follows the structure of [quantms](https://github.com/bigbio/quantms) for future integration and compatibility. This repo is a sandbox for developing and testing DIA analysis workflows to ready them for inclusion in quantms.

## Workflows

oDIAFlow currently implements two main workflows:

### 1. Empirical Library Workflow (DDA + DIA)

Generates a spectral library from DDA data, then uses it to analyze DIA data.

```
DDA mzML files
    ↓
SAGE Search (database search)
    ↓
EasyPQP ConvertSage (convert to pickle format)
    ↓
EasyPQP Library (build spectral library)
    ↓
OpenSwathAssayGenerator (generate transitions)
    ↓
OpenSwathDecoyGenerator (add decoys)
    ↓
    ┌─────────────────────────────────────┐
    │  DIA Analysis Pipeline              │
    └─────────────────────────────────────┘
    ↓
DIA mzML files → OpenSwathWorkflow (extract features + XICs)
    ↓
Merge OSW/OSWPQ (combine runs)
    ↓
Arycal (XIC-based alignment)
    ↓
PyProphet Alignment Scoring
    ↓
PyProphet (score → peptide inference → protein inference)
    ↓
Final Results (TSV)
```

### 2. In-Silico Library Workflow (Predicted Library + DIA)

Uses a predicted spectral library (e.g., from AlphaPeptDeep, DIA-NN) to analyze DIA data.

```
Transition TSV (predicted library)
    ↓
OpenSwathAssayGenerator (generate transitions)
    ↓
OpenSwathDecoyGenerator (add decoys)
    ↓
    ┌─────────────────────────────────────┐
    │  DIA Analysis Pipeline              │
    └─────────────────────────────────────┘
    ↓
DIA mzML files → OpenSwathWorkflow (extract features + XICs)
    ↓
Merge OSW/OSWPQ (combine runs)
    ↓
Arycal (XIC-based alignment)
    ↓
PyProphet Alignment Scoring
    ↓
PyProphet (score → peptide inference → protein inference)
    ↓
Final Results (TSV)
```

## Usage

### Empirical Library Workflow

```bash
nextflow run main.nf \
  --workflow empirical \
  --dda_glob "data/dda/*.mzML" \
  --dia_glob "data/dia/*.mzML" \
  --fasta "db/uniprot.fasta" \
  --irt_traml "lib/iRTassays.TraML" \
  --outdir results
```

### In-Silico Library Workflow

```bash
nextflow run main.nf \
  --workflow insilico \
  --dia_glob "data/dia/*.mzML" \
  --transition_tsv "lib/predicted_library.tsv" \
  --irt_traml "lib/iRTassays.TraML" \
  --outdir results
```

## Parameters

### Required Parameters

**Empirical workflow:**
- `--dda_glob`: Path pattern to DDA mzML files (e.g., "data/dda/*.mzML")
- `--dia_glob`: Path pattern to DIA mzML files (e.g., "data/dia/*.mzML")
- `--fasta`: Path to FASTA database file

**In-silico workflow:**
- `--dia_glob`: Path pattern to DIA mzML files
- `--transition_tsv`: Path to predicted transition TSV file

### Optional Parameters

- `--workflow`: Workflow type: 'empirical' (default) or 'insilico'
- `--irt_traml`: Path to iRT peptide TraML file 
- `--swath_windows`: Path to SWATH window definition file
- `--use_parquet`: Use Parquet format for PyProphet (default: false)
- `--outdir`: Output directory (default: "results")

## Tools Integrated

- **Sage**: Fast proteomics database search engine
- **EasyPQP**: Spectral library generation from search results
- **OpenMS/OpenSWATH**: Feature extraction and scoring
- **Arycal**: Chromatogram alignment
- **PyProphet**: Semi-supervised learning and statistical validation

## Requirements

- Nextflow (version 25.10 or later)
- Docker or Singularity/Apptainer
- Container image: `ghcr.io/openswath/openswath:dev`

## Configuration

### Structure

```bash
conf/
├── base.config           # Resource labels (process_low, process_medium, etc.) 
├── modules.config        # Process-specific: ext.args, publishDir, containerOptions
├── profiles.config       # Execution profiles: docker, singularity, slurm, pbs, cloud
├── example_user.config   # Template for users to copy and customize
├── resources/
│   ├── local.config      # Resources for local/workstation execution
│   └── hpc.config        # Resources for HPC cluster execution
└── test/
    └── test.config       # Minimal test dataset configuration

nextflow.config           # Main config: params defaults + includes all sub-configs
```

### Examples

```bash
# Local development with Docker
nextflow run main.nf -profile docker,local --dia_glob "data/*.mzML" ...

# HPC with Singularity and SLURM
nextflow run main.nf -profile singularity,slurm --dia_glob "data/*.mzML" ...

# Test run
nextflow run main.nf -profile docker,test

# Custom user config
nextflow run main.nf -profile docker,local -c my_analysis.config
```

## Architecture

The pipeline follows a modular structure compatible with quantms:

```
oDIAFlow/
├── main.nf                    # Entry point
├── nextflow.config            # Configuration
├── workflows/                 # High-level workflows
│   ├── dia_empirical_library.nf
│   └── dia_insilico_library.nf
├── subworkflows/              # Reusable sub-workflows
│   └── local/
│       ├── pyprophet_osw/
│       └── pyprophet_parquet/
└── modules/                   # Individual process modules
    └── local/
        ├── sage/
        ├── easypqp/
        ├── openms/
        ├── pyprophet/
        └── arycal/
```
