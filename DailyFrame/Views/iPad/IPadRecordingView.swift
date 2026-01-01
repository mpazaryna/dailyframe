import SwiftUI

struct IPadRecordingView: View {
    @EnvironmentObject var videoManager: VideoManagerViewModel
    @State private var selectedVideo: VideoDay?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar - Video list
            sidebarContent
                .navigationTitle("DailyFrame")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
                #endif
        } detail: {
            // Main content
            detailContent
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

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Sync status
            HStack {
                SyncStatusView(syncState: videoManager.syncState)
                Spacer()
            }
            .padding()

            // Video list
            if videoManager.allVideos.isEmpty {
                emptyStateView
            } else {
                videoList
            }
        }
        .background(.ultraThinMaterial.opacity(0.3))
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "video.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No videos yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Record your first video to get started")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    private var videoList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(videoManager.allVideos) { video in
                    VideoListItemView(
                        video: video,
                        isSelected: selectedVideo?.id == video.id
                    ) {
                        selectedVideo = video
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch videoManager.recordingState {
        case .reviewing:
            if let video = videoManager.currentVideo, let videoURL = video.videoURL {
                VideoQAView(
                    videoURL: videoURL,
                    onKeep: { videoManager.keepVideo() },
                    onRedo: {
                        Task { await videoManager.redoVideo() }
                    }
                )
            }

        default:
            if videoManager.todayHasVideo {
                todayRecordedView
            } else {
                VideoRecorderView()
            }
        }
    }

    private var todayRecordedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.green)

            Text("Today's video recorded!")
                .font(.title)
                .fontWeight(.semibold)

            Text("Come back tomorrow to record another")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    IPadRecordingView()
        .environmentObject(VideoManagerViewModel())
}
