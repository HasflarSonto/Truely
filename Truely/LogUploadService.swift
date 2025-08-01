import Foundation
import Combine

class LogUploadService: ObservableObject {
    private let baseURL = "https://api.true-ly.com"
    private var uploadTimer: Timer?
    private var isActive = false
    private var organization: String = "default"
    private var sessionId: String = ""
    private var meetingLink: String = ""
    private var platform: String = "Unknown"
    private var sessionStartTime: Date = Date()
    private var encryptedKey: String = ""
    
    // References to monitoring services
    private var networkMonitor: NetworkMonitor?
    private var processMonitor: ProcessMonitor?
    private var suspiciousDetector: SuspiciousProcessDetector?
    private var sessionFolderName: String?
    
    // Published properties for UI updates
    @Published var lastUploadTime: Date?
    @Published var uploadStatus: UploadStatus = .idle
    @Published var lastUploadError: String?
    
    enum UploadStatus {
        case idle
        case uploading
        case success
        case failed
    }
    
    func configure(organization: String, sessionId: String, meetingLink: String, platform: String, encryptedKey: String) {
        self.organization = organization
        self.sessionId = sessionId
        self.meetingLink = meetingLink
        self.platform = platform
        self.sessionStartTime = Date()
        self.encryptedKey = encryptedKey
    }
    
    func setMonitoringServices(networkMonitor: NetworkMonitor, processMonitor: ProcessMonitor, suspiciousDetector: SuspiciousProcessDetector) {
        self.networkMonitor = networkMonitor
        self.processMonitor = processMonitor
        self.suspiciousDetector = suspiciousDetector
    }
    
    func setSessionFolderName(_ folderName: String) {
        self.sessionFolderName = folderName
        print("📁 LogUploadService: Session folder name set to: \(folderName)")
    }
    
    func startUploadService() {
        guard !isActive else { return }
        isActive = true
        
        print("📤 Log upload service started - uploading every 60 seconds")
        
        // Upload immediately on start
        uploadLogs()
        
        // Set up timer for every 60 seconds
        uploadTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            DispatchQueue.global(qos: .utility).async {
                self.uploadLogs()
            }
        }
    }
    
    func stopUploadService() {
        isActive = false
        uploadTimer?.invalidate()
        uploadTimer = nil
        print("📤 Log upload service stopped")
    }
    
    private func uploadLogs() {
        guard isActive else { return }
        
        DispatchQueue.main.async {
            self.uploadStatus = .uploading
        }
        
        // Collect current log data
        let logData = collectLogData()
        
        // Create JSON file
        guard let jsonData = createJSONFile(logData: logData) else {
            DispatchQueue.main.async {
                self.uploadStatus = .failed
                self.lastUploadError = "Failed to create JSON data"
            }
            return
        }
        
        // Mock upload to S3 (API calls removed)
        uploadToS3Mock(jsonData: jsonData, folderName: sessionFolderName) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.uploadStatus = .success
                    self.lastUploadTime = Date()
                    self.lastUploadError = nil
                    print("📤 Logs uploaded successfully (mock)")
                } else {
                    self.uploadStatus = .failed
                    self.lastUploadError = error ?? "Unknown upload error"
                    print("📤 Log upload failed: \(error ?? "Unknown error")")
                }
            }
        }
    }
    
    private func collectLogData() -> LogUploadRequest {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        // Collect network connections
        let networkConnections = collectNetworkConnections()
        
        // Collect suspicion scores
        let suspicionScores = collectSuspicionScores()
        
        // Collect forbidden apps
        let forbiddenApps = processMonitor?.detectedForbiddenApps ?? []
        
        // Create session info
        let sessionInfo = SessionInfo(
            sessionId: sessionId,
            meetingLink: meetingLink,
            platform: platform,
            startTime: ISO8601DateFormatter().string(from: sessionStartTime),
            monitoringActive: processMonitor?.isMonitoringActive ?? false
        )
        
        return LogUploadRequest(
            timestamp: timestamp,
            organization: organization,
            networkConnections: networkConnections,
            suspicionScores: suspicionScores,
            forbiddenApps: forbiddenApps,
            sessionInfo: sessionInfo
        )
    }
    
    private func collectNetworkConnections() -> [NetworkConnectionLog] {
        guard let networkMonitor = networkMonitor else { return [] }
        
        return networkMonitor.networkDetections.map { detection in
            NetworkConnectionLog(
                processName: detection.processName,
                pid: detection.pid,
                destinationDomain: detection.destinationDomain,
                destinationPort: detection.destinationPort,
                connectionProtocol: detection.connectionProtocol,
                confidence: detection.confidence.description,
                timestamp: ISO8601DateFormatter().string(from: detection.timestamp)
            )
        }
    }
    
    private func collectSuspicionScores() -> [SuspicionScoreLog] {
        guard let suspiciousDetector = suspiciousDetector else { return [] }
        
        // Get advanced detection results and calculate scores
        let advancedResults = suspiciousDetector.advancedDetectionResults
        
        // Group results by process to calculate total scores
        var processScores: [String: (Int, [String], [String])] = [:] // [processName: (score, detectionTypes, evidence)]
        
        for result in advancedResults {
            let processKey = "\(result.processName)_\(result.pid)"
            
            if let existing = processScores[processKey] {
                let newScore = existing.0 + result.evidence.count * 2
                let newTypes = existing.1 + [result.type.description]
                let newEvidence = existing.2 + result.evidence
                processScores[processKey] = (newScore, newTypes, newEvidence)
            } else {
                let score = result.evidence.count * 2
                let types = [result.type.description]
                processScores[processKey] = (score, types, result.evidence)
            }
        }
        
        // Convert to SuspicionScoreLog objects
        return processScores.map { (processKey, data) in
            let components = processKey.components(separatedBy: "_")
            let processName = components.dropLast().joined(separator: "_")
            let pid = Int32(components.last ?? "0") ?? 0
            
            return SuspicionScoreLog(
                processName: processName,
                pid: pid,
                score: data.0,
                detectionTypes: Array(Set(data.1)), // Remove duplicates
                evidence: data.2
            )
        }.sorted { $0.score > $1.score } // Sort by score descending
    }
    
    private func createJSONFile(logData: LogUploadRequest) -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(logData)
        } catch {
            print("📤 Error encoding log data: \(error)")
            return nil
        }
    }
    
    // MARK: - Mock Upload Methods (API calls removed)
    
    private func uploadToS3Mock(jsonData: Data, folderName: String? = nil, completion: @escaping (Bool, String?) -> Void) {
        let finalFolderName: String
        if let folderName = folderName {
            finalFolderName = folderName
        } else {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            finalFolderName = "\(timestamp)_\(organization)"
        }
        
        print("📤 LogUploadService: Mock - Uploading JSON data to S3")
        print("📤 LogUploadService: Mock - Folder name: \(finalFolderName)")
        print("📤 LogUploadService: Mock - Data size: \(jsonData.count) bytes")
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("📤 LogUploadService: Mock - Upload completed successfully")
            completion(true, nil)
        }
    }
    
    // MARK: - Screenshot Upload Methods (Mock)
    
    func uploadScreenshot(filePath: String, folderName: String, fileName: String, completion: @escaping (Bool, String?) -> Void) {
        print("📸 LogUploadService: Mock - Starting screenshot upload")
        print("📸 LogUploadService: Mock - File path: \(filePath)")
        print("📸 LogUploadService: Mock - Folder name: \(folderName)")
        print("📸 LogUploadService: Mock - File name: \(fileName)")
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("❌ LogUploadService: Screenshot file not found: \(filePath)")
            completion(false, "Screenshot file not found: \(filePath)")
            return
        }
        
        guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            print("❌ LogUploadService: Failed to read screenshot data")
            completion(false, "Failed to read screenshot data")
            return
        }
        
        print("📸 LogUploadService: Mock - Image data size: \(imageData.count) bytes")
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("✅ LogUploadService: Mock - Screenshot upload completed successfully")
            completion(true, nil)
        }
    }
    
    // MARK: - Video Upload Methods (Mock)
    
    func uploadVideo(filePath: String, folderName: String, fileName: String, completion: @escaping (Bool, String?) -> Void) {
        print("🎥 LogUploadService: Mock - Starting video upload")
        print("🎥 LogUploadService: Mock - File path: \(filePath)")
        print("🎥 LogUploadService: Mock - Folder name: \(folderName)")
        print("🎥 LogUploadService: Mock - File name: \(fileName)")
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("❌ LogUploadService: Video file not found: \(filePath)")
            completion(false, "Video file not found: \(filePath)")
            return
        }
        
        guard let videoData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            print("❌ LogUploadService: Failed to read video data")
            completion(false, "Failed to read video data")
            return
        }
        
        print("🎥 LogUploadService: Mock - Video data size: \(videoData.count) bytes")
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("✅ LogUploadService: Mock - Video upload completed successfully")
            completion(true, nil)
        }
    }
    
    // MARK: - Public Methods for Manual Upload
    
    func uploadLogsNow() {
        DispatchQueue.global(qos: .utility).async {
            self.uploadLogs()
        }
    }
    
    private func uploadLogsWithSession(folderName: String) {
        guard isActive else { return }
        
        DispatchQueue.main.async {
            self.uploadStatus = .uploading
        }
        
        // Collect current log data
        let logData = collectLogData()
        
        // Create JSON file
        guard let jsonData = createJSONFile(logData: logData) else {
            DispatchQueue.main.async {
                self.uploadStatus = .failed
                self.lastUploadError = "Failed to create JSON data"
            }
            return
        }
        
        // Mock upload to S3 via API with session folder name
        uploadToS3Mock(jsonData: jsonData, folderName: folderName) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.uploadStatus = .success
                    self.lastUploadTime = Date()
                    self.lastUploadError = nil
                    print("📤 Logs uploaded successfully to session folder: \(folderName) (mock)")
                } else {
                    self.uploadStatus = .failed
                    self.lastUploadError = error ?? "Unknown upload error"
                    print("📤 Log upload failed: \(error ?? "Unknown error")")
                }
            }
        }
    }
    
    func getUploadStatus() -> String {
        switch uploadStatus {
        case .idle:
            return "Idle"
        case .uploading:
            return "Uploading..."
        case .success:
            return "Success"
        case .failed:
            return "Failed: \(lastUploadError ?? "Unknown error")"
        }
    }
} 