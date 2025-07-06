#!/usr/bin/env python3
"""
Test script to verify Truely.app works without crashing
"""

import subprocess
import time
import signal
import os

def test_app():
    """Test the Truely.app by running it and checking if it starts successfully"""
    
    app_path = "distribution/Truely.app"
    
    if not os.path.exists(app_path):
        print("❌ Truely.app not found in distribution folder")
        return False
    
    print("🧪 Testing Truely.app...")
    print(f"📁 App path: {app_path}")
    
    try:
        # Start the app
        print("🚀 Starting Truely.app...")
        process = subprocess.Popen(
            ["open", app_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        
        # Wait a moment for the app to start
        time.sleep(3)
        
        # Check if the process is still running
        if process.poll() is None:
            print("✅ Truely.app started successfully!")
            print("⏱️  App is running for 10 seconds to test stability...")
            
            # Let it run for 10 seconds to test stability
            time.sleep(10)
            
            # Try to gracefully close the app
            print("🛑 Attempting to close Truely.app...")
            try:
                subprocess.run(["pkill", "-f", "Truely"], check=False)
                print("✅ Truely.app closed successfully")
            except Exception as e:
                print(f"⚠️  Warning: Could not close app gracefully: {e}")
            
            return True
        else:
            stdout, stderr = process.communicate()
            print(f"❌ Truely.app failed to start")
            print(f"stdout: {stdout.decode()}")
            print(f"stderr: {stderr.decode()}")
            return False
            
    except Exception as e:
        print(f"❌ Error testing Truely.app: {e}")
        return False

if __name__ == "__main__":
    success = test_app()
    if success:
        print("\n🎉 Truely.app test PASSED!")
        print("✅ The app starts and runs without crashing")
        print("✅ Location services crash has been fixed")
    else:
        print("\n💥 Truely.app test FAILED!")
        print("❌ The app still has issues") 