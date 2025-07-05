#!/usr/bin/env python3
"""
Advanced Screen Capture Tool for macOS
A comprehensive screen capture application that can handle protected content
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
            # Install selenium and webdriver-manager
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
    filename='advanced_screen_capture.log',
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
    """Handles joining Zoom and Google Meet meetings"""
    
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
            
            # Return success - note that actual joining requires user interaction
            print(f"Opened Zoom meeting {clean_id} in Zoom application")
            return True
        except Exception as e:
            print(f"Error joining Zoom meeting: {e}")
            return False
    
    @staticmethod
    def try_zoom_automation(meeting_id: str, password: str = None) -> bool:
        """Attempt to automate Zoom joining using AppleScript (limited success)"""
        try:
            # This AppleScript attempts to automate Zoom, but will likely be blocked
            script = f'''
            tell application "Zoom.us"
                activate
                delay 2
                tell application "System Events"
                    tell process "Zoom.us"
                        -- Try to click join button if it exists
                        try
                            click button "Join" of window 1
                        on error
                            -- If no join button, try to enter meeting ID
                            try
                                set value of text field 1 of window 1 to "{meeting_id}"
                                click button "Join" of window 1
                            on error
                                -- If that fails, just note that manual intervention is needed
                                display dialog "Please manually join meeting {meeting_id}"
                            end try
                        end try
                    end tell
                end tell
            end tell
            '''
            
            # Run the AppleScript
            result = subprocess.run(['osascript', '-e', script], 
                                  capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0:
                print(f"AppleScript automation attempted for meeting {meeting_id}")
                return True
            else:
                print(f"AppleScript failed: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            print("AppleScript timed out")
            return False
        except Exception as e:
            print(f"AppleScript error: {e}")
            return False
    
    @staticmethod
    def join_google_meet(meeting_url: str) -> bool:
        """Join a Google Meet meeting using the meeting URL"""
        try:
            # Clean and validate the URL
            if not meeting_url.startswith(('http://', 'https://')):
                if 'meet.google.com' in meeting_url:
                    meeting_url = 'https://' + meeting_url
                else:
                    return False
            
            # Open in default browser
            webbrowser.open(meeting_url)
            return True
        except Exception as e:
            print(f"Error joining Google Meet: {e}")
            return False
    
    @staticmethod
    def parse_meeting_url(url: str) -> dict:
        """Parse a meeting URL to determine type and extract meeting info"""
        try:
            parsed = urllib.parse.urlparse(url)
            
            # Zoom meeting detection
            if 'zoom.us' in parsed.netloc or 'zoommtg://' in url:
                # Extract meeting ID from various Zoom URL formats
                if 'zoommtg://' in url:
                    # Handle zoommtg:// format
                    params = urllib.parse.parse_qs(parsed.query)
                    meeting_id = params.get('confno', [''])[0]
                else:
                    # Handle web URL format
                    path_parts = parsed.path.split('/')
                    meeting_id = None
                    for i, part in enumerate(path_parts):
                        if part in ['j', 'join'] and i + 1 < len(path_parts):
                            meeting_id = path_parts[i + 1]
                            break
                
                return {
                    'type': 'zoom',
                    'meeting_id': meeting_id,
                    'password': urllib.parse.parse_qs(parsed.query).get('pwd', [None])[0]
                }
            
            # Google Meet detection
            elif 'meet.google.com' in parsed.netloc:
                meeting_code = parsed.path.strip('/')
                return {
                    'type': 'google_meet',
                    'meeting_url': url,
                    'meeting_code': meeting_code
                }
            
            return {'type': 'unknown', 'url': url}
            
        except Exception as e:
            print(f"Error parsing meeting URL: {e}")
            return {'type': 'unknown', 'url': url}

class BotMeetingJoiner:
    """Handles joining meetings as a bot using browser automation"""
    
    def __init__(self):
        self.driver = None
        self.driver_process = None
        self.is_joined = False
        self._driver_lock = threading.Lock()
        self._child_pids = []  # Track child PIDs for cleanup
        


def setup_driver(self):

    import logging
    import undetected_chromedriver as uc
    
    """Setup undetected Chrome driver for automation"""
    if not SELENIUM_AVAILABLE:
        return False

    try:
        user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 CustomAgent/1.0"

        # Setup undetected Chrome options
        chrome_options = uc.ChromeOptions()
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        chrome_options.add_argument("--disable-blink-features=AutomationControlled")
        chrome_options.add_argument(f"user-agent={user_agent}")

        # Launch undetected Chrome
        self.driver = uc.Chrome(options=chrome_options, headless=False)

        # Try to capture the Chrome process PID
        try:
            self.driver_process = getattr(self.driver.service, 'process', None)
            if self.driver_process:
                self._child_pids.append(self.driver_process.pid)
                logging.info('Started undetected ChromeDriver (PID: %s)', self.driver_process.pid)
        except Exception as pid_err:
            logging.warning('Could not capture ChromeDriver PID: %s', pid_err)

        return True

    except Exception as e:
        logging.error('Failed to start undetected ChromeDriver: %s', e)
        return False

    
    def join_zoom_meeting_bot(self, meeting_id: str, name: str = "Bot", password: str = None) -> bool:
        """Join Zoom meeting as a bot using web interface"""
        if not self.setup_driver():
            return False
            
        try:
            # Parse meeting ID from URL if it's a full URL
            clean_meeting_id = self.extract_zoom_meeting_id(meeting_id)
            if not clean_meeting_id:
                print(f"Could not extract meeting ID from: {meeting_id}")
                return False
            
            # Navigate to Zoom web join page
            join_url = f"https://zoom.us/wc/join/{clean_meeting_id}"
            self.driver.get(join_url)
            
            # Wait for page to load
            wait = WebDriverWait(self.driver, 10)
            
            # Enter name
            try:
                name_input = wait.until(EC.presence_of_element_located((By.ID, "inputname")))
                name_input.clear()
                name_input.send_keys(name)
            except:
                print("Could not find name input field")
            
            # Enter password if provided
            if password:
                try:
                    password_input = wait.until(EC.presence_of_element_located((By.ID, "inputpasscode")))
                    password_input.clear()
                    password_input.send_keys(password)
                except:
                    print("Could not find password input field")
            
            # Click join button
            try:
                join_button = wait.until(EC.element_to_be_clickable((By.ID, "joinBtn")))
                join_button.click()
                self.is_joined = True
                print(f"Successfully joined Zoom meeting {clean_meeting_id} as {name}")
                return True
            except Exception as e:
                print(f"Failed to click join button: {e}")
                return False
                
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
                
                # Handle web URL formats
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
    
    def join_google_meet_bot(self, meeting_url: str, name: str = "Bot") -> bool:
        """Join Google Meet as a bot using web interface"""
        if not self.setup_driver():
            return False
            
        try:
            # Navigate to Google Meet
            if not meeting_url.startswith(('http://', 'https://')):
                meeting_url = 'https://' + meeting_url
            
            self.driver.get(meeting_url)
            
            # Wait for page to load
            wait = WebDriverWait(self.driver, 15)
            
            # Handle Google Meet join flow
            try:
                # Look for join button
                join_button = wait.until(EC.element_to_be_clickable((By.XPATH, "//span[contains(text(), 'Join now') or contains(text(), 'Ask to join')]")))
                join_button.click()
                
                # Enter name if prompted
                try:
                    name_input = wait.until(EC.presence_of_element_located((By.XPATH, "//input[@placeholder='Your name']")))
                    name_input.clear()
                    name_input.send_keys(name)
                except:
                    print("Could not find name input field")
                
                # Click final join button
                try:
                    final_join = wait.until(EC.element_to_be_clickable((By.XPATH, "//span[contains(text(), 'Join now') or contains(text(), 'Ask to join')]")))
                    final_join.click()
                    self.is_joined = True
                    print(f"Successfully joined Google Meet as {name}")
                    return True
                except:
                    print("Could not find final join button")
                    return False
                    
            except Exception as e:
                print(f"Failed to join Google Meet: {e}")
                return False
                
        except Exception as e:
            print(f"Error joining Google Meet as bot: {e}")
            return False
    
    def send_chat_message(self, message: str) -> bool:
        """Send a message in the meeting chat"""
        if not self.driver or not self.is_joined:
            return False
            
        try:
            wait = WebDriverWait(self.driver, 5)
            
            # Try to find and click chat button
            try:
                chat_button = wait.until(EC.element_to_be_clickable((By.XPATH, "//button[contains(@aria-label, 'Chat') or contains(@title, 'Chat')]")))
                chat_button.click()
            except:
                print("Could not find chat button")
                return False
            
            # Find chat input and send message
            try:
                chat_input = wait.until(EC.presence_of_element_located((By.XPATH, "//textarea[contains(@placeholder, 'Type a message') or contains(@aria-label, 'Chat message')]")))
                chat_input.clear()
                chat_input.send_keys(message)
                
                # Send the message
                send_button = wait.until(EC.element_to_be_clickable((By.XPATH, "//button[contains(@aria-label, 'Send') or contains(@title, 'Send')]")))
                send_button.click()
                
                print(f"Sent message: {message}")
                return True
            except Exception as e:
                print(f"Failed to send message: {e}")
                return False
                
        except Exception as e:
            print(f"Error sending chat message: {e}")
            return False
    
    def leave_meeting(self):
        """Leave the current meeting"""
        if not self.driver:
            return
            
        try:
            # Try to find and click leave button
            wait = WebDriverWait(self.driver, 5)
            leave_button = wait.until(EC.element_to_be_clickable((By.XPATH, "//button[contains(@aria-label, 'Leave') or contains(@title, 'Leave') or contains(text(), 'Leave')]")))
            leave_button.click()
            
            # Confirm leave if prompted
            try:
                confirm_button = wait.until(EC.element_to_be_clickable((By.XPATH, "//button[contains(text(), 'Leave') or contains(text(), 'End')]")))
                confirm_button.click()
            except:
                pass
                
            self.is_joined = False
            print("Left the meeting")
        except Exception as e:
            print(f"Error leaving meeting: {e}")
    
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

    # Example: Add timeout to subprocess calls (AppleScript)
    @staticmethod
    def run_applescript_with_timeout(script, timeout=10):
        try:
            result = subprocess.run(['osascript', '-e', script], capture_output=True, text=True, timeout=timeout)
            return result
        except subprocess.TimeoutExpired:
            logging.error('AppleScript timed out')
            return None
        except Exception as e:
            logging.error('AppleScript error: %s', e)
            return None

class BotJoinThread(QThread):
    """Thread for joining meetings as a bot"""
    result_ready = pyqtSignal(bool, str)
    
    def __init__(self, bot_joiner, meeting_type, meeting_id, bot_name, password=None):
        super().__init__()
        self.bot_joiner = bot_joiner
        self.meeting_type = meeting_type
        self.meeting_id = meeting_id
        self.bot_name = bot_name
        self.password = password
    
    def run(self):
        try:
            if self.meeting_type == 'zoom':
                success = self.bot_joiner.join_zoom_meeting_bot(self.meeting_id, self.bot_name, self.password)
                if success:
                    self.result_ready.emit(True, f"Successfully joined Zoom meeting {self.meeting_id} as {self.bot_name}")
                else:
                    self.result_ready.emit(False, "Failed to join Zoom meeting as bot")
            elif self.meeting_type == 'meet':
                success = self.bot_joiner.join_google_meet_bot(self.meeting_id, self.bot_name)
                if success:
                    self.result_ready.emit(True, f"Successfully joined Google Meet as {self.bot_name}")
                else:
                    self.result_ready.emit(False, "Failed to join Google Meet as bot")
        except Exception as e:
            self.result_ready.emit(False, f"Error joining meeting: {str(e)}")

class BotMessageThread(QThread):
    """Thread for sending messages as a bot"""
    result_ready = pyqtSignal(bool, str)
    
    def __init__(self, bot_joiner, message):
        super().__init__()
        self.bot_joiner = bot_joiner
        self.message = message
    
    def run(self):
        try:
            success = self.bot_joiner.send_chat_message(self.message)
            if success:
                self.result_ready.emit(True, f"Message sent: {self.message}")
            else:
                self.result_ready.emit(False, "Failed to send message")
        except Exception as e:
            self.result_ready.emit(False, f"Error sending message: {str(e)}")

class ProcessMonitorApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Truely - Suspicious Process Monitor & Meeting Joiner")
        self.setGeometry(100, 100, 500, 600)
        self.process_names = ["cluely"]
        # Known suspicious executable paths (add more as needed)
        self.suspicious_paths = ["/Applications/Cluely.app/Contents/MacOS/Cluely"]
        # Known suspicious hashes (add real hash if known)
        self.suspicious_hashes = [
            # Example: "abcdef1234567890..."
        ]
        self.last_alerted_pids = set()
        self.worker = None
        self.meeting_joiner = MeetingJoiner()
        self.bot_joiner = BotMeetingJoiner()
        self.init_ui()
        self.init_tray_icon()
        self.init_alert_window()
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.check_processes)
        self.timer.start(2000)  # Check every 2 seconds
        self.check_processes()

    def init_ui(self):
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout(central_widget)
        layout.setSpacing(10)
        layout.setContentsMargins(12, 10, 12, 10)

        # Title
        title = QLabel("Truely - Process Monitor & Meeting Joiner")
        title.setStyleSheet("font-size: 16px; font-weight: bold; margin-bottom: 4px;")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)

        # Create tab widget
        self.tab_widget = QTabWidget()
        layout.addWidget(self.tab_widget)

        # Process Monitor Tab
        self.process_tab = QWidget()
        self.init_process_monitor_tab()
        self.tab_widget.addTab(self.process_tab, "Process Monitor")

        # Meeting Joiner Tab
        self.meeting_tab = QWidget()
        self.init_meeting_joiner_tab()
        self.tab_widget.addTab(self.meeting_tab, "Meeting Joiner")

        # Bot Joiner Tab
        self.bot_tab = QWidget()
        self.init_bot_joiner_tab()
        self.tab_widget.addTab(self.bot_tab, "Bot Joiner")

    def init_process_monitor_tab(self):
        """Initialize the process monitoring tab"""
        layout = QVBoxLayout(self.process_tab)
        layout.setSpacing(10)
        layout.setContentsMargins(0, 0, 0, 0)

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

    def init_meeting_joiner_tab(self):
        """Initialize the meeting joiner tab"""
        layout = QVBoxLayout(self.meeting_tab)
        layout.setSpacing(15)
        layout.setContentsMargins(0, 0, 0, 0)

        # Information section
        info_group = QGroupBox("ℹ️ How It Works")
        info_group.setStyleSheet("QGroupBox { font-weight: bold; font-size: 12px; }")
        info_layout = QVBoxLayout(info_group)
        
        info_text = QLabel("This tool opens meetings in Zoom/Meet apps or browser. Manual confirmation is required to actually join meetings and send messages.")
        info_text.setStyleSheet("font-size: 10px; color: #666; padding: 8px; background: #f5f5f5; border-radius: 4px;")
        info_text.setWordWrap(True)
        info_layout.addWidget(info_text)
        
        layout.addWidget(info_group)

        # Quick Join Section
        quick_join_group = QGroupBox("Quick Join")
        quick_join_group.setStyleSheet("QGroupBox { font-weight: bold; font-size: 12px; }")
        quick_layout = QVBoxLayout(quick_join_group)

        # Meeting URL/ID input
        url_label = QLabel("Meeting URL or ID:")
        url_label.setStyleSheet("font-size: 11px;")
        quick_layout.addWidget(url_label)
        
        self.meeting_input = QLineEdit()
        self.meeting_input.setPlaceholderText("Enter Zoom meeting ID, Zoom URL, or Google Meet URL")
        self.meeting_input.setStyleSheet("padding: 8px; font-size: 11px;")
        quick_layout.addWidget(self.meeting_input)

        # Password input (for Zoom)
        self.password_label = QLabel("Password (optional):")
        self.password_label.setStyleSheet("font-size: 11px;")
        quick_layout.addWidget(self.password_label)
        
        self.password_input = QLineEdit()
        self.password_input.setPlaceholderText("Enter meeting password if required")
        self.password_input.setStyleSheet("padding: 8px; font-size: 11px;")
        self.password_input.setEchoMode(QLineEdit.EchoMode.Password)
        quick_layout.addWidget(self.password_input)

        # Join button
        self.join_btn = QPushButton("Join Meeting")
        self.join_btn.setStyleSheet("padding: 10px; font-size: 12px; font-weight: bold; background: #4CAF50; color: white; border-radius: 4px;")
        self.join_btn.clicked.connect(self.join_meeting)
        quick_layout.addWidget(self.join_btn)

        layout.addWidget(quick_join_group)

        # Manual Join Section
        manual_group = QGroupBox("Manual Join")
        manual_group.setStyleSheet("QGroupBox { font-weight: bold; font-size: 12px; }")
        manual_layout = QGridLayout(manual_group)

        # Zoom section
        zoom_label = QLabel("Zoom Meeting:")
        zoom_label.setStyleSheet("font-size: 11px; font-weight: bold;")
        manual_layout.addWidget(zoom_label, 0, 0)

        self.zoom_id_input = QLineEdit()
        self.zoom_id_input.setPlaceholderText("Meeting ID or URL (e.g., 123456789 or https://zoom.us/j/123456789)")
        self.zoom_id_input.setStyleSheet("padding: 6px; font-size: 11px;")
        manual_layout.addWidget(self.zoom_id_input, 0, 1)

        self.zoom_pwd_input = QLineEdit()
        self.zoom_pwd_input.setPlaceholderText("Password (optional)")
        self.zoom_pwd_input.setStyleSheet("padding: 6px; font-size: 11px;")
        self.zoom_pwd_input.setEchoMode(QLineEdit.EchoMode.Password)
        manual_layout.addWidget(self.zoom_pwd_input, 0, 2)

        self.zoom_join_btn = QPushButton("Join Zoom")
        self.zoom_join_btn.setStyleSheet("padding: 6px 12px; font-size: 11px; background: #2D8CFF; color: white; border-radius: 3px;")
        self.zoom_join_btn.clicked.connect(self.join_zoom_manual)
        manual_layout.addWidget(self.zoom_join_btn, 0, 3)

        # Auto join button (experimental)
        self.zoom_auto_btn = QPushButton("Auto Join")
        self.zoom_auto_btn.setStyleSheet("padding: 6px 12px; font-size: 11px; background: #FF6B35; color: white; border-radius: 3px;")
        self.zoom_auto_btn.clicked.connect(self.auto_join_zoom)
        self.zoom_auto_btn.setToolTip("Attempts to automate joining (may be blocked by macOS security)")
        manual_layout.addWidget(self.zoom_auto_btn, 0, 4)

        # Google Meet section
        meet_label = QLabel("Google Meet:")
        meet_label.setStyleSheet("font-size: 11px; font-weight: bold;")
        manual_layout.addWidget(meet_label, 1, 0)

        self.meet_url_input = QLineEdit()
        self.meet_url_input.setPlaceholderText("Meeting URL (e.g., meet.google.com/abc-defg-hij)")
        self.meet_url_input.setStyleSheet("padding: 6px; font-size: 11px;")
        manual_layout.addWidget(self.meet_url_input, 1, 1, 1, 2)

        self.meet_join_btn = QPushButton("Join Meet")
        self.meet_join_btn.setStyleSheet("padding: 6px 12px; font-size: 11px; background: #00AC47; color: white; border-radius: 3px;")
        self.meet_join_btn.clicked.connect(self.join_meet_manual)
        manual_layout.addWidget(self.meet_join_btn, 1, 3)

        layout.addWidget(manual_group)

        # Recent meetings section
        recent_group = QGroupBox("Recent Meetings")
        recent_group.setStyleSheet("QGroupBox { font-weight: bold; font-size: 12px; }")
        recent_layout = QVBoxLayout(recent_group)

        self.recent_meetings_list = QListWidget()
        self.recent_meetings_list.setStyleSheet("font-size: 11px; max-height: 100px;")
        recent_layout.addWidget(self.recent_meetings_list)

        # Add some example meetings
        example_meetings = [
            "Zoom: 123456789 (Team Standup)",
            "Meet: meet.google.com/abc-defg-hij (Project Review)",
            "Zoom: 987654321 (Client Meeting)"
        ]
        self.recent_meetings_list.addItems(example_meetings)

        layout.addWidget(recent_group)

        # Status area
        self.meeting_status = QTextEdit()
        self.meeting_status.setReadOnly(True)
        self.meeting_status.setMaximumHeight(80)
        self.meeting_status.setStyleSheet("background: #23272e; color: #e0e0e0; font-family: monospace; font-size: 10px; border-radius: 4px; padding: 4px;")
        self.meeting_status.setHtml("<span style='color:#b3e6ff;'>Ready to join meetings. Enter a meeting URL or ID above.</span>")
        layout.addWidget(self.meeting_status)

    def init_bot_joiner_tab(self):
        """Initialize the bot joiner tab"""
        layout = QVBoxLayout(self.bot_tab)
        layout.setSpacing(15)
        layout.setContentsMargins(0, 0, 0, 0)

        # Warning section
        warning_group = QGroupBox("⚠️ Bot Features")
        warning_group.setStyleSheet("QGroupBox { font-weight: bold; font-size: 12px; }")
        warning_layout = QVBoxLayout(warning_group)
        
        warning_text = QLabel("This feature joins meetings as a bot using browser automation. Use responsibly and only for authorized meetings.")
        warning_text.setStyleSheet("font-size: 10px; color: #ff5555; padding: 8px; background: #ffe6e6; border-radius: 4px;")
        warning_text.setWordWrap(True)
        warning_layout.addWidget(warning_text)
        
        layout.addWidget(warning_group)

        # Selenium Status
        selenium_group = QGroupBox("🔧 Selenium Status")
        selenium_group.setStyleSheet("QGroupBox { font-weight: bold; font-size: 12px; }")
        selenium_layout = QVBoxLayout(selenium_group)
        
        if SELENIUM_AVAILABLE:
            selenium_status = QLabel("✅ Selenium is available and ready for bot automation")
            selenium_status.setStyleSheet("font-size: 10px; color: #4CAF50; padding: 8px; background: #e8f5e8; border-radius: 4px;")
        else:
            selenium_status = QLabel("❌ Selenium not available. Bot features will be disabled. Please install: pip install selenium webdriver-manager")
            selenium_status.setStyleSheet("font-size: 10px; color: #ff5555; padding: 8px; background: #ffe6e6; border-radius: 4px;")
        
        selenium_status.setWordWrap(True)
        selenium_layout.addWidget(selenium_status)
        
        # Add retry button if Selenium is not available
        if not SELENIUM_AVAILABLE:
            retry_btn = QPushButton("🔄 Retry Selenium Installation")
            retry_btn.setStyleSheet("padding: 6px 12px; font-size: 11px; background: #FF6B35; color: white; border-radius: 3px;")
            retry_btn.clicked.connect(self.retry_selenium_installation)
            selenium_layout.addWidget(retry_btn)
        
        layout.addWidget(selenium_group)

        # Bot Configuration
        config_group = QGroupBox("Bot Configuration")
        config_group.setStyleSheet("QGroupBox { font-weight: bold; font-size: 12px; }")
        config_layout = QGridLayout(config_group)

        # Bot name
        name_label = QLabel("Bot Name:")
        name_label.setStyleSheet("font-size: 11px;")
        config_layout.addWidget(name_label, 0, 0)

        self.bot_name_input = QLineEdit()
        self.bot_name_input.setText("Meeting Bot")
        self.bot_name_input.setStyleSheet("padding: 6px; font-size: 11px;")
        config_layout.addWidget(self.bot_name_input, 0, 1)

        # Auto send message
        self.auto_message_checkbox = QCheckBox("Auto send message")
        self.auto_message_checkbox.setStyleSheet("font-size: 11px;")
        config_layout.addWidget(self.auto_message_checkbox, 0, 2)

        # Message input
        message_label = QLabel("Message:")
        message_label.setStyleSheet("font-size: 11px;")
        config_layout.addWidget(message_label, 1, 0)

        self.bot_message_input = QLineEdit()
        self.bot_message_input.setText("Hello! I'm a bot joining this meeting.")
        self.bot_message_input.setStyleSheet("padding: 6px; font-size: 11px;")
        config_layout.addWidget(self.bot_message_input, 1, 1, 1, 2)

        layout.addWidget(config_group)

        # Zoom Bot Section
        zoom_bot_group = QGroupBox("Zoom Bot")
        zoom_bot_group.setStyleSheet("QGroupBox { font-weight: bold; font-size: 12px; }")
        zoom_bot_layout = QGridLayout(zoom_bot_group)

        zoom_bot_label = QLabel("Meeting ID/URL:")
        zoom_bot_label.setStyleSheet("font-size: 11px;")
        zoom_bot_layout.addWidget(zoom_bot_label, 0, 0)

        self.zoom_bot_id_input = QLineEdit()
        self.zoom_bot_id_input.setPlaceholderText("Enter Zoom meeting ID or URL")
        self.zoom_bot_id_input.setStyleSheet("padding: 6px; font-size: 11px;")
        zoom_bot_layout.addWidget(self.zoom_bot_id_input, 0, 1)

        self.zoom_bot_pwd_input = QLineEdit()
        self.zoom_bot_pwd_input.setPlaceholderText("Password (optional)")
        self.zoom_bot_pwd_input.setStyleSheet("padding: 6px; font-size: 11px;")
        self.zoom_bot_pwd_input.setEchoMode(QLineEdit.EchoMode.Password)
        zoom_bot_layout.addWidget(self.zoom_bot_pwd_input, 0, 2)

        self.zoom_bot_join_btn = QPushButton("Join as Bot")
        self.zoom_bot_join_btn.setStyleSheet("padding: 6px 12px; font-size: 11px; background: #2D8CFF; color: white; border-radius: 3px;")
        self.zoom_bot_join_btn.clicked.connect(self.join_zoom_as_bot)
        zoom_bot_layout.addWidget(self.zoom_bot_join_btn, 0, 3)

        layout.addWidget(zoom_bot_group)

        # Google Meet Bot Section
        meet_bot_group = QGroupBox("Google Meet Bot")
        meet_bot_group.setStyleSheet("QGroupBox { font-weight: bold; font-size: 12px; }")
        meet_bot_layout = QGridLayout(meet_bot_group)

        meet_bot_label = QLabel("Meeting URL:")
        meet_bot_label.setStyleSheet("font-size: 11px;")
        meet_bot_layout.addWidget(meet_bot_label, 0, 0)

        self.meet_bot_url_input = QLineEdit()
        self.meet_bot_url_input.setPlaceholderText("Enter Google Meet URL")
        self.meet_bot_url_input.setStyleSheet("padding: 6px; font-size: 11px;")
        meet_bot_layout.addWidget(self.meet_bot_url_input, 0, 1, 1, 2)

        self.meet_bot_join_btn = QPushButton("Join as Bot")
        self.meet_bot_join_btn.setStyleSheet("padding: 6px 12px; font-size: 11px; background: #00AC47; color: white; border-radius: 3px;")
        self.meet_bot_join_btn.clicked.connect(self.join_meet_as_bot)
        meet_bot_layout.addWidget(self.meet_bot_join_btn, 0, 3)

        layout.addWidget(meet_bot_group)

        # Bot Controls
        controls_group = QGroupBox("Bot Controls")
        controls_group.setStyleSheet("QGroupBox { font-weight: bold; font-size: 12px; }")
        controls_layout = QHBoxLayout(controls_group)

        self.send_message_btn = QPushButton("Send Message")
        self.send_message_btn.setStyleSheet("padding: 8px 16px; font-size: 11px; background: #4CAF50; color: white; border-radius: 4px;")
        self.send_message_btn.clicked.connect(self.send_bot_message)
        self.send_message_btn.setEnabled(False)
        controls_layout.addWidget(self.send_message_btn)

        self.leave_meeting_btn = QPushButton("Leave Meeting")
        self.leave_meeting_btn.setStyleSheet("padding: 8px 16px; font-size: 11px; background: #ff5555; color: white; border-radius: 4px;")
        self.leave_meeting_btn.clicked.connect(self.leave_bot_meeting)
        self.leave_meeting_btn.setEnabled(False)
        controls_layout.addWidget(self.leave_meeting_btn)

        layout.addWidget(controls_group)

        # Bot Status
        self.bot_status = QTextEdit()
        self.bot_status.setReadOnly(True)
        self.bot_status.setMaximumHeight(100)
        self.bot_status.setStyleSheet("background: #23272e; color: #e0e0e0; font-family: monospace; font-size: 10px; border-radius: 4px; padding: 4px;")
        self.bot_status.setHtml("<span style='color:#b3e6ff;'>Bot ready. Enter meeting details above to join as a bot.</span>")
        layout.addWidget(self.bot_status)

    def init_tray_icon(self):
        # Normal icon: circle with a capital T, Columbia blue background
        self.normal_pixmap = QPixmap(32, 32)
        self.normal_pixmap.fill(QColor(0, 0, 0, 0))
        painter = QPainter(self.normal_pixmap)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setBrush(QColor("#C4D8E2"))  # Columbia blue
        painter.setPen(QColor("#C4D8E2"))
        painter.drawEllipse(0, 0, 32, 32)
        painter.setPen(QColor("#2d2d2d"))  # Dark gray for contrast
        font = QFont("Arial", 18, QFont.Weight.Bold)
        painter.setFont(font)
        rect = QRect(0, 0, 32, 32)
        painter.drawText(rect, Qt.AlignmentFlag.AlignCenter, "T")
        painter.end()
        self.normal_icon = QIcon(self.normal_pixmap)
        # Warning icon: red circle with exclamation
        self.warning_pixmap = QPixmap(32, 32)
        self.warning_pixmap.fill(QColor(0, 0, 0, 0))
        painter = QPainter(self.warning_pixmap)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setBrush(QColor("#ff5555"))
        painter.setPen(QColor("#ff5555"))
        painter.drawEllipse(0, 0, 32, 32)
        painter.setPen(QColor("white"))
        font = QFont("Arial", 20, QFont.Weight.Bold)
        painter.setFont(font)
        rect = QRect(0, 0, 32, 32)
        painter.drawText(rect, Qt.AlignmentFlag.AlignCenter, "!")
        painter.end()
        self.warning_icon = QIcon(self.warning_pixmap)
        self.tray_icon = QSystemTrayIcon(self)
        self.tray_icon.setIcon(self.normal_icon)
        tray_menu = QMenu()
        show_action = QAction("Show Window", self)
        show_action.triggered.connect(self.show)
        tray_menu.addAction(show_action)
        quit_action = QAction("Quit", self)
        quit_action.triggered.connect(QApplication.instance().quit)
        tray_menu.addAction(quit_action)
        self.tray_icon.setContextMenu(tray_menu)
        self.tray_icon.show()

    def set_tray_warning(self, warning):
        # Only update icon if state changes
        current = self.tray_icon.icon().cacheKey()
        if warning and current != self.warning_icon.cacheKey():
            self.tray_icon.setIcon(self.warning_icon)
        elif not warning and current != self.normal_icon.cacheKey():
            self.tray_icon.setIcon(self.normal_icon)

    def init_alert_window(self):
        self.alert_window = QWidget(None, Qt.WindowType.WindowStaysOnTopHint | Qt.WindowType.FramelessWindowHint)
        self.alert_window.setWindowTitle("Truely Alert")
        self.alert_window.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.alert_window.setFixedSize(320, 100)
        layout = QVBoxLayout(self.alert_window)
        layout.setContentsMargins(0, 0, 0, 0)
        alert_label = QLabel("<b style='font-size:22px;color:#ff5555;'>⚠️ Cluely Detected!</b>")
        alert_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        alert_label.setStyleSheet("background: #23272e; color: #ff5555; border-radius: 16px; padding: 18px; font-size: 18px;")
        layout.addWidget(alert_label)
        self.alert_window.hide()

    def show_alert_window(self):
        # Center on screen
        screen = QApplication.primaryScreen().geometry()
        x = screen.center().x() - self.alert_window.width() // 2
        y = screen.center().y() - self.alert_window.height() // 2
        self.alert_window.move(x, y)
        self.alert_window.show()
        self.alert_window.raise_()
        self.alert_window.activateWindow()

    def hide_alert_window(self):
        self.alert_window.hide()

    def notify_suspicious(self, message):
        self.tray_icon.showMessage("Truely Alert", message, QSystemTrayIcon.MessageIcon.Critical)

    def add_process(self):
        name, ok = QInputDialog.getText(self, "Add Process", "Enter process name:")
        if ok and name.strip():
            name = name.strip().lower()
            if name not in [self.process_list.item(i).text() for i in range(self.process_list.count())]:
                self.process_list.addItem(name)
                self.log_message(f"Added process: {name}")
            else:
                QMessageBox.information(self, "Already Exists", f"Process '{name}' is already in the list.")

    def remove_selected(self):
        selected = self.process_list.selectedItems()
        if not selected:
            return
        for item in selected:
            self.log_message(f"Removed process: {item.text()}")
            self.process_list.takeItem(self.process_list.row(item))

    def get_process_names(self) -> List[str]:
        return [self.process_list.item(i).text() for i in range(self.process_list.count())]

    def check_processes(self):
        try:
            from AppKit import NSWorkspace
            running_apps = NSWorkspace.sharedWorkspace().runningApplications()
            running = {}
            for app in running_apps:
                name = app.localizedName()
                if name:
                    running[name.lower()] = app.processIdentifier()
            found_any = False
            for pname in self.get_process_names():
                matches = [n for n in running if pname in n]
                if matches:
                    for n in matches:
                        pid = running[n]
                        self.log_message(f"{n} is running (PID: {pid})")
                    found_any = True
                else:
                    self.log_message(f"{pname} is not running.")
            if not self.get_process_names():
                self.log_message("No processes to monitor.")
        except Exception as e:
            self.log_message(f"Error checking processes: {e}")
        # Start background suspicious process detection
        if self.worker is not None and self.worker.isRunning():
            self.worker.stop()
            self.worker.wait()
        self.worker = SuspiciousProcessWorker(self.get_process_names, self.suspicious_paths, self.suspicious_hashes)
        self.worker.result_ready.connect(self.handle_suspicious_result)
        self.worker.start()

    def handle_suspicious_result(self, suspicious, new_alerted_pids):
        # Show/hide alert window and set tray icon
        if suspicious:
            self.show_alert_window()
            self.set_tray_warning(True)
        else:
            self.hide_alert_window()
            self.set_tray_warning(False)
        # Show notification for new suspicious PIDs
        for pid in new_alerted_pids:
            if pid not in self.last_alerted_pids:
                self.notify_suspicious(f"Suspicious process detected (PID: {pid})")
        self.last_alerted_pids = new_alerted_pids
        if suspicious:
            self.suspicious_text.setHtml("<br>".join(suspicious))
        else:
            self.suspicious_text.setHtml("<span style='color:#b3e6ff;'>No suspicious processes detected.</span>")

    def log_message(self, message: str):
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.log_text.append(f"[{timestamp}] {message}")

    def join_meeting(self):
        """Handle quick join meeting functionality"""
        url = self.meeting_input.text().strip()
        password = self.password_input.text().strip()
        
        if not url:
            self.meeting_status.setHtml("<span style='color:#ff5555;'>Please enter a meeting URL or ID.</span>")
            return
        
        # Try to parse the URL first
        meeting_info = self.meeting_joiner.parse_meeting_url(url)
        
        if meeting_info['type'] == 'zoom':
            meeting_id = meeting_info.get('meeting_id')
            if not meeting_id:
                # If no meeting ID found, try to extract from the input using bot joiner logic
                meeting_id = self.bot_joiner.extract_zoom_meeting_id(url)
            success = self.meeting_joiner.join_zoom_meeting(meeting_id, password or meeting_info.get('password'))
            if success:
                self.meeting_status.setHtml(f"<span style='color:#4CAF50;'>✅ Opened Zoom meeting: {meeting_id}<br><small>Please confirm joining in the Zoom app</small></span>")
                self.add_to_recent_meetings(f"Zoom: {meeting_id}")
            else:
                self.meeting_status.setHtml("<span style='color:#ff5555;'>Failed to open Zoom meeting. Please check the meeting ID.</span>")
                
        elif meeting_info['type'] == 'google_meet':
            meeting_url = meeting_info.get('meeting_url', url)
            success = self.meeting_joiner.join_google_meet(meeting_url)
            if success:
                self.meeting_status.setHtml(f"<span style='color:#4CAF50;'>✅ Opened Google Meet: {meeting_info.get('meeting_code', 'meeting')}<br><small>Meeting opened in your browser</small></span>")
                self.add_to_recent_meetings(f"Meet: {meeting_info.get('meeting_code', url)}")
            else:
                self.meeting_status.setHtml("<span style='color:#ff5555;'>Failed to open Google Meet. Please check the URL.</span>")
        else:
            # Try to treat as a Zoom meeting ID
            if url.isdigit():
                success = self.meeting_joiner.join_zoom_meeting(url, password)
                if success:
                    self.meeting_status.setHtml(f"<span style='color:#4CAF50;'>✅ Opened Zoom meeting: {url}<br><small>Please confirm joining in the Zoom app</small></span>")
                    self.add_to_recent_meetings(f"Zoom: {url}")
                else:
                    self.meeting_status.setHtml("<span style='color:#ff5555;'>Failed to open Zoom meeting. Please check the meeting ID.</span>")
            else:
                self.meeting_status.setHtml("<span style='color:#ff5555;'>Invalid meeting URL or ID. Please check the format.</span>")

    def join_zoom_meeting(self, meeting_id: str, password: str = None):
        """Join a Zoom meeting manually"""
        if not meeting_id.strip():
            self.meeting_status.setHtml("<span style='color:#ff5555;'>Please enter a Zoom meeting ID.</span>")
            return False
        
        # Extract meeting ID from URL if needed
        clean_meeting_id = self.bot_joiner.extract_zoom_meeting_id(meeting_id)
        
        success = self.meeting_joiner.join_zoom_meeting(clean_meeting_id, password)
        if success:
            self.meeting_status.setHtml(f"<span style='color:#4CAF50;'>✅ Opened Zoom meeting: {clean_meeting_id}<br><small>Please confirm joining in the Zoom app</small></span>")
            self.add_to_recent_meetings(f"Zoom: {clean_meeting_id}")
        else:
            self.meeting_status.setHtml("<span style='color:#ff5555;'>Failed to open Zoom meeting. Please check the meeting ID.</span>")
        return success

    def join_google_meet(self, meeting_url: str):
        """Join a Google Meet meeting manually"""
        if not meeting_url.strip():
            self.meeting_status.setHtml("<span style='color:#ff5555;'>Please enter a Google Meet URL.</span>")
            return False
        
        success = self.meeting_joiner.join_google_meet(meeting_url)
        if success:
            # Extract meeting code for display
            meeting_info = self.meeting_joiner.parse_meeting_url(meeting_url)
            meeting_code = meeting_info.get('meeting_code', meeting_url)
            self.meeting_status.setHtml(f"<span style='color:#4CAF50;'>✅ Opened Google Meet: {meeting_code}<br><small>Meeting opened in your browser</small></span>")
            self.add_to_recent_meetings(f"Meet: {meeting_code}")
        else:
            self.meeting_status.setHtml("<span style='color:#ff5555;'>Failed to open Google Meet. Please check the URL.</span>")
        return success

    def join_zoom_manual(self):
        """Handle manual Zoom join button click"""
        meeting_id = self.zoom_id_input.text().strip()
        password = self.zoom_pwd_input.text().strip()
        self.join_zoom_meeting(meeting_id, password)

    def join_meet_manual(self):
        """Handle manual Google Meet join button click"""
        meeting_url = self.meet_url_input.text().strip()
        self.join_google_meet(meeting_url)

    def auto_join_zoom(self):
        """Attempt to automate Zoom joining (experimental)"""
        meeting_id = self.zoom_id_input.text().strip()
        password = self.zoom_pwd_input.text().strip()
        
        if not meeting_id:
            self.meeting_status.setHtml("<span style='color:#ff5555;'>Please enter a Zoom meeting ID first.</span>")
            return
        
        self.meeting_status.setHtml("<span style='color:#FF6B35;'>🔄 Attempting automated join...<br><small>This may be blocked by macOS security</small></span>")
        
        # First open the meeting normally
        success = self.meeting_joiner.join_zoom_meeting(meeting_id, password)
        
        if success:
            # Wait a moment for Zoom to open, then try automation
            QTimer.singleShot(3000, lambda: self._attempt_automation(meeting_id))
        else:
            self.meeting_status.setHtml("<span style='color:#ff5555;'>Failed to open Zoom meeting.</span>")

    def _attempt_automation(self, meeting_id: str):
        """Attempt AppleScript automation after a delay"""
        try:
            success = self.meeting_joiner.try_zoom_automation(meeting_id)
            if success:
                self.meeting_status.setHtml(f"<span style='color:#4CAF50;'>✅ Automation attempted for meeting: {meeting_id}<br><small>Check Zoom app for results</small></span>")
            else:
                self.meeting_status.setHtml(f"<span style='color:#FF6B35;'>⚠️ Automation failed for meeting: {meeting_id}<br><small>Please join manually in Zoom app</small></span>")
        except Exception as e:
            self.meeting_status.setHtml(f"<span style='color:#ff5555;'>❌ Automation error: {str(e)}<br><small>Please join manually</small></span>")

    def add_to_recent_meetings(self, meeting_info: str):
        """Add a meeting to the recent meetings list"""
        # Check if already exists
        for i in range(self.recent_meetings_list.count()):
            if self.recent_meetings_list.item(i).text() == meeting_info:
                return
        
        # Add to the top of the list
        self.recent_meetings_list.insertItem(0, meeting_info)
        
        # Keep only the last 10 meetings
        while self.recent_meetings_list.count() > 10:
            self.recent_meetings_list.takeItem(self.recent_meetings_list.count() - 1)

    def join_zoom_as_bot(self):
        """Join Zoom meeting as a bot"""
        if not SELENIUM_AVAILABLE:
            self.bot_status.setHtml("<span style='color:#ff5555;'>Selenium not available. Please install: pip install selenium webdriver-manager</span>")
            return
            
        meeting_id = self.zoom_bot_id_input.text().strip()
        password = self.zoom_bot_pwd_input.text().strip()
        bot_name = self.bot_name_input.text().strip()
        
        if not meeting_id:
            self.bot_status.setHtml("<span style='color:#ff5555;'>Please enter a Zoom meeting ID.</span>")
            return
        
        self.bot_status.setHtml("<span style='color:#FF6B35;'>🔄 Joining Zoom meeting as bot...</span>")
        
        # Run bot joining in a separate thread to avoid blocking UI
        self.bot_thread = BotJoinThread(self.bot_joiner, 'zoom', meeting_id, bot_name, password)
        self.bot_thread.result_ready.connect(self.on_bot_join_result)
        self.bot_thread.start()

    def join_meet_as_bot(self):
        """Join Google Meet as a bot"""
        if not SELENIUM_AVAILABLE:
            self.bot_status.setHtml("<span style='color:#ff5555;'>Selenium not available. Please install: pip install selenium webdriver-manager</span>")
            return
            
        meeting_url = self.meet_bot_url_input.text().strip()
        bot_name = self.bot_name_input.text().strip()
        
        if not meeting_url:
            self.bot_status.setHtml("<span style='color:#ff5555;'>Please enter a Google Meet URL.</span>")
            return
        
        self.bot_status.setHtml("<span style='color:#FF6B35;'>🔄 Joining Google Meet as bot...</span>")
        
        # Run bot joining in a separate thread to avoid blocking UI
        self.bot_thread = BotJoinThread(self.bot_joiner, 'meet', meeting_url, bot_name)
        self.bot_thread.result_ready.connect(self.on_bot_join_result)
        self.bot_thread.start()

    def on_bot_join_result(self, success: bool, message: str):
        """Handle bot join result"""
        if success:
            self.bot_status.setHtml(f"<span style='color:#4CAF50;'>✅ {message}</span>")
            self.send_message_btn.setEnabled(True)
            self.leave_meeting_btn.setEnabled(True)
            
            # Auto send message if enabled
            if self.auto_message_checkbox.isChecked():
                QTimer.singleShot(3000, self.send_bot_message)
        else:
            self.bot_status.setHtml(f"<span style='color:#ff5555;'>❌ {message}</span>")

    def send_bot_message(self):
        """Send a message as the bot"""
        if not self.bot_joiner.is_joined:
            self.bot_status.setHtml("<span style='color:#ff5555;'>Bot is not in a meeting.</span>")
            return
        
        message = self.bot_message_input.text().strip()
        if not message:
            self.bot_status.setHtml("<span style='color:#ff5555;'>Please enter a message to send.</span>")
            return
        
        self.bot_status.setHtml("<span style='color:#FF6B35;'>🔄 Sending message...</span>")
        
        # Run message sending in a separate thread
        self.message_thread = BotMessageThread(self.bot_joiner, message)
        self.message_thread.result_ready.connect(self.on_message_result)
        self.message_thread.start()

    def on_message_result(self, success: bool, message: str):
        """Handle message send result"""
        if success:
            self.bot_status.setHtml(f"<span style='color:#4CAF50;'>✅ {message}</span>")
        else:
            self.bot_status.setHtml(f"<span style='color:#ff5555;'>❌ {message}</span>")

    def leave_bot_meeting(self):
        """Leave the current bot meeting"""
        if not self.bot_joiner.is_joined:
            self.bot_status.setHtml("<span style='color:#ff5555;'>Bot is not in a meeting.</span>")
            return
        
        self.bot_joiner.leave_meeting()
        self.send_message_btn.setEnabled(False)
        self.leave_meeting_btn.setEnabled(False)
        self.bot_status.setHtml("<span style='color:#4CAF50;'>✅ Bot left the meeting.</span>")

    def closeEvent(self, event):
        """Clean up resources when application closes"""
        # Close bot driver if active
        if hasattr(self, 'bot_joiner'):
            self.bot_joiner.close_driver()
        
        # Stop worker thread if running
        if hasattr(self, 'worker') and self.worker and self.worker.isRunning():
            self.worker.stop()
            self.worker.wait()
        
        event.accept()

    def retry_selenium_installation(self):
        """Retry Selenium installation"""
        global SELENIUM_AVAILABLE
        SELENIUM_AVAILABLE = install_selenium_if_needed()
        if SELENIUM_AVAILABLE:
            self.bot_status.setHtml("<span style='color:#4CAF50;'>✅ Selenium installation successful! Please restart the application.</span>")
        else:
            self.bot_status.setHtml("<span style='color:#ff5555;'>❌ Failed to install Selenium. Please install manually: pip install selenium webdriver-manager</span>")

def main():
    # Watchdog timer (optional, e.g. 2 hours)
    def watchdog():
        time.sleep(60*60*2)
        logging.error('Watchdog: Exiting due to timeout')
        os._exit(1)
    threading.Thread(target=watchdog, daemon=True).start()

    # Signal handlers for robust cleanup
    def handle_exit(signum, frame):
        logging.info('Received signal %s, exiting', signum)
        QApplication.quit()
        os._exit(0)
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, handle_exit)

    app = QApplication(sys.argv)
    window = ProcessMonitorApp()
    window.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main() 