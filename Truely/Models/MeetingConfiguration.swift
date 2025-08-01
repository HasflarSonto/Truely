import Foundation
import Combine

/// Manages meeting configuration data derived from decrypted encrypted key
class MeetingConfiguration: ObservableObject {
    @Published var meetingLink: String = ""
    @Published var forbiddenApps: [String] = []
    @Published var botId: String = ""
    @Published var folderPath: String = ""
    @Published var planType: PlanType = .free
    @Published var isConfigured: Bool = false
    
    // Computed properties for backward compatibility
    var forbiddenAppsString: String {
        forbiddenApps.joined(separator: ",")
    }
    
    var forbiddenAppsArray: [String] {
        forbiddenApps.filter { !$0.isEmpty }
    }
    
    /// Update configuration from a successful decryption response
    /// - Parameter response: The DecryptResponse containing meeting configuration
    func updateFromDecryptResponse(_ response: DecryptResponse) {
        DispatchQueue.main.async {
            self.meetingLink = response.meetingLink
            self.forbiddenApps = response.forbiddenApps
            self.botId = response.botId
            self.folderPath = response.folderPath
            self.planType = PlanType(rawValue: response.planType) ?? .free
            self.isConfigured = true
            
            print("MeetingConfiguration: Updated with new configuration")
            print("  - Meeting Link: \(self.meetingLink)")
            print("  - Bot ID: \(self.botId)")
            print("  - Forbidden Apps: \(self.forbiddenApps)")
            print("  - Folder Path: \(self.folderPath)")
            print("  - Plan Type: \(self.planType.displayName)")
        }
    }
    
    /// Clear all configuration data
    func clear() {
        DispatchQueue.main.async {
            self.meetingLink = ""
            self.forbiddenApps = []
            self.botId = ""
            self.folderPath = ""
            self.planType = .free
            self.isConfigured = false
            
            print("MeetingConfiguration: Configuration cleared")
        }
    }
    
    /// Validate that the configuration has all required data
    var isValid: Bool {
        return !meetingLink.isEmpty && !botId.isEmpty && isConfigured
    }
    
    /// Get the meeting platform type based on the meeting link
    var meetingPlatform: String {
        if meetingLink.contains("zoom.us") || meetingLink.contains("zoom.com") {
            return "Zoom"
        } else if meetingLink.contains("meet.google.com") {
            return "Google Meet"
        }
        return "Unknown"
    }
    
    /// Check if a meeting link is a supported platform
    static func isSupportedMeetingLink(_ link: String) -> Bool {
        let isZoom = link.contains("zoom.us") || link.contains("zoom.com")
        let isGoogleMeet = link.contains("meet.google.com")
        return isZoom || isGoogleMeet
    }
    
    /// Validate a meeting link format
    static func isValidMeetingLink(_ link: String) -> Bool {
        guard let url = URL(string: link) else { return false }
        return isSupportedMeetingLink(link) && url.scheme != nil
    }
}