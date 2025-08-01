import SwiftUI
import AppKit
import AVFoundation

func makeWindowTransparent() {
    DispatchQueue.main.async {
        if let window = NSApplication.shared.windows.first {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.titled)
            window.styleMask.insert(.fullSizeContentView)
            // Do NOT hide the standard window buttons
            // Do NOT set custom corner radius or masksToBounds
        }
    }
}

func setInitialWindowSize() {
    DispatchQueue.main.async {
        if let window = NSApplication.shared.windows.first {
            let initialSize = NSSize(width: 450, height: 550)
            window.setContentSize(initialSize)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var pendingURL: URL?
    
    func application(_ application: NSApplication, open urls: [URL]) {
        print("🔗 AppDelegate: application open urls called with: \(urls)")
        if let url = urls.first {
            pendingURL = url
            // Store URL in UserDefaults for persistence
            UserDefaults.standard.set(url.absoluteString, forKey: "PendingURL")
            // Post notification to ContentView
            NotificationCenter.default.post(name: NSNotification.Name("URLReceived"), object: url)
            
            // Bring app to front and show window
            DispatchQueue.main.async {
                NSApplication.shared.activate(ignoringOtherApps: true)
                // Show all windows and bring them to front
                for window in NSApplication.shared.windows {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
    
    func application(_ application: NSApplication, openFile filename: String) -> Bool {
        print("🔗 AppDelegate: application openFile called with: \(filename)")
        return false
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🔗 AppDelegate: applicationDidFinishLaunching")
        
        // Check launch arguments for URL
        let arguments = ProcessInfo.processInfo.arguments
        print("🔗 AppDelegate: Launch arguments: \(arguments)")
        
        for argument in arguments {
            if argument.hasPrefix("truely://") {
                if let url = URL(string: argument) {
                    print("🔗 AppDelegate: Found URL in launch arguments: \(url)")
                    // Store URL in UserDefaults and wait for ContentView to be ready
                    UserDefaults.standard.set(url.absoluteString, forKey: "PendingURL")
                    
                    // Bring app to front after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        // Show all windows and bring them to front
                        for window in NSApplication.shared.windows {
                            window.makeKeyAndOrderFront(nil)
                        }
                    }
                    return
                }
            }
        }
        
        // Check if app was launched with a URL
        if let url = pendingURL {
            print("🔗 AppDelegate: Processing pending URL from launch: \(url)")
            UserDefaults.standard.set(url.absoluteString, forKey: "PendingURL")
            
            // Bring app to front after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                // Show all windows and bring them to front
                for window in NSApplication.shared.windows {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
}

@main
struct TruelyApp: App {
    @State private var isTerminating = false
    @State private var pendingURL: URL?
    @State private var contentViewRef: ContentView?
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView(pendingURL: $pendingURL)
                .onAppear {
                    print("🔗 TruelyApp: WindowGroup onAppear, pendingURL: \(pendingURL?.absoluteString ?? "nil")")
                }
                .background(WindowAccessor(onWindowClose: handleAppTermination))
                .onAppear {
                    makeWindowTransparent()
                    setInitialWindowSize()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ContentViewReady"))) { notification in
                    if let contentView = notification.object as? ContentView {
                        contentViewRef = contentView
                    }
                }
                .onOpenURL { url in
                    print("🔗 TruelyApp: onOpenURL called with: \(url)")
                    handleIncomingURL(url)
                }
        }
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Truely") {
                    handleAppTermination()
                }
                .keyboardShortcut("q")
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
    
    private func handleIncomingURL(_ url: URL) {
        print("🔗 TruelyApp: Received URL: \(url)")
        // Store the URL to be processed when ContentView is ready
        pendingURL = url
        
        // Also try to bring the app to front
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    private func handleAppTermination() {
        guard !isTerminating else { return }
        isTerminating = true
        
        // Perform cleanup if monitoring is active
        if let contentView = contentViewRef {
            contentView.performMonitoringCleanup(showUI: true) {
                // Cleanup completed, now terminate the app
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            }
        } else {
            // If no ContentView reference, quit immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

// Helper to access the window and set up close handling
struct WindowAccessor: NSViewRepresentable {
    let onWindowClose: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = WindowAccessorView()
        view.onWindowClose = onWindowClose
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class WindowAccessorView: NSView {
    var onWindowClose: (() -> Void)?
    private var windowDelegate: WindowDelegate?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if let window = self.window, windowDelegate == nil {
            windowDelegate = WindowDelegate(onClose: onWindowClose ?? {})
            window.delegate = windowDelegate
        }
    }
}

class WindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    private var isClosing = false
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if isClosing {
            return true // Allow close if we're already in the closing process
        }
        
        isClosing = true
        onClose()
        return false // Prevent immediate close, let our handler manage it
    }
}
