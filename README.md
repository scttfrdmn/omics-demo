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
- Python 3.6+ with pip
- Node.js 14+ and npm (for the dashboard)

## Detailed Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/omics-demo.git
cd omics-demo
```

### 2. Environment Setup

The demo consists of three main components:
- **Nextflow Workflow**: Handles genomic processing
- **Backend API**: Provides secure access to AWS resources
- **Dashboard**: Visualizes progress and results

Set up the environment with:

```bash
./setup.sh your-unique-bucket-name your-aws-region
```

This script:
- Creates a dedicated S3 bucket for the demo
- Generates a configuration file
- Sets up the directory structure
- Installs Python dependencies
- Validates AWS permissions

### 3. Install Dependencies

#### Python Dependencies

The setup script will try to install Python dependencies, but you can also do this manually:

```bash
pip3 install -r requirements.txt
```

#### Node.js Dependencies

For the dashboard:

```bash
cd dashboard
npm install
```

### 4. Prepare Demo Data

```bash
./prepare_demo_data.sh
```

This script will:
- Download sample data from the 1000 Genomes Project
- Process and upload it to your S3 bucket
- Prepare the necessary reference files

### 5. Deploy AWS Infrastructure

```bash
aws cloudformation create-stack \
  --stack-name omics-demo \
  --template-body file://cloudformation.yaml \
  --capabilities CAPABILITY_IAM \
  --parameters ParameterKey=DataBucketName,ParameterValue=your-unique-bucket-name
```

Wait for stack creation to complete (10-15 minutes):

```bash
aws cloudformation wait stack-create-complete --stack-name omics-demo
```

### 6. Start the Backend API

The backend API provides a secure interface to AWS resources for the dashboard:

```bash
./start_api.sh
```

The API will be available at http://localhost:5000.

### 7. Start the Dashboard

```bash
cd dashboard
npm start
```

The dashboard will be available at http://localhost:3000.

### 8. Run a Test Job

Verify that everything works:

```bash
./test_demo.sh
```

This runs a small subset of samples to ensure the pipeline and infrastructure are functioning correctly.

### 9. Run the Full Demo

When ready for your presentation:

```bash
./start_demo.sh
```

Open the dashboard in your browser to monitor progress.

### 10. Reset the Demo (if needed)

If you encounter issues during the demo:

```bash
./reset_demo.sh
```

## Architecture Details

### Workflow Engine

The genomic analysis pipeline is implemented using Nextflow, which:
- Manages workflow dependencies
- Handles error recovery
- Provides detailed execution reports
- Integrates with AWS Batch for scaled computing

Key processes in the workflow:
1. Reference genome preparation
2. Parallel variant calling on 100 samples
3. Variant merging and statistical analysis
4. Report generation

### AWS Components

- **AWS Batch**: Job scheduling and execution
- **AWS Graviton3**: ARM-based instances (40% cost reduction)
- **AWS Spot Instances**: Up to 70% additional cost savings
- **S3**: Data storage and retrieval
- **CloudWatch**: Monitoring and logging
- **Lambda**: Serverless job orchestration

### Dashboard

The React-based dashboard provides:
- Real-time progress tracking
- Resource utilization graphs
- Cost analysis with comparison to traditional approaches
- Interactive visualizations of genomic data
- Error notifications

### Backend API

The Flask-based API secures AWS interactions by:
- Handling authentication and authorization
- Preventing exposure of credentials
- Providing standardized endpoints for status and results
- Implementing retry logic and error handling

## Cost Optimization Details

This demo showcases several AWS cost optimization techniques:
- Using Graviton3 ARM processors (30-40% cheaper than x86)
- Leveraging Spot instances (up to 70% discount from On-Demand)
- Optimizing storage costs with lifecycle policies
- Using containerized workloads for maximum efficiency
- Scaling to zero when not in use

## Troubleshooting

### Common Issues

1. **AWS Permissions**: Ensure your AWS user has appropriate permissions for CloudFormation, IAM, S3, Batch, and EC2.

2. **S3 Bucket Naming**: If bucket creation fails, try a different bucket name (they must be globally unique).

3. **Quota Limits**: You may need to request quota increases for AWS Batch compute and GPU instances.

4. **Dashboard Connection Issues**: If the dashboard can't connect to the API, check that the API server is running and accessible.

5. **AWS Batch Failures**: Use the CloudWatch Logs (accessible from the AWS Management Console) to diagnose Batch job issues.

### Logs

- **API Logs**: Check `setup.log` in the project root directory
- **Dashboard Logs**: Available in the browser developer console
- **AWS Batch Job Logs**: Available in CloudWatch Logs
- **Pipeline Logs**: Available in S3 at `s3://your-bucket-name/results/logs`

## Cleanup

To delete all AWS resources and avoid ongoing charges:
```bash
aws cloudformation delete-stack --stack-name omics-demo
```

Additionally, empty and delete the S3 bucket:
```bash
aws s3 rm s3://your-bucket-name --recursive
aws s3 rb s3://your-bucket-name
```

## Customization

You can customize various aspects of the demo:
- Change the number of samples in `config.sh`
- Modify genomic regions in `workflow/nextflow.config`
- Adjust compute resources in `cloudformation.yaml`
- Change visualization options in the dashboard

## Citation

If you use this demo in your research or presentations, please cite:
- 1000 Genomes Project Consortium. A global reference for human genetic variation. Nature 526, 68–74 (2015).
- Li H. (2011) A statistical framework for SNP calling, mutation discovery, association mapping and population genetical parameter estimation from sequencing data. Bioinformatics. 27(21):2987-93.