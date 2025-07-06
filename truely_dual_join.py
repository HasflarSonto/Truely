#!/usr/bin/env python3
"""
Truely - Dual-Join Process Monitor
A streamlined version focused on automatic dual-join functionality at startup
"""

import sys
import os
import time
import webbrowser
import urllib.parse
import subprocess
from datetime import datetime
from typing import List
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QPushButton, QLabel, QLineEdit, QTextEdit, QListWidget, QListWidgetItem, QInputDialog, QMessageBox, QSystemTrayIcon, QMenu, QTabWidget, QGroupBox, QGridLayout, QCheckBox
)
from PyQt6.QtCore import Qt, QTimer, QRect, QThread, pyqtSignal
from PyQt6.QtGui import QIcon, QPixmap, QPainter, QColor, QFont, QAction
import psutil
import hashlib
import logging
import signal
import threading

# Auto-install Selenium if not available
def install_selenium_if_needed():
    """Automatically install Selenium and webdriver-manager if not available"""
    try:
        import selenium
        from webdriver_manager.chrome import ChromeDriverManager
        return True
    except ImportError:
        print("Selenium not found. Installing required packages...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "selenium", "webdriver-manager"], 
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("Selenium installed successfully!")
            return True
        except subprocess.CalledProcessError:
            print("Failed to install Selenium automatically. Please install manually: pip install selenium webdriver-manager")
            return False

# Try to install Selenium at startup
SELENIUM_AVAILABLE = install_selenium_if_needed()

# Selenium imports for bot functionality
try:
    from selenium import webdriver
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    from selenium.webdriver.chrome.service import Service
    from selenium.webdriver.chrome.options import Options
    from webdriver_manager.chrome import ChromeDriverManager
    SELENIUM_AVAILABLE = True
except ImportError:
    SELENIUM_AVAILABLE = False
    print("Selenium not available. Bot features will be disabled.")

# Setup logging
logging.basicConfig(
    filename='truely_dual_join.log',
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s'
)

class SuspiciousProcessWorker(QThread):
    result_ready = pyqtSignal(list, set)
    def __init__(self, get_process_names, suspicious_paths, suspicious_hashes):
        super().__init__()
        self.get_process_names = get_process_names
        self.suspicious_paths = suspicious_paths
        self.suspicious_hashes = suspicious_hashes
        self._running = True
        self.last_alerted_pids = set()
    
    def run(self):
        suspicious = []
        new_alerted_pids = set()
        for proc in psutil.process_iter(['pid', 'name', 'exe']):
            if not self._running:
                return
            try:
                info = proc.info
                pname = info.get('name', '').lower()
                pexe = info.get('exe', '')
                # Check name
                if any(mon in pname for mon in self.get_process_names()):
                    suspicious.append(f'<span style="color:#ff5555;"><b>[NAME]</b></span> <b>{pname}</b> <span style="color:#b3e6ff;">(PID: <b>{info["pid"]}</b>)</span>')
                    new_alerted_pids.add(info['pid'])
                # Check path
                if pexe and any(pexe == path for path in self.suspicious_paths):
                    suspicious.append(f'<span style="color:#ffd700;"><b>[PATH]</b></span> <b>{pexe}</b> <span style="color:#b3e6ff;">(PID: <b>{info["pid"]}</b>)</span>')
                    new_alerted_pids.add(info['pid'])
                # Check hash
                if pexe and os.path.exists(pexe):
                    try:
                        with open(pexe, 'rb') as f:
                            file_hash = hashlib.sha256(f.read()).hexdigest()
                        if file_hash in self.suspicious_hashes:
                            suspicious.append(f'<span style="color:#00ff99;"><b>[HASH]</b></span> <b>{pexe}</b> <span style="color:#b3e6ff;">(PID: <b>{info["pid"]}</b>)</span>')
                            new_alerted_pids.add(info['pid'])
                    except Exception:
                        pass
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        self.result_ready.emit(suspicious, new_alerted_pids)
    
    def stop(self):
        self._running = False

class MeetingJoiner:
    """Handles joining Zoom meetings for the user"""
    
    @staticmethod
    def join_zoom_meeting(meeting_id: str, password: str = None) -> bool:
        """Join a Zoom meeting using meeting ID and optional password"""
        try:
            # Remove any non-numeric characters from meeting ID
            clean_id = ''.join(filter(str.isdigit, meeting_id))
            if not clean_id:
                return False
                
            # Construct Zoom URL
            zoom_url = f"zoommtg://zoom.us/join?confno={clean_id}"
            if password:
                zoom_url += f"&pwd={password}"
            
            # Try to open with Zoom app first
            webbrowser.open(zoom_url)
            
            print(f"Opened Zoom meeting {clean_id} in Zoom application")
            return True
        except Exception as e:
            print(f"Error joining Zoom meeting: {e}")
            return False

class BotMeetingJoiner:
    """Handles joining meetings as a bot using browser automation"""
    
    def __init__(self):
        self.driver = None
        self.driver_process = None
        self.is_joined = False
        self._driver_lock = threading.Lock()
        self._child_pids = []  # Track child PIDs for cleanup
    
    def setup_driver(self):
        """Setup Chrome driver for automation"""
        if not SELENIUM_AVAILABLE:
            return False
            
        try:
            user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 CustomAgent/1.0"

            chrome_options = Options()
            chrome_options.add_argument("--no-sandbox")
            chrome_options.add_argument("--headless=new")
            chrome_options.add_argument("--disable-dev-shm-usage")
            chrome_options.add_argument("--disable-blink-features=AutomationControlled")
            chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
            chrome_options.add_experimental_option('useAutomationExtension', False)
            chrome_options.add_argument(f"user-agent={user_agent}")
            chrome_options.add_argument("--disable-blink-features=AutomationControlled")
            
            # Use webdriver-manager to handle ChromeDriver installation
            service = Service(ChromeDriverManager().install())
            self.driver = webdriver.Chrome(service=service, options=chrome_options)
            self.driver_process = service.process
            if self.driver_process:
                self._child_pids.append(self.driver_process.pid)
            logging.info('Started ChromeDriver (PID: %s)', getattr(self.driver_process, 'pid', None))
            
            # Hide automation indicators
            self.driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
            
            return True
        except Exception as e:
            logging.error('Failed to start ChromeDriver: %s', e)
            return False
    
    def join_zoom_meeting_bot(self, meeting_id: str, name: str = "Truely Bot", password: str = None) -> bool:
        """Join Zoom meeting as a bot using web interface"""
        if not self.setup_driver():
            return False
        try:
            # If meeting_id is a URL, extract passcode if not provided
            passcode = password
            if (not password) and ('?' in meeting_id or 'zoom.us' in meeting_id):
                parsed = urllib.parse.urlparse(meeting_id)
                query = urllib.parse.parse_qs(parsed.query)
                passcode = query.get('pwd', [None])[0]

            clean_meeting_id = self.extract_zoom_meeting_id(meeting_id)
            if not clean_meeting_id:
                print(f"Could not extract meeting ID from: {meeting_id}")
                return False
            join_url = f"https://zoom.us/wc/join/{clean_meeting_id}"
            print(f"Navigating to: {join_url}")
            self.driver.get(join_url)
            wait = WebDriverWait(self.driver, 10)  # Reduced from 15 to 10

            # 1. Handle the mic/camera popup quickly (may appear twice)
            for attempt in range(2):
                try:
                    continue_btn = wait.until(
                        EC.element_to_be_clickable((By.XPATH, "//div[contains(@class, 'continue-without-mic-camera')]"))
                    )
                    continue_btn.click()
                    print(f"Selected: Continue without microphone and camera (attempt {attempt + 1})")
                    time.sleep(0.3)  # Reduced from 1 to 0.3
                except Exception as e:
                    print(f"No more 'Continue without microphone and camera' popups found (attempt {attempt + 1}): {e}")
                    break

            # 2. Reduced wait time for page load
            time.sleep(0.5)  # Reduced from 2 to 0.5
            print("Waiting for page to load...")

            # 3. Try to fill in name using multiple selectors (faster approach)
            name_filled = False
            name_selectors = [
                (By.ID, "input-for-name"),
                (By.NAME, "inputname"),
                (By.XPATH, "//input[@placeholder='Enter your name']"),
                (By.XPATH, "//input[contains(@placeholder, 'name')]"),
                (By.XPATH, "//input[@type='text' and contains(@class, 'name')]"),
                (By.CSS_SELECTOR, "input[placeholder*='name']")
            ]
            
            for selector_type, selector_value in name_selectors:
                try:
                    name_input = wait.until(EC.presence_of_element_located((selector_type, selector_value)))
                    name_input.clear()
                    name_input.send_keys(name)
                    print(f"Successfully filled name using selector: {selector_type} = {selector_value}")
                    name_filled = True
                    break
                except Exception as e:
                    print(f"Could not find name input with selector {selector_type} = {selector_value}: {e}")
                    continue
            
            if not name_filled:
                print("Warning: Could not find name input field, proceeding anyway...")

            # 4. Try to fill in passcode using multiple selectors (faster approach)
            if passcode:
                passcode_filled = False
                passcode_selectors = [
                    (By.ID, "input-for-pwd"),
                    (By.NAME, "inputpwd"),
                    (By.XPATH, "//input[@placeholder='Enter meeting passcode']"),
                    (By.XPATH, "//input[contains(@placeholder, 'passcode')]"),
                    (By.XPATH, "//input[contains(@placeholder, 'password')]"),
                    (By.XPATH, "//input[@type='password']"),
                    (By.CSS_SELECTOR, "input[placeholder*='passcode']"),
                    (By.CSS_SELECTOR, "input[placeholder*='password']")
                ]
                
                for selector_type, selector_value in passcode_selectors:
                    try:
                        password_input = wait.until(EC.presence_of_element_located((selector_type, selector_value)))
                        password_input.clear()
                        password_input.send_keys(passcode)
                        print(f"Successfully filled passcode using selector: {selector_type} = {selector_value}")
                        passcode_filled = True
                        break
                    except Exception as e:
                        print(f"Could not find passcode input with selector {selector_type} = {selector_value}: {e}")
                        continue
                
                if not passcode_filled:
                    print("Warning: Could not find passcode input field, proceeding anyway...")
            else:
                print("No passcode provided, skipping passcode field")

            # 5. Click join button using multiple strategies (faster approach)
            join_success = False
            join_selectors = [
                (By.XPATH, "//button[contains(@class, 'preview-join-button')]"),
                (By.XPATH, "//button[contains(text(), 'Join')]"),
                (By.XPATH, "//button[contains(@aria-label, 'Join')]"),
                (By.XPATH, "//button[contains(@title, 'Join')]"),
                (By.XPATH, "//button[contains(@class, 'join')]"),
                (By.XPATH, "//button[contains(@class, 'button') and contains(text(), 'Join')]"),
                (By.CSS_SELECTOR, "button[class*='join']"),
                (By.CSS_SELECTOR, "button[class*='preview-join']")
            ]
            
            for selector_type, selector_value in join_selectors:
                try:
                    join_button = wait.until(EC.element_to_be_clickable((selector_type, selector_value)))
                    join_button.click()
                    print(f"Successfully clicked join button using selector: {selector_type} = {selector_value}")
                    join_success = True
                    break
                except Exception as e:
                    print(f"Could not click join button with selector {selector_type} = {selector_value}: {e}")
                    continue
            
            if not join_success:
                print("Warning: Could not find or click join button, but proceeding anyway...")
                print("The meeting might still join automatically or require manual intervention")

            # 6. Reduced wait time to check if we successfully joined
            time.sleep(1.5)  # Reduced from 3 to 1.5
            
            # Check if we're in the meeting by looking for meeting controls
            try:
                meeting_controls = self.driver.find_elements(By.XPATH, "//button[contains(@aria-label, 'Leave') or contains(@aria-label, 'Chat') or contains(@aria-label, 'Share')]")
                if meeting_controls:
                    print("Successfully joined the meeting - found meeting controls")
                    self.is_joined = True
                    return True
                else:
                    print("Meeting controls not found - may still be joining or need manual intervention")
                    # Still mark as joined in case the controls appear later
                    self.is_joined = True
                    return True
            except Exception as e:
                print(f"Error checking meeting status: {e}")
                # Still mark as joined and return True to allow the process to continue
                self.is_joined = True
                return True

        except Exception as e:
            print(f"Error joining Zoom meeting as bot: {e}")
            return False
    
    def extract_zoom_meeting_id(self, input_text: str) -> str:
        """Extract Zoom meeting ID from various URL formats or direct ID"""
        try:
            # If it's just a numeric ID, return it
            if input_text.isdigit():
                return input_text
            
            # If it's a URL, parse it
            if 'zoom.us' in input_text or 'zoommtg://' in input_text:
                parsed = urllib.parse.urlparse(input_text)
                
                # Handle zoommtg:// format
                if 'zoommtg://' in input_text:
                    params = urllib.parse.parse_qs(parsed.query)
                    meeting_id = params.get('confno', [''])[0]
                    if meeting_id:
                        return meeting_id
                
                # Handle web URL formats (including subdomains like us05web.zoom.us)
                path_parts = parsed.path.split('/')
                
                # Look for meeting ID in path
                for i, part in enumerate(path_parts):
                    if part in ['j', 'join', 'wc', 'join'] and i + 1 < len(path_parts):
                        meeting_id = path_parts[i + 1]
                        # Remove any query parameters or fragments
                        meeting_id = meeting_id.split('?')[0].split('#')[0]
                        if meeting_id.isdigit():
                            return meeting_id
                
                # Try to find any numeric part that could be a meeting ID
                for part in path_parts:
                    if part.isdigit() and len(part) >= 9:  # Zoom IDs are typically 9-11 digits
                        return part
            
            # If no URL format detected, try to extract any numeric sequence
            import re
            numbers = re.findall(r'\d+', input_text)
            for num in numbers:
                if len(num) >= 9:  # Likely a Zoom meeting ID
                    return num
            
            return input_text  # Return original if no parsing worked
            
        except Exception as e:
            print(f"Error extracting meeting ID: {e}")
            return input_text
    
    def open_chat_panel(self) -> bool:
        """Open the chat panel in Zoom meeting"""
        if not self.driver or not self.is_joined:
            return False
        try:
            # Try to switch to meeting iframe if it exists
            self.switch_to_meeting_iframe()
            # Handle any overlay elements that might block clicks
            self.handle_overlay_elements()
            wait = WebDriverWait(self.driver, 8)
            
            # Find the chat button using the specific HTML structure provided
            try:
                # Use the exact structure: div with id="chat" containing button with aria-label="open the chat panel"
                chat_button = wait.until(EC.element_to_be_clickable((
                    By.XPATH, "//div[@id='chat']//button[@aria-label='open the chat panel']"
                )))
                
                # Additional verification: ensure it's the chat button and not share button
                button_text = chat_button.find_element(By.XPATH, ".//span[contains(@class, 'footer-button-base__button-label')]")
                if button_text.text.strip() == "Chat":
                    print(f"Found chat button with text: '{button_text.text}'")
                    print(f"Button aria-label: {chat_button.get_attribute('aria-label')}")
                    print(f"Button is displayed: {chat_button.is_displayed()}")
                    print(f"Button is enabled: {chat_button.is_enabled()}")
                    
                    # Clear any existing focus and wait
                    self.driver.execute_script("document.activeElement.blur();")
                    time.sleep(0.5)
                    
                    self.scroll_element_into_view(chat_button)
                    
                    # Wait a moment before clicking to ensure everything is ready
                    time.sleep(0.5)
                    
                    # Try a more precise single-click approach
                    success = False
                    
                    # Strategy 1: Focus first, then click
                    try:
                        print("Trying focus + click strategy...")
                        chat_button.click()  # This should focus the element
                        time.sleep(0.2)  # Brief pause
                        chat_button.click()  # This should actually click it
                        print("Focus + click successful")
                        success = True
                    except Exception as e:
                        print(f"Focus + click failed: {e}")
                    
                    # Strategy 2: JavaScript click with focus if first failed
                    if not success:
                        try:
                            print("Trying JavaScript focus + click...")
                            self.driver.execute_script("arguments[0].focus();", chat_button)
                            time.sleep(0.2)
                            self.driver.execute_script("arguments[0].click();", chat_button)
                            print("JavaScript focus + click successful")
                            success = True
                        except Exception as e:
                            print(f"JavaScript focus + click failed: {e}")
                    
                    # Strategy 3: Direct JavaScript click if both failed
                    if not success:
                        try:
                            print("Trying direct JavaScript click...")
                            self.driver.execute_script("arguments[0].click();", chat_button)
                            print("Direct JavaScript click successful")
                            success = True
                        except Exception as e:
                            print(f"Direct JavaScript click failed: {e}")
                    
                    if success:
                        print("Chat panel opened successfully")
                        time.sleep(1)  # Wait for chat panel to fully open
                        return True
                    else:
                        print("All clicking strategies failed")
                        return False
                        
                else:
                    print(f"Found button with wrong text: {button_text.text}")
                    return False
                    
            except Exception as e:
                print(f"Could not find chat button: {e}")
                return False
                
        except Exception as e:
            print(f"Error opening chat panel: {e}")
            return False

    def send_message_to_chat(self, message: str) -> bool:
        """Send a message in the already opened chat panel"""
        if not self.driver or not self.is_joined:
            return False
        try:
            wait = WebDriverWait(self.driver, 8)
            
            # Find the correct chat input (div.tiptap.ProseMirror[contenteditable='true'])
            try:
                chat_input = wait.until(EC.presence_of_element_located((
                    By.CSS_SELECTOR, "div.tiptap.ProseMirror[contenteditable='true']"
                )))
                chat_input.click()
                chat_input.clear() if hasattr(chat_input, 'clear') else None
                chat_input.send_keys(message)
                # Press Enter to send
                from selenium.webdriver.common.keys import Keys
                chat_input.send_keys(Keys.RETURN)
                print(f"Sent message: {message}")
                return True
            except Exception as e:
                print(f"Failed to send message: {e}")
                return False
        except Exception as e:
            print(f"Error sending message to chat: {e}")
            return False

    def send_chat_message(self, message: str) -> bool:
        """Send a message in the meeting chat (Zoom web client) - combines open and send"""
        # First open the chat panel
        if not self.open_chat_panel():
            return False
        
        # Then send the message
        return self.send_message_to_chat(message)

    def wait_for_meeting_loaded(self, timeout=30):
        """Wait for the meeting to be fully loaded before proceeding"""
        try:
            wait = WebDriverWait(self.driver, timeout)
            # Wait for common meeting elements to appear
            wait.until(EC.presence_of_element_located((
                By.XPATH, "//button[contains(@aria-label, 'Share') or contains(@aria-label, 'Chat') or contains(@aria-label, 'Leave')]"
            )))
            print("Meeting fully loaded")
            return True
        except Exception as e:
            print(f"Meeting may not be fully loaded: {e}")
            return False

    def switch_to_meeting_iframe(self):
        """Switch to the meeting iframe if it exists"""
        try:
            # Look for common iframe selectors in Zoom
            iframe_selectors = [
                "//iframe[contains(@id, 'meeting')]",
                "//iframe[contains(@class, 'meeting')]",
                "//iframe[contains(@title, 'meeting')]",
                "//iframe[contains(@src, 'meeting')]",
                "//iframe[contains(@src, 'zoom')]"
            ]
            
            for selector in iframe_selectors:
                try:
                    iframe = self.driver.find_element(By.XPATH, selector)
                    self.driver.switch_to.frame(iframe)
                    print(f"Switched to iframe: {selector}")
                    return True
                except:
                    continue
            
            # If no iframe found, stay in default content
            self.driver.switch_to.default_content()
            print("No meeting iframe found, staying in default content")
            return False
            
        except Exception as e:
            print(f"Error switching to iframe: {e}")
            return False

    def handle_overlay_elements(self):
        """Handle potential overlay elements that might block clicks"""
        try:
            # Look for common overlay elements and try to close them
            overlay_selectors = [
                "//div[contains(@class, 'overlay')]",
                "//div[contains(@class, 'modal')]",
                "//div[contains(@class, 'popup')]",
                "//button[contains(@aria-label, 'Close')]",
                "//button[contains(@title, 'Close')]",
                "//span[contains(@class, 'close')]"
            ]
            
            for selector in overlay_selectors:
                try:
                    overlay = self.driver.find_element(By.XPATH, selector)
                    if overlay.is_displayed():
                        overlay.click()
                        print(f"Closed overlay: {selector}")
                        time.sleep(0.5)
                except:
                    continue
                    
        except Exception as e:
            print(f"Error handling overlays: {e}")

    def scroll_element_into_view(self, element):
        """Scroll element into view before clicking"""
        try:
            self.driver.execute_script("arguments[0].scrollIntoView(true);", element)
            time.sleep(0.5)  # Wait for scroll to complete
            print("Scrolled element into view")
        except Exception as e:
            print(f"Error scrolling element into view: {e}")

    def close_driver(self):
        """Close the browser driver"""
        with self._driver_lock:
            if self.driver:
                try:
                    self.driver.quit()
                    logging.info('Closed Selenium driver')
                except Exception as e:
                    logging.warning('Error closing Selenium driver: %s', e)
                self.driver = None
            # Force kill any child processes
            for pid in self._child_pids:
                try:
                    os.kill(pid, 9)
                    logging.info('Force killed child process PID: %s', pid)
                except Exception as e:
                    logging.warning('Failed to kill child PID %s: %s', pid, e)
            self._child_pids.clear()

class BotSendMessageThread(QThread):
    """Thread for sending messages as a bot"""
    result_ready = pyqtSignal(bool, str)
    
    def __init__(self, bot_joiner, message):
        super().__init__()
        self.bot_joiner = bot_joiner
        self.message = message
    
    def run(self):
        try:
            success = self.bot_joiner.send_message_to_chat(self.message)
            if success:
                self.result_ready.emit(True, f"Message sent successfully: {self.message}")
            else:
                self.result_ready.emit(False, "Failed to send message")
        except Exception as e:
            self.result_ready.emit(False, f"Error sending message: {str(e)}")

class ProcessMonitorApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Truely - Dual-Join Process Monitor")
        self.setGeometry(100, 100, 500, 600)
        self.process_names = ["cluely"]
        # Known suspicious executable paths
        self.suspicious_paths = ["/Applications/Cluely.app/Contents/MacOS/Cluely"]
        # Known suspicious hashes
        self.suspicious_hashes = []
        self.last_alerted_pids = set()
        self.worker = None
        self.meeting_joiner = MeetingJoiner()
        self.bot_joiner = BotMeetingJoiner()
        
        # Automated meeting variables
        self.auto_meeting_active = False
        self.chat_opened = False
        self.last_cluely_alert_time = 0
        self.alert_cooldown = 30  # seconds between alerts
        
        self.init_ui()
        self.init_tray_icon()
        self.init_alert_window()
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.check_processes)
        self.timer.start(2000)  # Check every 2 seconds
        self.check_processes()
        
        # Update initial automated status
        QTimer.singleShot(500, self.update_automated_status)
        
        # Start automated meeting setup
        QTimer.singleShot(1000, self.start_automated_meeting)

    def start_automated_meeting(self):
        """Start the automated meeting process by asking for Zoom link"""
        if not SELENIUM_AVAILABLE:
            self.log_message("Selenium not available. Automated meeting features disabled.")
            return
            
        # Ask for Zoom link
        zoom_link, ok = QInputDialog.getText(
            self, 
            "Dual-Join Meeting Setup", 
            "Enter Zoom meeting URL or ID:\n(Leave empty to skip automated meeting)",
            QLineEdit.EchoMode.Normal
        )
        
        if ok and zoom_link.strip():
            self.log_message(f"Starting dual-join meeting with: {zoom_link}")
            self.join_dual_meeting(zoom_link.strip())
        else:
            self.log_message("Dual-join meeting setup skipped.")

    def join_dual_meeting(self, zoom_link: str):
        """Join both bot and user to the same meeting"""
        try:
            # Extract meeting ID and passcode from the URL
            meeting_id = self.bot_joiner.extract_zoom_meeting_id(zoom_link)
            if not meeting_id:
                self.log_message("Could not extract meeting ID from the provided link.")
                return
            
            # Extract passcode from URL if present
            passcode = None
            if 'pwd=' in zoom_link:
                try:
                    parsed = urllib.parse.urlparse(zoom_link)
                    query = urllib.parse.parse_qs(parsed.query)
                    passcode = query.get('pwd', [None])[0]
                    
                    if not passcode:
                        import re
                        pwd_match = re.search(r'pwd=([^&]+)', zoom_link)
                        if pwd_match:
                            passcode = pwd_match.group(1)
                    
                    if passcode:
                        self.log_message(f"Extracted passcode from URL: {passcode}")
                except Exception as e:
                    self.log_message(f"Could not extract passcode from URL: {e}")
            
            # Step 1: Join as bot
            self.log_message(f"Joining meeting {meeting_id} as Truely Bot...")
            bot_success = self.bot_joiner.join_zoom_meeting_bot(meeting_id, "Truely Bot", passcode)
            
            if bot_success:
                self.auto_meeting_active = True
                self.update_automated_status()
                self.log_message("Successfully joined meeting as bot!")
                
                # Step 2: Also join the actual user to the same meeting
                self.log_message("Joining actual user to the same meeting...")
                user_success = self.meeting_joiner.join_zoom_meeting(meeting_id, passcode)
                if user_success:
                    self.log_message("Successfully opened Zoom app for user to join!")
                    self.add_to_recent_meetings(f"Zoom: {meeting_id}")
                else:
                    self.log_message("Failed to open Zoom app for user.")
                
                # Wait a bit for meeting to load, then open chat
                QTimer.singleShot(2000, self.open_automated_chat)
                return True
            else:
                self.log_message("Failed to join meeting as bot.")
                return False
                
        except Exception as e:
            self.log_message(f"Error in dual meeting setup: {e}")
            return False

    def open_automated_chat(self):
        """Open chat panel for automated messaging"""
        try:
            if not self.auto_meeting_active:
                return
                
            self.log_message("Opening chat panel...")
            success = self.bot_joiner.open_chat_panel()
            if success:
                self.chat_opened = True
                self.update_automated_status()
                self.log_message("Chat panel opened successfully!")
                self.log_message("Automated monitoring active - will send alerts when cluely is detected.")
                
                # Send introduction message
                QTimer.singleShot(1000, self.send_introduction_message)
            else:
                self.log_message("Failed to open chat panel.")
                
        except Exception as e:
            self.log_message(f"Error opening automated chat: {e}")

    def send_introduction_message(self):
        """Send an introduction message when the bot joins the meeting"""
        try:
            if not self.auto_meeting_active or not self.chat_opened:
                return
            # Only send once per meeting
            if hasattr(self, '_intro_message_sent') and self._intro_message_sent:
                return
            self._intro_message_sent = True
            # Send the exact message requested
            intro_message = "Hello everyone! I'm Truely, your automated meeting monitor."
            self.intro_message_thread = BotSendMessageThread(self.bot_joiner, intro_message)
            self.intro_message_thread.result_ready.connect(self.on_intro_message_result)
            self.intro_message_thread.start()
        except Exception as e:
            self.log_message(f"Error sending introduction message: {e}")

    def on_intro_message_result(self, success: bool, message: str):
        """Handle introduction message send result"""
        if success:
            self.log_message("Introduction message sent successfully!")
        else:
            self.log_message("Failed to send introduction message.")

    def send_automated_alert(self, process_info: str):
        """Send suspicious activity alert to the meeting chat"""
        try:
            if not self.auto_meeting_active or not self.chat_opened:
                return
                
            # Check cooldown to avoid spam
            current_time = time.time()
            if current_time - self.last_cluely_alert_time < self.alert_cooldown:
                return
                
            # Create alert message
            timestamp = datetime.now().strftime("%H:%M:%S")
            alert_message = (
                f"ALERT: SUSPICIOUS ACTIVITY DETECTED [{timestamp}]\n"
                f"{process_info}\n\n"
                "This process has been flagged as potentially suspicious by Truely monitoring system."
            )
            # Send message
            success = self.bot_joiner.send_message_to_chat(alert_message)
            if success:
                self.last_cluely_alert_time = current_time
                self.log_message("Alert sent to meeting chat!")
            else:
                self.log_message("Failed to send alert to chat.")
        except Exception as e:
            self.log_message(f"Error sending automated alert: {e}")

    def init_ui(self):
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout(central_widget)
        layout.setSpacing(10)
        layout.setContentsMargins(12, 10, 12, 10)

        # Title
        title = QLabel("Truely - Dual-Join Process Monitor")
        title.setStyleSheet("font-size: 16px; font-weight: bold; margin-bottom: 4px;")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)

        # Automated monitoring status
        self.auto_status_label = QLabel("🤖 Automated Monitoring: Inactive")
        self.auto_status_label.setStyleSheet("font-size: 12px; font-weight: bold; color: #666; padding: 8px; background: #f0f0f0; border-radius: 4px; border: 1px solid #ddd;")
        layout.addWidget(self.auto_status_label)

        # Instructions
        instructions = QLabel("Add process names to monitor (case-insensitive, partial match):")
        instructions.setStyleSheet("font-size: 11px; margin-bottom: 2px;")
        layout.addWidget(instructions)

        # List of process names
        self.process_list = QListWidget()
        self.process_list.addItems(self.process_names)
        self.process_list.setStyleSheet("font-size: 11px;")
        layout.addWidget(self.process_list)

        # Add/Remove buttons
        btn_layout = QHBoxLayout()
        self.add_btn = QPushButton("Add Process")
        self.add_btn.setStyleSheet("padding: 4px 10px;")
        self.add_btn.clicked.connect(self.add_process)
        btn_layout.addWidget(self.add_btn)
        self.remove_btn = QPushButton("Remove Selected")
        self.remove_btn.setStyleSheet("padding: 4px 10px;")
        self.remove_btn.clicked.connect(self.remove_selected)
        btn_layout.addWidget(self.remove_btn)
        layout.addLayout(btn_layout)

        # Suspicious process area
        suspicious_label = QLabel("Suspicious Processes:")
        suspicious_label.setStyleSheet("font-size: 12px; font-weight: bold; margin-top: 8px;")
        layout.addWidget(suspicious_label)
        self.suspicious_text = QTextEdit()
        self.suspicious_text.setReadOnly(True)
        self.suspicious_text.setStyleSheet("background: #3a3f4b; color: #ffb347; font-family: monospace; font-size: 11px; border-radius: 4px; padding: 4px;")
        layout.addWidget(self.suspicious_text)

        # Status/log area
        status_label = QLabel("Status Log:")
        status_label.setStyleSheet("font-size: 12px; font-weight: bold; margin-top: 8px;")
        layout.addWidget(status_label)
        self.log_text = QTextEdit()
        self.log_text.setReadOnly(True)
        self.log_text.setStyleSheet("background: #23272e; color: #e0e0e0; font-family: monospace; font-size: 11px; border-radius: 4px; padding: 4px;")
        layout.addWidget(self.log_text)

        # Manual check button
        self.check_btn = QPushButton("Check Now")
        self.check_btn.setStyleSheet("margin-top: 8px; padding: 6px 16px; font-size: 12px; font-weight: bold;")
        self.check_btn.clicked.connect(self.check_processes)
        layout.addWidget(self.check_btn, alignment=Qt.AlignmentFlag.AlignCenter)

    def init_tray_icon(self):
        # Normal icon: circle with a capital T, Columbia blue background
        self.tray_icon = QSystemTrayIcon(self)
        self.tray_icon.setToolTip("Truely - Process Monitor")
        
        # Create normal icon (blue circle with T)
        normal_pixmap = QPixmap(32, 32)
        normal_pixmap.fill(QColor(0, 0, 0, 0))  # Transparent background
        painter = QPainter(normal_pixmap)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        
        # Draw blue circle
        painter.setBrush(QColor(155, 194, 230))  # Columbia blue
        painter.setPen(QColor(100, 150, 200))
        painter.drawEllipse(2, 2, 28, 28)
        
        # Draw white T
        painter.setPen(QColor(255, 255, 255))
        font = QFont("Arial", 16, QFont.Weight.Bold)
        painter.setFont(font)
        painter.drawText(normal_pixmap.rect(), Qt.AlignmentFlag.AlignCenter, "T")
        painter.end()
        
        self.normal_icon = QIcon(normal_pixmap)
        self.tray_icon.setIcon(self.normal_icon)
        
        # Create warning icon (red circle with T)
        warning_pixmap = QPixmap(32, 32)
        warning_pixmap.fill(QColor(0, 0, 0, 0))
        painter = QPainter(warning_pixmap)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        
        painter.setBrush(QColor(255, 85, 85))  # Red
        painter.setPen(QColor(200, 50, 50))
        painter.drawEllipse(2, 2, 28, 28)
        
        painter.setPen(QColor(255, 255, 255))
        painter.setFont(font)
        painter.drawText(warning_pixmap.rect(), Qt.AlignmentFlag.AlignCenter, "T")
        painter.end()
        
        self.warning_icon = QIcon(warning_pixmap)
        
        # Create tray menu
        tray_menu = QMenu()
        show_action = QAction("Show", self)
        show_action.triggered.connect(self.show)
        tray_menu.addAction(show_action)
        
        quit_action = QAction("Quit", self)
        quit_action.triggered.connect(self.close)
        tray_menu.addAction(quit_action)
        
        self.tray_icon.setContextMenu(tray_menu)
        self.tray_icon.show()

    def set_tray_warning(self, warning):
        # Only update icon if state changes
        if warning:
            self.tray_icon.setIcon(self.warning_icon)
        else:
            self.tray_icon.setIcon(self.normal_icon)

    def init_alert_window(self):
        """Initialize the always-on-top alert window"""
        self.alert_window = QWidget()
        self.alert_window.setWindowTitle("⚠️ TRUELY ALERT")
        self.alert_window.setWindowFlags(Qt.WindowType.WindowStaysOnTopHint | Qt.WindowType.FramelessWindowHint)
        self.alert_window.setStyleSheet("background-color: #ff4444; color: white; border: 3px solid #cc0000;")
        
        layout = QVBoxLayout(self.alert_window)
        
        # Alert title
        title = QLabel("⚠️ SUSPICIOUS PROCESS DETECTED ⚠️")
        title.setStyleSheet("font-size: 18px; font-weight: bold; margin: 10px;")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)
        
        # Alert message
        self.alert_message = QLabel("A suspicious process has been detected on your system!")
        self.alert_message.setStyleSheet("font-size: 14px; margin: 10px;")
        self.alert_message.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.alert_message.setWordWrap(True)
        layout.addWidget(self.alert_message)
        
        # Close button
        close_btn = QPushButton("Dismiss Alert")
        close_btn.setStyleSheet("padding: 8px 16px; font-size: 12px; background: #cc0000; color: white; border: none; border-radius: 4px;")
        close_btn.clicked.connect(self.hide_alert_window)
        layout.addWidget(close_btn, alignment=Qt.AlignmentFlag.AlignCenter)
        
        # Position window
        screen = QApplication.primaryScreen().geometry()
        self.alert_window.setGeometry(screen.width() - 400, 50, 380, 150)

    def pulse_alert(self):
        """Pulse the alert window to draw attention"""
        if hasattr(self, 'alert_window') and self.alert_window.isVisible():
            # Simple pulse effect - could be enhanced
            current_style = self.alert_window.styleSheet()
            if "border: 5px solid #ff0000" in current_style:
                self.alert_window.setStyleSheet(current_style.replace("border: 5px solid #ff0000", "border: 3px solid #cc0000"))
            else:
                self.alert_window.setStyleSheet(current_style.replace("border: 3px solid #cc0000", "border: 5px solid #ff0000"))

    def show_alert_window(self):
        """Show the alert window"""
        if hasattr(self, 'alert_window'):
            self.alert_window.show()
            self.alert_window.raise_()
            self.alert_window.activateWindow()

    def hide_alert_window(self):
        """Hide the alert window"""
        if hasattr(self, 'alert_window'):
            self.alert_window.hide()

    def notify_suspicious(self, message):
        """Show notification for suspicious activity"""
        self.tray_icon.showMessage("Truely Alert", message, QSystemTrayIcon.MessageIcon.Warning, 5000)

    def add_process(self):
        """Add a process to monitor"""
        process_name, ok = QInputDialog.getText(self, "Add Process", "Enter process name to monitor:")
        if ok and process_name.strip():
            self.process_names.append(process_name.strip().lower())
            self.process_list.addItem(process_name.strip())

    def remove_selected(self):
        """Remove selected process from monitoring"""
        current_row = self.process_list.currentRow()
        if current_row >= 0:
            item = self.process_list.takeItem(current_row)
            if item.text().lower() in self.process_names:
                self.process_names.remove(item.text().lower())

    def get_process_names(self) -> List[str]:
        return self.process_names

    def check_processes(self):
        """Check for suspicious processes"""
        if self.worker and self.worker.isRunning():
            return
            
        self.worker = SuspiciousProcessWorker(
            self.get_process_names, 
            self.suspicious_paths, 
            self.suspicious_hashes
        )
        self.worker.result_ready.connect(self.handle_suspicious_result)
        self.worker.start()

    def handle_suspicious_result(self, suspicious, new_alerted_pids):
        # Show/hide alert window and set tray icon
        if suspicious:
            # Check if we have new PIDs to alert about
            new_pids = new_alerted_pids - self.last_alerted_pids
            if new_pids:
                self.show_alert_window()
                self.set_tray_warning(True)
                
                # Send alert to meeting chat if available
                for process_info in suspicious:
                    self.send_automated_alert(process_info)
                
                # Show notification
                self.notify_suspicious(f"Detected {len(suspicious)} suspicious processes")
                
                # Pulse alert window
                QTimer.singleShot(1000, self.pulse_alert)
        else:
            self.hide_alert_window()
            self.set_tray_warning(False)
        
        # Update display
        if suspicious:
            self.suspicious_text.setHtml("<br>".join(suspicious))
        else:
            self.suspicious_text.setHtml("<span style='color:#4CAF50;'>✅ No suspicious processes detected</span>")
        
        self.last_alerted_pids = new_alerted_pids

    def log_message(self, message: str):
        """Add a message to the log"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.log_text.append(f"[{timestamp}] {message}")

    def add_to_recent_meetings(self, meeting_info: str):
        """Add a meeting to the recent meetings list"""
        # This is a simplified version - in the full app this would update a list
        self.log_message(f"Added to recent meetings: {meeting_info}")

    def update_automated_status(self):
        """Update the automated monitoring status display"""
        if self.auto_meeting_active:
            if self.chat_opened:
                self.auto_status_label.setText("🤖 Automated Monitoring: Active (Chat Ready)")
                self.auto_status_label.setStyleSheet("font-size: 12px; font-weight: bold; color: #4CAF50; padding: 8px; background: #e8f5e8; border-radius: 4px; border: 1px solid #4CAF50;")
            else:
                self.auto_status_label.setText("🤖 Automated Monitoring: Active (Joining Chat...)")
                self.auto_status_label.setStyleSheet("font-size: 12px; font-weight: bold; color: #FF6B35; padding: 8px; background: #fff3e0; border-radius: 4px; border: 1px solid #FF6B35;")
        else:
            self.auto_status_label.setText("🤖 Automated Monitoring: Inactive")
            self.auto_status_label.setStyleSheet("font-size: 12px; font-weight: bold; color: #666; padding: 8px; background: #f0f0f0; border-radius: 4px; border: 1px solid #ddd;")

    def closeEvent(self, event):
        """Handle application close event"""
        try:
            # Stop worker thread
            if self.worker and self.worker.isRunning():
                self.worker.stop()
                self.worker.wait()
            
            # Close bot driver
            if self.bot_joiner:
                self.bot_joiner.close_driver()
            
            # Hide tray icon
            if hasattr(self, 'tray_icon'):
                self.tray_icon.hide()
            
            event.accept()
        except Exception as e:
            print(f"Error during shutdown: {e}")
            event.accept()

def main():
    # Watchdog timer (optional, e.g. 2 hours)
    def watchdog():
        print("Watchdog timer expired - shutting down")
        os._exit(0)
    
    def handle_exit(signum, frame):
        print("Received signal, shutting down gracefully...")
        os._exit(0)
    
    # Set up signal handlers
    signal.signal(signal.SIGINT, handle_exit)
    signal.signal(signal.SIGTERM, handle_exit)
    
    # Start watchdog timer (optional)
    # threading.Timer(7200, watchdog).start()  # 2 hours
    
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)  # Keep running when window is closed
    
    window = ProcessMonitorApp()
    window.show()
    
    sys.exit(app.exec())

if __name__ == "__main__":
    main() 