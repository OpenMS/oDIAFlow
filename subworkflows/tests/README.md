# Subworkflow Tests

This directory contains integration tests for subworkflows in the oDIAFlow pipeline.

## Overview

Subworkflow tests validate that multiple modules work together correctly. These tests use the same test data as module tests (located in `modules/tests/data/`).

## Available Tests

### PyProphet OSW Subworkflow

Test the full PyProphet pipeline on SQLite OSW format:

```bash
nextflow run subworkflows/tests/pyprophet_osw_test.nf \
  -c subworkflows/tests/config/pyprophet_osw_subworkflow.config \
  -profile docker
```

**Test workflow:** Aligned OSW → Peakgroup scoring → Peptide inference → Protein inference → Export TSV

**Test data required:**
- `modules/tests/data/test_data.osw` - Aligned OSW file
- `modules/tests/data/test.pqp` - PQP library (for scoring context)

### PyProphet Parquet Subworkflow

Test the full PyProphet pipeline on Parquet format:

```bash
nextflow run subworkflows/tests/pyprophet_parquet_test.nf \
  -c subworkflows/tests/config/pyprophet_parquet_subworkflow.config \
  -profile docker
```

**Test workflow:** 
1. **Export OSW to Parquet** - Converts `test_data.osw` to parquet format with `--split_runs` flag
   - Creates a `.oswpq` directory containing subdirectories for each run
   - Each run subdirectory has `precursors_features.parquet` and `transition_features.parquet`
2. **Peakgroup scoring** - Scores features in the parquet data
3. **Peptide inference** - Performs peptide-level inference across runs
4. **Protein inference** - Performs protein-level inference
5. **Merge parquet** - Merges all run parquet files into a single `merged.parquet`
6. **Export TSV** - Exports final results to TSV format

**Test data required:**
- `modules/tests/data/test_data.osw` - Source OSW file (automatically converted to parquet)
- `modules/tests/data/test.pqp` - PQP library (for scoring context)

**Parquet Structure:**
```
test_data.oswpq/
├── feature_alignment.parquet
├── run1.oswpq/
│   ├── precursors_features.parquet
│   └── transition_features.parquet
├── run2.oswpq/
│   ├── precursors_features.parquet
│   └── transition_features.parquet
└── run3.oswpq/
    ├── precursors_features.parquet
    └── transition_features.parquet
```

**NOTE:** This test demonstrates the full parquet workflow by first converting OSW data to parquet format, then running the complete PyProphet analysis pipeline on the parquet data.

## Key Differences: Module Tests vs Subworkflow Tests

| Aspect | Module Tests | Subworkflow Tests |
|--------|--------------|-------------------|
| **Scope** | Single process | Multiple processes chained |
| **Purpose** | Validate individual components | Validate integration |
| **Data** | Minimal required inputs | Realistic pipeline data |
| **Duration** | Fast (< 5 min) | Moderate (5-15 min) |
| **Location** | `modules/tests/` | `subworkflows/tests/` |

## Configuration

Test configs are located in `subworkflows/tests/config/` and include:

- **Process-specific settings**: Using process selectors with subworkflow scope
- **Reduced parameters**: Faster execution for testing
- **Container options**: Environment variables for Docker/Singularity

### Process Selector Syntax

For subworkflow processes, use the pattern:
```groovy
process {
  withName: 'SUBWORKFLOW_NAME:PROCESS_NAME' {
    cpus = 2
    memory = '4.GB'
  }
}
```

Or apply to all processes in a subworkflow:
```groovy
process {
  withName: 'PYPROPHET_OSW_FULL:.*' {
    cpus = 2
    memory = '4.GB'
  }
}
```

## Running Tests

### Individual Test

```bash
nextflow run subworkflows/tests/<test>.nf \
  -c subworkflows/tests/config/<config>.config \
  -profile docker
```

### With Resume

```bash
nextflow run subworkflows/tests/<test>.nf \
  -c subworkflows/tests/config/<config>.config \
  -profile docker \
  -resume
```

### Debug Mode

```bash
nextflow run subworkflows/tests/<test>.nf \
  -c subworkflows/tests/config/<config>.config \
  -profile docker \
  -with-trace \
  -with-report \
  -with-timeline
```

## Creating New Subworkflow Tests

1. **Create test workflow** in `subworkflows/tests/<name>_test.nf`
2. **Create test config** in `subworkflows/tests/config/<name>.config`
3. **Reuse existing test data** from `modules/tests/data/`
4. **Add documentation** to this README

### Template

```nextflow
#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { YOUR_SUBWORKFLOW } from '../local/your_subworkflow/main.nf'

workflow {
    // Setup input channels using existing test data
    def input_ch = Channel.of( file('../modules/tests/data/test_file') )
    
    // Run subworkflow
    YOUR_SUBWORKFLOW(input_ch)
    
    // Inspect outputs
    YOUR_SUBWORKFLOW.out.result.view { "Result: $it" }
}
```

## Best Practices

1. **Reuse test data**: Don't duplicate test files, reference from `modules/tests/data/`
2. **Test realistic scenarios**: Subworkflows should test actual pipeline use cases
3. **Chain appropriately**: Ensure inputs match what the subworkflow expects in production
4. **Keep fast**: Use reduced parameters to keep tests under 15 minutes
5. **Document dependencies**: Note which test data files are required
