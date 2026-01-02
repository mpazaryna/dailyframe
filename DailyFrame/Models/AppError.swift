import Foundation

enum AppError: LocalizedError {
    case cameraUnavailable
    case microphoneUnavailable
    case permissionDenied(PermissionType)
    case recordingFailed(String)
    case saveFailed(String)
    case iCloudUnavailable
    case iCloudContainerNotFound
    case syncFailed(String)
    case storageQuotaExceeded
    case fileNotFound(String)
    case exportFailed(String)
    case compositionFailed(String)
    case alreadyRecordedToday
    case unknown(String)

    enum PermissionType: String {
        case camera = "Camera"
        case microphone = "Microphone"
    }

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Camera is not available on this device"
        case .microphoneUnavailable:
            return "Microphone is not available on this device"
        case .permissionDenied(let type):
            return "\(type.rawValue) permission was denied. Please enable in Settings."
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        case .saveFailed(let reason):
            return "Failed to save video: \(reason)"
        case .iCloudUnavailable:
            return "iCloud is not available. Please sign in to iCloud."
        case .iCloudContainerNotFound:
            return "iCloud container not found. Please check your iCloud settings."
        case .syncFailed(let reason):
            return "Sync failed: \(reason)"
        case .storageQuotaExceeded:
            return "iCloud storage is full. Please free up space."
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .compositionFailed(let reason):
            return "Failed to create montage: \(reason)"
        case .alreadyRecordedToday:
            return "You've already recorded a video today"
        case .unknown(let message):
            return message
        }
    }
}
