import Foundation
import AVFoundation
import Combine

#if os(iOS)
@MainActor
final class CameraService: NSObject, ObservableObject {
    @Published private(set) var isSessionRunning = false
    @Published private(set) var isRecording = false
    @Published private(set) var error: AppError?

    private let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private let movieFileOutput = AVCaptureMovieFileOutput()

    private var recordingContinuation: CheckedContinuation<URL, Error>?
    private let sessionQueue = DispatchQueue(label: "com.paz.dailyframe.camera")

    var previewLayer: AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    func setupSession() async throws {
        guard await PermissionManager.shared.hasAllPermissions else {
            throw AppError.permissionDenied(.camera)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AppError.unknown("Camera service deallocated"))
                    return
                }

                do {
                    self.captureSession.beginConfiguration()
                    self.captureSession.sessionPreset = .high

                    // Video input
                    guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                        throw AppError.cameraUnavailable
                    }
                    let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                    if self.captureSession.canAddInput(videoInput) {
                        self.captureSession.addInput(videoInput)
                        self.videoDeviceInput = videoInput
                    }

                    // Audio input
                    if let audioDevice = AVCaptureDevice.default(for: .audio) {
                        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                        if self.captureSession.canAddInput(audioInput) {
                            self.captureSession.addInput(audioInput)
                            self.audioDeviceInput = audioInput
                        }
                    }

                    // Movie output
                    if self.captureSession.canAddOutput(self.movieFileOutput) {
                        self.captureSession.addOutput(self.movieFileOutput)

                        if let connection = self.movieFileOutput.connection(with: .video) {
                            if connection.isVideoStabilizationSupported {
                                connection.preferredVideoStabilizationMode = .auto
                            }
                        }
                    }

                    self.captureSession.commitConfiguration()
                    continuation.resume()
                } catch {
                    self.captureSession.commitConfiguration()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    func startRecording() async throws -> URL {
        guard !isRecording else {
            throw AppError.recordingFailed("Already recording")
        }

        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "recording_\(UUID().uuidString).mov"
        let outputURL = tempDirectory.appendingPathComponent(fileName)

        return try await withCheckedThrowingContinuation { continuation in
            self.recordingContinuation = continuation

            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AppError.unknown("Camera service deallocated"))
                    return
                }

                if let connection = self.movieFileOutput.connection(with: .video) {
                    connection.videoOrientation = .portrait
                }

                self.movieFileOutput.startRecording(to: outputURL, recordingDelegate: self)

                DispatchQueue.main.async {
                    self.isRecording = true
                }
            }
        }
    }

    func stopRecording() {
        sessionQueue.async { [weak self] in
            self?.movieFileOutput.stopRecording()
        }
    }
}

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            self.isRecording = false

            if let error = error {
                self.recordingContinuation?.resume(throwing: AppError.recordingFailed(error.localizedDescription))
            } else {
                self.recordingContinuation?.resume(returning: outputFileURL)
            }
            self.recordingContinuation = nil
        }
    }
}

#else
// macOS stub - camera not supported
@MainActor
final class CameraService: ObservableObject {
    @Published private(set) var isSessionRunning = false
    @Published private(set) var isRecording = false
    @Published private(set) var error: AppError? = .cameraUnavailable

    func setupSession() async throws {
        throw AppError.cameraUnavailable
    }

    func startSession() {}
    func stopSession() {}

    func startRecording() async throws -> URL {
        throw AppError.cameraUnavailable
    }

    func stopRecording() {}
}
#endif
