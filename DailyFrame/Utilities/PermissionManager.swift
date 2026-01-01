import Foundation
import AVFoundation

@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published private(set) var cameraStatus: AVAuthorizationStatus = .notDetermined
    @Published private(set) var microphoneStatus: AVAuthorizationStatus = .notDetermined

    private init() {
        updateStatuses()
    }

    var hasAllPermissions: Bool {
        cameraStatus == .authorized && microphoneStatus == .authorized
    }

    var needsPermissionRequest: Bool {
        cameraStatus == .notDetermined || microphoneStatus == .notDetermined
    }

    func updateStatuses() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    func requestCameraPermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        updateStatuses()
        return granted
    }

    func requestMicrophonePermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        updateStatuses()
        return granted
    }

    func requestAllPermissions() async -> Bool {
        let cameraGranted = await requestCameraPermission()
        let microphoneGranted = await requestMicrophonePermission()
        return cameraGranted && microphoneGranted
    }

    var cameraPermissionMessage: String? {
        switch cameraStatus {
        case .denied:
            return "Camera access denied. Enable in Settings."
        case .restricted:
            return "Camera access is restricted."
        default:
            return nil
        }
    }

    var microphonePermissionMessage: String? {
        switch microphoneStatus {
        case .denied:
            return "Microphone access denied. Enable in Settings."
        case .restricted:
            return "Microphone access is restricted."
        default:
            return nil
        }
    }
}
