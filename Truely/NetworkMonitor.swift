import Foundation
import Network
import AppKit
import Combine
import Darwin

struct NetworkDetectionResult: Equatable {
    let timestamp: Date
    let processName: String
    let processPath: String
    let pid: pid_t
    let destinationDomain: String
    let destinationPort: Int
    let connectionProtocol: String
    let confidence: DetectionConfidence
    let message: String
    let evidence: [String]
    
    enum DetectionConfidence {
        case definitive    // Known LLM API endpoints
        case suspicious    // AI/ML related domains
        case informational // General network activity
        
        var description: String {
            switch self {
            case .definitive: return "DEFINITIVE"
            case .suspicious: return "SUSPICIOUS" 
            case .informational: return "INFO"
            }
        }
    }
}

class NetworkMonitor: ObservableObject {
    @Published var networkDetections: [NetworkDetectionResult] = []
    
    private var isActive = false
    private var networkMonitoringTimer: Timer?
    private var lastDetectionLog = Date()
    private let logInterval: TimeInterval = 30.0 // Log summary every 30 seconds
    
    // LLM API endpoints to monitor
    private let llmApiDomains = [
        "api.openai.com",
        "api.anthropic.com", 
        "api.cohere.ai",
        "api.together.xyz",
        "api.replicate.com",
        "api.huggingface.co",
        "generativelanguage.googleapis.com", // Google Gemini
        "claude.ai",
        "chat.openai.com",
        "bard.google.com",
        "copilot.microsoft.com",
        "api.mistral.ai",
        "api.groq.com",
        "api.perplexity.ai"
    ]
    
    // AI/ML related domains that might be suspicious
    private let aiRelatedDomains = [
        "openai.com",
        "anthropic.com",
        "huggingface.co",
        "replicate.com",
        "runpod.io",
        "modal.com",
        "kaggle.com",
        "colab.research.google.com"
    ]
    
    func startNetworkMonitoring() {
        guard !isActive else { return }
        isActive = true
        
        print("🌐 Network monitoring started for LLM API detection")
        
        // Monitor network connections every 10 seconds for better capture of short-lived connections
        networkMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            DispatchQueue.global(qos: .utility).async {
                self.checkNetworkConnections()
            }
        }
        
        // Run initial check
        DispatchQueue.global(qos: .utility).async {
            self.checkNetworkConnections()
        }
    }
    
    func stopNetworkMonitoring() {
        isActive = false
        networkMonitoringTimer?.invalidate()
        networkMonitoringTimer = nil
        networkDetections.removeAll()
        print("🌐 Network monitoring stopped")
    }
    
    private func checkNetworkConnections() {
        let startTime = Date()
        var newDetections: [NetworkDetectionResult] = []
        
        // Use lsof to get network connections with process information
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        // Only show ESTABLISHED outbound connections, not listening sockets
        task.arguments = ["-i", "-n", "-P", "-sTCP:ESTABLISHED"]
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errorPipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                newDetections = parseNetworkConnections(output: output)
            }
        } catch {
            // Silently handle errors - network monitoring is supplementary
        }
        
        let scanTime = Date().timeIntervalSince(startTime)
        
        // Update detections on main thread
        DispatchQueue.main.async {
            // Only keep unique detections from the last 5 minutes
            let fiveMinutesAgo = Date().addingTimeInterval(-300)
            self.networkDetections = self.networkDetections.filter { $0.timestamp > fiveMinutesAgo }
            
            // Add new detections
            for detection in newDetections {
                // Avoid duplicates by checking if we already have this process->domain combo recently
                let isDuplicate = self.networkDetections.contains { existing in
                    existing.pid == detection.pid && 
                    existing.destinationDomain == detection.destinationDomain &&
                    existing.timestamp.timeIntervalSince(detection.timestamp) < 60 // Within last minute
                }
                
                if !isDuplicate {
                    self.networkDetections.append(detection)
                }
            }
        }
        
        // Log summary periodically
        if Date().timeIntervalSince(lastDetectionLog) >= logInterval {
            logNetworkDetectionSummary(scanTime: scanTime, newDetections: newDetections)
            lastDetectionLog = Date()
        }
        
        // Only log if we have meaningful detections
        if newDetections.count > 0 {
            print("🌐 Found \(newDetections.count) new outbound connections")
        }
    }
    
    private func parseNetworkConnections(output: String) -> [NetworkDetectionResult] {
        var detections: [NetworkDetectionResult] = []
        let lines = output.components(separatedBy: .newlines)
        var processSummary: [String: [String]] = [:] // [processName: [destinations]]
        
        for line in lines {
            // Skip header line and empty lines
            guard !line.isEmpty && !line.starts(with: "COMMAND") else { continue }
            
            // Parse lsof output: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 9 else { continue }
            
            let processName = components[0]
            guard let pid = pid_t(components[1]) else { continue }
            let connectionInfo = components[8] // This contains the connection details
            
            // Only process outbound connections (contain "->")
            guard connectionInfo.contains("->") else { continue }
            
            if let detection = analyzeConnection(
                processName: processName,
                pid: pid,
                connectionInfo: connectionInfo
            ) {
                detections.append(detection)
                
                // Group by process for cleaner display
                let resolvedHost = resolveIPToDomain(detection.destinationDomain)
                let displayHost = resolvedHost.isEmpty ? detection.destinationDomain : resolvedHost
                let destination = "\(displayHost):\(detection.destinationPort)"
                let processKey = "\(processName) (PID:\(pid))"
                
                if processSummary[processKey] == nil {
                    processSummary[processKey] = []
                }
                if !processSummary[processKey]!.contains(destination) {
                    processSummary[processKey]!.append(destination)
                }
            }
        }
        
        // Show ALL outbound connections (no filtering)
        if !processSummary.isEmpty {
            print("🌐 ALL OUTBOUND CONNECTIONS (\(detections.count) total):")
            
            // First, highlight any potential LLM-related processes
            let llmSuspects = processSummary.filter { (processKey, destinations) in
                let lowerKey = processKey.lowercased()
                let hasLLMProcess = ["chatgpt", "claude", "openai", "anthropic", "electron", "desktop"].contains { lowerKey.contains($0) }
                let hasLLMDestination = destinations.contains { dest in
                    dest.contains("openai.com") || dest.contains("anthropic.com") || dest.contains("claude.ai")
                }
                return hasLLMProcess || hasLLMDestination
            }
            
            if !llmSuspects.isEmpty {
                print("🔍 POTENTIAL LLM/AI PROCESSES:")
                for (processKey, destinations) in llmSuspects.sorted(by: { $0.key < $1.key }) {
                    print("🚨 \(processKey):")
                    for destination in destinations {
                        print("    → \(destination)")
                    }
                }
                print("")
            }
            
            // Then show all processes
            for (processKey, destinations) in processSummary.sorted(by: { $0.key < $1.key }) {
                print("📱 \(processKey):")
                for destination in destinations {
                    print("    → \(destination)")
                }
            }
        } else {
            print("🌐 No outbound connections found")
        }
        
        return detections
    }
    
    private func analyzeConnection(processName: String, pid: pid_t, connectionInfo: String) -> NetworkDetectionResult? {
        // Extract destination from connection info
        // Expected format: "192.168.1.100:54321->142.250.191.78:443" or similar
        var destinationHost = ""
        var destinationPort = 0
        
        if connectionInfo.contains("->") {
            // Format: local->remote (this is what we want for outbound connections)
            let parts = connectionInfo.components(separatedBy: "->")
            if parts.count >= 2 {
                let remote = parts[1].trimmingCharacters(in: .whitespaces)
                
                // Handle IPv6 format [addr]:port or regular addr:port
                if remote.starts(with: "[") {
                    // IPv6 format: [addr]:port
                    if let bracketEnd = remote.firstIndex(of: "]"),
                       let colonIndex = remote.lastIndex(of: ":") {
                        destinationHost = String(remote[remote.index(after: remote.startIndex)..<bracketEnd])
                        let portStr = String(remote[remote.index(after: colonIndex)...])
                        destinationPort = Int(portStr) ?? 0
                    }
                } else {
                    // Regular format: addr:port
                    if let colonIndex = remote.lastIndex(of: ":") {
                        destinationHost = String(remote[..<colonIndex])
                        let portStr = String(remote[remote.index(after: colonIndex)...])
                        destinationPort = Int(portStr) ?? 0
                    }
                }
            }
        }
        
        // Only skip truly empty hosts
        guard !destinationHost.isEmpty else { return nil }
        
        // Try to resolve IP addresses to domain names for better detection
        let resolvedHost = resolveIPToDomain(destinationHost)
        let hostToAnalyze = resolvedHost.isEmpty ? destinationHost : resolvedHost
        
        // Get process path for additional context
        let processPath = getProcessPathString(forPid: pid)
        
        // Analyze if this is an LLM-related connection
        let (confidence, evidence) = analyzeDestination(host: hostToAnalyze, port: destinationPort)
        
        // For debugging: log what we're finding with detailed info
        let suspiciousApps = ["cluely", "chatgpt", "safari", "chrome", "desktop", "electron", "claude", "openai"]
        let shouldLogVerbose = suspiciousApps.contains { processName.lowercased().contains($0) } ||
                              hostToAnalyze.contains("openai.com") || 
                              hostToAnalyze.contains("anthropic.com") ||
                              hostToAnalyze.contains("chat.openai")
        
        if shouldLogVerbose {
            let domainInfo = resolvedHost.isEmpty ? destinationHost : "\(resolvedHost) (IP: \(destinationHost))"
            print("🌐 VERBOSE: \(processName) (PID:\(pid)) → \(domainInfo):\(destinationPort)")
            print("🌐   Confidence: \(confidence.description) | Protocol: \(destinationPort == 443 ? "HTTPS" : "HTTP")")
            if !evidence.isEmpty {
                print("🌐   Evidence: \(evidence.joined(separator: ", "))")
            }
            print("🌐   ---")
        }
        
        // TEMPORARILY: Report all connections to debug what's happening
        // guard confidence != .informational else { return nil }
        
        let timestamp = Date()
        let displayHost = resolvedHost.isEmpty ? destinationHost : "\(resolvedHost) (\(destinationHost))"
        let message = "[\(confidence.description)] \(processName) → \(displayHost):\(destinationPort)"
        
        return NetworkDetectionResult(
            timestamp: timestamp,
            processName: processName,
            processPath: processPath,
            pid: pid,
            destinationDomain: hostToAnalyze,
            destinationPort: destinationPort,
            connectionProtocol: destinationPort == 443 ? "HTTPS" : "HTTP",
            confidence: confidence,
            message: message,
            evidence: evidence
        )
    }
    
    private func analyzeDestination(host: String, port: Int) -> (NetworkDetectionResult.DetectionConfidence, [String]) {
        let lowerHost = host.lowercased()
        var evidence: [String] = []
        
        // Check for definitive LLM API endpoints
        for apiDomain in llmApiDomains {
            if lowerHost.contains(apiDomain.lowercased()) {
                evidence.append("Direct API call to \(apiDomain)")
                evidence.append("Port: \(port) (\(port == 443 ? "HTTPS" : "HTTP"))")
                return (.definitive, evidence)
            }
        }
        
        // Check for AI-related domains
        for aiDomain in aiRelatedDomains {
            if lowerHost.contains(aiDomain.lowercased()) {
                evidence.append("Connection to AI/ML service: \(aiDomain)")
                evidence.append("Port: \(port)")
                return (.suspicious, evidence)
            }
        }
        
        // Check for suspicious patterns in domain names
        let suspiciousKeywords = ["ai", "ml", "gpt", "claude", "llm", "chatbot", "assistant"]
        for keyword in suspiciousKeywords {
            if lowerHost.contains(keyword) {
                evidence.append("Domain contains AI-related keyword: \(keyword)")
                evidence.append("Full domain: \(host)")
                return (.suspicious, evidence)
            }
        }
        
        return (.informational, evidence)
    }
    
    private func resolveIPToDomain(_ ipAddress: String) -> String {
        // Only try to resolve if it looks like an IP address
        guard ipAddress.contains(".") || ipAddress.contains(":") else { return "" }
        guard !ipAddress.contains("localhost") else { return "" }
        
        // Quick check if it's already a domain name
        if ipAddress.contains(".") && !CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: ipAddress.replacingOccurrences(of: ".", with: ""))) {
            return "" // Already a domain name
        }
        
        // Simple reverse DNS lookup
        var addr = inet_addr(ipAddress)
        
        if addr != INADDR_NONE {
            let hostent = gethostbyaddr(&addr, 4, AF_INET)
            if let hostent = hostent, let name = hostent.pointee.h_name {
                let domain = String(cString: name)
                // Only return if it's a meaningful domain (not just reverse IP)
                if !domain.contains(".in-addr.arpa") && domain.contains(".") {
                    return domain
                }
            }
        }
        
        return ""
    }
    
    private func getProcessPathString(forPid pid: pid_t) -> String {
        let pathBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: 4096)
        defer { pathBuffer.deallocate() }
        
        // Call the C bridge function directly
        let result = getProcessPath(pid, pathBuffer, 4096)
        if result > 0 {
            return String(cString: pathBuffer)
        }
        return ""
    }
    
    private func logNetworkDetectionSummary(scanTime: TimeInterval, newDetections: [NetworkDetectionResult]) {
        let definitiveCount = newDetections.filter { $0.confidence == .definitive }.count
        let suspiciousCount = newDetections.filter { $0.confidence == .suspicious }.count
        let totalDetections = networkDetections.count
        
        print("🌐 Network scan completed in \(String(format: "%.2f", scanTime))s - Found \(newDetections.count) new connections (\(totalDetections) total active)")
        
        if definitiveCount > 0 || suspiciousCount > 0 {
            print("🌐 LLM API ACTIVITY DETECTED:")
            print("🌐   DEFINITIVE (LLM APIs): \(definitiveCount)")
            print("🌐   SUSPICIOUS (AI-related): \(suspiciousCount)")
            
            // Show top LLM connections
            let llmConnections = newDetections.filter { $0.confidence == .definitive }
            for (index, detection) in llmConnections.prefix(5).enumerated() {
                print("🌐   \(index + 1). \(detection.processName) (PID: \(detection.pid)) → \(detection.destinationDomain)")
            }
        }
    }
}