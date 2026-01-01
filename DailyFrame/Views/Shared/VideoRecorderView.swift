import SwiftUI
import AVFoundation

#if os(iOS)
struct VideoRecorderView: View {
    @EnvironmentObject var videoManager: VideoManagerViewModel
    @State private var hasRequestedPermissions = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview
                CameraPreviewView()
                    .ignoresSafeArea()

                // Recording overlay
                VStack {
                    Spacer()

                    // Status indicator
                    if videoManager.isRecording {
                        RecordingIndicator()
                            .padding(.bottom, 20)
                    }

                    // Record button
                    RecordButton(
                        isRecording: videoManager.isRecording,
                        canRecord: videoManager.canRecord
                    ) {
                        if videoManager.isRecording {
                            videoManager.stopRecording()
                        } else {
                            Task {
                                await videoManager.startRecording()
                            }
                        }
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 40)
                }
            }
        }
        .task {
            if !hasRequestedPermissions {
                hasRequestedPermissions = true
                let granted = await PermissionManager.shared.requestAllPermissions()
                if granted {
                    await videoManager.prepareCamera()
                }
            }
        }
        .onDisappear {
            videoManager.stopCamera()
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        let cameraService = CameraService()
        let previewLayer = cameraService.previewLayer
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

struct RecordButton: View {
    let isRecording: Bool
    let canRecord: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(isRecording ? .red : .white)
                    .frame(width: isRecording ? 30 : 60, height: isRecording ? 30 : 60)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
            }
        }
        .disabled(!canRecord && !isRecording)
        .opacity(canRecord || isRecording ? 1 : 0.5)
        .glassEffect()
    }
}

struct RecordingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 12, height: 12)
                .opacity(isAnimating ? 0.3 : 1)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: isAnimating)

            Text("Recording")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .glassEffect()
        .onAppear {
            isAnimating = true
        }
    }
}

#else
// macOS placeholder - no camera recording
struct VideoRecorderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Camera Not Available")
                .font(.title2)
                .fontWeight(.medium)

            Text("Video recording is only available on iPhone and iPad")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

struct RecordButton: View {
    let isRecording: Bool
    let canRecord: Bool
    let action: () -> Void

    var body: some View {
        EmptyView()
    }
}
#endif

#Preview {
    VideoRecorderView()
        .environmentObject(VideoManagerViewModel())
}
