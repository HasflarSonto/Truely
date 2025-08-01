import Foundation
import Combine

class RecallService: ObservableObject {
    private var apiKey: String = ""
    private var meetingLink: String = ""
    private var botId: String?
    private var encryptedKey: String = ""
    // Mock base URL (API calls removed)
    private let baseURL = "https://us-west-2.recall.ai"
    
    // Callbacks for introduction message status
    var onIntroductionStart: (() -> Void)?
    var onIntroductionComplete: (() -> Void)?
    
    func configure(apiKey: String, meetingLink: String, encryptedKey: String) {
        self.apiKey = apiKey
        self.meetingLink = meetingLink
        self.encryptedKey = encryptedKey
    }
    
    private func getMeetingPlatform() -> String {
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
    
    func sendStartingMessage(forbiddenApps: [String], startingKey: String, endingKey: String, onStart: (() -> Void)? = nil, onComplete: (() -> Void)? = nil) {
        guard let botId = botId else { 
            onComplete?()
            return 
        }
        
        onStart?() // Notify that we're starting to send messages
        
        let platform = getMeetingPlatform()
        let messages = [
            "Hello everyone! I'm Truely, your automated meeting monitor.",
            "Platform: \(platform) | Monitoring Key: \(startingKey)",
            "I'll be keeping a close eye on the following applications: \(forbiddenApps.joined(separator: ", "))",
            "To stop monitoring remotely, send 'Truely End' in the chat."
        ]
        
        sendMessagesSequentially(botId: botId, messages: messages, index: 0) {
            onComplete?() // Notify that we're done sending messages
        }
    }

    private func sendMessagesSequentially(botId: String, messages: [String], index: Int, completion: (() -> Void)? = nil) {
        guard index < messages.count else { 
            completion?()
            return 
        }
        
        sendChatMessage(botId: botId, message: messages[index]) {
            // Send the next message after the current one is sent
            self.sendMessagesSequentially(botId: botId, messages: messages, index: index + 1, completion: completion)
        }
    }

    // Mock implementation of startBot (API calls removed)
    func startBot(forbiddenApps: [String], startingKey: String, endingKey: String, completion: @escaping (Bool) -> Void) {
        guard !apiKey.isEmpty, !meetingLink.isEmpty else {
            completion(false)
            return
        }
        
        print("RecallService: Mock - Starting bot for \(getMeetingPlatform()) meeting")
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Generate a mock bot ID
            self.botId = "mock-bot-\(UUID().uuidString)"
            print("RecallService: Mock - Bot created with ID: \(self.botId ?? "unknown") for \(self.getMeetingPlatform()) meeting")
            
            // Send starting messages after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.sendStartingMessage(forbiddenApps: forbiddenApps, startingKey: startingKey, endingKey: endingKey, onStart: self.onIntroductionStart, onComplete: self.onIntroductionComplete)
            }
            
            completion(true)
        }
    }
    
    func sendAlertToMeeting(apps: [String]) {
        guard let botId = botId else { return }
        
        // Extract just the application name from the first detected app
        let firstApp = apps.first ?? "Unknown Application"
        let appName = extractAppName(from: firstApp)
        let message = "⚠️ Forbidden Application Detected: \(appName)"
        
        sendChatMessage(botId: botId, message: message)
    }
    
    // Legacy method for backward compatibility
    func sendAlertToZoom(apps: [String]) {
        sendAlertToMeeting(apps: apps)
    }
    
    // Mock implementation of sendFarewellAndStop (API calls removed)
    func sendFarewellAndStop(endingKey: String, sessionId: String, completion: @escaping () -> Void) {
        guard let botId = botId else {
            completion()
            return
        }
        
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
            
            self.sendMessagesSequentially(botId: botId, messages: farewellMessages, index: 0) {
                // Add a small delay to ensure message is delivered before leaving
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // After message is sent and delivered, make the bot leave the call
                    self.leaveCall {
                        completion()
                    }
                }
            }
        }
    }
    
    // Mock function to get dump link from server (API call removed)
    private func getDumpLink(sessionId: String, completion: @escaping (String) -> Void) {
        print("RecallService: Mock - Getting dump link for session: \(sessionId)")
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let mockUrl = "https://example.com/dumps/\(sessionId)/dump.zip"
            print("RecallService: Mock - Dump link received: \(mockUrl)")
            completion(mockUrl)
        }
    }
    
    // Mock implementation of sendChatMessage (API call removed)
    private func sendChatMessage(botId: String, message: String, completion: (() -> Void)? = nil) {
        print("RecallService: Mock - Sending chat message to \(getMeetingPlatform()) meeting")
        print("RecallService: Mock - Message: \(message)")
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("RecallService: Mock - Message sent to \(self.getMeetingPlatform()) chat: \(message)")
            completion?()
        }
    }
    
    // Mock implementation of leaveCall (API call removed)
    func leaveCall(completion: (() -> Void)? = nil) {
        guard let botId = botId else { 
            completion?()
            return 
        }
        
        print("RecallService: Mock - Bot leaving \(getMeetingPlatform()) meeting")
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("RecallService: Mock - Bot left \(self.getMeetingPlatform()) meeting successfully")
            
            DispatchQueue.main.async {
                self.botId = nil
                completion?()
            }
        }
    }
    
    // Mock implementation of stopBot (API call removed)
    func stopBot(completion: (() -> Void)? = nil) {
        guard let botId = botId else { 
            completion?()
            return 
        }
        
        print("RecallService: Mock - Stopping bot")
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("RecallService: Mock - Bot stopped successfully")
            
            DispatchQueue.main.async {
                self.botId = nil
                completion?()
            }
        }
    }
}
