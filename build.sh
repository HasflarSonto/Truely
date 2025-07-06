#!/bin/bash

# Truely Build Script
# This script builds the Truely.app and creates a distribution package

echo "🔨 Building Truely.app..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/ dist/

# Build the app
echo "📦 Building with PyInstaller..."
pyinstaller truely.spec

if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully!"
    
    # Create distribution
    echo "📦 Creating distribution package..."
    python create_distribution.py
    
    echo ""
    echo "🎉 Build and distribution completed!"
    echo "📁 Your distribution is ready in the 'distribution' folder"
    echo "📋 Next steps:"
    echo "   1. Copy config_template.py to config.py"
    echo "   2. Edit config.py with your settings"
    echo "   3. Test the app by double-clicking Truely.app"
    echo "   4. Zip the distribution folder for sharing"
else
    echo "❌ Build failed!"
    exit 1
fi 