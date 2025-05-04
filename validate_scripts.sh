#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright 2025 Scott Friedman, All Rights Reserved.
# Validates shell scripts in the repository

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ERRORS_FOUND=0

# Check for shellcheck
if ! command -v shellcheck &> /dev/null; then
    echo "Error: shellcheck is not installed. Please install it first."
    echo "On macOS: brew install shellcheck"
    echo "On Ubuntu: apt-get install shellcheck"
    exit 1
fi

# Find all shell scripts
echo "Finding shell scripts..."
SHELL_SCRIPTS=$(find "${SCRIPT_DIR}" -name "*.sh" -type f)

# Check each script
for script in ${SHELL_SCRIPTS}; do
    echo "Checking ${script}..."
    
    # Ensure script is executable
    if [[ ! -x "${script}" ]]; then
        echo "Warning: Script ${script} is not executable. Setting executable permission."
        chmod +x "${script}"
    fi
    
    # Check if script has a shebang
    if ! head -n1 "${script}" | grep -q '^#!'; then
        echo "Error: ${script} is missing a shebang line."
        ERRORS_FOUND=$((ERRORS_FOUND + 1))
    fi
    
    # Run shellcheck
    if ! shellcheck "${script}"; then
        echo "Error: ${script} failed shellcheck validation."
        ERRORS_FOUND=$((ERRORS_FOUND + 1))
    fi
done

echo "Validation complete!"
if [[ ${ERRORS_FOUND} -gt 0 ]]; then
    echo "Found ${ERRORS_FOUND} errors in shell scripts."
    exit 1
else
    echo "All shell scripts passed validation!"
    exit 0
fi