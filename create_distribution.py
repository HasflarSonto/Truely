#!/usr/bin/env python3
"""
Distribution script for Truely
Creates a clean distribution package with the .app file and config template
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

def create_distribution():
    """Create a distribution package"""
    
    # Create distribution directory
    dist_dir = Path("distribution")
    if dist_dir.exists():
        shutil.rmtree(dist_dir)
    dist_dir.mkdir()
    
    # Copy the .app file
    app_source = Path("dist/Truely.app")
    app_dest = dist_dir / "Truely.app"
    
    if app_source.exists():
        print(f"Copying {app_source} to {app_dest}")
        shutil.copytree(app_source, app_dest)
    else:
        print("Error: Truely.app not found in dist/ directory")
        return False
    
    # Create a config template
    config_template = """# Truely Configuration File
# Edit these settings as needed

# Zoom meeting URL (replace with your actual meeting URL)
ZOOM_URL = "https://us05web.zoom.us/j/YOUR_MEETING_ID?pwd=YOUR_PASSWORD"

# Applications to monitor (add or remove as needed)
APPS = ["cluely", "claude"]

# Start and end keys for monitoring
START_KEY = "HIHIHI"
END_KEY = "BYEBYE"

# Enable/disable chat monitoring (True/False)
CHAT_MONITORING_ENABLED = True

# Status update interval in seconds
STATUS_UPDATE_INTERVAL = 10
"""
    
    config_path = dist_dir / "config_template.py"
    with open(config_path, 'w') as f:
        f.write(config_template)
    
    # Create README for distribution
    readme_content = """# Truely Distribution

## Installation Instructions

1. **Extract the distribution package** to your desired location
2. **Copy the config file**: 
   - Copy `config_template.py` to `config.py`
   - Edit `config.py` with your actual Zoom meeting URL and settings
3. **Run the application**:
   - Double-click `Truely.app` to start the application
   - Or right-click and select "Open" if macOS blocks the app

## Configuration

Edit `config.py` to customize:
- **ZOOM_URL**: Your Zoom meeting URL
- **APPS**: List of applications to monitor
- **START_KEY/END_KEY**: Monitoring keys
- **CHAT_MONITORING_ENABLED**: Enable/disable chat monitoring
- **STATUS_UPDATE_INTERVAL**: How often to send status updates

## Troubleshooting

If macOS blocks the app:
1. Go to System Preferences > Security & Privacy
2. Click "Open Anyway" for Truely.app

If the app doesn't start:
1. Make sure `config.py` is in the same directory as `Truely.app`
2. Check that your Zoom URL is valid
3. Ensure you have an internet connection

## Support

For issues or questions, please refer to the main documentation.
"""
    
    readme_path = dist_dir / "README.txt"
    with open(readme_path, 'w') as f:
        f.write(readme_content)
    
    print(f"\n✅ Distribution created successfully in '{dist_dir}' directory!")
    print(f"📁 Contents:")
    print(f"   - Truely.app (main application)")
    print(f"   - config_template.py (configuration template)")
    print(f"   - README.txt (installation instructions)")
    print(f"\n📋 Next steps:")
    print(f"   1. Copy config_template.py to config.py")
    print(f"   2. Edit config.py with your settings")
    print(f"   3. Test the app by double-clicking Truely.app")
    print(f"   4. Zip the distribution folder for sharing")
    
    return True

def build_and_distribute():
    """Build the app and create distribution"""
    print("🔨 Building Truely.app...")
    
    # Run PyInstaller
    result = subprocess.run([sys.executable, "-m", "PyInstaller", "truely.spec"], 
                          capture_output=True, text=True)
    
    if result.returncode != 0:
        print("❌ Build failed!")
        print("Error output:", result.stderr)
        return False
    
    print("✅ Build completed successfully!")
    
    # Create distribution
    return create_distribution()

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--build":
        build_and_distribute()
    else:
        create_distribution() 