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
  #!/usr/bin/env python3
  import pandas as pd
  import sys

  # Combine PSM results
  print("Reading DDA results from ${dda_results}...")
  dda_df = pd.read_csv("${dda_results}", sep='\\t')
  print(f"DDA results: {len(dda_df)} rows")
  
  print("Reading DIA results from ${dia_results}...")
  dia_df = pd.read_csv("${dia_results}", sep='\\t')
  print(f"DIA results: {len(dia_df)} rows")
  
  # Combine results
  combined_df = pd.concat([dda_df, dia_df], ignore_index=True)
  print(f"Combined results: {len(combined_df)} rows")
  
  # Save combined results
  combined_df.to_csv("combined_results.sage.tsv", sep='\\t', index=False)
  print(f"Saved combined results to combined_results.sage.tsv")
  
  # Combine matched fragments
  print("\\nReading DDA matched fragments from ${dda_fragments}...")
  dda_frag_df = pd.read_csv("${dda_fragments}", sep='\\t')
  print(f"DDA matched fragments: {len(dda_frag_df)} rows")
  
  print("Reading DIA matched fragments from ${dia_fragments}...")
  dia_frag_df = pd.read_csv("${dia_fragments}", sep='\\t')
  print(f"DIA matched fragments: {len(dia_frag_df)} rows")
  
  # Combine fragments
  combined_frag_df = pd.concat([dda_frag_df, dia_frag_df], ignore_index=True)
  print(f"Combined matched fragments: {len(combined_frag_df)} rows")
  
  # Save combined fragments
  combined_frag_df.to_csv("combined_matched_fragments.sage.tsv", sep='\\t', index=False)
  print(f"Saved combined matched fragments to combined_matched_fragments.sage.tsv")
  
  print("\\nDone!")
  """ > sage_combine_results.log 2>&1
  
  python3 -c "
import pandas as pd

# Combine PSM results
print('Reading DDA results from ${dda_results}...')
dda_df = pd.read_csv('${dda_results}', sep='\\t')
print(f'DDA results: {len(dda_df)} rows')

print('Reading DIA results from ${dia_results}...')
dia_df = pd.read_csv('${dia_results}', sep='\\t')
print(f'DIA results: {len(dia_df)} rows')

# Combine results
combined_df = pd.concat([dda_df, dia_df], ignore_index=True)
print(f'Combined results: {len(combined_df)} rows')

# Save combined results
combined_df.to_csv('combined_results.sage.tsv', sep='\\t', index=False)
print(f'Saved combined results to combined_results.sage.tsv')

# Combine matched fragments
print('\\nReading DDA matched fragments from ${dda_fragments}...')
dda_frag_df = pd.read_csv('${dda_fragments}', sep='\\t')
print(f'DDA matched fragments: {len(dda_frag_df)} rows')

print('Reading DIA matched fragments from ${dia_fragments}...')
dia_frag_df = pd.read_csv('${dia_fragments}', sep='\\t')
print(f'DIA matched fragments: {len(dia_frag_df)} rows')

# Combine fragments
combined_frag_df = pd.concat([dda_frag_df, dia_frag_df], ignore_index=True)
print(f'Combined matched fragments: {len(combined_frag_df)} rows')

# Save combined fragments
combined_frag_df.to_csv('combined_matched_fragments.sage.tsv', sep='\\t', index=False)
print(f'Saved combined matched fragments to combined_matched_fragments.sage.tsv')

print('\\nDone!')
" 2>&1 | tee sage_combine_results.log
  """
}
