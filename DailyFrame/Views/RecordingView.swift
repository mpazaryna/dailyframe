import SwiftUI
import AVFoundation

#if os(iOS)
import AVKit

// MARK: - Recording View

/// Unified recording view for iPhone and iPad.
/// Uses RecordingLayoutConfig for platform-adaptive layout.
struct RecordingView: View {
    @Environment(\.videoLibrary) private var library
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var config: RecordingLayoutConfig { RecordingLayoutConfig.current(sizeClass) }

    let onComplete: (VideoTake) -> Void
    let onCancel: () -> Void

    @State private var camera = CameraService()
    @State private var isRecording = false
    @State private var errorMessage: String?
    @State private var hasRequestedPermissions = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreviewView(session: camera.captureSession)
                    .ignoresSafeArea()

                VStack {
                    // Top bar with cancel button
                    HStack {
                        cancelButton
                        Spacer()
                    }
                    .padding(config.topBarPadding)

                    Spacer()

                    // Recording indicator
                    if isRecording {
                        recordingIndicator
                            .padding(.bottom, 20)
                    }

                    // Record button
                    recordButton
                        .padding(.bottom, geometry.safeAreaInsets.bottom + config.bottomPadding)
                }
            }
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            guard !hasRequestedPermissions else { return }
            hasRequestedPermissions = true
            let granted = await PermissionManager.shared.requestAllPermissions()
            if granted {
                do {
                    try await camera.setupSession()
                    camera.startSession()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        .onAppear {
            // Enable orientation notifications so we can detect device rotation
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        }
        .onDisappear {
            camera.stopSession()
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
    }

    // MARK: - Components

    private var cancelButton: some View {
        Button {
            camera.stopSession()
            onCancel()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: config.cancelButtonSize, height: config.cancelButtonSize)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
    }

    private var recordButton: some View {
        Button {
            Task { await handleRecordButton() }
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: config.recordButtonSize, height: config.recordButtonSize)

                Circle()
                    .fill(isRecording ? .red : .white)
                    .frame(
                        width: isRecording ? config.recordButtonRecordingSize : config.recordButtonInnerSize,
                        height: isRecording ? config.recordButtonRecordingSize : config.recordButtonInnerSize
                    )
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
            }
        }
        .disabled(!canRecord && !isRecording)
        .opacity(canRecord || isRecording ? 1 : 0.5)
        .glassEffect()
    }

    private var canRecord: Bool {
        Platform.current.supportsCamera && !isRecording
    }

    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 12, height: 12)

            Text("Recording")
                .font(.system(size: config.bodyFontSize, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .glassEffect()
    }

    // MARK: - Actions

    private func handleRecordButton() async {
        if isRecording {
            camera.stopRecording()
        } else {
            isRecording = true
            do {
                let tempURL = try await camera.startRecording()
                if let take = try await library?.saveRecording(from: tempURL) {
                    camera.stopSession()
                    onComplete(take)
                }
            } catch {
                errorMessage = error.localizedDescription
                isRecording = false
            }
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.frame = uiView.bounds
        uiView.updatePreviewOrientation()
    }
}

@MainActor
class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black

        // Observe orientation changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        updatePreviewOrientation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func orientationDidChange() {
        updatePreviewOrientation()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        updatePreviewOrientation()
    }

    func updatePreviewOrientation() {
        guard let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(0) else {
            return
        }

        let angle: CGFloat
        switch UIDevice.current.orientation {
        case .portrait:
            angle = 90
        case .portraitUpsideDown:
            angle = 270
        case .landscapeLeft:
            angle = 0
        case .landscapeRight:
            angle = 180
        default:
            // Use interface orientation as fallback
            if let windowScene = window?.windowScene {
                switch windowScene.interfaceOrientation {
                case .portrait:
                    angle = 90
                case .portraitUpsideDown:
                    angle = 270
                case .landscapeLeft:
                    angle = 0
                case .landscapeRight:
                    angle = 180
                default:
                    angle = 90
                }
            } else {
                angle = 90
            }
        }

        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }
}

#Preview {
    RecordingView(
        onComplete: { _ in },
        onCancel: {}
    )
    .environment(\.videoLibrary, VideoLibrary())
}

#endif
