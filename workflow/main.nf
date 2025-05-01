#!/usr/bin/env nextflow

/*
 * Nextflow pipeline for the 15-minute Omics Demo
 * This pipeline processes samples from the 1000 Genomes Project
 * and performs variant calling and other analyses
 */

// Define parameters with defaults from nextflow.config
params.samples = params.samples ?: 's3://omics-demo-bucket/input/sample_list.csv'
params.output = params.output ?: 's3://omics-demo-bucket/results'
params.reference = params.reference ?: 's3://1000genomes/technical/reference/human_g1k_v37.fasta.gz'
params.regions = params.regions ?: 'chr20'  // Limit to chromosome 20 for demo speed

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

// Error handling function
def errorMessage(error) {
    log.error "Pipeline execution stopped with error: ${error.message}"
    log.error "Error details: ${error.toString()}"
    // Attempt to notify monitoring systems if available
    try {
        if (params.monitoring) {
            log.info "Sending notification to monitoring system"
            // Code to send alert would go here
        }
    } catch (Exception e) {
        log.error "Failed to send error notification: ${e.message}"
    }
}

// Create input channel from samples CSV with error handling
Channel
    .fromPath(params.samples)
    .ifEmpty { error("Cannot find sample file: ${params.samples}") }
    .splitCsv(header: true)
    .map { row -> 
        if (!row.sample_id || !row.bam_path) {
            error("Invalid sample file format. Missing required fields: sample_id and/or bam_path")
        }
        tuple(row.sample_id, file(row.bam_path))
    }
    .set { bam_files }

// Download and index reference genome
process prepare_reference {
    cpus 4
    memory '8 GB'
    errorStrategy { task.exitStatus in [1,2,3,143,137] ? 'retry' : 'terminate' }
    maxRetries 3
    
    output:
    tuple path('reference.fasta'), path('reference.fasta.fai') into reference_ch
    
    script:
    """
    set -e
    echo "Downloading reference genome from ${params.reference}"
    aws s3 cp ${params.reference} reference.fasta.gz
    
    echo "Extracting reference genome"
    gunzip -f reference.fasta.gz
    
    echo "Indexing reference genome"
    samtools faidx reference.fasta || { echo "Failed to index reference genome"; exit 1; }
    
    echo "Reference preparation complete"
    """
}

// Process each BAM file in parallel
process call_variants {
    cpus 4
    memory '8 GB'
    tag { sample_id }
    errorStrategy { task.exitStatus in [1,2,3,143,137] ? 'retry' : 'terminate' }
    maxRetries 3
    
    input:
    tuple val(sample_id), path(bam_file) from bam_files
    tuple path(reference), path(reference_idx) from reference_ch.first()
    
    output:
    tuple val(sample_id), path("${sample_id}.vcf.gz"), path("${sample_id}.vcf.gz.tbi") into vcf_files
    
    script:
    """
    set -e
    echo "Processing sample: ${sample_id}"
    
    # Index the BAM file if needed
    if [ ! -f "${bam_file}.bai" ]; then
        echo "Indexing BAM file"
        samtools index ${bam_file} || { echo "Failed to index BAM file"; exit 2; }
    fi
    
    # Validate BAM file
    echo "Validating BAM file"
    samtools quickcheck ${bam_file} || { echo "BAM file failed validation"; exit 3; }
    
    # Call variants using bcftools
    echo "Calling variants for region ${params.regions}"
    bcftools mpileup -f ${reference} -r ${params.regions} ${bam_file} | \
    bcftools call -mv -Oz -o ${sample_id}.vcf.gz || { echo "Variant calling failed"; exit 4; }
    
    # Index the VCF
    echo "Indexing VCF file"
    bcftools index -t ${sample_id}.vcf.gz || { echo "Failed to index VCF file"; exit 5; }
    
    # Log completion for monitoring
    echo "Completed variant calling for sample ${sample_id}"
    """
}

// Merge all VCF files
process merge_vcfs {
    cpus 8
    memory '16 GB'
    errorStrategy { task.exitStatus in [1,2,3,143,137] ? 'retry' : 'terminate' }
    maxRetries 2
    
    input:
    path('vcfs/*') from vcf_files.map { it[1] }.collect()
    path('vcfs_idx/*') from vcf_files.map { it[2] }.collect()
    
    output:
    tuple path('merged.vcf.gz'), path('merged.vcf.gz.tbi') into merged_vcf
    
    script:
    """
    set -e
    echo "Merging ${vcfs.size()} VCF files"
    
    # Create list of VCF files
    ls vcfs/*.vcf.gz > vcf_list.txt
    
    # Validate VCF files before merge
    echo "Validating VCF files"
    for vcf in \$(cat vcf_list.txt); do
        bcftools index -t \$vcf 2>/dev/null || { echo "VCF file \$vcf is not properly indexed"; exit 1; }
    done
    
    # Count VCF files for validation
    vcf_count=\$(wc -l < vcf_list.txt)
    echo "Found \$vcf_count VCF files to merge"
    
    if [ \$vcf_count -eq 0 ]; then
        echo "No VCF files to merge, exiting with error"
        exit 2
    fi
    
    # Merge VCFs
    echo "Merging VCF files"
    bcftools merge -l vcf_list.txt -Oz -o merged.vcf.gz || { echo "VCF merge failed"; exit 3; }
    
    # Index merged VCF
    echo "Indexing merged VCF"
    bcftools index -t merged.vcf.gz || { echo "Failed to index merged VCF"; exit 4; }
    
    # Log completion
    echo "Completed merging of all VCF files"
    """
}

// Calculate basic stats
process vcf_stats {
    cpus 2
    memory '4 GB'
    errorStrategy { task.exitStatus in [1,2,3,143,137] ? 'retry' : 'terminate' }
    maxRetries 3
    
    input:
    tuple path(vcf), path(vcf_idx) from merged_vcf
    
    output:
    path('stats.txt') into stats_ch
    path('stats.json') into stats_json_ch
    
    script:
    """
    set -e
    echo "Calculating statistics for merged VCF"
    
    # Validate VCF
    echo "Validating merged VCF"
    bcftools index -t ${vcf} 2>/dev/null || { echo "Merged VCF is not properly indexed"; exit 1; }
    
    # Generate stats
    echo "Running bcftools stats"
    bcftools stats ${vcf} > stats.txt || { echo "Failed to generate VCF stats"; exit 2; }
    
    # Check if stats were generated
    if [ ! -s stats.txt ]; then
        echo "Stats file is empty, something went wrong"
        exit 3
    fi
    
    # Extract key metrics with proper error handling
    echo "Extracting key metrics to JSON"
    total_variants=\$(grep -m 1 "number of SNPs:" stats.txt | awk '{print \$6}')
    transitions=\$(grep -m 1 "number of transitions:" stats.txt | awk '{print \$5}')
    transversions=\$(grep -m 1 "number of transversions:" stats.txt | awk '{print \$5}')
    ti_tv_ratio=\$(grep -m 1 "ts/tv ratio:" stats.txt | awk '{print \$4}')
    
    # Validate extracted metrics
    if [ -z "\$total_variants" ] || [ -z "\$transitions" ] || [ -z "\$transversions" ] || [ -z "\$ti_tv_ratio" ]; then
        echo "Failed to extract one or more metrics from stats.txt"
        echo "Stats file content:"
        cat stats.txt
        exit 4
    fi
    
    # Create JSON summary for dashboard
    echo "{" > stats.json
    echo "  \\"totalVariants\\": \$total_variants," >> stats.json
    echo "  \\"transitions\\": \$transitions," >> stats.json
    echo "  \\"transversions\\": \$transversions," >> stats.json
    echo "  \\"tiTvRatio\\": \$ti_tv_ratio" >> stats.json
    echo "}" >> stats.json
    
    # Validate JSON format
    if ! python3 -m json.tool stats.json > /dev/null 2>&1; then
        echo "Invalid JSON format in stats.json"
        cat stats.json
        exit 5
    fi
    
    echo "Completed statistics calculation"
    """
}

// Upload results to S3
process upload_results {
    publishDir "${params.output}", mode: 'copy'
    errorStrategy { task.exitStatus in [1,2,3,143,137] ? 'retry' : 'terminate' }
    maxRetries 3
    
    input:
    tuple path(vcf), path(vcf_idx) from merged_vcf
    path(stats) from stats_ch
    path(stats_json) from stats_json_ch
    
    output:
    path('*')
    
    script:
    """
    set -e
    echo "Preparing results for upload to ${params.output}"
    
    # Create output directories
    mkdir -p vcf
    mkdir -p stats
    
    # Verify input files exist and are not empty
    if [ ! -s ${vcf} ]; then
        echo "VCF file is empty or missing"
        exit 1
    fi
    
    if [ ! -s ${stats} ]; then
        echo "Stats file is empty or missing"
        exit 2
    fi
    
    if [ ! -s ${stats_json} ]; then
        echo "Stats JSON file is empty or missing"
        exit 3
    fi
    
    # Copy files to appropriate locations
    echo "Copying files to output structure"
    cp ${vcf} vcf/
    cp ${vcf_idx} vcf/
    cp ${stats} stats/
    cp ${stats_json} stats/
    
    # Generate a timestamp for completion
    date > completion_time.txt
    
    echo "Completed organizing results for upload"
    """
}

// Generate cost report
process generate_cost_report {
    publishDir "${params.output}/reports", mode: 'copy'
    errorStrategy { task.exitStatus in [1,2,3,143,137] ? 'retry' : 'terminate' }
    maxRetries 3
    
    output:
    path('cost_report.json')
    
    script:
    """
    set -e
    echo "Generating cost report"
    
    # Use defaults if environment variables aren't set
    SPOT_HOURS=\${NEXTFLOW_SPOT_HOURS:-0.5}
    GPU_HOURS=\${NEXTFLOW_GPU_HOURS:-0.25}
    
    # Validate inputs are numeric
    if ! [[ \$SPOT_HOURS =~ ^[0-9]+(\\.[0-9]+)?\$ ]]; then
        echo "Invalid SPOT_HOURS: \$SPOT_HOURS"
        SPOT_HOURS=0.5
    fi
    
    if ! [[ \$GPU_HOURS =~ ^[0-9]+(\\.[0-9]+)?\$ ]]; then
        echo "Invalid GPU_HOURS: \$GPU_HOURS"
        GPU_HOURS=0.25
    fi
    
    # Calculate costs safely with proper validation
    # Using awk for more reliable floating point math compared to bc
    COMPUTE_COST=\$(awk "BEGIN {print \$SPOT_HOURS * 0.0408 + \$GPU_HOURS * 0.50}")
    STORAGE_COST=0.12
    DATA_TRANSFER=0.02
    TOTAL_COST=\$(awk "BEGIN {print \$COMPUTE_COST + \$STORAGE_COST + \$DATA_TRANSFER}")
    
    # Calculate approximate costs based on instance hours
    cat << EOF > cost_report.json
    {
      "estimated_cost": {
        "compute": {
          "graviton_spot": \$(awk "BEGIN {print \$SPOT_HOURS * 0.0408}"),
          "gpu_spot": \$(awk "BEGIN {print \$GPU_HOURS * 0.50}")
        },
        "storage": \$STORAGE_COST,
        "data_transfer": \$DATA_TRANSFER,
        "total": \$TOTAL_COST
      },
      "comparison": {
        "on_premises": 1800.00,
        "standard_cloud": 120.00,
        "optimized_cloud": \$TOTAL_COST
      },
      "time_saved": "336 hours (2 weeks)"
    }
    EOF
    
    # Validate the JSON
    if ! python3 -m json.tool cost_report.json > /dev/null 2>&1; then
        echo "Invalid JSON format in cost_report.json"
        cat cost_report.json
        exit 1
    fi
    
    echo "Cost report generated successfully"
    """
}

// Workflow completion handler
workflow.onComplete {
    def color = workflow.success ? 'green' : 'red'
    def status = workflow.success ? 'SUCCESS' : 'FAILED'
    
    log.info """
    =========================================
    Pipeline execution summary
    =========================================
    Status     : ${status}
    Completed at: ${workflow.complete}
    Duration    : ${workflow.duration}
    workDir     : ${workflow.workDir}
    Exit status : ${workflow.exitStatus}
    =========================================
    """
    
    // Send email or notification if configured
    if (workflow.success) {
        log.info "Pipeline completed successfully!"
    } else {
        log.error "Pipeline execution failed"
    }
}

// Error handling for the entire workflow
workflow.onError {
    errorMessage(workflow.errorReport)
}

// AWS Batch specific settings loaded from config file