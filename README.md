# True-ly

True-ly is an open-source macOS application designed to monitor and manage processes during video meetings, ensuring that you are interacting with a real person. It achieves this by detecting and alerting users about forbidden applications running on their system during meetings, with comprehensive meeting verification and evidence collection.

## Features

### Free Plan
- **Real-time Process Monitoring**: Continuously checks for forbidden applications every 2 seconds
- **Basic Detection**: Simple process name matching against forbidden applications list
- **Web Integration & URL Scheme**: Seamless integration with web-based workflows via `truely://` URL scheme
- **Video Meeting Integration**: Join video meetings directly from the app and monitor the session
- **Modern UI**: Clean, production-ready interface built with SwiftUI for easy configuration and monitoring
- **Legal Terms & Agreement**: Comprehensive legal consent system with bulletproof terms

### Pro Plan (All Free features +)
- **Advanced Process Monitoring**: Multiple detection methods including process enumeration, GUI monitoring, and hash verification
- **Network Traffic Monitoring**: Real-time detection of LLM API connections and AI service usage via network analysis (every 10 seconds)
- **Automatic Screen Capture**: Periodic desktop screenshots every 2 minutes with automatic upload to server
- **Startup Video Recording**: 45-second startup video recording with automatic upload for comprehensive evidence collection
- **Cross-Desktop Window Detection**: Discovers and monitors windows across all desktop spaces, even when hidden or on different desktops
- **Real-time Alerts**: Sends alerts to the meeting chat if any forbidden applications are detected
- **Automatic Permission Handling**: Seamlessly requests and guides users through screen recording permissions
- **Graceful Cleanup**: Ensures proper bot departure with farewell messages before app termination
- **Meeting Verification System**: Comprehensive verification that the meeting app is running on the monitored computer with detailed evidence collection
- **Session Management**: Organized file management with session-based folders and comprehensive logging
- **Automatic Log Upload**: Background log upload service that automatically uploads system logs, screenshots, and videos to the server

## Components

### 1. User Interface

- **File**: `ContentView.swift`
- **Description**: Defines the main UI of the application using SwiftUI with a modern glassmorphic design. Features two main stages:
  - **Setup Stage**: Configuration form with enhanced encrypted key input, terms and agreement acceptance, and configuration validation
  - **Monitoring Stage**: Clean dashboard showing system status, forbidden app list, detection status, and stop monitoring button
- **UI Features**: 
  - Gradient backgrounds with smooth animations
  - Responsive layout with full-width configuration summary
  - Enhanced text input with larger font size and horizontal padding
  - Keyboard shortcuts (Enter key to submit)
  - Real-time status updates and configuration validation
  - Glassmorphic design elements with proper spacing and visual hierarchy
  - **Legal Terms Integration**: Comprehensive terms and agreement system with interactive acceptance
  - **Terms Validation**: Prevents proceeding without accepting terms with clear error messaging
  - **Production-Ready Interface**: Clean, minimal UI focused on essential functionality

### 2. Meeting Integration

- **File**: `RecallService.swift`
- **Description**: Manages meeting integration functionality with mock implementations for open source release. The service handles:
  - Bot creation and meeting joining (mock)
  - Sequential chat message sending (greetings, alerts, farewells)
  - Meeting departure handling (mock)
  - Bot lifecycle management (mock)

### 3. Process Monitoring

- **File**: `ProcessMonitor.swift`
- **Description**: Monitors running processes on the system using a timer-based approach (every 2 seconds). It checks against a list of forbidden applications and updates the UI with any detected forbidden apps. Integrates with `SuspiciousProcessDetector` and `NetworkMonitor` for comprehensive monitoring capabilities.

### 4. Advanced Process Detection

- **File**: `SuspiciousProcessDetector.swift`
- **Description**: Detects suspicious processes using multiple criteria:
  - **Name-based Detection**: Matches process names against suspicious patterns
  - **Path-based Detection**: Checks specific file paths
  - **Hash-based Detection**: SHA256 hash verification of executable files
- **Features**: Prevents duplicate alerts for the same processes and tracks alerted PIDs

### 5. Network Traffic Monitoring

- **File**: `NetworkMonitor.swift`
- **Description**: Real-time network connection monitoring to detect LLM API usage and AI service connections:
  - **LLM API Detection**: Monitors connections to OpenAI, Anthropic, Cohere, and other AI service endpoints
  - **Reverse DNS Resolution**: Converts IP addresses to domain names for better identification
  - **Process Attribution**: Links network connections to specific applications and processes
  - **Smart Filtering**: Distinguishes between local, private, and internet traffic
  - **Real-time Logging**: Provides detailed connection information in app logs
- **Key Features**: 
  - Detects impossible-to-evade network traffic patterns
  - Monitors 14+ major LLM API endpoints
  - Groups connections by process for clean output
  - Highlights potential AI-related applications
  - **Optimized Monitoring**: Network checks every 10 seconds for reduced system impact

### 6. System Integration Bridge

- **Files**: `ProcessBridge.h`, `ProcessBridge.c`
- **Description**: C bridge for low-level system process access. Provides:
  - System process enumeration using `sysctl` and `libproc`
  - Process name and path retrieval
  - SHA256 hash calculation for executable files
  - Memory management for process lists

### 7. Application Lifecycle

- **File**: `TruelyApp.swift`
- **Description**: Manages the app's lifecycle, including startup and termination. Features:
  - Transparent window styling with glassmorphic effects
  - Custom window close handling to ensure proper cleanup
  - Integration with `RecallService` for bot management (mock)
  - Ensures farewell messages are sent before app termination
  - **Window Management**: Remembers user's preferred window position instead of forcing center placement
  - **Permission Management**: Automatic screen recording permission requests and user guidance

### 8. Configuration Management

- **File**: `MeetingConfiguration.swift`
- **Description**: Manages meeting configuration settings including:
  - Platform selection (Zoom, Teams, etc.)
  - Forbidden applications list
  - Configuration validation
  - Real-time configuration summary display

### 9. Automatic Screen Capture & Evidence Collection

- **File**: `ContentView.swift` (Screen capture functions)
- **Description**: Automatic screen capture and evidence collection capabilities:
  - **Automatic Screenshots**: Periodic desktop screenshots every 2 minutes with automatic upload
  - **Startup Video Recording**: 45-second startup video recording with automatic upload
  - **Session Management**: All files organized in session-based folders on desktop
  - **Cross-Desktop Window Detection**: Discover windows across all desktop spaces
  - **Permission Handling**: Automatic screen recording permission requests and System Settings guidance
- **Key Features**:
  - **Automatic Operation**: All capture and upload functionality runs automatically in the background
  - **Multi-Monitor Support**: Captures all screens including side monitors in a single image
  - **Optimized File Sizes**: Uses `.nominalResolution` and aggressive JPEG compression (10% quality) for small file sizes
  - **Cursor Movement Capture**: All captures include real-time cursor movement and positioning with proper coordinate conversion
  - **Session Organization**: Files saved to local session folders with timestamp-based naming
- **Server Integration**: Uploads use server-provided folder paths from configuration response
- **Automatic Upload**: All captures automatically uploaded to server with consistent folder naming
  - **Startup Video**: 45-second video recording at 2x speed with H.264 compression for small file sizes

### 10. Loading State Management

- **File**: `LoadingState.swift`
- **Description**: Handles complex loading states and error management:
  - Unified loading state tracking
  - Error handling with retry capabilities
  - User-friendly error messages
  - Loading state visualization

### 11. Log Upload Service

- **File**: `LogUploadService.swift`
- **Description**: Comprehensive background service for automatic file uploads:
  - **Automatic Log Upload**: Uploads system logs every minute
  - **Screenshot Upload**: Automatically uploads periodic screenshots
  - **Video Upload**: Automatically uploads startup videos
  - **Session Management**: Consistent folder naming across all uploads
  - **Background Operation**: Runs automatically without user intervention
  - **Error Handling**: Robust error handling with retry mechanisms
  - **Status Tracking**: Internal status tracking for monitoring upload operations

## How It Works

### Web Integration Workflow

1. **Web Link Click**: Users click a web link (e.g., `https://example.com/join?key=encrypted_key`)
2. **Automatic App Launch**: The web system attempts to open `truely://join?key=encrypted_key`
3. **App Opens**: Truely app launches automatically with window brought to front
4. **Key Population**: Encrypted key is automatically pasted into the app interface
5. **User Control**: User manually accepts terms and clicks "Join Meeting & Start Monitoring"

### Traditional Workflow

1. **Setup Phase**: Users manually enter their encrypted key and accept the terms and agreement. The interface provides real-time validation and configuration summary.

2. **Permission Setup**: The app automatically requests screen recording permissions at startup and guides users to System Settings if needed.

3. **Meeting Join**: The app uses the `RecallService` to create and configure a bot that joins the video meeting (mock implementation for open source).

4. **Automatic Evidence Collection**: The system automatically begins collecting evidence:
   - **Startup Video**: 45-second video recording starts immediately
   - **Periodic Screenshots**: Desktop screenshots every 2 minutes
   - **Session Organization**: All files saved to organized session folders

5. **Process & Network Detection**: The `ProcessMonitor` and `NetworkMonitor` continuously check for forbidden applications using:
   - System process enumeration via C bridge
   - GUI application monitoring via NSWorkspace
   - Bundle identifier checking
   - Path-based detection for app bundles
   - Real-time network traffic analysis
   - LLM API connection monitoring

6. **Automatic Upload**: The `LogUploadService` automatically uploads all collected evidence:
   - System logs every minute
   - Screenshots as they are captured
   - Startup videos when completed
   - All files organized in consistent session folders

7. **Alert System**: When forbidden applications or suspicious network activity are detected, the `RecallService` automatically sends formatted alerts to the meeting chat (mock implementation).

8. **Graceful Exit**: The app ensures the bot sends farewell messages and properly leaves the meeting before termination.

## Technical Architecture

### Detection Methods

#### Process Detection
- **System Process Enumeration**: Uses `sysctl` and `libproc` APIs for comprehensive process listing
- **GUI Application Monitoring**: Leverages `NSWorkspace.shared.runningApplications`
- **Bundle Identifier Checking**: Examines app bundle IDs for forbidden applications
- **Path-based Detection**: Checks executable paths and app bundle locations
- **Hash Verification**: SHA256 hash matching for executable files

#### Network Traffic Monitoring
- **Real-time Connection Analysis**: Uses `lsof` to monitor active network connections
- **LLM API Detection**: Identifies connections to OpenAI, Anthropic, Cohere, and other AI services
- **Reverse DNS Resolution**: Converts IP addresses to readable domain names
- **Traffic Classification**: Categorizes connections as definitive, suspicious, or informational
- **Process Attribution**: Links network activity to specific applications and PIDs

#### Automatic Screen Capture & Evidence Collection
- **Periodic Screenshots**: Automatic desktop capture every 2 minutes using `CGWindowListCreateImage`
- **Startup Video Recording**: 45-second video recording with H.264 compression at 500 kbps
- **Session Management**: Organized file storage in session-based folders
- **Multi-Monitor Support**: Captures all screens including side monitors in a single image
- **Optimized File Sizes**: Uses `.nominalResolution` and aggressive JPEG compression (10% quality) for small file sizes
- **Cursor Movement Capture**: All captures include real-time cursor movement and positioning
- **Automatic Upload**: Background upload service for all captured evidence

### Automatic Upload System

#### Log Upload Service
- **Background Operation**: Runs automatically without user intervention
- **Periodic Log Upload**: Uploads system logs every minute
- **Screenshot Upload**: Automatically uploads periodic screenshots as they are captured
- **Video Upload**: Automatically uploads startup videos when completed
- **Session Consistency**: All uploads use consistent session folder naming
- **Error Handling**: Robust error handling with retry mechanisms
- **Status Tracking**: Internal status tracking for monitoring upload operations

#### File Organization
- **Session Folders**: All files organized in session-based folders on desktop
- **Server-Provided Paths**: Uploads use server-provided folder paths (e.g., `organization/user/timestamp`)
- **Local Organization**: Local files use timestamp-based folders for organization
- **Automatic Creation**: Session folders created automatically at monitoring start
- **Fallback Support**: Falls back to desktop if session folder creation fails

## Installation & Usage

### Web Integration (Recommended)

1. **Build the Project**: Open `Truely.xcodeproj` in Xcode and build for macOS
2. **Grant Permissions**: The app will automatically request screen recording permissions
3. **Click Web Link**: Visit your web join link (e.g., `https://example.com/join?key=encrypted_key`)
4. **App Opens Automatically**: Truely app launches with encrypted key pre-populated
5. **Accept Terms**: Manually accept the terms and conditions
6. **Start Monitoring**: Click "Join Meeting & Start Monitoring" to begin
7. **Automatic Operation**: The app will automatically collect evidence and upload files in the background

### Manual Setup

1. **Build the Project**: Open `Truely.xcodeproj` in Xcode and build for macOS
2. **Grant Permissions**: The app will automatically request screen recording permissions
3. **Configure**: Enter your encrypted key and accept the terms
4. **Start Monitoring**: Click "Join Meeting & Start Monitoring" to begin
5. **Automatic Operation**: The app will automatically collect evidence and upload files in the background

## Requirements

- macOS 12.0 or later
- Screen recording permissions
- Internet connection for meeting integration and file uploads
- Valid encrypted key
- Web browser (for web integration workflow)

## URL Scheme Integration

The app supports the `truely://` URL scheme for seamless web integration:

### Supported URL Formats:
- `truely://join?key=encrypted_key_here`
- `truely://?key=encrypted_key_here`
- `truely:///join?key=encrypted_key_here`

### Web Integration:
When users click web links, the web system can automatically:
1. Generate encrypted meeting keys
2. Create join links with the encrypted key
3. Attempt to open the Truely app via URL scheme
4. Provide fallback options if the app isn't installed

The app will automatically:
1. Open when the URL scheme is triggered
2. Bring the window to the front
3. Extract and populate the encrypted key
4. Wait for user to accept terms and start monitoring

## Privacy & Security

### Free Plan
- **Local Monitoring Only**: All monitoring occurs locally on your device
- **No Evidence Collection**: No screenshots, videos, or logs are captured or stored
- **No Cloud Storage**: No data is uploaded to external servers
- **Basic Process Monitoring**: Only monitors running processes for forbidden applications

### Pro Plan
- **Screen Capture & Video Recording**: The app captures periodic screenshots every 2 minutes and records a 45-second startup video
- **Automatic Upload**: All captured evidence (screenshots, videos, logs) is automatically uploaded to secure cloud servers
- **Data Retention**: Evidence may be retained indefinitely for compliance, verification, or legal purposes
- **Third-Party Storage**: Data is stored on cloud servers and may be transmitted outside your local jurisdiction
- **No Local Privacy**: Users have no expectation of privacy regarding screen content captured during monitoring sessions
- **Network Monitoring**: Monitors network connections for LLM API usage and AI service connections

### Both Plans
- **Comprehensive Consent**: Detailed terms and agreement system ensures explicit user consent for all monitoring activities
- **Security Measures**: Industry-standard security implemented, though absolute security cannot be guaranteed

## Contributing

This is an open-source project. We welcome contributions from the community! Please feel free to submit issues, feature requests, or pull requests.

### Development Setup

1. Fork the repository
2. Clone your fork locally
3. Open `Truely.xcodeproj` in Xcode
4. Build and run the project
5. Make your changes
6. Submit a pull request

### Code Style

- Follow Swift style guidelines
- Add comments for complex logic
- Include tests for new features
- Update documentation as needed

## License

This project is licensed under the Elastic License 2.0 (ELv2) - see the LICENSE file for details. This license is restrictive and prevents commercial use of the software.

## Legal Notice

True-ly is provided "as is" without any warranty. Users must accept the comprehensive terms and agreement before use. The app is designed for legitimate monitoring purposes only and users are responsible for compliance with applicable laws and regulations.

## Disclaimer

This software is for educational and legitimate monitoring purposes only. Users are responsible for ensuring compliance with all applicable laws and regulations in their jurisdiction. The authors are not responsible for any misuse of this software.
