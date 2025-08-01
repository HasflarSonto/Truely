import Foundation
import AppKit
import Combine

enum DetectionConfidence {
    case definitive    // Red - 100% sure (current methods)
    case suspicious    // Yellow - potentially suspicious (new methods)
    case clean         // Green - no issues
    
    var description: String {
        switch self {
        case .definitive: return "DEFINITIVE"
        case .suspicious: return "SUSPICIOUS"
        case .clean: return "CLEAN"
        }
    }
}

struct AdvancedDetectionResult: Equatable {
    let confidence: DetectionConfidence
    let type: DetectionType
    let processName: String
    let processPath: String
    let pid: pid_t
    let message: String
    let evidence: [String]  // Supporting evidence for the detection
    
    enum DetectionType: Equatable {
        case name
        case path
        case hash
        case windowProperty      // NEW
        case screenEvasion       // NEW
        case elevatedLayer       // NEW
        case behavioralPattern   // NEW
        
        var description: String {
            switch self {
            case .name: return "name"
            case .path: return "path"
            case .hash: return "hash"
            case .windowProperty: return "window_property"
            case .screenEvasion: return "screen_evasion"
            case .elevatedLayer: return "elevated_layer"
            case .behavioralPattern: return "behavioral_pattern"
            }
        }
    }
}

struct SuspiciousProcessResult: Equatable {
    let type: DetectionType
    let processName: String
    let processPath: String
    let pid: pid_t
    let message: String
    
    enum DetectionType: Equatable {
        case name
        case path
        case hash
    }
}

class SuspiciousProcessDetector: ObservableObject {
    @Published var suspiciousProcesses: [SuspiciousProcessResult] = []
    @Published var advancedDetectionResults: [AdvancedDetectionResult] = []
    
    private var suspiciousProcessNames: Set<String> = []
    private var suspiciousPaths: Set<String> = []
    private var suspiciousHashes: Set<String> = []
    private var lastAlertedPids: Set<pid_t> = []
    
    // Advanced detection settings
    private var enableAdvancedDetection: Bool = false
    private var windowPropertyThreshold: Int = 3
    private var screenEvasionThreshold: Int = 2
    
    func configure(processNames: [String], paths: [String], hashes: [String]) {
        self.suspiciousProcessNames = Set(processNames.map { $0.lowercased() })
        self.suspiciousPaths = Set(paths)
        self.suspiciousHashes = Set(hashes.map { $0.lowercased() })
    }
    
    func configureAdvancedDetection(enabled: Bool, windowThreshold: Int = 3, screenEvasionThreshold: Int = 2) {
        self.enableAdvancedDetection = enabled
        self.windowPropertyThreshold = windowThreshold
        self.screenEvasionThreshold = screenEvasionThreshold
    }
    
    func detectSuspiciousProcesses() -> ([SuspiciousProcessResult], Set<pid_t>) {
        var suspicious: [SuspiciousProcessResult] = []
        var newAlertedPids: Set<pid_t> = []
        
        // Get all system processes using C bridge
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
                
                // Check name
                if checkProcessName(processName, pid: pid, suspicious: &suspicious) {
                    newAlertedPids.insert(pid)
                }
                
                // Check path
                if !processPath.isEmpty && checkProcessPath(processPath, processName: processName, pid: pid, suspicious: &suspicious) {
                    newAlertedPids.insert(pid)
                }
                
                // Check hash
                if !processPath.isEmpty && checkProcessHash(processPath, processName: processName, pid: pid, suspicious: &suspicious) {
                    newAlertedPids.insert(pid)
                }
            }
            
            // Free the allocated memory
            freeProcessList(processArray)
        }
        
        // Also check NSWorkspace for GUI applications
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            guard let appName = app.localizedName else { continue }
            let pid = app.processIdentifier
            
            // Check name
            if checkProcessName(appName, pid: pid, suspicious: &suspicious) {
                newAlertedPids.insert(pid)
            }
            
            // Check bundle path if available
            if let bundlePath = app.bundleURL?.path {
                if checkProcessPath(bundlePath, processName: appName, pid: pid, suspicious: &suspicious) {
                    newAlertedPids.insert(pid)
                }
                
                if checkProcessHash(bundlePath, processName: appName, pid: pid, suspicious: &suspicious) {
                    newAlertedPids.insert(pid)
                }
            }
        }
        
        return (suspicious, newAlertedPids)
    }
    
    func detectAdvancedSuspiciousProcesses() -> [AdvancedDetectionResult] {
        guard enableAdvancedDetection else { 
            return [] 
        }
        
        let startTime = Date()
        var advancedResults: [AdvancedDetectionResult] = []
        var processScores: [(String, Int, pid_t)] = [] // (processName, score, pid)
        
        // Get all system processes using C bridge
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
                
                // FAST FILTERING: Skip obviously system processes early
                if shouldSkipProcess(processName: processName, processPath: processPath) {
                    continue
                }
                
                let beforeCount = advancedResults.count
                
                // Fast name check first (no expensive window operations)
                let hasSuspiciousName = checkSuspiciousName(processName)
                if hasSuspiciousName {
                    // For suspicious names, do full analysis
                    _ = checkProcessNameAdvanced(processName, pid: pid, results: &advancedResults)
                    if !processPath.isEmpty {
                        _ = checkProcessPathAdvanced(processPath, processName: processName, pid: pid, results: &advancedResults)
                        _ = checkProcessHashAdvanced(processPath, processName: processName, pid: pid, results: &advancedResults)
                    }
                    
                    // Full window analysis for suspicious names
                    checkWindowProperties(pid: pid, processName: processName, processPath: processPath, results: &advancedResults)
                    checkScreenEvasion(pid: pid, processName: processName, processPath: processPath, results: &advancedResults)
                    checkElevatedLayers(pid: pid, processName: processName, processPath: processPath, results: &advancedResults)
                } else {
                    // For non-suspicious names, only do lightweight checks
                    _ = checkProcessNameAdvanced(processName, pid: pid, results: &advancedResults)
                    if !processPath.isEmpty {
                        _ = checkProcessPathAdvanced(processPath, processName: processName, pid: pid, results: &advancedResults)
                        // Skip hash checking for performance unless suspicious name
                    }
                    
                    // Only basic window property check using pre-computed data
                    checkWindowPropertiesLightweight(process: process, processName: processName, processPath: processPath, results: &advancedResults)
                }
                
                // Calculate total score for this process
                if advancedResults.count > beforeCount {
                    let processResults = Array(advancedResults[beforeCount...])
                    let totalScore = calculateProcessScore(processName: processName, results: processResults)
                    processScores.append((processName, totalScore, pid))
                }
            }
            
            freeProcessList(processArray)
        }
        
        let scanTime = Date().timeIntervalSince(startTime)
        print("📋 Advanced detection scan completed in \(String(format: "%.2f", scanTime))s - Found \(advancedResults.count) detections")
        
        // Show top 10 highest scoring processes
        let topProcesses = processScores.sorted { $0.1 > $1.1 }.prefix(10)
        print("📋 TOP 10 HIGHEST SUSPICION SCORES:")
        for (index, (processName, score, pid)) in topProcesses.enumerated() {
            print("📋 \(index + 1). \(processName) (PID: \(pid)) - Score: \(score)")
        }
        
        return advancedResults
    }
    
    private func calculateProcessScore(processName: String, results: [AdvancedDetectionResult]) -> Int {
        var totalScore = 0
        
        // Base scoring from evidence
        for result in results {
            totalScore += result.evidence.count * 2
        }
        
        // Bonus for suspicious names
        let suspiciousNames = ["cluely", "cheat", "hack", "overlay", "inject", "bot", "auto", "trainer", "mod"]
        let lowerName = processName.lowercased()
        for suspiciousName in suspiciousNames {
            if lowerName.contains(suspiciousName) {
                totalScore += 5
                break
            }
        }
        
        return totalScore
    }
    
    private func shouldSkipProcess(processName: String, processPath: String) -> Bool {
        // Only skip the most basic kernel/system processes
        let coreSystemProcesses = ["kernel_task", "launchd"]
        
        for systemProcess in coreSystemProcesses {
            if processName == systemProcess {  // Exact match only
                return true
            }
        }
        
        return false
    }
    
    private func checkSuspiciousName(_ processName: String) -> Bool {
        let suspiciousNames = ["cluely", "cheat", "hack", "overlay", "inject", "bot", "auto", "trainer", "mod"]
        let lowerName = processName.lowercased()
        return suspiciousNames.contains { lowerName.contains($0) }
    }
    
    private func checkWindowPropertiesLightweight(process: SystemProcessInfo, processName: String, processPath: String, results: inout [AdvancedDetectionResult]) {
        var suspiciousEvidence: [String] = []
        var suspiciousScore = 0
        
        // Use pre-computed values (much faster than window enumeration)
        if process.windowCount == 0 {
            suspiciousEvidence.append("Completely hidden - no visible windows")
            suspiciousScore += 3
        }
        
        if process.suspiciousWindowCount > 0 {
            suspiciousEvidence.append("Suspicious window patterns detected")
            suspiciousScore += 2
        }
        
        if process.screenEvasionCount > 0 {
            suspiciousEvidence.append("Screen evasion detected")
            suspiciousScore += 1
        }
        
        if process.elevatedLayerCount > 0 {
            suspiciousEvidence.append("Elevated layer usage")
            suspiciousScore += 1
        }
        
        // Lower threshold for lightweight detection
        if suspiciousScore >= 3 && !suspiciousEvidence.isEmpty {
            let detectionResult = AdvancedDetectionResult(
                confidence: .suspicious,
                type: .windowProperty,
                processName: processName,
                processPath: processPath,
                pid: process.pid,
                message: "[SUSPICIOUS] Lightweight stealth detection: \(processName) (PID: \(process.pid))",
                evidence: suspiciousEvidence
            )
            results.append(detectionResult)
        }
    }
    
    private func checkProcessName(_ processName: String, pid: pid_t, suspicious: inout [SuspiciousProcessResult]) -> Bool {
        let lowerName = processName.lowercased()
        
        for suspiciousName in suspiciousProcessNames {
            if lowerName.contains(suspiciousName) {
                let result = SuspiciousProcessResult(
                    type: .name,
                    processName: processName,
                    processPath: "",
                    pid: pid,
                    message: "[NAME] \(processName) (PID: \(pid))"
                )
                suspicious.append(result)
                return true
            }
        }
        return false
    }
    
    private func checkProcessPath(_ processPath: String, processName: String, pid: pid_t, suspicious: inout [SuspiciousProcessResult]) -> Bool {
        if suspiciousPaths.contains(processPath) {
            let result = SuspiciousProcessResult(
                type: .path,
                processName: processName,
                processPath: processPath,
                pid: pid,
                message: "[PATH] \(processPath) (PID: \(pid))"
            )
            suspicious.append(result)
            return true
        }
        return false
    }
    
    private func checkProcessHash(_ processPath: String, processName: String, pid: pid_t, suspicious: inout [SuspiciousProcessResult]) -> Bool {
        // Only check files that exist
        guard FileManager.default.fileExists(atPath: processPath) else { return false }
        
        // Calculate SHA256 hash using C function
        let hashBufferSize = 65 // 64 chars + null terminator
        let hashBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: hashBufferSize)
        defer { hashBuffer.deallocate() }
        
        let result = calculateFileSHA256(processPath, hashBuffer, hashBufferSize)
        guard result == 0 else { return false }
        
        let fileHash = String(cString: hashBuffer).lowercased()
        
        if suspiciousHashes.contains(fileHash) {
            let suspiciousResult = SuspiciousProcessResult(
                type: .hash,
                processName: processName,
                processPath: processPath,
                pid: pid,
                message: "[HASH] \(processPath) (PID: \(pid))"
            )
            suspicious.append(suspiciousResult)
            return true
        }
        
        return false
    }
    
    func updateLastAlertedPids(_ pids: Set<pid_t>) {
        lastAlertedPids = pids
    }
    
    func getLastAlertedPids() -> Set<pid_t> {
        return lastAlertedPids
    }
    
    // MARK: - Advanced Detection Methods
    
    private func checkProcessNameAdvanced(_ processName: String, pid: pid_t, results: inout [AdvancedDetectionResult]) -> Bool {
        let lowerName = processName.lowercased()
        
        for suspiciousName in suspiciousProcessNames {
            if lowerName.contains(suspiciousName) {
                let result = AdvancedDetectionResult(
                    confidence: .definitive,
                    type: .name,
                    processName: processName,
                    processPath: "",
                    pid: pid,
                    message: "[DEFINITIVE] Process name match: \(processName) (PID: \(pid))",
                    evidence: ["Process name contains '\(suspiciousName)'"]
                )
                results.append(result)
                return true
            }
        }
        return false
    }
    
    private func checkProcessPathAdvanced(_ processPath: String, processName: String, pid: pid_t, results: inout [AdvancedDetectionResult]) -> Bool {
        if suspiciousPaths.contains(processPath) {
            let result = AdvancedDetectionResult(
                confidence: .definitive,
                type: .path,
                processName: processName,
                processPath: processPath,
                pid: pid,
                message: "[DEFINITIVE] Path match: \(processPath) (PID: \(pid))",
                evidence: ["Process path exactly matches known suspicious path"]
            )
            results.append(result)
            return true
        }
        return false
    }
    
    private func checkProcessHashAdvanced(_ processPath: String, processName: String, pid: pid_t, results: inout [AdvancedDetectionResult]) -> Bool {
        guard FileManager.default.fileExists(atPath: processPath) else { return false }
        
        let hashBufferSize = 65
        let hashBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: hashBufferSize)
        defer { hashBuffer.deallocate() }
        
        let result = calculateFileSHA256(processPath, hashBuffer, hashBufferSize)
        guard result == 0 else { return false }
        
        let fileHash = String(cString: hashBuffer).lowercased()
        
        if suspiciousHashes.contains(fileHash) {
            let advancedResult = AdvancedDetectionResult(
                confidence: .definitive,
                type: .hash,
                processName: processName,
                processPath: processPath,
                pid: pid,
                message: "[DEFINITIVE] Hash match: \(processPath) (PID: \(pid))",
                evidence: ["File hash matches known suspicious binary: \(fileHash)"]
            )
            results.append(advancedResult)
            return true
        }
        
        return false
    }
    
    private func checkWindowProperties(pid: pid_t, processName: String, processPath: String, results: inout [AdvancedDetectionResult]) {
        // Only skip truly system-critical processes
        let systemCritical = ["kernel_task", "launchd", "WindowServer"]
        for critical in systemCritical {
            if processName.contains(critical) {
                return
            }
        }
        
        var properties = WindowProperties()
        let result = getWindowProperties(pid, &properties)
        
        guard result == 0 else { return }
        
        var suspiciousEvidence: [String] = []
        var suspiciousScore = 0
        
        // 1. STEALTH DETECTION - Apps trying to be invisible
        if properties.windowCount == 0 {
            suspiciousEvidence.append("Completely hidden - no visible windows")
            suspiciousScore += 3
        }
        
        if properties.windowCount == 1 && properties.sharingStateDisabled > 0 {
            suspiciousEvidence.append("Single hidden window detected")
            suspiciousScore += 2
        }
        
        // 2. BEHAVIORAL FINGERPRINTING - Classic evasion combo
        if properties.windowCount <= 3 && properties.sharingStateDisabled > 0 && properties.elevatedLayers > 0 {
            suspiciousEvidence.append("Classic evasion pattern: few windows with hiding techniques")
            suspiciousScore += 4
        }
        
        // 3. NAME-BASED HEURISTICS - Suspicious process names
        let suspiciousNames = ["cluely", "cheat", "hack", "overlay", "inject", "bot", "auto", "trainer", "mod"]
        let lowerName = processName.lowercased()
        for suspiciousName in suspiciousNames {
            if lowerName.contains(suspiciousName) {
                suspiciousEvidence.append("Suspicious process name contains '\(suspiciousName)'")
                suspiciousScore += 5
                break
            }
        }
        
        // 4. RATIO ANALYSIS - High evasion-to-window ratio
        let evasionRatio = Double(properties.sharingStateDisabled) / Double(max(properties.windowCount, 1))
        if evasionRatio >= 0.5 && properties.windowCount <= 5 {
            suspiciousEvidence.append("High evasion ratio: \(String(format: "%.1f", evasionRatio)) with low window count")
            suspiciousScore += 3
        }
        
        // 5. STEALTH ELEVATED LAYERS - Small footprint with elevation
        if properties.windowCount <= 2 && properties.elevatedLayers > 0 {
            suspiciousEvidence.append("Minimal windows but using elevated layers")
            suspiciousScore += 2
        }
        
        // 6. STILL CHECK FOR EXCESSIVE BEHAVIOR (but lower priority)
        if properties.windowCount > 20 {
            suspiciousEvidence.append("Excessive window count: \(properties.windowCount)")
            suspiciousScore += 1
        }
        
        // Trigger detection with lower threshold but smarter scoring
        if suspiciousScore >= 3 && !suspiciousEvidence.isEmpty {
            let detectionResult = AdvancedDetectionResult(
                confidence: .suspicious,
                type: .windowProperty,
                processName: processName,
                processPath: processPath,
                pid: pid,
                message: "[SUSPICIOUS] Stealth behavior detected: \(processName) (PID: \(pid))",
                evidence: suspiciousEvidence
            )
            results.append(detectionResult)
        }
    }
    
    private func checkScreenEvasion(pid: pid_t, processName: String, processPath: String, results: inout [AdvancedDetectionResult]) {
        let evasionCount = detectScreenEvasion(pid)
        
        // Skip if no evasion detected
        if evasionCount == 0 {
            return
        }
        
        var suspiciousScore = 0
        var suspiciousEvidence: [String] = []
        
        // Check for suspicious name patterns first
        let suspiciousNames = ["cluely", "cheat", "hack", "overlay", "inject", "bot", "auto", "trainer", "mod"]
        let lowerName = processName.lowercased()
        let hasSuspiciousName = suspiciousNames.contains { lowerName.contains($0) }
        
        if hasSuspiciousName {
            // Any evasion from suspicious-named process is highly suspicious
            suspiciousScore += 5
            suspiciousEvidence.append("Suspicious process name with screen evasion: \(evasionCount)")
        } else {
            // For legitimate-sounding names, require more evasion or check patterns
            if evasionCount >= 15 {
                // Very high evasion even for legitimate apps
                suspiciousScore += 3
                suspiciousEvidence.append("Excessive screen evasion techniques: \(evasionCount)")
            } else if evasionCount >= 5 && !processPath.contains("/Applications/") {
                // Moderate evasion from non-standard location
                suspiciousScore += 2
                suspiciousEvidence.append("Screen evasion from non-standard location: \(evasionCount)")
            }
        }
        
        if suspiciousScore >= 2 && !suspiciousEvidence.isEmpty {
            let detectionResult = AdvancedDetectionResult(
                confidence: .suspicious,
                type: .screenEvasion,
                processName: processName,
                processPath: processPath,
                pid: pid,
                message: "[SUSPICIOUS] Screen evasion detected: \(processName) (PID: \(pid))",
                evidence: suspiciousEvidence + ["Process path: \(processPath)"]
            )
            results.append(detectionResult)
        }
    }
    
    private func checkElevatedLayers(pid: pid_t, processName: String, processPath: String, results: inout [AdvancedDetectionResult]) {
        let elevatedCount = detectElevatedLayers(pid)
        
        if elevatedCount == 0 {
            return
        }
        
        var suspiciousScore = 0
        var suspiciousEvidence: [String] = []
        
        // Check for suspicious name patterns first
        let suspiciousNames = ["cluely", "cheat", "hack", "overlay", "inject", "bot", "auto", "trainer", "mod"]
        let lowerName = processName.lowercased()
        let hasSuspiciousName = suspiciousNames.contains { lowerName.contains($0) }
        
        if hasSuspiciousName {
            // Any elevated layers from suspicious-named process
            suspiciousScore += 4
            suspiciousEvidence.append("Suspicious process using elevated layers: \(elevatedCount)")
        } else {
            // For other processes, look for patterns
            if elevatedCount >= 10 {
                // Very high elevated layer usage
                suspiciousScore += 2
                suspiciousEvidence.append("Excessive elevated layer usage: \(elevatedCount)")
            } else if elevatedCount >= 3 && !processPath.contains("/Applications/") && !processPath.contains("/System/") {
                // Moderate elevated layers from unusual location
                suspiciousScore += 2
                suspiciousEvidence.append("Elevated layers from non-standard location: \(elevatedCount)")
            }
        }
        
        if suspiciousScore >= 2 && !suspiciousEvidence.isEmpty {
            let detectionResult = AdvancedDetectionResult(
                confidence: .suspicious,
                type: .elevatedLayer,
                processName: processName,
                processPath: processPath,
                pid: pid,
                message: "[SUSPICIOUS] Elevated layer usage: \(processName) (PID: \(pid))",
                evidence: suspiciousEvidence + ["Process path: \(processPath)"]
            )
            results.append(detectionResult)
        }
    }
}