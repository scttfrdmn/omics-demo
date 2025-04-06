# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- **Setup**: `./setup.sh <bucket-name> <region>`
- **Test**: `./test_demo.sh`
- **Data Preparation**: `./prepare_demo_data.sh`
- **Start Demo**: `./start_demo.sh`
- **Reset Demo**: `./reset_demo.sh`
- **Check Resources**: `./check_resources.sh`

## Nextflow Commands

- **Run Full Pipeline**: `nextflow run workflow/main.nf -profile aws`
- **Run Test Pipeline**: `nextflow run workflow/main.nf -profile test`
- **Lint Nextflow Files**: `nextflow lint workflow/main.nf`

## Code Style Guidelines

- **Shell Scripts**: Use `set -e` for error handling, include descriptive comments and section headers
- **Python**: Follow PEP 8, use snake_case for variables/functions, UPPERCASE for constants
- **Nextflow**: Use camelCase for process names, snake_case for variables, indent with 4 spaces
- **Error Handling**: Always check exit codes in shell scripts, use try/except in Python
- **Imports**: Group imports (standard library, third-party, local) with a blank line between groups
- **Naming**: Use descriptive names; prefix AWS resources with "omics-demo-"
- **Documentation**: Document parameters, return values, and complex logic

## AWS Patterns

Keep all resource names consistent with the "omics-demo-" prefix for easy identification and cleanup.