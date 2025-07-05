# Truely - Suspicious Process Monitor & Meeting Joiner

A modern, real-time GUI application for monitoring and detecting suspicious processes on macOS, with integrated meeting join functionality for Zoom and Google Meet. Features a menu bar icon, always-on-top alert, and a responsive, beautiful interface.

## ✨ Features

### 🔍 Process Monitoring
- **Real-time Detection**: Continuously monitors for suspicious processes in the background
- **Menu Bar Icon**: Always visible, changes color when suspicious activity is detected
- **Always-on-Top Alert**: Warning window appears over other apps when threats are found
- **Editable Process List**: Add/remove process names to monitor (case-insensitive, partial match)
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

### 🤖 Bot Joiner (Auto-Installation)
- **Automatic Setup**: Selenium and dependencies are automatically installed on first run
- **Browser Automation**: Join meetings as a bot using Chrome browser automation
- **Chat Integration**: Send messages in meeting chat automatically
- **Custom Bot Names**: Set custom names for your bot
- **Auto-Message**: Automatically send messages upon joining
- **Meeting Control**: Leave meetings programmatically

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
3. **Configure bot** - Set bot name and message settings
4. **Enter meeting details** - Use Zoom meeting ID/URL or Google Meet URL
5. **Join as bot** - Click "Join as Bot" to automatically join
6. **Send messages** - Use "Send Message" button for chat
7. **Leave meeting** - Use "Leave Meeting" to exit

## 🔧 Bot Features

### What the Bot Can Do
- ✅ Join Zoom meetings via web interface (supports IDs and URLs)
- ✅ Join Google Meet meetings via web interface
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

---

**Version**: 2.0  
**Last Updated**: July 2024  
**Compatibility**: macOS 10.15+ with Python 3.8+ 