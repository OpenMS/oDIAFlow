# Module Tests

This directory contains unit tests for individual modules in the oDIAFlow pipeline.

## Available Tests

### Sage Search Module

Test database search with Sage on DDA data:

```bash
nextflow run modules/tests/sage_search_test.nf \
  -c modules/tests/config/sage_search.config \
  -profile docker
```

**Test data required:**
- `modules/tests/data/test_raw_1.mzML` - DDA mzML file 1
- `modules/tests/data/test_raw_2.mzML` - DDA mzML file 2
- `modules/tests/data/uniprotkb_organism_id_1314_AND_reviewed_2025_11_18.fasta` - Protein database

### EasyPQP Library Generation

Test spectral library generation from Sage search results:

```bash
nextflow run modules/tests/easypqp_library_test.nf \
  -c modules/tests/config/easypqp_library.config \
  -profile docker
```

**Test workflow:** Sage search → EasyPQP convert (TSV → pickle) → EasyPQP library (combine pickles → TSV library)

**Test data required:**
- `modules/tests/data/test_raw_1.mzML` - DDA mzML file 1
- `modules/tests/data/test_raw_2.mzML` - DDA mzML file 2
- `modules/tests/data/uniprotkb_organism_id_1314_AND_reviewed_2025_11_18.fasta` - Protein database

### PyProphet Modules

Test individual PyProphet scoring and inference modules:

```bash
# Peakgroup scoring (MS2-level)
nextflow run modules/tests/pyprophet_peakgroup_scoring_test.nf \
  -c modules/tests/config/pyprophet_tests.config \
  -profile docker

# Transition scoring (requires peakgroup scoring first)
nextflow run modules/tests/pyprophet_transition_scoring_test.nf \
  -c modules/tests/config/pyprophet_tests.config \
  -profile docker

# Peptide inference (requires scoring first)
nextflow run modules/tests/pyprophet_peptide_inference_test.nf \
  -c modules/tests/config/pyprophet_tests.config \
  -profile docker

# Protein inference (requires scoring + peptide inference)
nextflow run modules/tests/pyprophet_protein_inference_test.nf \
  -c modules/tests/config/pyprophet_tests.config \
  -profile docker
```

**Test data required:** `modules/tests/data/test_data.osw`

### Arycal Alignment Module

Test XIC-based chromatogram alignment:

```bash
nextflow run modules/tests/arycal_alignment_test.nf \
  -c modules/tests/config/arycal_alignment.config \
  -profile docker
```

**Test data required:**
- `modules/tests/data/test_chrom_1.sqMass` - XIC file 1
- `modules/tests/data/test_chrom_2.sqMass` - XIC file 2
- `modules/tests/data/test_data.osw` - Feature file (OSW format)

### OpenSwath Library Generation

Test spectral library generation from TraML:

```bash
nextflow run modules/tests/openswath_library_generation_test.nf \
  -c modules/tests/config/openswath_library_generation.config \
  -profile docker
```

**Test workflow:** TraML → OpenSwathAssayGenerator (targets) → OpenSwathDecoyGenerator (targets + decoys)

**Test data required:** `modules/tests/data/strep_iRT_small.TraML`

### FDRBench Entrapment Module

Test entrapment database generation for FDR control evaluation:

```bash
nextflow run modules/tests/fdrbench_entrapment_test.nf \
  -c modules/tests/config/fdrbench_entrapment.config \
  -profile docker
```

**Test workflow:** FASTA → FDRBench (generate shuffled entrapment sequences) → Entrapment FASTA

**Test data required:**
- `modules/tests/data/uniprotkb_organism_id_1314_AND_reviewed_2025_11_18.fasta` - Protein database

**Outputs:**
- Entrapment FASTA with shuffled sequences labeled `_p_target`
- Peptide pair mapping file (for peptide-level entrapment)
- Execution log

### OpenSwathWorkflow Module

Test feature extraction from DIA data:

```bash
nextflow run modules/tests/openswathworkflow_test.nf \
  -c modules/tests/config/openswathworkflow.config \
  -profile docker
```

**Test data required:**
- `modules/tests/data/test_raw_1.mzML` - DIA mzML file
- `modules/tests/data/test.pqp` - Spectral library (PQP format)
- `modules/tests/data/strep_win.txt` - SWATH windows file (optional)

## Configuration Files

Test configs are located in `modules/tests/config/`:

- **`sage_search.config`** - Config for Sage database search
  - Reduced missed_cleavages for faster testing
  - Wider mass tolerances for test data
  - Annotate matches enabled
  - 4 CPUs, 8GB RAM

- **`easypqp_library.config`** - Config for EasyPQP library generation
  - Includes Sage search configuration
  - MUST have `annotate_matches = true` for matched_fragments
  - Tests full workflow: Sage → convert → library
  - 4 CPUs for Sage, 2 CPUs for EasyPQP steps

- **`pyprophet_tests.config`** - Unified config for all PyProphet tests
  - Reduced iterations for faster testing
  - Lower resource requirements (2 CPUs, 4GB RAM)
  - Environment variables for Docker permissions

- **`arycal_alignment.config`** - Config for Arycal XIC alignment
  - FFT-DTW alignment method with star reference
  - Relaxed parameters for test data
  - Smaller batch size (500) and smoothing window (7)
  - 4 CPUs, 8GB RAM

- **`openswath_library_generation.config`** - Config for library generation
  - Reduced min_transitions for small test library
  - Shuffle method for decoy generation
  - 2 CPUs, 4GB RAM

- **`fdrbench_entrapment.config`** - Config for FDRBench entrapment
  - Protein-level entrapment with shuffled sequences
  - DIA-NN compatible output format
  - Fixed seed (42) for reproducible test results
  - 2 CPUs, 4GB RAM
  
- **`openswathworkflow.config`** - Config for OpenSwathWorkflow
  - Relaxed calibration thresholds for small test data
  - Standard DIA mode (non-PASEF)
  - 4 CPUs, 8GB RAM

## Container Profiles

### Docker (Recommended for local testing)

```bash
-profile docker
```

Uses: `ghcr.io/openswath/openswath:dev`

### Singularity (For HPC systems)

```bash
-profile singularity
```

## Customizing Tests

### Override Parameters

Create a custom config or edit existing configs:

```groovy
params {
  pyprophet {
    peakgroup_scoring {
      classifier = "LDA"  // Change classifier
      ss_num_iter = 5     // Adjust iterations
    }
  }
}
```

### Add Custom Arguments

Use `ext.args` in process configs:

```groovy
process {
  withName: PYPROPHET_PEAKGROUP_SCORING {
    ext.args = '--test --parametric'
  }
}
```

## Troubleshooting

### Permission Errors (DuckDB/Matplotlib)

If you see permission errors like:
```
Failed to create directory "//.duckdb": Permission denied
```

The test configs already include fixes via environment variables. If issues persist, check that your Docker setup allows the user mapping:

```bash
docker.runOptions = '-u $(id -u):$(id -g)'
```

### View Execution Logs

Check the work directory for detailed logs:

```bash
cd work/<hash>
cat .command.log
cat .command.err
cat .command.out
```

### Enable Debug Mode

```bash
nextflow run <test>.nf \
  -c <config>.config \
  -profile docker \
  -with-trace \
  -with-report \
  -with-dag dag.png
```

## Test Data Location

All test data should be placed in `modules/tests/data/`:

```
modules/tests/data/
├── test_data.osw                                         # OSW file for PyProphet/Arycal tests
├── test_chrom_1.sqMass                                   # XIC file 1 for Arycal
├── test_chrom_2.sqMass                                   # XIC file 2 for Arycal
├── test_raw_1.mzML                                       # DDA/DIA mzML file 1
├── test_raw_2.mzML                                       # DDA/DIA mzML file 2
├── test.pqp                                              # Spectral library
├── strep_iRT_small.TraML                                 # TraML for library generation
├── strep_win.txt                                         # SWATH windows definition
└── uniprotkb_organism_id_1314_AND_reviewed_2025_11_18.fasta  # Protein FASTA database
```
