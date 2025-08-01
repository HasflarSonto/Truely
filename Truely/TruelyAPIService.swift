import Foundation
import Combine

class TruelyAPIService: ObservableObject {
    private let baseURL = "https://api.true-ly.com"
    private var encryptedKey: String = ""
    
    // Callbacks for introduction message status (maintaining compatibility with RecallService interface)
    var onIntroductionStart: (() -> Void)?
    var onIntroductionComplete: (() -> Void)?
    
    func setEncryptedKey(_ key: String) {
        self.encryptedKey = key
        print("🔐 TruelyAPI: Encrypted key set: \(key.prefix(10))...")
    }
    
    // MARK: - Mock API Endpoints (API calls removed)
    
    /// Decrypt the encrypted key and initialize the bot
    /// - Parameters:
    ///   - encryptedKey: The encrypted key containing meeting configuration
    ///   - completion: Completion handler with DecryptResponse or error
    func decryptKeyAndStartBot(encryptedKey: String, completion: @escaping (Result<DecryptResponse, TruelyAPIError>) -> Void) {
        guard !encryptedKey.isEmpty else {
            completion(.failure(.invalidEncryptedKey))
            return
        }
        
        print("TruelyAPI: Mock - Decrypting key and initializing bot...")
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Create a mock response
            let mockResponse = DecryptResponse(
                meetingLink: "https://us05web.zoom.us/j/123456789?pwd=mockPassword",
                forbiddenApps: ["cluely", "chatgpt", "bard"],
                botId: "mock-bot-id-\(UUID().uuidString)",
                folderPath: "mock/folder/path",
                planType: "free"
            )
            
            print("TruelyAPI: Mock - Successfully decrypted key - Bot ID: \(mockResponse.botId)")
            print("TruelyAPI: Mock - Meeting Link: \(mockResponse.meetingLink)")
            print("TruelyAPI: Mock - Forbidden Apps: \(mockResponse.forbiddenApps)")
            completion(.success(mockResponse))
        }
    }
    
    /// Send a chat message to the meeting
    /// - Parameters:
    ///   - meetingLink: The meeting URL
    ///   - botId: The bot identifier
    ///   - message: The message to send
    ///   - completion: Completion handler with ChatResponse or error
    func sendChatMessage(meetingLink: String, botId: String, message: String, completion: @escaping (Result<ChatResponse, TruelyAPIError>) -> Void) {
        guard !meetingLink.isEmpty, !botId.isEmpty, !message.isEmpty else {
            completion(.failure(.missingRequiredData))
            return
        }
        
        print("TruelyAPI: Mock - Sending chat message to meeting...")
        print("TruelyAPI: Mock - Message: \(message)")
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let mockResponse = ChatResponse(
                statusCode: 200,
                body: "{\"message\": \"Chat message sent successfully\"}"
            )
            
            print("TruelyAPI: Mock - Chat message sent successfully")
            completion(.success(mockResponse))
        }
    }
    
    /// Leave the meeting
    /// - Parameters:
    ///   - meetingLink: The meeting URL
    ///   - botId: The bot identifier
    ///   - completion: Completion handler with LeaveResponse or error
    func leaveMeeting(meetingLink: String, botId: String, completion: @escaping (Result<LeaveResponse, TruelyAPIError>) -> Void) {
        guard !meetingLink.isEmpty, !botId.isEmpty else {
            completion(.failure(.missingRequiredData))
            return
        }
        
        print("TruelyAPI: Mock - Requesting bot to leave meeting...")
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let mockResponse = LeaveResponse(
                statusCode: 200,
                body: "{\"message\": \"Truely bot left the meeting successfully\"}"
            )
            
            print("TruelyAPI: Mock - Bot left meeting successfully")
            completion(.success(mockResponse))
        }
    }
    
    // MARK: - Helper Methods for RecallService Compatibility
    
    /// Send introduction messages (mimics RecallService.sendStartingMessage behavior)
    /// - Parameters:
    ///   - meetingLink: The meeting URL
    ///   - botId: The bot identifier
    ///   - forbiddenApps: Array of forbidden application names
    ///   - startingKey: Starting key for monitoring
    ///   - endingKey: Ending key for monitoring
    ///   - onStart: Callback when starting to send messages
    ///   - onComplete: Callback when all messages are sent
    func sendStartingMessage(meetingLink: String, botId: String, forbiddenApps: [String], startingKey: String, endingKey: String, onStart: (() -> Void)? = nil, onComplete: (() -> Void)? = nil) {
        
        onStart?() // Notify that we're starting to send messages
        
        let platform = getMeetingPlatform(from: meetingLink)
        let messages = [
            "Hello everyone! I'm Truely, your automated meeting monitor.",
            "Platform: \(platform) | Monitoring Key: \(startingKey)",
            "I'll be keeping a close eye on the following applications: \(forbiddenApps.joined(separator: ", "))",
            "To stop monitoring remotely, send 'Truely End' in the chat."
        ]
        
        sendMessagesSequentially(meetingLink: meetingLink, botId: botId, messages: messages, index: 0) {
            onComplete?() // Notify that we're done sending messages
        }
    }
    
    /// Send farewell messages and leave meeting (mimics RecallService.sendFarewellAndStop behavior)
    /// - Parameters:
    ///   - meetingLink: The meeting URL
    ///   - botId: The bot identifier
    ///   - endingKey: Ending key for monitoring
    ///   - sessionId: Session ID for the meeting
    ///   - completion: Completion callback
    func sendFarewellAndStop(meetingLink: String, botId: String, endingKey: String, sessionId: String, completion: @escaping () -> Void) {
        // First, get the dump link
        getDumpLink(sessionId: sessionId) { [weak self] presignedUrl in
            guard let self = self else {
                completion()
                return
            }
            
            // Send farewell messages with the dump link
            let farewellMessages = [
                "Manual exit initiated",
                "Meeting documentation link is: \(presignedUrl)",
                "Truely Bot is leaving the meeting"
            ]
            
            self.sendMessagesSequentially(meetingLink: meetingLink, botId: botId, messages: farewellMessages, index: 0) {
                // Add a small delay to ensure message is delivered before leaving
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // After message is sent and delivered, make the bot leave the call
                    self.leaveMeeting(meetingLink: meetingLink, botId: botId) { result in
                        switch result {
                        case .success:
                            print("TruelyAPI: Successfully left meeting")
                        case .failure(let error):
                            print("TruelyAPI: Error leaving meeting: \(error)")
                        }
                        DispatchQueue.main.async {
                            completion()
                        }
                    }
                }
            }
        }
    }
    
    /// Send alert message to meeting (mimics RecallService.sendAlertToMeeting behavior)
    /// - Parameters:
    ///   - meetingLink: The meeting URL
    ///   - botId: The bot identifier
    ///   - apps: Array of detected forbidden apps
    func sendAlertToMeeting(meetingLink: String, botId: String, apps: [String]) {
        // Extract just the application name from the first detected app
        let firstApp = apps.first ?? "Unknown Application"
        let appName = extractAppName(from: firstApp)
        let message = "⚠️ Forbidden Application Detected: \(appName)"
        
        sendChatMessage(meetingLink: meetingLink, botId: botId, message: message) { result in
            switch result {
            case .success:
                print("TruelyAPI: Alert sent successfully")
            case .failure(let error):
                print("TruelyAPI: Error sending alert: \(error)")
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func sendMessagesSequentially(meetingLink: String, botId: String, messages: [String], index: Int, completion: (() -> Void)? = nil) {
        guard index < messages.count else { 
            completion?()
            return 
        }
        
        sendChatMessage(meetingLink: meetingLink, botId: botId, message: messages[index]) { result in
            switch result {
            case .success:
                // Send the next message after the current one is sent
                self.sendMessagesSequentially(meetingLink: meetingLink, botId: botId, messages: messages, index: index + 1, completion: completion)
            case .failure(let error):
                print("TruelyAPI: Error sending message: \(error)")
                // Continue with next message even if one fails
                self.sendMessagesSequentially(meetingLink: meetingLink, botId: botId, messages: messages, index: index + 1, completion: completion)
            }
        }
    }
    
    private func getMeetingPlatform(from meetingLink: String) -> String {
        if meetingLink.contains("zoom.us") || meetingLink.contains("zoom.com") {
            return "Zoom"
        } else if meetingLink.contains("meet.google.com") {
            return "Google Meet"
        }
        return "Unknown"
    }
    
    private func extractAppName(from appString: String) -> String {
        // Extract just the application name from strings like:
        // "Cluely (GUI App - PID: 3029)" -> "Cluely"
        // "Cluely Helper (GPU) (PID: 3030)" -> "Cluely"
        // "Cluely (Bundle: com.cluely.app)" -> "Cluely"
        
        let components = appString.components(separatedBy: " (")
        return components.first ?? appString
    }
    
    /// Get dump link from server (mock implementation)
    /// - Parameters:
    ///   - sessionId: Session ID for the meeting
    ///   - completion: Completion handler with presigned URL
    private func getDumpLink(sessionId: String, completion: @escaping (String) -> Void) {
        print("TruelyAPI: Mock - Getting dump link for session: \(sessionId)")
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let mockUrl = "https://example.com/dumps/\(sessionId)/dump.zip"
            print("TruelyAPI: Mock - Dump link received: \(mockUrl)")
            completion(mockUrl)
        }
    }
    

}