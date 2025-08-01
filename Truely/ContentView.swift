import SwiftUI
import Foundation
import AppKit
import AVFoundation
import CoreVideo

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.blendingMode = .behindWindow
        effectView.material = .hudWindow // You can try .sidebar, .underWindowBackground, etc.
        effectView.state = .active
        return effectView
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

extension View {
    func glassmorphicCard() -> some View {
        self
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 8)
    }
    func glassTextField(colorScheme: ColorScheme, isSetup: Bool) -> some View {
        self
            .padding(6)
            .background(
                colorScheme == .dark
                    ? Color.white.opacity(isSetup ? 0.22 : 0.14)
                    : Color.black.opacity(isSetup ? 0.13 : 0.06)
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
    func glassButton(filled: Bool = true, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        GlassButtonView(content: self, filled: filled, isEnabled: isEnabled, action: action)
    }
}

struct GlassButtonView<Content: View>: View {
    let content: Content
    let filled: Bool
    let action: () -> Void
    let isEnabled: Bool
    @State private var isHovered = false
    
    init(content: Content, filled: Bool, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.content = content
        self.filled = filled
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                filled 
                    ? Color.purple.opacity((isHovered && isEnabled) ? 0.35 : 0.18)
                    : Color.purple.opacity((isHovered && isEnabled) ? 0.12 : 0.0)
            )
            .foregroundColor(filled ? .primary : .purple)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.purple.opacity((isHovered && isEnabled) ? 0.45 : 0.18), 
                        lineWidth: (isHovered && isEnabled) ? 2 : 1
                    )
            )
            .scaleEffect((isHovered && isEnabled) ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.1).delay(0), value: isHovered)
            .animation(.easeInOut(duration: 0.1).delay(0), value: isEnabled)
            .contentShape(Rectangle())
            .onTapGesture {
                if isEnabled {
                    action()
                }
            }
            .onHover { hovering in
                if isEnabled {
                    isHovered = hovering
                } else {
                    isHovered = false
                }
            }
    }
}

enum AppStage {
    case setup
    case monitoring
}



extension View {
    func glassTag(isHighlighted: Bool = false) -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(isHighlighted ? Color.red.opacity(0.7) : Color.white.opacity(0.18))
            .foregroundColor(isHighlighted ? .white : .primary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isHighlighted ? Color.red : Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}

struct ContentView: View {
    enum Field: Hashable {
        case encryptedKey
    }
    
    @Environment(\.colorScheme) var colorScheme
    @State private var stage: AppStage = .setup
    @State private var encryptedKey: String = ""
    @State private var isMonitoring: Bool = false
    @State private var statusMessage: String = "Ready to monitor"
    @State private var detectedApps: [String] = []
    @FocusState private var focusedField: Field?
    @Binding var pendingURL: URL?
    @State private var debugLogs: [String] = []
    @State private var pendingNotificationURL: URL?
    @State private var urlCheckTimer: Timer?
    
    @StateObject private var truelyAPIService = TruelyAPIService()
    @StateObject private var meetingConfiguration = MeetingConfiguration()
    @StateObject private var processMonitor = ProcessMonitor()
    
    // MARK: - Log Upload Service
    @StateObject private var logUploadService = LogUploadService()
    

    
    // MARK: - Loading State Management
    @StateObject private var loadingStateManager = LoadingStateManager()
    @State private var showingErrorAlert: Bool = false
    @State private var currentErrorMessage: String = ""
    @State private var currentRetryAction: (() -> Void)?
    @State private var lastScanTime: Date = Date()
    @State private var lastAlertTime: Date = Date(timeIntervalSince1970: 0) // Initialize to epoch to allow first alert
    @State private var showingPermissionAlert: Bool = false
    @State private var hasScreenRecordingPermission: Bool = false
    @State private var isCheckingPermission: Bool = true
    @State private var hasInitializedPermission: Bool = false

    
    // MARK: - Terms and Agreement
    @State private var showingTermsAgreement: Bool = false
    @State private var hasAcceptedTerms: Bool = false
    @State private var hasTriedToProceedWithoutTerms: Bool = false
    
    // MARK: - Video Recording
    @State private var isRecording: Bool = false
    @State private var recordingStartTime: Date?
    @State private var recordingTimer: Timer?
    @State private var screenRecorder: ScreenRecorder?
    @State private var isUploadingDesktopCapture: Bool = false
    @State private var automaticScreenshotTimer: Timer?
    @State private var isTestVideoRecording: Bool = false
    
    // MARK: - Startup Video Recording
    @State private var startupVideoRecorder: ScreenRecorder?
    @State private var hasStartedStartupVideo: Bool = false
    @State private var startupVideoTimer: Timer?
    
    // MARK: - Session Management
    @State private var currentSessionId: String = ""
    @State private var sessionFolderPath: String = ""

    
    var forbiddenAppsArray: [String] {
        meetingConfiguration.forbiddenAppsArray
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }
    
    private var statusBoxBackgroundColor: Color {
        if isAnyOperationLoading() && !isMonitoring {
            return Color.blue.opacity(0.08)
        } else if isMonitoring {
            return Color.green.opacity(0.08)
        } else if colorScheme == .dark {
            return Color.white.opacity(0.08)
        } else {
            return Color.black.opacity(0.04)
        }
    }
    
    private var statusBoxStrokeColor: Color {
        if isAnyOperationLoading() && !isMonitoring {
            return Color.blue.opacity(0.2)
        } else if isMonitoring {
            return Color.green.opacity(0.2)
        } else {
            return Color.white.opacity(0.12)
        }
    }
    
    // MARK: - Verification Status Properties
    // All verification status properties removed for demo
    
    // MARK: - Permission Management
    
    private var permissionBlockingOverlay: some View {
        ZStack {
            // Background blur
            VisualEffectView().ignoresSafeArea()
            
            // Dark overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "camera.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.white)
                
                // Title
                Text("Screen Recording Permission Required")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Description
                VStack(spacing: 12) {
                    Text("Truely requires screen recording permission to function properly.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    Text("This permission is essential for:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                            Text("Capturing screenshots for evidence collection")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                            Text("Recording video evidence during monitoring")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                            Text("Monitoring screen activity for security")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                
                // Buttons
                VStack(spacing: 12) {
                    Button(action: openSystemSettings) {
                        HStack {
                            Image(systemName: "gear")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Open System Settings")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: checkScreenRecordingPermission) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Check Permission Status")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 40)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 60)
        }
    }
    
    private func checkScreenRecordingPermission() {
        isCheckingPermission = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let hasPermission = CGPreflightScreenCaptureAccess()
            
            DispatchQueue.main.async {
                self.hasScreenRecordingPermission = hasPermission
                self.isCheckingPermission = false
                self.hasInitializedPermission = true
                
                if !hasPermission {
                    // Show the permission alert as a fallback
                    self.showingPermissionAlert = true
                } else {
                    // Permission granted, hide any existing alerts
                    self.showingPermissionAlert = false
                }
            }
        }
    }
    
    private func startPermissionCheckTimer() {
        // Check permission every 2 seconds when permission is not granted
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            if !self.hasScreenRecordingPermission {
                let hasPermission = CGPreflightScreenCaptureAccess()
                if hasPermission != self.hasScreenRecordingPermission {
                    DispatchQueue.main.async {
                        self.hasScreenRecordingPermission = hasPermission
                        self.showingPermissionAlert = false
                        self.hasInitializedPermission = true
                        timer.invalidate() // Stop checking once permission is granted
                    }
                }
            } else {
                timer.invalidate() // Stop checking once permission is granted
            }
        }
    }
    
    private func openSystemSettings() {
        // Open System Settings to the Screen Recording section
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback: open general Privacy & Security settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    var body: some View {
        ZStack {
            VisualEffectView().ignoresSafeArea()
            
            // Show loading state until permission is initialized
            if !hasInitializedPermission {
                // Show a simple loading state that matches the app's design
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                    
                    Text("Initializing...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            } else {
                // Permission blocking overlay
                if !hasScreenRecordingPermission {
                    permissionBlockingOverlay
                }
                
                // Main content (only shown if permission is granted)
                if hasScreenRecordingPermission {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: colorScheme == .dark ? "#e0d4f3" : "#d5c5ef"), location: 0.0),
                    .init(color: Color(hex: "#ba9fe7"), location: 0.3),
                    .init(color: Color(hex: "#a17dda"), location: 0.7),
                    .init(color: Color(hex: "#966fd6"), location: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(colorScheme == .dark ? 0.22 : 0.22)
            .ignoresSafeArea()
            (colorScheme == .dark ? Color.black : Color.white)
                .opacity(stage == .setup ? 0.35 : (detectedApps.isEmpty ? 0.15 : 0.35))
                .animation(.easeInOut(duration: 0.6), value: stage)
                .animation(.easeInOut(duration: 0.8), value: detectedApps.isEmpty)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("Truely")
                        .font(.system(size: 30, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                        .shadow(color: Color.white.opacity(0.2), radius: 1, x: 0, y: 1)
                        .padding(.top, 12)
                    Text("The Anti-Cluely")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(Color.primary.opacity(0.4))
                        .padding(.bottom, 8)
                    if stage == .setup {
                        setupForm
                            .transition(.asymmetric(
                                insertion: .opacity.animation(.easeInOut(duration: 0.5)),
                                removal: .opacity.animation(.easeInOut(duration: 0.3))
                            ))
                    } else {
                        monitoringDashboard
                            .transition(.asymmetric(
                                insertion: .opacity.animation(.easeInOut(duration: 0.5)),
                                removal: .opacity.animation(.easeInOut(duration: 0.3))
                            ))
                    }
                }
                
                Spacer()
            }
            .font(.system(size: 12, design: .default))
            .frame(maxWidth: 400)
            .padding(10)
            }
            }
        }
        .onReceive(processMonitor.$detectedForbiddenApps) { apps in
            detectedApps = apps
            if !apps.isEmpty && isMonitoring && meetingConfiguration.isValid {
                // Only send alert if 3 seconds have passed since last alert
                let timeSinceLastAlert = Date().timeIntervalSince(lastAlertTime)
                if timeSinceLastAlert >= 3.0 {
                truelyAPIService.sendAlertToMeeting(
                    meetingLink: meetingConfiguration.meetingLink,
                    botId: meetingConfiguration.botId,
                    apps: apps
                )
                    lastAlertTime = Date()
                }
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            if let retryAction = currentRetryAction {
                Button("Retry") {
                    showingErrorAlert = false
                    retryAction()
                }
                Button("Cancel", role: .cancel) {
                    showingErrorAlert = false
                }
            } else {
                Button("OK") {
                    showingErrorAlert = false
                }
            }
        } message: {
            Text(currentErrorMessage)
        }
        .alert("Screen Recording Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open System Settings") {
                openSystemSettings()
            }
            Button("Check Again") {
                checkScreenRecordingPermission()
            }
        } message: {
            Text("Truely requires screen recording permission to function. Please enable it in System Settings > Privacy & Security > Screen Recording, then click 'Check Again'.")
        }

        .sheet(isPresented: $showingTermsAgreement) {
            TermsAgreementView(
                onAccept: {
                    hasAcceptedTerms = true
                    showingTermsAgreement = false
                },
                onDismiss: {
                    showingTermsAgreement = false
                }
            )
        }

        .onChange(of: isMonitoring) { newValue in
            // Update last scan time when monitoring starts
            if newValue {
                lastScanTime = Date()
                
                // Set up a timer to update scan time periodically
                Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { timer in
                    if isMonitoring {
                        lastScanTime = Date()
                    } else {
                        timer.invalidate()
                    }
                }
            }
        }

        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("URLReceived"))) { notification in
            if let url = notification.object as? URL {
                addDebugLog("🔗 Received URL from notification: \(url)")
                pendingNotificationURL = url
                
                // Try to process immediately
                processIncomingURL(url)
                
                // If the key field is still empty after a short delay, try again
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if encryptedKey.isEmpty {
                        addDebugLog("🔗 Retrying URL processing (key still empty)")
                        processIncomingURL(url)
                    }
                }
            }
        }
        .onAppear {
            addDebugLog("🔗 onAppear called")
            
            // Notify the app that ContentView is ready
            NotificationCenter.default.post(name: NSNotification.Name("ContentViewReady"), object: self)
            
            // Check screen recording permission first
            checkScreenRecordingPermission()
            startPermissionCheckTimer()
            
            // Process any pending URL when view appears
            if let url = pendingURL {
                addDebugLog("🔗 Processing pending URL: \(url)")
                processIncomingURL(url)
                pendingURL = nil
            } else if let url = pendingNotificationURL {
                addDebugLog("🔗 Processing pending notification URL: \(url)")
                processIncomingURL(url)
                pendingNotificationURL = nil
            } else {
                // Check UserDefaults for stored URL
                if let storedURLString = UserDefaults.standard.string(forKey: "PendingURL"),
                   let url = URL(string: storedURLString) {
                    addDebugLog("🔗 Processing stored URL from UserDefaults: \(url)")
                    processIncomingURL(url)
                    // Only clear if processing was successful
                    if !encryptedKey.isEmpty {
                        UserDefaults.standard.removeObject(forKey: "PendingURL")
                        addDebugLog("🔗 Cleared stored URL after successful processing")
                    }
                } else {
                    addDebugLog("🔗 No pending URL")
                }
            }
            
            // Start a timer to periodically check for stored URLs
            urlCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                if encryptedKey.isEmpty {
                    if let storedURLString = UserDefaults.standard.string(forKey: "PendingURL"),
                       let url = URL(string: storedURLString) {
                        addDebugLog("🔗 Timer: Processing stored URL: \(url)")
                        processIncomingURL(url)
                        if !encryptedKey.isEmpty {
                            UserDefaults.standard.removeObject(forKey: "PendingURL")
                            addDebugLog("🔗 Timer: Cleared stored URL after successful processing")
                            urlCheckTimer?.invalidate()
                            urlCheckTimer = nil
                        }
                    }
                } else {
                    // Key is set, stop the timer
                    urlCheckTimer?.invalidate()
                    urlCheckTimer = nil
                }
            }
        }
        .onChange(of: pendingURL) { newURL in
            addDebugLog("🔗 pendingURL changed to: \(newURL?.absoluteString ?? "nil")")
            // Process URL if it arrives while view is already loaded
            if let url = newURL {
                addDebugLog("🔗 Processing URL from onChange: \(url)")
                // Add a small delay to ensure UI is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    processIncomingURL(url)
                    pendingURL = nil
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowScreenRecordingPermissionAlert"))) { _ in
            showingPermissionAlert = true
        }
    }
    
    var setupForm: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Truely Encrypted Key:")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                SecureField("Enter your encrypted Truely key", text: $encryptedKey)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 16))
                    .frame(height: 40)
                    .padding(.horizontal, 10)
                    .glassTextField(colorScheme: colorScheme, isSetup: true)
                    .focused($focusedField, equals: .encryptedKey)
                    .disabled(!canInteractWithUI())
                    .onSubmit {
                        if !encryptedKey.isEmpty && canInteractWithUI() {
                            startMonitoring()
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { 
                        if canInteractWithUI() {
                            focusedField = .encryptedKey 
                        }
                    }
            }
            

            
            HStack {
                if isAnyOperationLoading() {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                }
                Text(isAnyOperationLoading() ? 
                     (loadingStateManager.getUnifiedStatusMessage()) : 
                     "Join Meeting & Start Monitoring")
            }
            .glassButton(
                filled: true, 
                isEnabled: !encryptedKey.isEmpty && canInteractWithUI(),
                action: {
                    startMonitoring()
                }
            )
            .opacity(encryptedKey.isEmpty || !canInteractWithUI() ? 0.4 : 1.0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Status: \(statusMessage)")
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundColor(isMonitoring ? .green : .primary)
                if !detectedApps.isEmpty {
                    Text("⚠️ Detected Forbidden Apps:")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundColor(.red)
                    ForEach(detectedApps, id: \.self) { app in
                        Text("• \(app)")
                            .foregroundColor(.red)
                    }
                }
                

            }
            
            // Terms and Agreement Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(action: {
                        showingTermsAgreement = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 12))
                            Text("Terms & Conditions")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.green)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Button(action: {
                        hasAcceptedTerms.toggle()
                        if hasAcceptedTerms {
                            hasTriedToProceedWithoutTerms = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: hasAcceptedTerms ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundColor(hasAcceptedTerms ? .green : .secondary)
                            Text("I accept the terms")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(hasAcceptedTerms ? .green : .secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if hasTriedToProceedWithoutTerms && !hasAcceptedTerms {
                    Text("You must accept the terms to continue")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 4)
            
            // Show configuration summary if we have valid config
            if meetingConfiguration.isValid {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configuration Summary:")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Platform: \(meetingConfiguration.meetingPlatform)")
                            .font(.system(size: 11, weight: .medium, design: .default))
                        Text("Plan: \(meetingConfiguration.planType.displayName)")
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .foregroundColor(meetingConfiguration.planType == .pro ? .green : .orange)
                        Text("Forbidden Apps: \(meetingConfiguration.forbiddenAppsString)")
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
                }
            }
            

            
            // Show verification status if verification is in progress
            // if verificationManager.isVerifying {
            //     VStack(alignment: .leading, spacing: 8) {
            //         Text("Meeting Verification:")
            //             .font(.system(size: 12, weight: .semibold, design: .default))
            //             .foregroundColor(.secondary)
            //         
            //         HStack {
            //             Image(systemName: verificationStatusIcon)
            //                 .foregroundColor(verificationStatusColor)
            //                 .font(.system(size: 12))
            //             Text(verificationStatusMessage)
            //                 .font(.system(size: 11, weight: .medium))
            //             .foregroundColor(verificationStatusColor)
            //             Spacer()
            //             if verificationManager.isVerifying {
            //                 ProgressView()
            //                     .scaleEffect(0.6)
            //                     .progressViewStyle(CircularProgressViewStyle(tint: verificationStatusColor))
            //             }
            //         }
            //         .padding(.horizontal, 12)
            //         .padding(.vertical, 8)
            //         .frame(maxWidth: .infinity, alignment: .leading)
            //         .background(verificationStatusBackgroundColor)
            //         .cornerRadius(8)
            //         .overlay(
            //             RoundedRectangle(cornerRadius: 8)
            //                 .stroke(verificationStatusColor.opacity(0.3), lineWidth: 1)
            //         )
            //     }
            // }
        }
    }
    

    

    
    var monitoringDashboard: some View {
        VStack(spacing: 16) {
            // Meeting Verification Status - Removed for demo
            
            // Enhanced Log Box with Real-time Status
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    Text("System Status:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    // Main status message
                    HStack {
                        if isMonitoring {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                        }
                        Text(statusMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isMonitoring ? .green : (isAnyOperationLoading() ? .blue : .primary))
                    }
                    
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(statusBoxBackgroundColor)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(statusBoxStrokeColor, lineWidth: 1)
                )
            }
            

            
            // Forbidden Apps Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "app.badge")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    Text("Forbidden Apps:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 80), spacing: 8)
                ], spacing: 8) {
                    ForEach(forbiddenAppsArray, id: \.self) { app in
                        Text(app)
                            .font(.system(size: 11, weight: .medium))
                            .glassTag(isHighlighted: detectedApps.contains(where: { $0.lowercased().contains(app.lowercased()) }))
                            .opacity(
                                detectedApps.contains(where: { $0.lowercased().contains(app.lowercased()) }) ? 1.2 : 1.0
                            )
                            .scaleEffect(
                                detectedApps.contains(where: { $0.lowercased().contains(app.lowercased()) }) ? 1.05 : 1.0
                            )
                    }
                }
            }
            
            // Status Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "shield")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    Text("Status:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    if detectedApps.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                            Text("All good! No forbidden apps detected.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.08))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green.opacity(0.2), lineWidth: 1)
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 14))
                                Text("Forbidden app detected!")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                            .opacity(0.8) // Slightly more opaque for better visibility
                            
                            // Scrollable container for detected apps
                            ScrollView(.vertical, showsIndicators: true) {
                                LazyVStack(alignment: .leading, spacing: 4) {
                                    ForEach(detectedApps, id: \.self) { app in
                                        Text("• \(app)")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.red.opacity(0.12))
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                                            )
                                            .opacity(0.6) // Less opaque for detected app items
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                            .frame(maxHeight: 120) // Limit height to prevent explosion
                            .background {
                                if #available(macOS 14.0, *) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.red.opacity(0.05))
                                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .foregroundColor(Color.red.opacity(0.05))
                                }
                            }
                            .opacity(0.6) // Less opaque for scroll container
                        }
                    }
                }
            }
            
            // Action Buttons
            VStack(spacing: 8) {
                
                // Stop Monitoring Button
                HStack {
                    if getLoadingState(.stoppingMonitoring).isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                    }
                    Text(getLoadingState(.stoppingMonitoring).isLoading ? 
                         (getLoadingState(.stoppingMonitoring).message ?? "Stopping...") : 
                         "Stop Monitoring")
                }
                .glassButton(
                    filled: true, 
                    isEnabled: isMonitoring && !getLoadingState(.stoppingMonitoring).isLoading,
                    action: {
                        stopMonitoring()
                    }
                )
                .opacity(!isMonitoring || getLoadingState(.stoppingMonitoring).isLoading ? 0.4 : 1.0)
            }
            .padding(.top, 12)
        }
    }
    
    // MARK: - Loading State Helper Functions
    
    private func setLoadingState(_ operation: OperationType, _ state: LoadingState) {
        loadingStateManager.setState(operation, state)
        updateStatusMessageFromLoadingState()
    }
    
    private func setLoading(_ operation: OperationType, message: String? = nil) {
        loadingStateManager.setLoading(operation, message: message)
        updateStatusMessageFromLoadingState()
    }
    
    private func setSuccess(_ operation: OperationType, message: String? = nil) {
        loadingStateManager.setSuccess(operation, message: message)
        updateStatusMessageFromLoadingState()
    }
    
    private func setError(_ operation: OperationType, message: String, isRetryable: Bool = true, retryAction: (() -> Void)? = nil) {
        loadingStateManager.setError(operation, message: message, isRetryable: isRetryable)
        currentErrorMessage = message
        currentRetryAction = retryAction
        if isRetryable && retryAction != nil {
            showingErrorAlert = true
        }
        updateStatusMessageFromLoadingState()
    }
    
    private func setIdle(_ operation: OperationType) {
        loadingStateManager.setIdle(operation)
        updateStatusMessageFromLoadingState()
    }
    
    private func updateStatusMessageFromLoadingState() {
        // Update the existing statusMessage for backward compatibility
        let unifiedMessage = loadingStateManager.getUnifiedStatusMessage()
        statusMessage = unifiedMessage
    }
    
    private func getLoadingState(_ operation: OperationType) -> LoadingState {
        return loadingStateManager.getState(operation)
    }
    
    private func isAnyOperationLoading() -> Bool {
        return loadingStateManager.hasActiveOperations
    }
    
    private func canInteractWithUI() -> Bool {
        return !isAnyOperationLoading()
    }
    
    private func startMonitoring() {
        guard !encryptedKey.isEmpty else {
            setError(.joiningMeeting, message: "Please enter your encrypted Truely key", isRetryable: true) {
                self.focusedField = .encryptedKey
            }
            return
        }
        
        guard hasAcceptedTerms else {
            hasTriedToProceedWithoutTerms = true
            setError(.joiningMeeting, message: "You must accept the terms to continue", isRetryable: false)
            return
        }
        
        // Step 1: Start meeting session

        
        // Step 2: Decrypt key and initialize bot
        setLoading(.startingBot, message: "Decrypting key and initializing bot...")
        
        // Set encrypted key for API authentication
        truelyAPIService.setEncryptedKey(encryptedKey)
        
        truelyAPIService.decryptKeyAndStartBot(encryptedKey: encryptedKey) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let decryptResponse):
                    // Update meeting configuration with decrypted data
                    self.meetingConfiguration.updateFromDecryptResponse(decryptResponse)
                    
                    // Validate the meeting link
                    guard let url = URL(string: decryptResponse.meetingLink),
                          MeetingConfiguration.isValidMeetingLink(decryptResponse.meetingLink) else {
                        self.setError(.joiningMeeting, message: "Invalid meeting link in configuration", isRetryable: true) {
                            self.startMonitoring()
                        }
                        return
                    }
                    
                    self.setSuccess(.startingBot, message: "Bot initialized successfully")
                    
                    // Step 3: Log meeting initiation for verification
        
                    
                    // Step 4: Opening meeting link
                    self.setLoading(.joiningMeeting, message: "Opening meeting link...")
                    NSWorkspace.shared.open(url)
                    
                    // Brief delay to show the loading state, then proceed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.setSuccess(.joiningMeeting, message: "Meeting link opened")
                        
                        // Step 5: Configuring process monitoring
                        self.setLoading(.scanningProcesses, message: "Configuring process monitoring...")
                        let forbiddenAppsArray = self.meetingConfiguration.forbiddenAppsArray
                        self.processMonitor.configure(forbiddenApps: forbiddenAppsArray, planType: self.meetingConfiguration.planType)
                        
                        // Enable advanced detection only for PRO plan
                        if self.meetingConfiguration.planType == .pro {
                            self.processMonitor.enableAdvancedDetection(windowThreshold: 5, screenEvasionThreshold: 3)
                        }
                        
                        // Step 6: Set up introduction message callbacks
                        self.truelyAPIService.onIntroductionStart = {
                            DispatchQueue.main.async {
                                self.statusMessage = "Sending introduction message..."
                            }
                        }
                        
                        self.truelyAPIService.onIntroductionComplete = {
                            DispatchQueue.main.async {
                                self.statusMessage = "Process scanning active"
                            }
                        }
                        
                        // Step 7: Send introduction messages and start monitoring
                        // self.setLoading(.scanningProcesses, message: "Sending introduction messages...")
                        
                        // Send introduction messages with temporary keys (since we don't store them separately anymore)
                        // let startingKey = "MONITOR_START"
                        // let endingKey = "MONITOR_END"
                        
                        // self.truelyAPIService.sendStartingMessage(
                        //     meetingLink: self.meetingConfiguration.meetingLink,
                        //     botId: self.meetingConfiguration.botId,
                        //     forbiddenApps: forbiddenAppsArray,
                        //     startingKey: startingKey,
                        //     endingKey: endingKey,
                        //     onStart: self.truelyAPIService.onIntroductionStart,
                        //     onComplete: self.truelyAPIService.onIntroductionComplete
                        // )
                        
                        // Step 8: Configure and start services based on plan type
                        if self.meetingConfiguration.planType == .pro {
                            // PRO PLAN: Full monitoring with evidence collection
                            self.setLoading(.scanningProcesses, message: "Configuring pro monitoring services...")
                            
                            // Configure log upload service
                            let platform = self.meetingConfiguration.meetingPlatform
                            let sessionId = UUID().uuidString
                            self.logUploadService.configure(
                                organization: "default", // You can make this configurable
                                sessionId: sessionId,
                                meetingLink: self.meetingConfiguration.meetingLink,
                                platform: platform,
                                encryptedKey: self.encryptedKey
                            )
                            
                            // Use folder path from decrypt response for server uploads
                            self.currentSessionId = self.meetingConfiguration.folderPath
                            print("📁 Using server-provided folder path: \(self.currentSessionId)")
                            
                            // Create local session folder for file storage
                            self.sessionFolderPath = self.createSessionFolder()
                            print("📁 Local session folder path: \(self.sessionFolderPath)")
                            
                            // Set session folder name in log upload service
                            self.logUploadService.setSessionFolderName(self.currentSessionId)
                            
                            // Set monitoring services
                            self.logUploadService.setMonitoringServices(
                                networkMonitor: self.processMonitor.getNetworkMonitor,
                                processMonitor: self.processMonitor,
                                suspiciousDetector: self.processMonitor.getSuspiciousDetector
                            )
                            
                            // Start log upload service
                            self.logUploadService.startUploadService()
                            
                            // Start automatic screenshot uploads every 2 minutes
                            self.startAutomaticScreenshotUploads()
                            
                            // Start 45-second startup video recording
                            self.startStartupVideoRecording()
                            
                            print("✅ Pro plan features enabled: Evidence collection, network monitoring, advanced detection")
                        } else {
                            // FREE PLAN: Basic process monitoring only
                            self.setLoading(.scanningProcesses, message: "Configuring basic monitoring...")
                            print("✅ Free plan: Basic process monitoring only")
                        }
                        
                        // Step 9: Start process monitoring
                        self.setLoading(.scanningProcesses, message: "Starting process monitoring...")
                        self.processMonitor.startMonitoring()
                        self.lastScanTime = Date()
                        
                        // Step 10: Complete verification and setup
            
                        print("✅ Meeting verification completed")
                        
                        // Complete setup
                        self.isMonitoring = true
                        self.setSuccess(.scanningProcesses, message: "Process scanning active")
                        self.stage = .monitoring
                    }
                    
                case .failure(let error):
                    self.setError(.startingBot, 
                                message: "Failed to decrypt key: \(error.localizedDescription)", 
                                isRetryable: true) {
                        self.startMonitoring() // Retry the entire process
                    }
                }
            }
        }
    }
    
    private func processIncomingURL(_ url: URL) {
        addDebugLog("🔗 processIncomingURL called with: \(url)")
        guard url.scheme == "truely" else { 
            addDebugLog("❌ Invalid URL scheme: \(url.scheme ?? "nil")")
            return 
        }
        
        var keyValue: String?
        
        // Handle different URL formats:
        // 1. truely://join?key=encrypted_key_here
        // 2. truely://?key=encrypted_key_here
        // 3. truely:///join?key=encrypted_key_here
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            // Extract key from query parameters
            keyValue = components.queryItems?.first(where: { $0.name == "key" })?.value
        }
        
        // Fallback: try to extract from path if no query parameter
        if keyValue == nil {
            let path = url.path
            if path.hasPrefix("/join/") {
                keyValue = String(path.dropFirst(6)) // Remove "/join/"
            } else if path.hasPrefix("/") && path.count > 1 {
                keyValue = String(path.dropFirst()) // Remove leading "/"
            }
        }
        
        if let key = keyValue, !key.isEmpty {
            addDebugLog("🔗 Extracted key: \(key)")
            // Validate key format (basic validation)
            if key.count < 10 { // Adjust based on your key requirements
                addDebugLog("❌ Key too short: \(key.count) characters")
                setError(.joiningMeeting, message: "Invalid key format received from URL", isRetryable: false)
                return
            }
            
            addDebugLog("✅ Setting encrypted key from URL")
            encryptedKey = key
            
            // Show success message
            statusMessage = "Key received from URL - please accept terms and start monitoring"
        } else {
            addDebugLog("❌ No valid key found in URL")
            setError(.joiningMeeting, message: "No valid key found in URL", isRetryable: false)
        }
    }
    
    private func addDebugLog(_ message: String) {
        let timestamp = DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] \(message)"
        DispatchQueue.main.async {
            self.debugLogs.append(logEntry)
            // Keep only last 10 logs
            if self.debugLogs.count > 10 {
                self.debugLogs.removeFirst()
            }
        }
    }
    
    // MARK: - Screen Capture Functions
    
    private func captureAllDesktops() {
        guard CGPreflightScreenCaptureAccess() else {
            print("⚠️ Screen Recording: No screen recording permission for all desktops capture")
            NotificationCenter.default.post(name: NSNotification.Name("ShowScreenRecordingPermissionAlert"), object: nil)
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        let filename = "AllDesktops_\(timestamp).jpg"
        let filePath = getCurrentFilePath(filename: filename)
        
        // Get all screens
        let screens = NSScreen.screens
        
        // Calculate the total bounds of all screens
        let totalBounds = screens.reduce(CGRect.null) { result, screen in
            result.union(screen.frame)
        }
        
        // Capture the entire desktop area at a reasonable resolution
        guard let cgImage = CGWindowListCreateImage(
            totalBounds,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .nominalResolution
        ) else {
            print("❌ Screen Recording: Failed to capture desktop")
            statusMessage = "Failed to capture desktop"
            return
        }
        
        // Create a new image with cursor overlay
        let imageWithCursor = addCursorToImage(cgImage: cgImage, bounds: totalBounds)
        
        // Create NSImage from CGImage with cursor
        let image = NSImage(cgImage: imageWithCursor, size: totalBounds.size)
        
        // Convert to JPEG with aggressive compression
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            print("❌ Screen Recording: Failed to create bitmap representation")
            statusMessage = "Failed to create image data"
            return
        }
        
        // Use JPEG with very aggressive compression for much smaller file sizes
        let jpegProperties: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionFactor: 0.1  // Very aggressive JPEG compression (10% quality)
        ]
        
        guard let data = bitmapRep.representation(using: .jpeg, properties: jpegProperties) else {
            print("❌ Screen Recording: Failed to create JPEG data")
            statusMessage = "Failed to create JPEG data"
            return
        }
        
        // Check file size before saving
        let fileSizeMB = Double(data.count) / (1024 * 1024)
        print("📊 Screen Recording: Generated image size: \(String(format: "%.2f", fileSizeMB)) MB")
        
        // If still too large, try even more aggressive compression
        if fileSizeMB > 1.0 {
            print("⚠️ Screen Recording: Image still too large, applying ultra compression...")
            
            // Try with even more aggressive compression
            let ultraCompressionProperties: [NSBitmapImageRep.PropertyKey: Any] = [
                .compressionFactor: 0.05  // Ultra aggressive compression (5% quality)
            ]
            
            if let ultraData = bitmapRep.representation(using: .jpeg, properties: ultraCompressionProperties) {
                let ultraFileSizeMB = Double(ultraData.count) / (1024 * 1024)
                print("📊 Screen Recording: Ultra compressed size: \(String(format: "%.2f", ultraFileSizeMB)) MB")
                
                do {
                    try ultraData.write(to: URL(fileURLWithPath: filePath))
                    print("✅ Screen Recording: All desktops captured successfully (ultra compressed): \(filename)")
                    statusMessage = "All desktops captured (ultra compressed): \(filename)"
                    return
                } catch {
                    print("❌ Screen Recording: Failed to save ultra compressed capture: \(error)")
                }
            }
        }
        
        // Save the normally compressed version
        do {
            try data.write(to: URL(fileURLWithPath: filePath))
            print("✅ Screen Recording: All desktops captured successfully: \(filename)")
            statusMessage = "All desktops captured: \(filename)"
        } catch {
            print("❌ Screen Recording: Failed to save all desktops capture: \(error)")
            statusMessage = "Failed to save all desktops capture"
        }
    }
    
    private func uploadDesktopCapture() {
        guard isMonitoring else {
            statusMessage = "Monitoring must be active to upload captures"
            return
        }
        
        isUploadingDesktopCapture = true
        statusMessage = "Capturing and uploading desktop..."
        
        // First capture the desktop
        guard CGPreflightScreenCaptureAccess() else {
            print("⚠️ Screen Recording: No screen recording permission for desktop capture")
            NotificationCenter.default.post(name: NSNotification.Name("ShowScreenRecordingPermissionAlert"), object: nil)
            isUploadingDesktopCapture = false
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        let filename = "Manual_AllDesktops_\(timestamp).jpg"
        let filePath = getCurrentFilePath(filename: filename)
        
        // Get all screens
        let screens = NSScreen.screens
        let totalBounds = screens.reduce(CGRect.null) { result, screen in
            result.union(screen.frame)
        }
        
        // Capture the entire desktop area
        guard let cgImage = CGWindowListCreateImage(
            totalBounds,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .nominalResolution
        ) else {
            print("❌ Screen Recording: Failed to capture desktop")
            statusMessage = "Failed to capture desktop"
            isUploadingDesktopCapture = false
            return
        }
        
        // Create a new image with cursor overlay
        let imageWithCursor = addCursorToImage(cgImage: cgImage, bounds: totalBounds)
        
        // Create NSImage from CGImage with cursor
        let image = NSImage(cgImage: imageWithCursor, size: totalBounds.size)
        
        // Convert to JPEG with compression
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            print("❌ Screen Recording: Failed to create bitmap representation")
            statusMessage = "Failed to create image data"
            isUploadingDesktopCapture = false
            return
        }
        
        let jpegProperties: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionFactor: 0.1  // 10% quality for small file size
        ]
        
        guard let data = bitmapRep.representation(using: .jpeg, properties: jpegProperties) else {
            print("❌ Screen Recording: Failed to create JPEG data")
            statusMessage = "Failed to create JPEG data"
            isUploadingDesktopCapture = false
            return
        }
        
        // Save the image locally first
        do {
            try data.write(to: URL(fileURLWithPath: filePath))
            print("✅ Screen Recording: Desktop captured for upload: \(filename)")
            
            // Now upload to server
            uploadDesktopCaptureToServer(filePath: filePath, filename: filename)
            
        } catch {
            print("❌ Screen Recording: Failed to save desktop capture: \(error)")
            statusMessage = "Failed to save desktop capture"
            isUploadingDesktopCapture = false
        }
    }
    
    private func uploadDesktopCaptureToServer(filePath: String, filename: String) {
        // Use the current session ID for consistent folder naming
        let folderName = currentSessionId
        
        print("📸 Uploading manual desktop capture: \(filename) to folder: \(folderName)")
        
        logUploadService.uploadScreenshot(
            filePath: filePath,
            folderName: folderName,
            fileName: filename
        ) { success, error in
            DispatchQueue.main.async {
                self.isUploadingDesktopCapture = false
                
                if success {
                    print("✅ Manual desktop capture uploaded successfully: \(filename)")
                    self.statusMessage = "Desktop capture uploaded: \(filename)"
                } else {
                    print("❌ Manual desktop capture upload failed: \(filename) - \(error ?? "Unknown error")")
                    self.statusMessage = "Upload failed: \(error ?? "Unknown error")"
                }
            }
        }
    }
    
    // MARK: - Automatic Screenshot Upload Functions
    
    private func startAutomaticScreenshotUploads() {
        print("📸 Starting automatic screenshot uploads every 2 minutes")
        
        // Stop any existing timer
        stopAutomaticScreenshotUploads()
        
        // Upload first screenshot after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.performAutomaticScreenshotUpload(prefix: "Startup")
        }
        
        // Set up timer for every 2 minutes (120 seconds)
        automaticScreenshotTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { _ in
            self.performAutomaticScreenshotUpload(prefix: "Periodic")
        }
    }
    
    private func stopAutomaticScreenshotUploads() {
        automaticScreenshotTimer?.invalidate()
        automaticScreenshotTimer = nil
        print("📸 Automatic screenshot uploads stopped")
    }
    
    private func performAutomaticScreenshotUpload(prefix: String) {
        guard isMonitoring else {
            print("📸 Skipping automatic screenshot - monitoring not active")
            return
        }
        
        print("📸 Performing automatic screenshot upload with prefix: \(prefix)")
        
        // Use the same capture logic as manual upload
        guard CGPreflightScreenCaptureAccess() else {
            print("⚠️ Screen Recording: No screen recording permission for automatic capture")
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        let filename = "\(prefix)_AllDesktops_\(timestamp).jpg"
        let filePath = getCurrentFilePath(filename: filename)
        
        // Get all screens
        let screens = NSScreen.screens
        let totalBounds = screens.reduce(CGRect.null) { result, screen in
            result.union(screen.frame)
        }
        
        // Capture the entire desktop area
        guard let cgImage = CGWindowListCreateImage(
            totalBounds,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .nominalResolution
        ) else {
            print("❌ Screen Recording: Failed to capture desktop for automatic upload")
            return
        }
        
        // Create a new image with cursor overlay
        let imageWithCursor = addCursorToImage(cgImage: cgImage, bounds: totalBounds)
        
        // Create NSImage from CGImage with cursor
        let image = NSImage(cgImage: imageWithCursor, size: totalBounds.size)
        
        // Convert to JPEG with compression
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            print("❌ Screen Recording: Failed to create bitmap representation for automatic upload")
            return
        }
        
        let jpegProperties: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionFactor: 0.1  // 10% quality for small file size
        ]
        
        guard let data = bitmapRep.representation(using: .jpeg, properties: jpegProperties) else {
            print("❌ Screen Recording: Failed to create JPEG data for automatic upload")
            return
        }
        
        // Save the image locally first
        do {
            try data.write(to: URL(fileURLWithPath: filePath))
            print("✅ Screen Recording: Automatic desktop captured: \(filename)")
            
            // Now upload to server
            uploadAutomaticScreenshotToServer(filePath: filePath, filename: filename, prefix: prefix)
            
        } catch {
            print("❌ Screen Recording: Failed to save automatic desktop capture: \(error)")
        }
    }
    
    private func uploadAutomaticScreenshotToServer(filePath: String, filename: String, prefix: String) {
        // Use the current session ID for consistent folder naming
        let folderName = currentSessionId
        
        print("📸 Uploading automatic screenshot: \(filename) to folder: \(folderName)")
        
        logUploadService.uploadScreenshot(
            filePath: filePath,
            folderName: folderName,
            fileName: filename
        ) { success, error in
            if success {
                print("✅ Automatic screenshot uploaded successfully: \(filename)")
            } else {
                print("❌ Automatic screenshot upload failed: \(filename) - \(error ?? "Unknown error")")
            }
        }
    }
    
    private func captureSpecificWindow(windowID: CGWindowID, windowName: String) {
        guard CGPreflightScreenCaptureAccess() else {
            print("⚠️ Screen Recording: No screen recording permission for window capture")
            NotificationCenter.default.post(name: NSNotification.Name("ShowScreenRecordingPermissionAlert"), object: nil)
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        let safeWindowName = windowName.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        let filename = "Window_\(safeWindowName)_\(timestamp).jpg"
        let filePath = getCurrentFilePath(filename: filename)
        
        // Capture the specific window at reasonable quality and file size
        if let cgImage = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, [.nominalResolution, .boundsIgnoreFraming]) {
            // Get window bounds for cursor positioning
            let windowBounds = getWindowBounds(windowID: windowID)
            // Add cursor to the captured image
            let imageWithCursor = addCursorToImage(cgImage: cgImage, bounds: windowBounds)
            let bitmapRep = NSBitmapImageRep(cgImage: imageWithCursor)
            
            // Use JPEG with aggressive compression for smaller file size
            let jpegProperties: [NSBitmapImageRep.PropertyKey: Any] = [
                .compressionFactor: 0.3 // Aggressive JPEG compression (30% quality)
            ]
            
            if let data = bitmapRep.representation(using: .jpeg, properties: jpegProperties) {
                do {
                    try data.write(to: URL(fileURLWithPath: filePath))
                    print("✅ Screen Recording: Window captured successfully: \(filename)")
                    statusMessage = "Window captured: \(filename)"
                } catch {
                    print("❌ Screen Recording: Failed to save window capture: \(error)")
                    statusMessage = "Failed to save window capture"
                }
            } else {
                print("❌ Screen Recording: Failed to create JPEG data for window")
                statusMessage = "Failed to create window capture data"
            }
        } else {
            print("❌ Screen Recording: Failed to capture window")
            statusMessage = "Failed to capture window"
        }
    }
    

    
    private func stopMonitoring() {
        performMonitoringCleanup(showUI: true)
    }
    
    // Public function that can be called from app level for cleanup
    func performMonitoringCleanup(showUI: Bool = false, completion: (() -> Void)? = nil) {
        if showUI {
            setLoading(.stoppingMonitoring, message: "Stopping process monitoring...")
        }
        
        processMonitor.stopMonitoring()
        
        // Stop log upload service
        logUploadService.stopUploadService()
        
        // Stop automatic screenshot uploads
        stopAutomaticScreenshotUploads()
        
        // Stop session
        
        guard meetingConfiguration.isValid else {
            // If no valid configuration, just stop monitoring locally
            DispatchQueue.main.async {
                self.isMonitoring = false
                if showUI {
                    self.setSuccess(.stoppingMonitoring, message: "Monitoring stopped")
                }
                self.meetingConfiguration.clear()
                
                // Clear session ID and folder path
                self.currentSessionId = ""
                self.sessionFolderPath = ""
                self.hasStartedStartupVideo = false
                
                self.stage = .setup
                
                // Call completion if provided
                completion?()
            }
            return
        }
        
        if showUI {
            setLoading(.stoppingMonitoring, message: "Sending farewell message...")
        }
        
        // Use temporary ending key since we don't store it separately anymore
        let endingKey = "MONITOR_END"
        
        truelyAPIService.sendFarewellAndStop(
            meetingLink: meetingConfiguration.meetingLink,
            botId: meetingConfiguration.botId,
            endingKey: endingKey,
            sessionId: currentSessionId
        ) {
            DispatchQueue.main.async {
                if showUI {
                    self.setLoading(.stoppingMonitoring, message: "Cleaning up...")
                }
                
                // Brief delay to show final loading state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isMonitoring = false
                    if showUI {
                        self.setSuccess(.stoppingMonitoring, message: "Monitoring stopped - Bot left meeting")
                        
                        // Clear all other states
                        self.setIdle(.scanningProcesses)
                        self.setIdle(.startingBot)
                        self.setIdle(.joiningMeeting)
                    }
                    
                    // Clear meeting configuration
                    self.meetingConfiguration.clear()
                    
                    // Clear session ID and folder path
                    self.currentSessionId = ""
                    self.sessionFolderPath = ""
                    self.hasStartedStartupVideo = false
                    
                    self.stage = .setup
                    
                    // Call completion if provided
                    completion?()
                }
            }
        }
    }
    
    // MARK: - Video Recording Functions
    
    private func startVideoRecording() {
        guard CGPreflightScreenCaptureAccess() else {
            print("⚠️ Video Recording: No screen recording permission for video capture")
            NotificationCenter.default.post(name: NSNotification.Name("ShowScreenRecordingPermissionAlert"), object: nil)
            return
        }
        
        // Create screen recorder
        screenRecorder = ScreenRecorder()
        
        // Start recording with session folder path
        screenRecorder?.startRecording(customPath: sessionFolderPath) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.isRecording = true
                    self.recordingStartTime = Date()
                    self.startRecordingTimer()
                    print("✅ Video Recording: Started successfully")
                    self.statusMessage = "Video recording started"
                case .failure(let error):
                    print("❌ Video Recording: Failed to start: \(error)")
                    self.statusMessage = "Failed to start video recording"
                }
            }
        }
    }
    
    private func stopVideoRecording() {
        screenRecorder?.stopRecording { result in
            DispatchQueue.main.async {
                self.isRecording = false
                self.recordingStartTime = nil
                self.stopRecordingTimer()
                
                switch result {
                case .success(let filename):
                    print("✅ Video Recording: Stopped successfully - \(filename)")
                    self.statusMessage = "Video recording saved: \(filename)"
                case .failure(let error):
                    print("❌ Video Recording: Failed to stop: \(error)")
                    self.statusMessage = "Failed to save video recording"
                }
            }
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Update UI if needed
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    // MARK: - Startup Video Recording Functions
    
    private func startStartupVideoRecording() {
        guard !hasStartedStartupVideo else {
            print("🎥 Startup Video: Already started startup video recording")
            return
        }
        
        guard CGPreflightScreenCaptureAccess() else {
            print("⚠️ Startup Video: No screen recording permission for startup video")
            return
        }
        
        print("🎥 Startup Video: Starting 45-second startup video recording...")
        
        // Create screen recorder
        startupVideoRecorder = ScreenRecorder()
        
        // Create custom filename for startup video
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let customFilename = "StartupVideo_\(timestamp).mp4"
        
        // Update the ScreenRecorder to use session folder path
        // We'll need to modify the ScreenRecorder to accept a custom path
        
        // Start recording with session folder path
        startupVideoRecorder?.startRecording(customFilename: customFilename, customPath: sessionFolderPath) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.hasStartedStartupVideo = true
                    print("✅ Startup Video: Started successfully")
                    
                    // Stop recording after 45 seconds
                    self.startupVideoTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: false) { _ in
                        self.stopStartupVideoRecording()
                    }
                    
                case .failure(let error):
                    print("❌ Startup Video: Failed to start: \(error)")
                }
            }
        }
    }
    
    private func stopStartupVideoRecording() {
        guard let recorder = startupVideoRecorder else {
            print("⚠️ Startup Video: No startup video recorder to stop")
            return
        }
        
        recorder.stopRecording { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let filename):
                    print("✅ Startup Video: Recording completed: \(filename)")
                    
                    // Construct full file path using session folder
                    let fullFilePath = (self.sessionFolderPath as NSString).appendingPathComponent(filename)
                    
                    // Upload the startup video
                    self.uploadStartupVideoToServer(filePath: fullFilePath)
                    
                case .failure(let error):
                    print("❌ Startup Video: Failed to stop: \(error)")
                }
                
                // Clean up
                self.startupVideoRecorder = nil
                self.startupVideoTimer?.invalidate()
                self.startupVideoTimer = nil
            }
        }
    }
    
    private func generateSessionId() -> String {
        // Use server-provided folder path if available, otherwise generate timestamp-based ID
        if !meetingConfiguration.folderPath.isEmpty {
            return meetingConfiguration.folderPath
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "\(timestamp)_default"
    }
    
    private func createSessionFolder() -> String {
        let sessionId = generateSessionId()
        let desktopPath = NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first ?? ""
        let folderPath = (desktopPath as NSString).appendingPathComponent(sessionId)
        
        // Create the session folder
        do {
            try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true)
            print("📁 Session folder created: \(folderPath)")
        } catch {
            print("❌ Failed to create session folder: \(error)")
        }
        
        return folderPath
    }
    
    private func getCurrentFilePath(filename: String) -> String {
        // Use session folder if available, otherwise fall back to desktop
        let basePath = sessionFolderPath.isEmpty ? 
            NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first ?? "" : 
            sessionFolderPath
        return (basePath as NSString).appendingPathComponent(filename)
    }
    
    private func uploadStartupVideoToServer(filePath: String) {
        // Use the current session ID for consistent folder naming
        let folderName = currentSessionId
        
        // Extract filename from path
        let fileName = (filePath as NSString).lastPathComponent
        
        print("🎥 Startup Video: Uploading startup video: \(fileName) to folder: \(folderName)")
        
        logUploadService.uploadVideo(
            filePath: filePath,
            folderName: folderName,
            fileName: fileName
        ) { success, error in
            if success {
                print("✅ Startup Video: Uploaded successfully: \(fileName)")
            } else {
                print("❌ Startup Video: Upload failed: \(fileName) - \(error ?? "Unknown error")")
            }
        }
    }
    
    // MARK: - Test Video Recording Functions
    
    private func startTestVideoRecording() {
        guard CGPreflightScreenCaptureAccess() else {
            print("⚠️ Test Video: No screen recording permission for test video")
            NotificationCenter.default.post(name: NSNotification.Name("ShowScreenRecordingPermissionAlert"), object: nil)
            return
        }
        
        print("🎥 Test Video: Starting 1-second test video recording...")
        isTestVideoRecording = true
        statusMessage = "Recording test video..."
        
        // Create screen recorder
        let testVideoRecorder = ScreenRecorder()
        
        // Create custom filename for test video
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let customFilename = "TestVideo_\(timestamp).mp4"
        
        // Start recording with session folder path
        testVideoRecorder.startRecording(customFilename: customFilename, customPath: sessionFolderPath) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Test Video: Started successfully")
                    
                    // Stop recording after 1 second
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.stopTestVideoRecording(recorder: testVideoRecorder)
                    }
                    
                case .failure(let error):
                    print("❌ Test Video: Failed to start: \(error)")
                    self.isTestVideoRecording = false
                    self.statusMessage = "Failed to start test video recording"
                }
            }
        }
    }
    
    private func stopTestVideoRecording(recorder: ScreenRecorder) {
        recorder.stopRecording { result in
            DispatchQueue.main.async {
                self.isTestVideoRecording = false
                
                switch result {
                case .success(let filename):
                    print("✅ Test Video: Recording completed: \(filename)")
                    self.statusMessage = "Test video recorded, uploading..."
                    
                    // Construct full file path using session folder
                    let fullFilePath = (self.sessionFolderPath as NSString).appendingPathComponent(filename)
                    
                    // Upload the test video
                    self.uploadTestVideoToServer(filePath: fullFilePath)
                    
                case .failure(let error):
                    print("❌ Test Video: Failed to stop: \(error)")
                    self.statusMessage = "Failed to save test video recording"
                }
            }
        }
    }
    
    private func uploadTestVideoToServer(filePath: String) {
        // Use the current session ID for consistent folder naming
        let folderName = currentSessionId.isEmpty ? generateSessionId() : currentSessionId
        
        // Extract filename from path
        let fileName = (filePath as NSString).lastPathComponent
        
        print("🎥 Test Video: Uploading test video: \(fileName) to folder: \(folderName)")
        
        logUploadService.uploadVideo(
            filePath: filePath,
            folderName: folderName,
            fileName: fileName
        ) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Test Video: Uploaded successfully: \(fileName)")
                    self.statusMessage = "Test video uploaded successfully: \(fileName)"
                } else {
                    print("❌ Test Video: Upload failed: \(fileName) - \(error ?? "Unknown error")")
                    self.statusMessage = "Test video upload failed: \(error ?? "Unknown error")"
                }
            }
        }
    }
    
    // MARK: - Cursor Capture Helper
    
    private func addCursorToImage(cgImage: CGImage, bounds: CGRect) -> CGImage {
        let width = Int(bounds.width)
        let height = Int(bounds.height)
        
        // Create a new bitmap context with the cursor
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        guard let context = context else { return cgImage }
        
        // Draw the original image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Get cursor position and image
        let cursorPosition = NSEvent.mouseLocation
        let cursorImage = NSCursor.current.image
        
        // Convert cursor position to image coordinates
        let cursorX = cursorPosition.x - bounds.origin.x
        let cursorY = bounds.height - (cursorPosition.y - bounds.origin.y) - cursorImage.size.height
        
        // Draw cursor if it's within the capture bounds
        if cursorX >= 0 && cursorY >= 0 && 
           cursorX + cursorImage.size.width <= bounds.width && 
           cursorY + cursorImage.size.height <= bounds.height {
            
            if let cursorCGImage = cursorImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cursorCGImage, in: CGRect(
                    x: cursorX,
                    y: cursorY,
                    width: cursorImage.size.width,
                    height: cursorImage.size.height
                ))
            }
        }
        
        return context.makeImage() ?? cgImage
    }
    
    private func getWindowBounds(windowID: CGWindowID) -> CGRect {
        let windowList = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]] ?? []
        
        for windowInfo in windowList {
            if let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
               let x = bounds["X"] as? CGFloat,
               let y = bounds["Y"] as? CGFloat,
               let width = bounds["Width"] as? CGFloat,
               let height = bounds["Height"] as? CGFloat {
                return CGRect(x: x, y: y, width: width, height: height)
            }
        }
        
        // Fallback to screen bounds if window bounds not found
        return NSScreen.main?.frame ?? CGRect.zero
    }
    
    // MARK: - Window Logging
}

// MARK: - Screen Recorder Class

class ScreenRecorder: NSObject {
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var displayLink: CVDisplayLink?
    private var outputURL: URL?
    private var isRecording = false
    private var frameCount = 0
    private var startTime: CMTime = .zero
    
    override init() {
        super.init()
    }
    
    func startRecording(customFilename: String? = nil, customPath: String? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isRecording else {
            completion(.failure(ScreenRecorderError.alreadyRecording))
            return
        }
        
        // Create output file
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        let basePath = customPath ?? NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first ?? ""
        let filename = customFilename ?? "ScreenRecording_\(timestamp).mp4"
        outputURL = URL(fileURLWithPath: (basePath as NSString).appendingPathComponent(filename))
        
        guard let outputURL = outputURL else {
            completion(.failure(ScreenRecorderError.invalidOutputURL))
            return
        }
        
        // Get screen dimensions
        let screens = NSScreen.screens
        let totalBounds = screens.reduce(CGRect.null) { result, screen in
            result.union(screen.frame)
        }
        
        let width = Int(totalBounds.width)
        let height = Int(totalBounds.height)
        
        // Configure video settings for small file size and 2x speed
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 500_000, // 500 kbps for small file size
                AVVideoMaxKeyFrameIntervalKey: 60, // Key frame every 60 frames (2x more frequent)
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
            ]
        ]
        
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            assetWriterInput?.expectsMediaDataInRealTime = true
            
            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
            
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: assetWriterInput!,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )
            
            if assetWriter?.canAdd(assetWriterInput!) == true {
                assetWriter?.add(assetWriterInput!)
            } else {
                completion(.failure(ScreenRecorderError.cannotAddInput))
                return
            }
            
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: .zero)
            
            isRecording = true
            startTime = .zero
            frameCount = 0
            
            // Start display link for screen capture
            startDisplayLink()
            
            completion(.success(()))
            
        } catch {
            completion(.failure(error))
        }
    }
    
    func stopRecording(completion: @escaping (Result<String, Error>) -> Void) {
        guard isRecording else {
            completion(.failure(ScreenRecorderError.notRecording))
            return
        }
        
        isRecording = false
        stopDisplayLink()
        
        assetWriterInput?.markAsFinished()
        assetWriter?.finishWriting {
            DispatchQueue.main.async {
                if let filename = self.outputURL?.lastPathComponent {
                    completion(.success(filename))
                } else {
                    completion(.failure(ScreenRecorderError.invalidOutputURL))
                }
            }
        }
    }
    
    private func startDisplayLink() {
        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        guard let displayLink = displayLink else { return }
        
        self.displayLink = displayLink
        
        CVDisplayLinkSetOutputCallback(displayLink, { (displayLink, _, _, _, _, displayLinkContext) -> CVReturn in
            let recorder = Unmanaged<ScreenRecorder>.fromOpaque(displayLinkContext!).takeUnretainedValue()
            recorder.captureFrame()
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
        
        CVDisplayLinkStart(displayLink)
    }
    
    private func stopDisplayLink() {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
            self.displayLink = nil
        }
    }
    
    private func captureFrame() {
        guard isRecording,
              let assetWriterInput = assetWriterInput,
              assetWriterInput.isReadyForMoreMediaData else { return }
        
        // Capture screen
        let screens = NSScreen.screens
        let totalBounds = screens.reduce(CGRect.null) { result, screen in
            result.union(screen.frame)
        }
        
        guard let cgImage = CGWindowListCreateImage(
            totalBounds,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .nominalResolution
        ) else { return }
        
        // Add cursor to the captured image
        let imageWithCursor = addCursorToImage(cgImage: cgImage, bounds: totalBounds)
        
        // Convert to pixel buffer
        let width = Int(totalBounds.width)
        let height = Int(totalBounds.height)
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else { return }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        
        context?.draw(imageWithCursor, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Calculate presentation time for 2x speed (60 FPS effective playback)
        let presentationTime = CMTime(value: CMTimeValue(frameCount), timescale: 60) // 60 FPS for 2x speed
        
        // Append to video
        if pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: presentationTime) == true {
            frameCount += 1
        }
    }
    
    private func addCursorToImage(cgImage: CGImage, bounds: CGRect) -> CGImage {
        let width = Int(bounds.width)
        let height = Int(bounds.height)
        
        // Create a new bitmap context with the cursor
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        guard let context = context else { return cgImage }
        
        // Draw the original image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Get cursor position and image
        let cursorPosition = NSEvent.mouseLocation
        let cursorImage = NSCursor.current.image
        
        // Convert cursor position to image coordinates
        let cursorX = cursorPosition.x - bounds.origin.x
        let cursorY = bounds.height - (cursorPosition.y - bounds.origin.y) - cursorImage.size.height
        
        // Draw cursor if it's within the capture bounds
        if cursorX >= 0 && cursorY >= 0 && 
           cursorX + cursorImage.size.width <= bounds.width && 
           cursorY + cursorImage.size.height <= bounds.height {
            
            if let cursorCGImage = cursorImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cursorCGImage, in: CGRect(
                    x: cursorX,
                    y: cursorY,
                    width: cursorImage.size.width,
                    height: cursorImage.size.height
                ))
            }
        }
        
        return context.makeImage() ?? cgImage
    }
}

// MARK: - Screen Recorder Errors

enum ScreenRecorderError: Error, LocalizedError {
    case alreadyRecording
    case notRecording
    case invalidOutputURL
    case cannotAddInput
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Already recording"
        case .notRecording:
            return "Not currently recording"
        case .invalidOutputURL:
            return "Invalid output URL"
        case .cannotAddInput:
            return "Cannot add video input"
        }
    }
}

// MARK: - Terms Agreement View

struct TermsAgreementView: View {
    let onAccept: () -> Void
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.blue)
                    Text("Truely Monitoring Consent & Terms of Use")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Text("Before proceeding, please read and accept the following Terms & Conditions:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            
            // Terms Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Monitoring & Data Access
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "eye")
                                .foregroundColor(.blue)
                                .font(.system(size: 14, weight: .semibold))
                            Text("Monitoring & Data Access")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• Truely monitors your device's running processes (PIDs), active window titles, and foreground application access during the meeting session.")
                            Text("• Pro plan includes: Network traffic monitoring, automatic screenshots, video recording, and evidence upload.")
                            Text("• Free plan includes: Basic process monitoring only.")
                            Text("• All captured evidence (Pro plan) is automatically uploaded to secure cloud servers for verification purposes.")
                            Text("• Monitoring is used solely for the purpose of determining whether the meeting is being conducted honestly and without the aid of unauthorized software.")
                        }
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                    }
                    
                    // Scope of Consent
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.shield")
                                .foregroundColor(.green)
                                .font(.system(size: 14, weight: .semibold))
                            Text("Scope of Consent")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("You grant Truely and its operators permission to:")
                            Text("• Analyze process activity to detect potential violations.")
                            Text("• Use elevated system permissions for real-time monitoring during active sessions.")
                            Text("• Report detected violations to the party hosting or conducting the meeting.")
                            Text("• For Pro plan: Capture, store, and upload screenshots and video footage.")
                            Text("• For Pro plan: Monitor network traffic and store evidence on secure cloud servers.")
                        }
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                    }
                    
                    // Accuracy & Results
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.system(size: 14, weight: .semibold))
                            Text("Accuracy & Results")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• You acknowledge that Truely's detection system is probabilistic and may produce false positives or false negatives.")
                            Text("• You agree not to hold Truely, its creators, contributors, or affiliates liable for any employment decisions, academic outcomes, reputational damage, or opportunity loss resulting from a detection result.")
                            Text("• Truely does not make definitive claims of dishonesty—it provides signal-based assessments to assist human reviewers.")
                        }
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                    }
                    
                    // Data Retention & Privacy
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.purple)
                                .font(.system(size: 14, weight: .semibold))
                            Text("Data Retention & Privacy")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• Pro plan: All captured screenshots and videos are automatically uploaded to secure cloud servers and may be retained indefinitely.")
                            Text("• Pro plan: Evidence may be shared with meeting hosts, compliance officers, or legal authorities as required by applicable regulations or policies.")
                            Text("• Pro plan: You acknowledge that cloud storage involves third-party services and consent to data transmission and storage outside your local jurisdiction.")
                            Text("• Pro plan: Truely implements industry-standard security measures, but cannot guarantee absolute security of transmitted or stored data.")
                            Text("• Pro plan: You have no expectation of privacy regarding screen content captured during monitoring sessions.")
                            Text("• Free plan: No evidence collection or cloud storage.")
                        }
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                    }
                    
                    // Liability & Disclaimer
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.red)
                                .font(.system(size: 14, weight: .semibold))
                            Text("Liability & Disclaimer")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• No warranty is provided. Truely is offered \"as is\" without any guarantee of uninterrupted functionality, security, or accuracy.")
                            Text("• In no event shall Truely, its developers, maintainers, or affiliates be liable for incidental, indirect, punitive, or consequential damages.")
                            Text("• You waive and release any and all claims related to data usage, system impact, or outcomes resulting from the use of Truely.")
                            Text("• You acknowledge that captured screenshots and videos may contain sensitive or personal information and consent to their storage and processing.")
                            Text("• You understand that evidence may be retained for compliance, verification, or legal purposes as required by the meeting host or applicable regulations.")
                        }
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                    }
                    
                    // Final Acknowledgement
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                                .font(.system(size: 14, weight: .semibold))
                            Text("Final Acknowledgement")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("By clicking \"Accept and Continue\", you:")
                            Text("• Confirm that you understand and accept all monitoring practices described above.")
                            Text("• Grant full consent for Truely to access and analyze system-level signals for the sole purpose of integrity verification.")
                            Text("• Acknowledge that you are the authorized user of this device and have the right to grant these permissions.")
                            Text("• Waive any legal claim against Truely or its affiliates resulting from your use of this software.")
                            Text("• Confirm that you are using this software voluntarily and understand the scope of monitoring.")
                            Text("• Pro plan users: Explicitly consent to screen capture, video recording, and cloud storage.")
                        }
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxHeight: 400)
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: onAccept) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Accept and Continue")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    ContentView(pendingURL: .constant(nil))
}

