#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright 2025 Scott Friedman, All Rights Reserved.
# Start the API server for the omics demo dashboard

set -e  # Exit on error

# Load configuration
source ./config.sh

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Python 3 is not installed. Please install Python 3 and try again."
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "pip3 is not installed. Please install pip3 and try again."
    exit 1
fi

# Install required packages if they don't exist
echo "Checking and installing Python dependencies..."
pip3 install -r requirements.txt

# Check AWS credentials
if ! aws sts get-caller-identity &>/dev/null; then
  echo "AWS CLI not configured. Please run 'aws configure' first."
  exit 1
fi

# Start the API server
echo "Starting API server at http://localhost:5000..."
python3 api/server.py