import Foundation

enum SyncState: Equatable {
    case idle
    case syncing
    case synced
    case offline
    case error(String)

    var displayText: String {
        switch self {
        case .idle:
            return ""
        case .syncing:
            return "Syncing..."
        case .synced:
            return "Synced"
        case .offline:
            return "Offline"
        case .error(let message):
            return "Sync Error: \(message)"
        }
    }

    var iconName: String {
        switch self {
        case .idle, .synced:
            return "checkmark.icloud"
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .offline:
            return "icloud.slash"
        case .error:
            return "exclamationmark.icloud"
        }
    }

    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

enum RecordingState: Equatable {
    case idle
    case preparing
    case recording
    case saving
    case saved(URL)
    case reviewing
    case error(String)

    var isRecording: Bool {
        self == .recording
    }

    var canRecord: Bool {
        switch self {
        case .idle, .error:
            return true
        default:
            return false
        }
    }
}
