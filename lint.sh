#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright 2025 Scott Friedman, All Rights Reserved.
# Run all linting tools on the codebase

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ERRORS=0

# Print header function
print_header() {
    echo ""
    echo "================================================"
    echo "  $1"
    echo "================================================"
}

# Check if pre-commit is installed
if ! command -v pre-commit &> /dev/null; then
    echo "Error: pre-commit is not installed. Please install it with:"
    echo "pip install pre-commit"
    exit 1
fi

# Run shell script validation
print_header "Validating shell scripts"
if ! "${SCRIPT_DIR}/validate_scripts.sh"; then
    ERRORS=$((ERRORS + 1))
fi

# Run Python linting
print_header "Running Python linting (flake8)"
if command -v flake8 &> /dev/null; then
    if ! flake8 "${SCRIPT_DIR}/api" "${SCRIPT_DIR}/tests"; then
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "Warning: flake8 not installed. Skipping Python linting."
fi

# Run Python formatting check
print_header "Checking Python formatting (black)"
if command -v black &> /dev/null; then
    if ! black --check --line-length=100 "${SCRIPT_DIR}/api" "${SCRIPT_DIR}/tests"; then
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "Warning: black not installed. Skipping Python formatting check."
fi

# Run JavaScript linting
print_header "Running JavaScript linting (ESLint)"
if [ -d "${SCRIPT_DIR}/dashboard/node_modules/.bin" ] && [ -f "${SCRIPT_DIR}/dashboard/node_modules/.bin/eslint" ]; then
    if ! (cd "${SCRIPT_DIR}/dashboard" && npm run lint); then
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "Warning: ESLint not installed. Run 'cd dashboard && npm install' first."
fi

# Run pre-commit hooks on all files
print_header "Running pre-commit hooks"
if ! pre-commit run --all-files; then
    ERRORS=$((ERRORS + 1))
fi

# Print summary
print_header "Linting Summary"
if [ ${ERRORS} -eq 0 ]; then
    echo "✅ All linting checks passed!"
    exit 0
else
    echo "❌ Found issues in ${ERRORS} linting checks. Please fix them."
    exit 1
fi