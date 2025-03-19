# 15-Minute "Wow" Omics Demo on AWS

This repository contains all necessary files to run a 15-minute demo showcasing how AWS cloud resources can dramatically accelerate genomics research while optimizing costs.

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI installed and configured
- Git
- Bash shell environment

## Quick Start

1. Clone this repository:
git clone https://github.com/your-username/omics-demo.git
cd omics-demo

2. Run the initial setup script:
./setup.sh your-unique-bucket-name your-aws-region

3. Prepare the demo data:
./prepare_demo_data.sh

4. Deploy the AWS infrastructure:
aws cloudformation create-stack 
--stack-name omics-demo 
--template-body file://cloudformation.yaml 
--capabilities CAPABILITY_IAM 
--parameters ParameterKey=DataBucketName,ParameterValue=your-unique-bucket-name

5. Wait for stack creation to complete (10-15 minutes):
aws cloudformation wait stack-create-complete --stack-name omics-demo

6. Run a test job:
./test_demo.sh

7. When ready for your presentation, start the demo:
./start_demo.sh

8. Open the dashboard URL printed by the script to monitor progress.

## Cleanup

To delete all AWS resources and avoid ongoing charges:
aws cloudformation delete-stack --stack-name omics-demo
Copy
For more detailed information, see the complete documentation in `docs/`.

