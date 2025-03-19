# 15-Minute "Wow" Omics Demo on AWS

This repository contains all necessary files to run a 15-minute demo showcasing how AWS cloud resources can dramatically accelerate genomic research while optimizing costs.

## Overview

This demo processes 100 samples from the 1000 Genomes Project in parallel, performing:
- Alignment and processing of genomic data
- Variant calling on chromosome 20
- Statistical analysis of genetic variants
- Population structure analysis
- Cost comparisons between on-premises and optimized cloud approaches

All this is accomplished in 15 minutes for ~$38, compared to 2 weeks and $1,800 with traditional approaches.

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI installed and configured
- Quota increases for:
  - 256+ vCPUs for AWS Batch (on-demand and spot)
  - 4+ GPU instances (g5g.2xlarge) in your region
- Git
- Bash shell environment

## Quick Start

1. Clone this repository:
   ```
   git clone https://github.com/your-username/omics-demo.git
   cd omics-demo
   ```

2. Run the initial setup script:
   ```
   ./setup.sh your-unique-bucket-name your-aws-region
   ```

3. Prepare the genomic data:
   ```
   ./prepare_demo_data.sh
   ```

4. Deploy the AWS infrastructure:
   ```
   aws cloudformation create-stack \
     --stack-name omics-demo \
     --template-body file://cloudformation.yaml \
     --capabilities CAPABILITY_IAM \
     --parameters ParameterKey=DataBucketName,ParameterValue=your-unique-bucket-name
   ```

5. Wait for stack creation to complete (10-15 minutes):
   ```
   aws cloudformation wait stack-create-complete --stack-name omics-demo
   ```

6. Verify resources are properly configured:
   ```
   ./check_resources.sh
   ```

7. Run a test job to ensure everything works:
   ```
   ./test_demo.sh
   ```

8. When ready for your presentation, start the demo:
   ```
   ./start_demo.sh
   ```

9. If you encounter issues during the demo, reset it:
   ```
   ./reset_demo.sh
   ```

10. Open the dashboard URL printed by the start_demo.sh script to monitor progress.

## Demo "Wow" Factors

- **Speed**: Processes 100 genomic samples and calls variants in just 15 minutes
- **Scale**: Analyzes thousands of genetic variants across multiple samples simultaneously
- **Visual Insights**: Interactive visualizations of variant distributions and population structure
- **Cost Efficiency**: 98% cost reduction compared to traditional on-premises approach
- **Scalability**: Automatically scales from 0 to 256 vCPUs based on workload

## Genomic Analysis Components

1. **Pre-processing**:
   - Reference genome preparation
   - BAM file processing

2. **Variant Calling**:
   - bcftools for genomic variant identification
   - Merge sample variants into cohort VCF

3. **Statistical Analysis**:
   - Transition/transversion ratio calculation
   - Variant annotation and effect prediction

4. **Population Analysis**:
   - Population structure visualization
   - Relatedness calculation

## AWS Components Used

- **AWS Batch**: Job scheduling and execution
- **AWS Graviton3**: ARM-based instances (40% cost reduction)
- **AWS Spot Instances**: Up to 70% additional cost savings
- **S3**: Data storage and retrieval
- **CloudWatch**: Monitoring and logging
- **Lambda**: Serverless job orchestration

## Cleanup

To delete all AWS resources and avoid ongoing charges:
```
aws cloudformation delete-stack --stack-name omics-demo
```

## Citation

If you use this demo in your research or presentations, please cite:
- 1000 Genomes Project Consortium. A global reference for human genetic variation. Nature 526, 68–74 (2015).
- Li H. (2011) A statistical framework for SNP calling, mutation discovery, association mapping and population genetical parameter estimation from sequencing data. Bioinformatics. 27(21):2987-93.
