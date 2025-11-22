process SAGE_COMBINE_RESULTS {
  tag "sage_combine_results"
  label 'process_low'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }"

  publishDir "${params.outdir}/sage", mode: params.publish_dir_mode, enabled: params.save_intermediates, pattern: "combined_*.sage.tsv"
  publishDir "${params.outdir}/logs/sage", mode: params.publish_dir_mode, enabled: params.save_logs, pattern: "*.log"

  input:
  tuple val(sample_id), path(dda_results), path(dia_results), path(dda_fragments), path(dia_fragments)

  output:
  tuple val(sample_id), path("combined_results.sage.tsv"), emit: results
  tuple val(sample_id), path("combined_matched_fragments.sage.tsv"), emit: matched_fragments
  path "*.log", emit: log

  script:
  """
  python3 <<'PY'
import pandas as pd
from datetime import datetime, timezone

def now_iso():
    return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

# Combine PSM results
print('Reading DDA results from ${dda_results}...')
dda_df = pd.read_csv('${dda_results}', sep='\t')
print(f'DDA results: {len(dda_df)} rows')

print('Reading DIA results from ${dia_results}...')
dia_df = pd.read_csv('${dia_results}', sep='\t')
print(f'DIA results: {len(dia_df)} rows')

# Combine results
combined_df = pd.concat([dda_df, dia_df], ignore_index=True)
print(f'Combined results: {len(combined_df)} rows')

# Save combined results
combined_df.to_csv('combined_results.sage.tsv', sep='\t', index=False)
print(f'Saved combined results to combined_results.sage.tsv')

# Compute Sage-style summary counts at 1% FDR
try:
    # target PSMs at 1% (spectrum_q)
    psm_count = int(combined_df[(combined_df.get('label') == 'target') & (combined_df.get('spectrum_q') <= 0.01)].shape[0])
except Exception:
    psm_count = 0

try:
    peptides = combined_df[(combined_df.get('label') == 'target') & (combined_df.get('peptide_q') <= 0.01)]['peptide'].dropna().unique()
    peptide_count = int(len(peptides))
except Exception:
    peptide_count = 0

try:
    prot_rows = combined_df[(combined_df.get('label') == 'target') & (combined_df.get('protein_q') <= 0.01)]['proteins'].dropna()
    proteins_set = set()
    for s in prot_rows:
        for p in str(s).split(';'):
            p = p.strip()
            if p:
                proteins_set.add(p)
    protein_count = int(len(proteins_set))
except Exception:
    protein_count = 0

print(f"[{now_iso()} INFO  combined sage] discovered {psm_count} target peptide-spectrum matches at 1% FDR")
print(f"[{now_iso()} INFO  combined sage] discovered {peptide_count} target peptides at 1% FDR")
print(f"[{now_iso()} INFO  combined sage] discovered {protein_count} target proteins at 1% FDR")

# Combine matched fragments
print('\nReading DDA matched fragments from ${dda_fragments}...')
dda_frag_df = pd.read_csv('${dda_fragments}', sep='\t')
print(f'DDA matched fragments: {len(dda_frag_df)} rows')

print('Reading DIA matched fragments from ${dia_fragments}...')
dia_frag_df = pd.read_csv('${dia_fragments}', sep='\t')
print(f'DIA matched fragments: {len(dia_frag_df)} rows')

# Combine fragments
combined_frag_df = pd.concat([dda_frag_df, dia_frag_df], ignore_index=True)
print(f'Combined matched fragments: {len(combined_frag_df)} rows')

# Save combined fragments
combined_frag_df.to_csv('combined_matched_fragments.sage.tsv', sep='\t', index=False)
print(f'Saved combined matched fragments to combined_matched_fragments.sage.tsv')

print('\nDone!')
PY 2>&1 | tee sage_combine_results.log
  """
}
