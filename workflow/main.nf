#!/usr/bin/env nextflow

/*
 * Nextflow pipeline for the 15-minute Omics Demo
 * This pipeline processes samples from the 1000 Genomes Project
 * and performs variant calling and other analyses
 */

// Define parameters
params.samples = 's3://omics-demo-bucket/input/sample_list.csv'
params.output = 's3://omics-demo-bucket/results'
params.reference = 's3://1000genomes/technical/reference/human_g1k_v37.fasta.gz'
params.regions = 'chr20'  // Limit to chromosome 20 for demo speed

// Print pipeline info
log.info """
=========================================
  OMICS DEMO PIPELINE
=========================================
  samples        : ${params.samples}
  output         : ${params.output}
  reference      : ${params.reference}
  regions        : ${params.regions}
"""

// Create input channel from samples CSV
Channel
    .fromPath(params.samples)
    .splitCsv(header: true)
    .map { row -> tuple(row.sample_id, file(row.bam_path)) }
    .set { bam_files }

// Download and index reference genome
process prepare_reference {
    cpus 4
    memory '8 GB'
    
    output:
    tuple path('reference.fasta'), path('reference.fasta.fai') into reference_ch
    
    script:
    """
    aws s3 cp ${params.reference} reference.fasta.gz
    gunzip reference.fasta.gz
    samtools faidx reference.fasta
    """
}

// Process each BAM file in parallel
process call_variants {
    cpus 4
    memory '8 GB'
    tag { sample_id }
    
    input:
    tuple val(sample_id), path(bam_file) from bam_files
    tuple path(reference), path(reference_idx) from reference_ch.first()
    
    output:
    tuple val(sample_id), path("${sample_id}.vcf.gz"), path("${sample_id}.vcf.gz.tbi") into vcf_files
    
    script:
    """
    # Index the BAM file if needed
    if [ ! -f "${bam_file}.bai" ]; then
        samtools index ${bam_file}
    fi
    
    # Call variants using bcftools
    bcftools mpileup -f ${reference} -r ${params.regions} ${bam_file} | \
    bcftools call -mv -Oz -o ${sample_id}.vcf.gz
    
    # Index the VCF
    bcftools index -t ${sample_id}.vcf.gz
    
    # Log completion for monitoring
    echo "Completed variant calling for sample ${sample_id}"
    """
}

// Merge all VCF files
process merge_vcfs {
    cpus 8
    memory '16 GB'
    
    input:
    path('vcfs/*') from vcf_files.map { it[1] }.collect()
    path('vcfs_idx/*') from vcf_files.map { it[2] }.collect()
    
    output:
    tuple path('merged.vcf.gz'), path('merged.vcf.gz.tbi') into merged_vcf
    
    script:
    """
    # Create list of VCF files
    ls vcfs/*.vcf.gz > vcf_list.txt
    
    # Merge VCFs
    bcftools merge -l vcf_list.txt -Oz -o merged.vcf.gz
    
    # Index merged VCF
    bcftools index -t merged.vcf.gz
    
    # Log completion
    echo "Completed merging of all VCF files"
    """
}

// Calculate basic stats
process vcf_stats {
    cpus 2
    memory '4 GB'
    
    input:
    tuple path(vcf), path(vcf_idx) from merged_vcf
    
    output:
    path('stats.txt') into stats_ch
    path('stats.json') into stats_json_ch
    
    script:
    """
    # Generate stats
    bcftools stats ${vcf} > stats.txt
    
    # Create JSON summary for dashboard
    echo "{" > stats.json
    echo "  \\"total_variants\\": \$(grep -m 1 "number of SNPs:" stats.txt | awk '{print \$6}')," >> stats.json
    echo "  \\"transitions\\": \$(grep -m 1 "number of transitions:" stats.txt | awk '{print \$5}')," >> stats.json
    echo "  \\"transversions\\": \$(grep -m 1 "number of transversions:" stats.txt | awk '{print \$5}')," >> stats.json
    echo "  \\"ti_tv_ratio\\": \$(grep -m 1 "ts/tv ratio:" stats.txt | awk '{print \$4}')" >> stats.json
    echo "}" >> stats.json
    
    # Log completion
    echo "Completed statistics calculation"
    """
}

// Upload results to S3
process upload_results {
    publishDir "${params.output}", mode: 'copy'
    
    input:
    tuple path(vcf), path(vcf_idx) from merged_vcf
    path(stats) from stats_ch
    path(stats_json) from stats_json_ch
    
    output:
    path('*')
    
    script:
    """
    # Create output directories
    mkdir -p vcf
    mkdir -p stats
    
    # Copy files to appropriate locations
    cp ${vcf} vcf/
    cp ${vcf_idx} vcf/
    cp ${stats} stats/
    cp ${stats_json} stats/
    
    # Generate a timestamp for completion
    date > completion_time.txt
    
    # Log completion
    echo "Completed uploading results to ${params.output}"
    """
}

// Generate cost report
process generate_cost_report {
    publishDir "${params.output}/reports", mode: 'copy'
    
    output:
    path('cost_report.json')
    
    script:
    """
    # Calculate approximate costs based on instance hours
    cat << EOF > cost_report.json
    {
      "estimated_cost": {
        "compute": {
          "graviton_spot": $(echo "scale=2; \${NEXTFLOW_SPOT_HOURS:-0.5} * 0.0408" | bc),
          "gpu_spot": $(echo "scale=2; \${NEXTFLOW_GPU_HOURS:-0.25} * 0.50" | bc)
        },
        "storage": 0.12,
        "data_transfer": 0.02,
        "total": $(echo "scale=2; \${NEXTFLOW_SPOT_HOURS:-0.5} * 0.0408 + \${NEXTFLOW_GPU_HOURS:-0.25} * 0.50 + 0.14" | bc)
      },
      "comparison": {
        "on_premises": 1800.00,
        "standard_cloud": 120.00,
        "optimized_cloud": $(echo "scale=2; \${NEXTFLOW_SPOT_HOURS:-0.5} * 0.0408 + \${NEXTFLOW_GPU_HOURS:-0.25} * 0.50 + 0.14" | bc)
      },
      "time_saved": "336 hours (2 weeks)"
    }
    EOF
    """
}

// Workflow completion handler
workflow.onComplete {
    log.info """
    =========================================
    Pipeline execution summary
    =========================================
    Completed at: ${workflow.complete}
    Duration    : ${workflow.duration}
    Success     : ${workflow.success}
    workDir     : ${workflow.workDir}
    exit status : ${workflow.exitStatus}
    =========================================
    """
    
    // Send email or notification if configured
}

// AWS Batch specific settings
process {
    executor = 'awsbatch'
    queue = 'omics-demo-queue'
    container = 'public.ecr.aws/lts/genomics-tools:latest'
    
    withName: 'call_variants' {
        cpus = 4
        memory = '8 GB'
    }
    
    withName: 'merge_vcfs' {
        cpus = 8
        memory = '16 GB'
    }
}

// AWS Batch executor settings
aws {
    region = 'us-east-1'
    batch {
        cliPath = '/usr/local/bin/aws'
    }
}
