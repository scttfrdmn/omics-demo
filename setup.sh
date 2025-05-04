#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright 2025 Scott Friedman, All Rights Reserved.
# setup.sh - Initial setup for the omics demo

set -e  # Exit on error

# Process command line arguments
BUCKET_NAME=${1:-omics-demo-bucket-$(LC_CTYPE=C tr -dc 'a-z0-9' < /dev/urandom | fold -w 10 | head -n 1)}
REGION=${2:-us-east-1}
AWS_PROFILE=${3:-default}

# Script constants
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"
LOG_FILE="${SCRIPT_DIR}/setup.log"

# Function for logging
log() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" | tee -a "${LOG_FILE}"
}

# Function to check for required tools
check_requirements() {
    log "Checking requirements..."
    
    # Check for AWS CLI
    if ! command -v aws &> /dev/null; then
        log "Error: AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS CLI configuration
    if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &>/dev/null; then
        log "Error: AWS CLI not configured correctly for profile '$AWS_PROFILE'. Please run 'aws configure --profile $AWS_PROFILE' first."
        exit 1
    fi
    
    # Check for other required tools
    for cmd in python3 pip3 curl jq; do
        if ! command -v $cmd &> /dev/null; then
            log "Warning: $cmd is not installed. Some features may not work correctly."
        fi
    done
    
    log "Requirements check completed."
}

# Create required directories
create_directories() {
    log "Creating required directories..."
    
    # Create directories as needed
    mkdir -p "${SCRIPT_DIR}/dashboard/css"
    mkdir -p "${SCRIPT_DIR}/dashboard/js"
    mkdir -p "${SCRIPT_DIR}/dashboard/src/components"
    mkdir -p "${SCRIPT_DIR}/dashboard/src/services"
    mkdir -p "${SCRIPT_DIR}/dashboard/public"
    mkdir -p "${SCRIPT_DIR}/workflow/templates"
    mkdir -p "${SCRIPT_DIR}/api"
    
    log "Directory structure created."
}

# Create S3 bucket with error handling
create_s3_bucket() {
    log "Setting up S3 bucket: $BUCKET_NAME"
    
    # Check if bucket exists
    if aws s3 ls "s3://$BUCKET_NAME" --profile "$AWS_PROFILE" 2>&1 > /dev/null; then
        log "Bucket already exists: $BUCKET_NAME"
    else
        # Create the bucket
        log "Creating S3 bucket: $BUCKET_NAME in $REGION using profile $AWS_PROFILE"
        
        if [[ "$REGION" == "us-east-1" ]]; then
            # Special case for us-east-1 which doesn't use LocationConstraint
            aws s3api create-bucket --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" || {
                log "Error: Failed to create bucket. Please check AWS permissions or try a different name."
                exit 1
            }
        else
            # Use LocationConstraint for other regions
            aws s3api create-bucket --bucket "$BUCKET_NAME" \
                --create-bucket-configuration LocationConstraint="$REGION" \
                --profile "$AWS_PROFILE" || {
                log "Error: Failed to create bucket. Please check AWS permissions or try a different name."
                exit 1
            }
        fi
        
        # Enable versioning for recovery
        aws s3api put-bucket-versioning \
            --bucket "$BUCKET_NAME" \
            --versioning-configuration Status=Enabled \
            --profile "$AWS_PROFILE"
            
        log "Bucket created: $BUCKET_NAME"
        
        # Add default lifecycle rule to clean up old versions
        log "Setting up lifecycle rules..."
        cat > /tmp/lifecycle.json << EOF
{
  "Rules": [
    {
      "ID": "ExpireOldVersions",
      "Status": "Enabled",
      "Filter": {},
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 30
      }
    }
  ]
}
EOF
        aws s3api put-bucket-lifecycle-configuration \
            --bucket "$BUCKET_NAME" \
            --lifecycle-configuration file:///tmp/lifecycle.json \
            --profile "$AWS_PROFILE" || {
            log "Warning: Failed to set lifecycle rules. Old versions won't be automatically cleaned up."
        }
    fi
}

# Create configuration file
create_config_file() {
    log "Creating configuration file..."
    
    cat > "${CONFIG_FILE}" << EOF
#!/bin/bash
# Auto-generated configuration for omics-demo
# Created: $(date)

# AWS Configuration
BUCKET_NAME=$BUCKET_NAME
REGION=$REGION
AWS_PROFILE=$AWS_PROFILE
STACK_NAME=omics-demo

# Dashboard Configuration
API_PORT=5000
DASHBOARD_PORT=3000

# Demo Configuration
SAMPLE_COUNT=100
DEMO_DURATION_MINUTES=15
EOF

    chmod +x "${CONFIG_FILE}"
    log "Configuration saved to ${CONFIG_FILE}"
}

# Install Python dependencies
install_python_deps() {
    if [[ -f "${SCRIPT_DIR}/requirements.txt" ]]; then
        log "Installing Python dependencies..."
        pip3 install -r "${SCRIPT_DIR}/requirements.txt" || {
            log "Warning: Failed to install some Python dependencies. The demo might not work correctly."
        }
    fi
}

# Main execution
log "==========================================="
log "Omics Demo Initial Setup"
log "==========================================="
log "Target bucket: $BUCKET_NAME"
log "Region: $REGION"
log "AWS Profile: $AWS_PROFILE"
log "==========================================="

# Run setup steps
check_requirements
create_directories
create_s3_bucket
create_config_file
install_python_deps

log "Setup complete!"
log "Next step: Run ./prepare_demo_data.sh to prepare the data"
log "To start the API server: ./start_api.sh"
log "To start the dashboard: cd dashboard && npm start"