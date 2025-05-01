#!/bin/bash
# Development environment setup script for omics-demo

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Function for printing headers
print_header() {
    echo ""
    echo "================================================"
    echo "  $1"
    echo "================================================"
}

# Check Python version
print_header "Checking Python version"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    echo "Found Python version: ${PYTHON_VERSION}"
    
    # Check if version is at least 3.6
    MAJOR=$(echo ${PYTHON_VERSION} | cut -d. -f1)
    MINOR=$(echo ${PYTHON_VERSION} | cut -d. -f2)
    
    if [ "${MAJOR}" -lt 3 ] || ([ "${MAJOR}" -eq 3 ] && [ "${MINOR}" -lt 6 ]); then
        echo "Error: Python 3.6+ is required. Found ${PYTHON_VERSION}"
        exit 1
    fi
else
    echo "Error: Python 3 not found. Please install Python 3.6+"
    exit 1
fi

# Check Node.js version
print_header "Checking Node.js version"
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version | cut -c2-)
    echo "Found Node.js version: ${NODE_VERSION}"
    
    # Check if version is at least 14
    MAJOR=$(echo ${NODE_VERSION} | cut -d. -f1)
    
    if [ "${MAJOR}" -lt 14 ]; then
        echo "Error: Node.js 14+ is required. Found ${NODE_VERSION}"
        exit 1
    fi
else
    echo "Error: Node.js not found. Please install Node.js 14+"
    exit 1
fi

# Install Python dependencies
print_header "Installing Python dependencies"
pip3 install -r "${SCRIPT_DIR}/requirements.txt"

# Install pre-commit
print_header "Setting up pre-commit hooks"
pip3 install pre-commit
pre-commit install

# Install Node.js dependencies
print_header "Installing Node.js dependencies"
(cd "${SCRIPT_DIR}/dashboard" && npm install)

# Set up git hook for running linting before commit
print_header "Installing git hooks"
if [ -d "${SCRIPT_DIR}/.git/hooks" ]; then
    # Create pre-commit hook
    echo "#!/bin/bash" > "${SCRIPT_DIR}/.git/hooks/pre-commit"
    echo "exec ${SCRIPT_DIR}/lint.sh" >> "${SCRIPT_DIR}/.git/hooks/pre-commit"
    chmod +x "${SCRIPT_DIR}/.git/hooks/pre-commit"
    echo "Git hooks installed."
else
    echo "Warning: .git/hooks directory not found. Git hooks not installed."
fi

# Final instructions
print_header "Development setup complete!"
echo "To run linting checks manually: ./lint.sh"
echo "To start the API server: ./start_api.sh"
echo "To start the dashboard: cd dashboard && npm start"