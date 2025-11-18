# Workflow Tests

This directory contains end-to-end integration tests for complete workflows in the oDIAFlow pipeline.

## Overview

Workflow tests validate entire analytical pipelines from raw data to final results. These tests use the same test data as module tests (located in `modules/tests/data/`).

## Available Tests

### DIA In-Silico Library Workflow

Test the complete in-silico library workflow using a pre-generated spectral library:

```bash
nextflow run workflows/tests/dia_insilico_library_test.nf \
  -c workflows/tests/config/dia_insilico_library_test.config \
  -profile docker
```

**Test workflow:** 
1. **Assay Generation** - Generate assay library from in-silico transition TSV
2. **Decoy Generation** - Add decoys to the library
3. **Feature Extraction** - Extract features from DIA mzML files using OpenSwathWorkflow
4. **Calibration Report** - Generate QC report from extraction debug files
5. **Merge OSW** - Combine per-run OSW files
6. **XIC Alignment** - Align chromatograms across runs with Arycal
7. **Alignment Scoring** - Score aligned features with PyProphet
8. **PyProphet Full** - Run complete PyProphet pipeline (scoring → peptide → protein → export)

**Test data required:**
- `modules/tests/data/test_raw_1.mzML.gz` - DIA run 1 (gzipped)
- `modules/tests/data/test_raw_2.mzML.gz` - DIA run 2 (gzipped)
- `modules/tests/data/test.tsv` - In-silico transition library
- `modules/tests/data/strep_win.txt` - SWATH window file

**Expected outputs:**
- Decoy-augmented PQP library
- Per-run OSW files with extracted features
- Merged and aligned OSW file
- Calibration report PDF
- Final TSV with quantified peptides/proteins

### DIA Empirical Library Workflow

Test the complete empirical library workflow (DDA search → spectral library → DIA analysis):

```bash
nextflow run workflows/tests/dia_empirical_library_test.nf \
  -c workflows/tests/config/dia_empirical_library_test.config \
  -profile docker
```

**Test workflow:**
1. **DDA Search** - Search DDA data with Sage to identify peptides
2. **Convert Results** - Convert Sage results to EasyPQP format
3. **Build Library** - Generate spectral library TSV with EasyPQP
4. **Assay Generation** - Convert library to PQP assay format
5. **Decoy Generation** - Add decoys to the library
6. **Feature Extraction** - Extract features from DIA mzML files
7. **Calibration Report** - Generate QC report from extraction debug files
8. **Merge OSW** - Combine per-run OSW files
9. **XIC Alignment** - Align chromatograms across runs with Arycal
10. **Alignment Scoring** - Score aligned features with PyProphet
11. **PyProphet Full** - Run complete PyProphet pipeline (scoring → peptide → protein → export)

**Test data required:**
- `modules/tests/data/test_raw_1.mzML.gz` - Used as both DDA and DIA (gzipped)
- `modules/tests/data/test_raw_2.mzML.gz` - Used as both DDA and DIA (gzipped)
- `modules/tests/data/uniprotkb_organism_id_1314_AND_reviewed_2025_11_18.fasta` - Protein database
- `modules/tests/data/strep_win.txt` - SWATH window file

**Note:** This test uses DIA files as DDA input for Sage search (Sage can search wide-window DIA data).

**Expected outputs:**
- Sage search results (PSMs and matched fragments)
- EasyPQP pickle files (per-run PSM and peak data)
- Spectral library TSV
- Decoy-augmented PQP library
- Per-run OSW files with extracted features
- Merged and aligned OSW file
- Calibration report PDF
- Final TSV with quantified peptides/proteins

## Key Differences: Module/Subworkflow vs Workflow Tests

| Aspect | Module Tests | Subworkflow Tests | Workflow Tests |
|--------|--------------|-------------------|----------------|
| **Scope** | Single process | Multiple processes | Complete pipeline |
| **Purpose** | Unit testing | Integration testing | End-to-end testing |
| **Data** | Minimal | Realistic subset | Full analysis |
| **Duration** | Fast (< 5 min) | Moderate (5-15 min) | Longer (15-60 min) |
| **Location** | `modules/tests/` | `subworkflows/tests/` | `workflows/tests/` |

## Test Data Location

Workflow tests reuse test data from module tests using relative paths:

```groovy
params {
  dia_glob = "modules/tests/data/test_raw*.mzML.gz"
  transition_tsv = "modules/tests/data/test.tsv"
  swath_windows = "modules/tests/data/strep_win.txt"
}
```

**Important:** Run workflow tests from the project root directory so relative paths resolve correctly.

## Configuration

Test configs are located in `workflows/tests/config/` and include:

- **All workflow parameters** - Complete parameter sets for the workflow
- **Process-specific settings** - CPU, memory, and container options for each step
- **Reduced parameters** - Optimized for faster test execution
- **Container options** - Environment variables for Docker/Singularity

### Process Selector Syntax

For workflow processes, use the pattern:
```groovy
process {
  withName: 'WORKFLOW_NAME:PROCESS_NAME' {
    cpus = 2
    memory = '4.GB'
  }
}
```

Or for subworkflow processes within a workflow:
```groovy
process {
  withName: 'WORKFLOW_NAME:SUBWORKFLOW_NAME:.*' {
    cpus = 2
    memory = '4.GB'
  }
}
```

## Running Tests

### Individual Tests

**DIA In-Silico Library Workflow:**
```bash
# Must run from project root!
cd /path/to/oDIAFlow
nextflow run workflows/tests/dia_insilico_library_test.nf \
  -c workflows/tests/config/dia_insilico_library_test.config \
  -profile docker
```

**DIA Empirical Library Workflow:**
```bash
# Must run from project root!
cd /path/to/oDIAFlow
nextflow run workflows/tests/dia_empirical_library_test.nf \
  -c workflows/tests/config/dia_empirical_library_test.config \
  -profile docker
```

### Run All Tests

```bash
# Run both workflow tests
cd /path/to/oDIAFlow

# In-silico library workflow
nextflow run workflows/tests/dia_insilico_library_test.nf \
  -c workflows/tests/config/dia_insilico_library_test.config \
  -profile docker

# Empirical library workflow
nextflow run workflows/tests/dia_empirical_library_test.nf \
  -c workflows/tests/config/dia_empirical_library_test.config \
  -profile docker
```

### With Resume

```bash
nextflow run workflows/tests/dia_insilico_library_test.nf \
  -c workflows/tests/config/dia_insilico_library_test.config \
  -profile docker \
  -resume
```

### Debug Mode

```bash
nextflow run workflows/tests/dia_insilico_library_test.nf \
  -c workflows/tests/config/dia_insilico_library_test.config \
  -profile docker \
  -with-trace \
  -with-report \
  -with-timeline \
  -with-dag dag.html
```

## Creating New Workflow Tests

1. **Create test workflow** in `workflows/tests/<name>_test.nf`
2. **Create test config** in `workflows/tests/config/<name>_test.config`
3. **Reuse existing test data** from `modules/tests/data/`
4. **Set all required parameters** in the config
5. **Add documentation** to this README

### Template

```nextflow
#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { YOUR_WORKFLOW } from '../your_workflow.nf'

workflow {
    log.info """
    ================================================================================
    Your Workflow Test
    ================================================================================
    
    Testing workflow with:
    - Input 1: description
    - Input 2: description
    
    ================================================================================
    """.stripIndent()
    
    YOUR_WORKFLOW()
}
```

## Best Practices

1. **Run from project root** - Workflow tests expect to be run from the repository root
2. **Use relative paths** - Reference test data with relative paths from project root
3. **Test realistic scenarios** - Workflows should test complete analytical pipelines
4. **Keep reasonably fast** - Optimize parameters to keep tests under 1 hour
5. **Document fully** - Include all inputs, outputs, and expected results
6. **Test both formats** - If applicable, test both SQLite and Parquet workflows
