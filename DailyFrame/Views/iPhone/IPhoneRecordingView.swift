import SwiftUI

struct IPhoneRecordingView: View {
    @EnvironmentObject var videoManager: VideoManagerViewModel

    var body: some View {
        ZStack {
            // Main content based on state
            switch videoManager.recordingState {
            case .idle, .preparing, .recording, .saving, .error:
                recordingInterface

            case .saved, .reviewing:
                if let video = videoManager.currentVideo, let videoURL = video.videoURL {
                    VideoQAView(
                        videoURL: videoURL,
                        onKeep: {
                            videoManager.keepVideo()
                        },
                        onRedo: {
                            Task {
                                await videoManager.redoVideo()
                            }
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $videoManager.showExportSheet) {
            if let video = videoManager.currentVideo, let videoURL = video.videoURL {
                VideoExportView(videoURL: videoURL) {
                    videoManager.finishReview()
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var recordingInterface: some View {
        ZStack {
            // Camera preview or placeholder
            if videoManager.todayHasVideo {
                todayRecordedView
            } else {
                VideoRecorderView()
            }

            // Top bar with sync status
            VStack {
                HStack {
                    SyncStatusView(syncState: videoManager.syncState)
                    Spacer()
                }
                .padding()

                Spacer()
            }
        }
    }

    private var todayRecordedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Today's video recorded!")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Come back tomorrow to record another")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if videoManager.currentVideo != nil {
                Button("View Today's Video") {
                    Task {
                        await videoManager.loadVideos()
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 20)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    IPhoneRecordingView()
        .environmentObject(VideoManagerViewModel())
}
