import Foundation

// MARK: - Loading State Management

enum LoadingState: Equatable {
    case idle
    case loading(String)
    case success(String?)
    case error(String, isRetryable: Bool)
    
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
    
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    var message: String? {
        switch self {
        case .idle:
            return nil
        case .loading(let message):
            return message
        case .success(let message):
            return message
        case .error(let message, _):
            return message
        }
    }
    
    var canRetry: Bool {
        if case .error(_, let isRetryable) = self {
            return isRetryable
        }
        return false
    }
}

enum OperationType: String, CaseIterable {
    case joiningMeeting = "joining_meeting"
    case startingBot = "starting_bot"
    case scanningProcesses = "scanning_processes"
    case stoppingMonitoring = "stopping_monitoring"
    case networkConnectivity = "network_connectivity"
    
    var displayName: String {
        switch self {
        case .joiningMeeting:
            return "Joining Meeting"
        case .startingBot:
            return "Starting Bot"
        case .scanningProcesses:
            return "Scanning Processes"
        case .stoppingMonitoring:
            return "Stopping Monitoring"
        case .networkConnectivity:
            return "Network Connectivity"
        }
    }
    
    var defaultLoadingMessage: String {
        switch self {
        case .joiningMeeting:
            return "Opening meeting link..."
        case .startingBot:
            return "Starting monitoring bot..."
        case .scanningProcesses:
            return "Scanning for forbidden applications..."
        case .stoppingMonitoring:
            return "Stopping monitoring session..."
        case .networkConnectivity:
            return "Checking network connection..."
        }
    }
}

// MARK: - Loading State Manager

@MainActor
class LoadingStateManager: ObservableObject {
    @Published private(set) var states: [OperationType: LoadingState] = [:]
    @Published private(set) var hasActiveOperations: Bool = false
    @Published private(set) var currentPrimaryOperation: OperationType?
    
    func setState(_ operation: OperationType, _ state: LoadingState) {
        states[operation] = state
        updateActiveOperations()
    }
    
    func getState(_ operation: OperationType) -> LoadingState {
        return states[operation] ?? .idle
    }
    
    func setLoading(_ operation: OperationType, message: String? = nil) {
        let loadingMessage = message ?? operation.defaultLoadingMessage
        setState(operation, .loading(loadingMessage))
    }
    
    func setSuccess(_ operation: OperationType, message: String? = nil) {
        setState(operation, .success(message))
        
        // Auto-clear success states after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if case .success = getState(operation) {
                setState(operation, .idle)
            }
        }
    }
    
    func setError(_ operation: OperationType, message: String, isRetryable: Bool = true) {
        setState(operation, .error(message, isRetryable: isRetryable))
    }
    
    func setIdle(_ operation: OperationType) {
        setState(operation, .idle)
    }
    
    func clearAll() {
        states.removeAll()
        updateActiveOperations()
    }
    
    func getActiveLoadingOperations() -> [OperationType] {
        return states.compactMap { (operation, state) in
            state.isLoading ? operation : nil
        }
    }
    
    func getErrorOperations() -> [OperationType] {
        return states.compactMap { (operation, state) in
            state.isError ? operation : nil
        }
    }
    
    private func updateActiveOperations() {
        let loadingOps = getActiveLoadingOperations()
        hasActiveOperations = !loadingOps.isEmpty
        currentPrimaryOperation = loadingOps.first
    }
    
    // Helper method to get a unified status message for backward compatibility
    func getUnifiedStatusMessage() -> String {
        // Priority order: errors first, then loading, then success, then idle
        
        // Check for errors first
        let errorOps = getErrorOperations()
        if let firstError = errorOps.first,
           case .error(let message, _) = getState(firstError) {
            return message
        }
        
        // Check for loading operations
        let loadingOps = getActiveLoadingOperations()
        if let firstLoading = loadingOps.first,
           case .loading(let message) = getState(firstLoading) {
            return message
        }
        
        // Check for recent success messages
        for (_, state) in states {
            if case .success(let message) = state, let msg = message {
                return msg
            }
        }
        
        return "Ready to monitor"
    }
}