#!/usr/bin/env python3
"""
Test script for chat monitoring functionality
"""

import time
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager

def test_chat_structure():
    """Test to understand Zoom's chat structure"""
    print("Starting chat structure test...")
    
    # Setup Chrome driver
    chrome_options = Options()
    chrome_options.add_argument("--headless=new")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=chrome_options)
    
    try:
        # Navigate to a test page or Zoom
        print("Navigating to Zoom...")
        driver.get("https://zoom.us")
        time.sleep(3)
        
        # Look for any elements containing "Truely"
        print("Searching for elements containing 'Truely'...")
        elements = driver.find_elements(By.XPATH, "//*[contains(text(), 'Truely')]")
        print(f"Found {len(elements)} elements containing 'Truely'")
        
        for i, elem in enumerate(elements[:10]):
            print(f"  Element {i}: '{elem.text.strip()}' (tag: {elem.tag_name}, class: {elem.get_attribute('class')})")
        
        # Look for chat-related elements
        print("\nSearching for chat-related elements...")
        chat_elements = driver.find_elements(By.XPATH, "//*[contains(@class, 'chat') or contains(@id, 'chat')]")
        print(f"Found {len(chat_elements)} chat-related elements")
        
        for i, elem in enumerate(chat_elements[:5]):
            print(f"  Chat element {i}: tag={elem.tag_name}, class={elem.get_attribute('class')}, id={elem.get_attribute('id')}")
        
    except Exception as e:
        print(f"Error during test: {e}")
    finally:
        driver.quit()
        print("Test completed.")

if __name__ == "__main__":
    test_chat_structure() 