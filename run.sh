#!/bin/bash

# PID Monitor Launcher
# This script sets up and launches the PID monitor tool

echo "PID Monitor - Cluely Detector"
echo "============================"

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed or not in PATH"
    echo "Please install Python 3.8 or later"
    exit 1
fi

# Check Python version
python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
required_version="3.8"

if [ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" != "$required_version" ]; then
    echo "Error: Python $python_version is installed, but Python $required_version or later is required"
    exit 1
fi

echo "Python version: $python_version ✓"

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Warning: This tool is designed for macOS. Some features may not work on other platforms."
fi

# Check if requirements are installed
echo "Checking dependencies..."
if ! python3 -c "import PyQt6, psutil, objc" 2>/dev/null; then
    echo "Installing dependencies..."
    pip3 install -r requirements.txt
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install dependencies"
        echo "Please run: pip3 install -r requirements.txt"
        exit 1
    fi
fi

echo "Dependencies ✓"

echo ""
echo "Launching PID Monitor..."
echo ""
python3 advanced_screen_capture.py 