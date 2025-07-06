# Truely - Dual-Join Process Monitor

A comprehensive macOS application that monitors for suspicious processes and automatically joins Zoom meetings with dual-join capability (both bot and user simultaneously).

## 🚀 Features

### Core Functionality
- **Real-time Process Monitoring**: Continuously monitors for suspicious processes (set in `config.py`)
- **Dual-Join Zoom Meetings**: Automatically joins meetings as both a bot and opens Zoom app for user
- **Automated Chat Alerts**: Sends real-time alerts to meeting chat when suspicious processes are detected
- **Automated Introduction Messages**: Bot sends a sequence of introduction messages to the meeting chat, including the monitoring key and the list of monitored applications
- **Graceful Shutdown**: Properly leaves meetings and cleans up resources on exit

### Automated Introduction Message Sequence
When the bot joins a meeting, it sends the following messages to the chat:

1. `Hello everyone! I'm Truely, your automated meeting monitor.`
2. `Monitoring Key: <KEY>` (where `<KEY>` is set in `config.py`)
3. `I'll be keeping an eye on the following applications and processes during this meeting: app1, app2, ...` (where the list is set in `config.py`)

### Bot Automation
- **Selenium WebDriver**: Headless Chrome automation for Zoom web client
- **Smart Element Detection**: Multiple strategies for finding and interacting with Zoom interface elements
- **Robust Error Handling**: Fallback mechanisms for different Zoom interface states
- **Chat Integration**: Opens chat panel and sends messages automatically

### User Interface
- **System Tray Icon**: Always-on-top monitoring with visual alerts
- **Alert Popup**: Prominent warning when suspicious processes detected
- **Status Logging**: Real-time status updates and debugging information
- **Graceful Shutdown**: Popup button triggers full cleanup process

## 🛠️ Technical Implementation

### Process Monitoring
```python
# Monitors for suspicious processes by name, path, and hash
self.process_names = APPS  # Set in config.py
self.suspicious_paths = ["/Applications/Cluely.app/Contents/MacOS/Cluely"]
self.suspicious_hashes = []
```

### Dual-Join Meeting System
```python
# Joins both bot and user to the same meeting
bot_success = self.bot_joiner.join_zoom_meeting_bot(meeting_id, "Truely Bot", passcode)
user_success = self.meeting_joiner.join_zoom_meeting(meeting_id, passcode)
```

### Bot Automation Features
- **Multiple Selector Strategies**: 10+ different XPath selectors for robust element detection
- **Iframe Handling**: Automatically switches to meeting iframe when needed
- **Double-Click Leave**: Properly handles Zoom's highlight-then-leave button behavior
- **JavaScript Fallbacks**: Uses JavaScript clicks when regular clicks fail

### Chat Alert System
```python
# Clean, formatted alerts without HTML tags
alert_message = (
    f"ALERT: SUSPICIOUS ACTIVITY DETECTED [{timestamp}]\n"
    f"{clean_process_info}\n\n"
    "This process has been flagged as potentially suspicious by Truely monitoring system."
)
```

## 🔧 Setup & Installation

### Prerequisites
- macOS (tested on macOS 13+)
- Python 3.8+
- Chrome browser installed

### Dependencies
```bash
pip install PyQt6 selenium webdriver-manager psutil
```

### Auto-Installation
The application automatically installs Selenium and webdriver-manager if not present:
```python
def install_selenium_if_needed():
    """Automatically install Selenium and webdriver-manager if not available"""
```

## 🚀 Usage

### Starting the Application
```bash
python3 truely_dual_join.py
```

### Initial Setup
1. **Meeting Setup**: Application prompts for Zoom meeting URL/ID at startup
2. **Dual-Join**: Automatically joins as bot and opens Zoom app for user
3. **Chat Integration**: Opens chat panel and sends introduction message
4. **Monitoring Active**: Continuously monitors for suspicious processes

### Alert System
- **Visual Alert**: Red popup appears when suspicious process detected
- **Chat Alert**: Bot sends formatted alert to meeting chat
- **System Notification**: Tray icon changes and shows notification
- **Cooldown**: 30-second cooldown between alerts to prevent spam

### Shutdown Process
- **Graceful Exit**: Ctrl+C or popup button triggers full cleanup
- **Goodbye Message**: Bot sends "Goodbye everyone! Truely signing off."
- **Leave Meeting**: Double-clicks leave button with proper timing
- **Resource Cleanup**: Closes Selenium driver and stops monitoring

## 🔍 Key Technical Solutions

### 1. Robust Element Detection
```python
# Multiple strategies for finding leave button
leave_selectors = [
    "//button[@aria-label='Leave']",
    "//button[contains(@class, 'footer-button-base__button') and @aria-label='Leave']",
    "//button[.//span[contains(@class, 'footer-button-base__button-label') and text()='Leave']]",
    "//button[.//svg[contains(@class, 'SvgLeave')]]",
    # ... 10+ more selectors
]
```

### 2. Double-Click Leave Strategy
```python
# Properly handles Zoom's highlight-then-leave behavior
print("Clicking leave button first time (to highlight)...")
leave_button.click()
time.sleep(0.5)  # Wait for highlight
print("Clicking leave button second time (to leave)...")
leave_button.click()
```

### 3. HTML Tag Cleaning
```python
# Extracts clean text from HTML-formatted process info
def clean_process_info_for_chat(self, process_info: str) -> str:
    clean_text = re.sub(r'<[^>]+>', '', process_info)
    # Returns: [NAME] cluely (PID: 49311)
```

### 4. Graceful Shutdown
```python
# Multiple cleanup triggers
atexit.register(self.cleanup_on_exit)  # Automatic cleanup
signal.signal(signal.SIGINT, handle_exit)  # Ctrl+C handling
popup_button.clicked.connect(self.shutdown_from_popup)  # Popup shutdown
```

## 🎯 Working Features

### ✅ Fully Functional
- **Dual-Join System**: Bot and user join same meeting simultaneously
- **Process Monitoring**: Real-time detection of suspicious processes
- **Chat Integration**: Opens chat panel and sends messages
- **Alert System**: Clean, formatted alerts without HTML tags
- **Graceful Shutdown**: Properly leaves meetings and cleans up
- **Error Handling**: Robust fallback mechanisms throughout
- **Development Mode**: Browser stays open for debugging

### 🔧 Technical Achievements
- **Selenium Automation**: Headless Chrome with proper Zoom integration
- **Element Detection**: 10+ selector strategies for maximum compatibility
- **Iframe Handling**: Automatic iframe switching for Zoom interface
- **Signal Handling**: Proper SIGINT/SIGTERM handling
- **Resource Management**: Clean process and driver cleanup
- **Logging System**: Comprehensive debugging and status logging

## 📝 Development Notes

### Browser Configuration
```python
# Headless Chrome with automation detection disabled
chrome_options.add_argument("--headless=new")
chrome_options.add_argument("--disable-blink-features=AutomationControlled")
chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
```

### Development Mode
- Browser stays open for debugging (commented out `close_driver()`)
- Detailed logging throughout all operations
- Debug output for chat messages

### Error Recovery
- Multiple fallback strategies for all operations
- Graceful degradation when elements not found
- Comprehensive exception handling

## 🎉 Success Metrics

- ✅ **Dual-Join Working**: Both bot and user successfully join meetings
- ✅ **Process Detection**: Real-time monitoring detects suspicious processes
- ✅ **Chat Integration**: Bot opens chat and sends formatted messages
- ✅ **Graceful Shutdown**: Properly leaves meetings and cleans up resources
- ✅ **Error Handling**: Robust fallback mechanisms throughout
- ✅ **Development Ready**: Browser stays open for debugging

The application is fully functional and ready for production use with proper browser cleanup enabled.

## ✨ Features

### 🔍 Process Monitoring
- **Real-time Detection**: Continuously monitors for suspicious processes in the background
- **Menu Bar Icon**: Always visible, changes color when suspicious activity is detected
- **Always-on-Top Alert**: Warning window appears over other apps when threats are found
- **Config-Driven Process List**: The list of monitored processes is set in `config.py` and cannot be edited from the UI
- **Multiple Detection Methods**: Flags processes by name, executable path, or hash
- **Live Status Log**: Real-time updates showing process status
- **Manual Check**: Instant process status check with "Check Now" button

### 🤖 Meeting Joiner
- **Quick Join**: Paste any Zoom or Google Meet URL/ID and join instantly
- **Manual Join**: Separate sections for Zoom and Google Meet with dedicated inputs
- **Password Support**: Enter meeting passwords for Zoom meetings
- **Recent Meetings**: Track and quickly access recently joined meetings
- **Smart URL Parsing**: Automatically detects meeting type and extracts information
- **Multiple Formats**: Supports various Zoom and Google Meet URL formats

### 🤖 Bot Joiner (Auto-Installation & Full Automation)
- **Automatic Setup**: Selenium and dependencies are automatically installed on first run
- **Browser Automation**: Join meetings as a bot using Chrome browser automation
- **Chat Integration**: Send messages in meeting chat automatically
- **Custom Bot Names**: Set custom names for your bot (default: **Truely Bot**)
- **Auto-Message**: Automatically send messages upon joining
- **Meeting Control**: Leave meetings programmatically
- **Hands-Free Zoom Join**: The bot will:
  - Automatically click the "Continue without microphone and camera" popup (up to two times if needed)
  - Extract the passcode from the meeting URL if not provided directly
  - Fill in the name and passcode using the correct input fields
  - Click the Join button using its class for maximum compatibility
  - Robust to Zoom UI changes and popups

## 🚀 Quick Start

### Prerequisites
- macOS (uses AppKit and menu bar APIs)
- Python 3.8 or later
- Chrome browser (for bot features)

### Installation
1. **Clone or download the project**
2. **Install dependencies**:
   ```bash
   pip3 install -r requirements.txt
   ```
3. **Run the application**:
   ```bash
   python3 advanced_screen_capture.py
   ```

**Note**: Selenium and webdriver-manager will be automatically installed on first run if not already present.

### 🎯 Startup Behavior
When you launch the application, it will:
1. **Prompt for Zoom meeting link** - Enter any Zoom meeting URL or ID
2. **Join as bot** - The application automatically joins the meeting as "Truely Bot" using browser automation
3. **Join as user** - Simultaneously opens the Zoom app for you to join the same meeting manually
4. **Set up monitoring** - The bot will monitor for suspicious processes and send alerts to the meeting chat

This dual-join functionality ensures both the automated bot and the actual user are present in the same meeting for comprehensive monitoring.

## 📖 Usage Guide

### Process Monitoring
1. **Launch the app** - GUI appears with "cluely" pre-loaded in the process list
2. **Add processes** - Click "Add Process" to add more process names to monitor
3. **Remove processes** - Select a process and click "Remove Selected"
4. **Monitor status** - Log area shows real-time updates every 2 seconds
5. **Manual check** - Click "Check Now" for immediate status check
6. **Watch for alerts** - Menu bar icon turns red if suspicious process detected

### Meeting Joiner
1. **Switch to Meeting Joiner tab**
2. **Quick Join** - Paste any Zoom or Google Meet URL/ID
3. **Manual Join** - Use dedicated sections for specific platforms
4. **Enter password** - Add meeting password if required (Zoom)
5. **Join meeting** - Click appropriate join button

### Bot Joiner
1. **Switch to Bot Joiner tab**
2. **Check Selenium Status** - Ensure automation is ready (green status)
3. **Configure bot** - Set bot name and message settings (default: **Truely Bot**)
4. **Enter meeting details** - Use Zoom meeting ID/URL or Google Meet URL
5. **Join as bot** - Click "Join as Bot" to automatically join
   - The bot will handle all Zoom popups, extract passcodes from links, fill in your name, and click Join for you
6. **Open chat** - Use "Open Chat" button to open the meeting chat panel
7. **Send messages** - Use "Send Message" button for chat
8. **Leave meeting** - Use "Leave Meeting" to exit

### Bot Joiner Automation Details
- The bot will automatically handle all Zoom web join popups, including clicking "Continue without microphone and camera" up to two times if needed
- If the passcode is embedded in the meeting URL, it will be extracted and used automatically
- The bot fills in the name and passcode using the correct input fields (`input-for-name` and `input-for-pwd`)
- The Join button is clicked using its class (`preview-join-button`) for maximum compatibility with Zoom UI changes
- The join flow is now fully hands-free and robust

## 🔧 Bot Features

### What the Bot Can Do
- ✅ Join Zoom meetings via web interface (supports IDs and URLs)
- ✅ Join Google Meet meetings via web interface
- ✅ Open meeting chat panel with precise clicking
- ✅ Send messages in meeting chat
- ✅ Use custom bot names
- ✅ Auto-send messages upon joining
- ✅ Leave meetings programmatically

### Auto-Installation
The application automatically:
- Detects if Selenium is installed
- Installs Selenium and webdriver-manager if missing
- Shows installation status in the UI
- Provides retry options if installation fails

### Supported Meeting Formats

**Zoom:**
- Meeting ID: `123456789`
- Zoom URLs: `https://zoom.us/j/123456789`
- Zoom app URLs: `zoommtg://zoom.us/join?confno=123456789`
- Zoom web URLs: `https://zoom.us/wc/join/123456789`

**Google Meet:**
- Meeting URLs: `https://meet.google.com/abc-defg-hij`
- Short URLs: `meet.google.com/abc-defg-hij`

## ⚠️ Limitations & Security

### Process Monitoring
- Always-on-top alert may not appear over full-screen apps due to macOS security
- Menu bar icon will always update regardless of alert visibility
- Native notifications may require additional permissions

### Meeting Joiner
- Regular meeting joiner requires manual confirmation due to security restrictions
- Opens meetings in Zoom app or browser (requires user interaction)
- Experimental automation features may be blocked by macOS security

### Bot Joiner
- Requires Chrome browser to be installed
- May be detected as automation by some meeting platforms
- Depends on web interface stability
- May not work with all meeting configurations
- Requires meeting access permissions

## 🛠️ Troubleshooting

### Bot Joiner Issues
**Selenium not available:**
- Check the "Selenium Status" in the Bot Joiner tab
- Click "Retry Selenium Installation" if needed
- Ensure Chrome browser is installed and up to date

**Chrome Driver errors:**
- Update Chrome to the latest version
- Clear driver cache: delete `.wdm` folder in home directory
- Restart the application

**Bot joining fails:**
- Verify meeting URL/ID format is correct
- Ensure you have permission to join the meeting
- Check internet connection
- Try a different meeting to test

### Application Issues
**Crashes or freezes:**
- Check all dependencies are installed: `pip3 install -r requirements.txt`
- Use Python 3.8 or later
- Grant necessary macOS permissions
- Restart the application

**Process stuck:**
- The app includes robust process cleanup and timeouts
- Check the log file: `advanced_screen_capture.log`
- Force quit if necessary and restart

## 🔒 Legal and Ethical Considerations

⚠️ **Important Disclaimer:**
This tool is provided for educational and personal use only. Users are responsible for:

- **Compliance with local laws** regarding process monitoring
- **Respect for privacy** and consent requirements  
- **Adherence to terms of service** of applications being monitored
- **Proper use** of process information
- **Meeting access permissions** - only join meetings you're authorized to attend

### Intended Use
- Monitoring your own applications
- Educational purposes
- System administration tasks
- Development and debugging
- Joining authorized meetings

### Do Not Use For
- Monitoring processes without permission
- Violating terms of service
- Infringing on privacy rights
- Conducting unauthorized surveillance
- Joining meetings without proper authorization

## 🛡️ Security Features

### Process Cleanup
- Automatic cleanup of child processes (ChromeDriver, browser instances)
- Timeout mechanisms for all subprocesses
- Signal handlers for graceful shutdown
- Watchdog timer to prevent indefinite hangs

### Defensive Programming
- Exception handling for all automation operations
- Resource cleanup in finally blocks
- Logging of all process activities
- Graceful degradation when features are unavailable

## 📋 Technical Details

- **GUI Framework**: PyQt6
- **Process Monitoring**: AppKit (via pyobjc) + psutil
- **Browser Automation**: Selenium WebDriver (Chrome)
- **Meeting Integration**: webbrowser module + custom URL parsing
- **Background Processing**: QThread for non-blocking operations
- **Auto-Installation**: subprocess for dependency management

## 🤝 Contributing

Feel free to submit issues, feature requests, or pull requests to improve the application.

## 🆕 Recent Improvements

### July 2024
- **Enhanced Chat Automation:**
  - Improved chat panel opening with precise clicking strategy that targets the "Chat" text element specifically
  - Eliminated side effects like unintended highlighting of other UI elements
  - Streamlined UI with single "Open Chat" button for better user experience
  - Enhanced reliability for opening chat panels in Zoom meetings
- **Code Optimization:**
  - Removed redundant chat opening methods and thread classes
  - Simplified button management and enabling/disabling logic
  - Improved code maintainability and reduced complexity

### June 2024
- **Robust Chat Automation:**
  - The bot now uses a highly specific selector for the Zoom chat button (`footer-button__button` with label `Chat`), ensuring it never clicks the screen share button by mistake.
  - The chat button is only clicked if its `aria-label` is `open the chat panel`, so the bot will not toggle or close the chat unnecessarily.
  - Sending a message as the bot will never trigger the screen sharing dialog.
  - Improved reliability for sending chat messages in Zoom meetings.
- **Bug Fixes:**
  - Fixed an issue where sending a message could accidentally open the screen sharing dialog due to a broad selector.
  - Enhanced the message sending logic to only interact with the correct chat input box.

---

**Version**: 2.1  
**Last Updated**: July 2024  
**Compatibility**: macOS 10.15+ with Python 3.8+ 