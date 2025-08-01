import Foundation
import AppKit
import Combine

class ProcessMonitor: ObservableObject {
    @Published var detectedForbiddenApps: [String] = []
    @Published var suspiciousProcesses: [SuspiciousProcessResult] = []
    @Published var advancedDetectionResults: [AdvancedDetectionResult] = []
    @Published var networkDetections: [NetworkDetectionResult] = []
    
    private var forbiddenAppNames: [String] = []
    private var basicMonitoringTimer: Timer?
    private var advancedMonitoringTimer: Timer?
    private var isActive = false
    private var suspiciousDetector = SuspiciousProcessDetector()
    private var networkMonitor = NetworkMonitor()
    private var cancellables = Set<AnyCancellable>()
    private var planType: PlanType = .free
    
    func configure(forbiddenApps: [String], planType: PlanType = .free) {
        self.forbiddenAppNames = forbiddenApps
        self.planType = planType
        print("🔧 ProcessMonitor configured for \(planType.displayName) plan")
    }
    
    func configureSuspiciousProcesses(processNames: [String], paths: [String], hashes: [String]) {
        suspiciousDetector.configure(processNames: processNames, paths: paths, hashes: hashes)
    }
    
    func enableAdvancedDetection(windowThreshold: Int = 3, screenEvasionThreshold: Int = 2) {
        suspiciousDetector.configureAdvancedDetection(enabled: true, windowThreshold: windowThreshold, screenEvasionThreshold: screenEvasionThreshold)
    }
    
    func startMonitoring() {
        guard !isActive else { return }
        isActive = true
        
        // Basic detection every 2 seconds (both plans)
        basicMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            DispatchQueue.global(qos: .userInitiated).async {
                self.checkBasicForbiddenApps()
            }
        }
        
        // Advanced features only for PRO plan
        if planType == .pro {
            // Slower advanced detection every 30 seconds
            advancedMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
                DispatchQueue.global(qos: .utility).async {
                    self.checkAdvancedSuspiciousProcesses()
                }
            }
            
            // Start network monitoring
            networkMonitor.startNetworkMonitoring()
            
            // Setup network detection binding
            networkMonitor.$networkDetections
                .receive(on: DispatchQueue.main)
                .assign(to: \.networkDetections, on: self)
                .store(in: &cancellables)
            
            print("✅ Pro plan: Advanced detection and network monitoring enabled")
        } else {
            print("✅ Free plan: Basic process monitoring only")
        }
        
        // Run basic check immediately on start
        DispatchQueue.global(qos: .userInitiated).async {
            self.checkBasicForbiddenApps()
        }
        
        // Run advanced check immediately if PRO plan
        if planType == .pro {
            DispatchQueue.global(qos: .utility).async {
                self.checkAdvancedSuspiciousProcesses()
            }
        }
    }
    
    func stopMonitoring() {
        isActive = false
        basicMonitoringTimer?.invalidate()
        advancedMonitoringTimer?.invalidate()
        basicMonitoringTimer = nil
        advancedMonitoringTimer = nil
        
        // Stop network monitoring
        networkMonitor.stopNetworkMonitoring()
        cancellables.removeAll()
        
        detectedForbiddenApps.removeAll()
        networkDetections.removeAll()
    }
    
    // MARK: - Public Access to Internal Services
    
    var getNetworkMonitor: NetworkMonitor {
        return networkMonitor
    }
    
    var getSuspiciousDetector: SuspiciousProcessDetector {
        return suspiciousDetector
    }
    
    var isMonitoringActive: Bool {
        return isActive
    }
    
    private func checkBasicForbiddenApps() {
        var detected: [String] = []
        
        // Check forbidden apps (existing functionality)
        var processes: UnsafeMutablePointer<SystemProcessInfo>?
        let processCount = getAllProcesses(&processes)
        
        if processCount > 0, let processArray = processes {
            for i in 0..<Int(processCount) {
                let process = processArray[i]
                let processName = withUnsafeBytes(of: process.name) { bytes in
                    String(cString: bytes.bindMemory(to: CChar.self).baseAddress!)
                }
                let processPath = withUnsafeBytes(of: process.path) { bytes in
                    String(cString: bytes.bindMemory(to: CChar.self).baseAddress!)
                }
                let pid = process.pid
                
                // Check against forbidden app names
                for forbiddenName in forbiddenAppNames {
                    let forbiddenLower = forbiddenName.lowercased()
                    
                    // Check process name
                    if processName.lowercased().contains(forbiddenLower) {
                        detected.append("\(processName) (PID: \(pid))")
                        continue
                    }
                    
                    // Check process path
                    if !processPath.isEmpty && processPath.lowercased().contains(forbiddenLower) {
                        detected.append("\(processName) (Path: \(processPath))")
                        continue
                    }
                    
                    // Check if path contains app bundle
                    if processPath.lowercased().contains("/\(forbiddenLower).app/") {
                        detected.append("\(processName) (App: \(forbiddenName))")
                    }
                }
            }
            
            // Free the allocated memory
            freeProcessList(processArray)
        }
        
        // Also check NSWorkspace for GUI applications
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            guard let appName = app.localizedName else { continue }
            
            for forbiddenName in forbiddenAppNames {
                if appName.lowercased().contains(forbiddenName.lowercased()) {
                    let entry = "\(appName) (GUI App - PID: \(app.processIdentifier))"
                    if !detected.contains(entry) {
                        detected.append(entry)
                    }
                }
            }
            
            // Check bundle identifier
            if let bundleId = app.bundleIdentifier {
                for forbiddenName in forbiddenAppNames {
                    if bundleId.lowercased().contains(forbiddenName.lowercased()) {
                        let entry = "\(appName) (Bundle: \(bundleId))"
                        if !detected.contains(entry) {
                            detected.append(entry)
                        }
                    }
                }
            }
        }
        
        // Debug logging
        if !detected.isEmpty {
            print("📋 FORBIDDEN APPS DETECTED: \(detected)")
        }
        
        // Log any active LLM network connections alongside forbidden apps
        logActiveNetworkConnections()
        
        DispatchQueue.main.async {
            if detected != self.detectedForbiddenApps {
                self.detectedForbiddenApps = Array(Set(detected))
            }
        }
    }
    
    private func checkAdvancedSuspiciousProcesses() {
        // Check for suspicious processes (legacy functionality)
        let (suspiciousResults, newAlertedPids) = suspiciousDetector.detectSuspiciousProcesses()
        suspiciousDetector.updateLastAlertedPids(newAlertedPids)
        
        // Check for advanced suspicious processes (new functionality)
        let advancedResults = suspiciousDetector.detectAdvancedSuspiciousProcesses()
        
        DispatchQueue.main.async {
            if suspiciousResults != self.suspiciousProcesses {
                self.suspiciousProcesses = suspiciousResults
            }
            
            if advancedResults != self.advancedDetectionResults {
                self.advancedDetectionResults = advancedResults
            }
        }
    }
    
    private func logActiveNetworkConnections() {
        // Only log if we have active LLM connections
        let activeLLMConnections = networkDetections.filter { $0.confidence == .definitive }
        let suspiciousAIConnections = networkDetections.filter { $0.confidence == .suspicious }
        
        if !activeLLMConnections.isEmpty || !suspiciousAIConnections.isEmpty {
            print("🌐 NETWORK LLM ACTIVITY DETECTED:")
            
            if !activeLLMConnections.isEmpty {
                print("🌐   DEFINITIVE LLM APIs (\(activeLLMConnections.count)):")
                for connection in activeLLMConnections.prefix(3) {
                    print("🌐     • \(connection.processName) (PID: \(connection.pid)) → \(connection.destinationDomain)")
                }
                if activeLLMConnections.count > 3 {
                    print("🌐     • ... and \(activeLLMConnections.count - 3) more")
                }
            }
            
            if !suspiciousAIConnections.isEmpty {
                print("🌐   SUSPICIOUS AI-RELATED (\(suspiciousAIConnections.count)):")
                for connection in suspiciousAIConnections.prefix(2) {
                    print("🌐     • \(connection.processName) (PID: \(connection.pid)) → \(connection.destinationDomain)")
                }
                if suspiciousAIConnections.count > 2 {
                    print("🌐     • ... and \(suspiciousAIConnections.count - 2) more")
                }
            }
        }
    }
}