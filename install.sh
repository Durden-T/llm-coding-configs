#!/bin/bash

# Exit on any error
set -e

echo "=========================================="
echo "Claude Code Installation Script"
echo "=========================================="
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 1. Check and install Homebrew
echo "Step 1: Checking for Homebrew..."
if ! command_exists brew; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "✓ Homebrew is already installed"
fi
echo ""

# 2. Install Claude Code
echo "Step 2: Installing Claude Code..."
if command_exists claude; then
    echo "✓ Claude Code is already installed"
else
    brew install claude-code
    echo "✓ Claude Code installed successfully"
fi
echo ""

# 3. Check and install required tools (uvx, npm, npx)
echo "Step 3: Checking for required tools..."

# Check and install uvx
if ! command_exists uvx; then
    echo "uvx not found. Installing via brew..."
    brew install uv
else
    echo "✓ uvx is available"
fi

# Check and install npm
if ! command_exists npm; then
    echo "npm not found. Installing via brew..."
    brew install npm
else
    echo "✓ npm is available"
fi

# Check and install npx (usually comes with npm, but double-check)
if ! command_exists npx; then
    echo "npx not found. Installing via brew..."
    brew install npx
else
    echo "✓ npx is available"
fi
echo ""

# 4. Install claude-code-router
echo "Step 4: Installing @musistudio/claude-code-router..."
npm install -g @musistudio/claude-code-router
echo "✓ @musistudio/claude-code-router installed successfully"
echo ""

# 5. Add superpowers marketplace
echo "Step 5: Adding superpowers marketplace..."
claude plugin marketplace add obra/superpowers-marketplace
echo "✓ Marketplace added successfully"
echo ""

# 6. Install superpowers plugin
echo "Step 6: Installing superpowers plugin..."
claude plugin install superpowers@superpowers-marketplace
echo "✓ Superpowers plugin installed successfully"
echo ""

echo "=========================================="
echo "Installation completed successfully! 🎉"
echo "=========================================="
