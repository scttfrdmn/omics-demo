#!/bin/bash
# prepare_demo_data.sh
# Script to prepare the 1000 Genomes Project data for the 15-minute Omics Demo

set -e  # Exit on error

# Source configuration if exists
if [ -f "./config.sh" ]; then
  source ./config.sh
else
  # Configuration
  BUCKET_NAME=${1:-omics-demo-bucket}  # Use provided bucket name or default
  REGION=${2:-us-east-1}  # Use provided region or default
fi

SAMPLE_COUNT=100  # Number of samples to include
SOURCE_BUCKET="s3://1000genomes"
OUTPUT_PATH="s3://$BUCKET_NAME/input"
TEMP_DIR="./temp_data"

echo "========================================="
echo "Omics Demo Data Preparation"
echo "========================================="
echo "Target bucket: $BUCKET_NAME"
echo "Region: $REGION"
echo "Sample count: $SAMPLE_COUNT"
echo "========================================="

# Create local temp directory
mkdir -p $TEMP_DIR
cd $TEMP_DIR

echo "Creating S3 bucket if it doesn't exist..."
if ! aws s3 ls "s3://$BUCKET_NAME" 2>&1 > /dev/null; then
  aws s3 mb "s3://$BUCKET_NAME" --region $REGION
  echo "Bucket created: $BUCKET_NAME"
else
  echo "Bucket already exists: $BUCKET_NAME"
fi

echo "Retrieving sample list from 1000 Genomes Project..."
# Get list of available samples (phase 3 alignment files)
aws s3 ls --recursive "${SOURCE_BUCKET}/phase3/data/" | grep "mapped.*bam$" > all_samples.txt

# Select a random subset of low-coverage samples for the demo
echo "Selecting $SAMPLE_COUNT random samples..."
grep "low_coverage" all_samples.txt | shuf -n $SAMPLE_COUNT > selected_samples.txt

# Create a CSV file with sample information
echo "sample_id,population,bam_path" > sample_list.csv

echo "Processing sample information..."
while read -r line; do
  # Extract the file path
  filepath=$(echo "$line" | awk '{print $4}')
  
  # Extract sample ID from the file path
  sample_id=$(basename "$filepath" | cut -d '.' -f 1)
  
  # Extract population code from the sample ID (first 3 characters)
  population=${sample_id:0:3}
  
  # Add to CSV
  echo "$sample_id,$population,${SOURCE_BUCKET}/$filepath" >> sample_list.csv
done < selected_samples.txt

echo "Uploading sample list to S3..."
aws s3 cp sample_list.csv "${OUTPUT_PATH}/sample_list.csv"

# Create a manifest file for the CloudFormation template
echo "Creating resource manifest..."
cat > manifest.json << EOF
{
  "samples": {
    "count": $SAMPLE_COUNT,
    "source": "${OUTPUT_PATH}/sample_list.csv"
  },
  "reference": "${SOURCE_BUCKET}/technical/reference/human_g1k_v37.fasta.gz",
  "region": "chr20"
}
EOF

# Upload manifest
aws s3 cp manifest.json "${OUTPUT_PATH}/manifest.json"

# Create a simple metadata file with information about populations
echo "Creating population metadata..."
cat > population_info.json << EOF
{
  "populations": {
    "ACB": "African Caribbean",
    "ASW": "African Ancestry SW US",
    "BEB": "Bengali",
    "CDX": "Dai Chinese",
    "CEU": "Utah European",
    "CHB": "Han Chinese",
    "CHS": "Southern Han Chinese",
    "CLM": "Colombian",
    "ESN": "Esan Nigeria",
    "FIN": "Finnish",
    "GBR": "British",
    "GIH": "Gujarati",
    "GWD": "Gambian Mandinka",
    "IBS": "Iberian Spain",
    "ITU": "Telugu India",
    "JPT": "Japanese",
    "KHV": "Kinh Vietnamese",
    "LWK": "Luhya Kenya",
    "MSL": "Mende Sierra Leone",
    "MXL": "Mexican Ancestry",
    "PEL": "Peruvian",
    "PJL": "Punjabi Pakistan",
    "PUR": "Puerto Rican",
    "STU": "Sri Lankan Tamil",
    "TSI": "Tuscan",
    "YRI": "Yoruba Nigeria"
  }
}
EOF

# Upload population metadata
aws s3 cp population_info.json "${OUTPUT_PATH}/population_info.json"

# Calculate population distribution for our sample
echo "Calculating population distribution..."
awk -F',' 'NR>1 {pop[$2]++} END {for (p in pop) print p","pop[p]}' sample_list.csv > population_counts.csv
aws s3 cp population_counts.csv "${OUTPUT_PATH}/population_counts.csv"

# Create a README for the bucket
cat > README.md << EOF
# Omics Demo Dataset

This bucket contains data for the 15-minute Omics Demo showcasing AWS cloud capabilities for genomic analysis.

## Contents

- /input/ - Input data including sample list and metadata
- /results/ - Analysis results from the demo pipeline
- /reports/ - Cost reports and performance metrics

## Sample Information

The demo uses $SAMPLE_COUNT samples from the 1000 Genomes Project, focusing on chromosome 20 for demonstration purposes.

## Reference

The reference genome used is human_g1k_v37.fasta.gz from the 1000 Genomes Project.
EOF

aws s3 cp README.md "s3://$BUCKET_NAME/README.md"

# Create reduced reference for demo (chromosome 20 only)
echo "Preparing reference genome subset..."
aws s3 cp "${SOURCE_BUCKET}/technical/reference/human_g1k_v37.fasta.fai" ./human_g1k_v37.fasta.fai

# Extract chromosome 20 entry
grep "^20" human_g1k_v37.fasta.fai > chr20.fai

# Create a reduced reference index for demo
cat > demo_reference.fai << EOF
$(cat chr20.fai)
EOF

aws s3 cp demo_reference.fai "${OUTPUT_PATH}/demo_reference.fai"

# Create template batch job script for custom initialization
cat > batch_init.sh << EOF
#!/bin/bash
# Initialization script for AWS Batch instances

# Install any additional tools needed
apt-get update
apt-get install -y samtools bcftools

# Download reference subset if needed
mkdir -p /references
aws s3 cp ${OUTPUT_PATH}/demo_reference.fai /references/

# Pre-cache commonly used Docker images
docker pull public.ecr.aws/lts/genomics-tools:latest
docker pull public.ecr.aws/lts/kraken2-gpu:latest

# Report successful initialization
echo "Batch instance initialization complete"
EOF

aws s3 cp batch_init.sh "${OUTPUT_PATH}/batch_init.sh"

# Create a test dataset with only 5 samples for quick testing
echo "Creating test dataset..."
head -n 6 sample_list.csv > test_sample_list.csv
aws s3 cp test_sample_list.csv "${OUTPUT_PATH}/test_sample_list.csv"

# Clean up
cd ..
echo "Cleaning up temporary files..."
rm -rf $TEMP_DIR

echo "========================================="
echo "Data preparation completed successfully!"
echo "========================================="
echo "Sample list: ${OUTPUT_PATH}/sample_list.csv"
echo "Reference index: ${OUTPUT_PATH}/demo_reference.fai"
echo "Manifest: ${OUTPUT_PATH}/manifest.json"
echo ""
echo "Next steps:"
echo "1. Deploy the CloudFormation stack"
echo "2. Run a test job with 5 samples"
echo "3. Prepare for the full demo"
echo "========================================="
