#!/usr/bin/env python3
"""
Setup script for PID Monitor
"""

import os
import sys
import subprocess
from setuptools import setup, find_packages

def install_requirements():
    """Install required packages"""
    print("Installing required packages...")
    
    # Read requirements
    with open('requirements.txt', 'r') as f:
        requirements = [line.strip() for line in f if line.strip() and not line.startswith('#')]
    
    # Install each requirement
    for requirement in requirements:
        print(f"Installing {requirement}...")
        try:
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', requirement])
        except subprocess.CalledProcessError as e:
            print(f"Failed to install {requirement}: {e}")
            return False
    
    return True

def check_macos():
    """Check if running on macOS"""
    import platform
    if platform.system() != 'Darwin':
        print("Warning: This tool is designed for macOS. Some features may not work on other platforms.")
        return False
    return True

def main():
    """Main setup function"""
    print("PID Monitor Setup")
    print("=" * 20)
    
    # Check platform
    check_macos()
    
    # Install requirements
    if not install_requirements():
        print("Failed to install requirements. Please install them manually:")
        print("pip install -r requirements.txt")
        return
    
    print("\nSetup completed!")
    print("\nUsage:")
    print("  GUI version: python advanced_screen_capture.py")

if __name__ == "__main__":
    main() 