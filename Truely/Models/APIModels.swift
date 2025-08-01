import Foundation

// MARK: - Plan Types

enum PlanType: String, CaseIterable {
    case free = "free"
    case pro = "pro"
    
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .pro:
            return "Pro"
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return [
                "Real-time process monitoring every 2 seconds",
                "Basic forbidden application detection"
            ]
        case .pro:
            return [
                "Real-time process monitoring every 2 seconds",
                "Advanced network traffic monitoring every 10 seconds",
                "LLM API connection detection (OpenAI, Anthropic, Cohere, etc.)",
                "Multiple detection methods (process enumeration, GUI monitoring, hash verification)",
                "Automatic screenshots every 2 minutes",
                "45-second startup video recording",
                "System logs uploaded every minute",
                "All evidence automatically uploaded to secure servers"
            ]
        }
    }
}

// MARK: - True-ly API Response Models

struct DecryptResponse: Codable {
    let meetingLink: String
    let forbiddenApps: [String]
    let botId: String
    let folderPath: String
    let planType: String
    
    enum CodingKeys: String, CodingKey {
        case meetingLink = "meeting_link"
        case forbiddenApps = "forbiddenApps"
        case botId = "bot_id"
        case folderPath = "folder_path"
        case planType = "plan_type"
    }
}

// Wrapper for the actual API response structure
struct DecryptAPIResponse: Codable {
    let statusCode: Int
    let headers: [String: String]
    let body: String
    
    // Decode the nested body JSON into DecryptResponse
    var decodedBody: DecryptResponse? {
        guard let data = body.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DecryptResponse.self, from: data)
    }
    
    // Decode error message from body if it's an error response
    var errorMessage: String? {
        guard let data = body.data(using: .utf8),
              let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) else {
            return nil
        }
        return errorResponse.message
    }
}

// Error response structure
struct ErrorResponse: Codable {
    let message: String
}

struct ChatResponse: Codable {
    let statusCode: Int
    let body: String
    
    enum CodingKeys: String, CodingKey {
        case statusCode = "statusCode"
        case body = "body"
    }
}

struct LeaveResponse: Codable {
    let statusCode: Int
    let body: String
    
    enum CodingKeys: String, CodingKey {
        case statusCode = "statusCode"
        case body = "body"
    }
}

// MARK: - API Request Models

struct DecryptRequest: Codable {
    let payload: String
}

struct ChatMessageRequest: Codable {
    let meetingLink: String
    let botId: String
    let chatMessage: String
    
    enum CodingKeys: String, CodingKey {
        case meetingLink = "meeting_link"
        case botId = "bot_id"
        case chatMessage = "chat_message"
    }
}

struct LeaveMeetingRequest: Codable {
    let meetingLink: String
    let botId: String
    
    enum CodingKeys: String, CodingKey {
        case meetingLink = "meeting_link"
        case botId = "bot_id"
    }
}

// MARK: - True-ly API Errors

enum TruelyAPIError: Error, LocalizedError {
    case invalidEncryptedKey
    case decryptionFailed
    case botCreationFailed
    case networkError(String)
    case serverError(String)
    case invalidResponse
    case missingRequiredData
    
    var errorDescription: String? {
        switch self {
        case .invalidEncryptedKey:
            return "Invalid encrypted key format"
        case .decryptionFailed:
            return "Failed to decrypt the provided key"
        case .botCreationFailed:
            return "Failed to create or initialize the monitoring bot"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .missingRequiredData:
            return "Missing required data in server response"
        }
    }
}

// MARK: - Log Upload Models

struct LogUploadRequest: Codable {
    let timestamp: String
    let organization: String
    let networkConnections: [NetworkConnectionLog]
    let suspicionScores: [SuspicionScoreLog]
    let forbiddenApps: [String]
    let sessionInfo: SessionInfo
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case organization
        case networkConnections = "network_connections"
        case suspicionScores = "suspicion_scores"
        case forbiddenApps = "forbidden_apps"
        case sessionInfo = "session_info"
    }
}

struct NetworkConnectionLog: Codable {
    let processName: String
    let pid: Int32
    let destinationDomain: String
    let destinationPort: Int
    let connectionProtocol: String
    let confidence: String
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case processName = "process_name"
        case pid
        case destinationDomain = "destination_domain"
        case destinationPort = "destination_port"
        case connectionProtocol = "connection_protocol"
        case confidence
        case timestamp
    }
}

struct SuspicionScoreLog: Codable {
    let processName: String
    let pid: Int32
    let score: Int
    let detectionTypes: [String]
    let evidence: [String]
    
    enum CodingKeys: String, CodingKey {
        case processName = "process_name"
        case pid
        case score
        case detectionTypes = "detection_types"
        case evidence
    }
}

struct SessionInfo: Codable {
    let sessionId: String
    let meetingLink: String
    let platform: String
    let startTime: String
    let monitoringActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case meetingLink = "meeting_link"
        case platform
        case startTime = "start_time"
        case monitoringActive = "monitoring_active"
    }
}

struct LogUploadResponse: Codable {
    let message: String
    let statusCode: Int?
    
    enum CodingKeys: String, CodingKey {
        case message
        case statusCode = "status_code"
    }
}

// MARK: - Dump Link API Models

struct DumpLinkResponse: Codable {
    let url: String
}