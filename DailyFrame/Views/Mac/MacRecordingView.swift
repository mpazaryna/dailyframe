import SwiftUI

struct MacRecordingView: View {
    @EnvironmentObject var videoManager: VideoManagerViewModel
    @State private var selectedVideo: VideoDay?

    var body: some View {
        NavigationSplitView {
            // Sidebar
            sidebarContent
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 350)
        } detail: {
            // Main content
            detailContent
        }
        .sheet(isPresented: $videoManager.showExportSheet) {
            if let video = videoManager.currentVideo, let videoURL = video.videoURL {
                VideoExportView(videoURL: videoURL) {
                    videoManager.finishReview()
                }
                .frame(minWidth: 400, minHeight: 400)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                SyncStatusView(syncState: videoManager.syncState)

                if let video = selectedVideo ?? videoManager.currentVideo,
                   video.videoURL != nil {
                    Button {
                        videoManager.triggerExport()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Videos")
                    .font(.headline)
                Spacer()
                Button {
                    videoManager.refreshVideos()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Video list
            if videoManager.allVideos.isEmpty {
                emptyStateView
            } else {
                videoList
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "video.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("No videos yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Record videos on your iPhone or iPad")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    private var videoList: some View {
        List(selection: $selectedVideo) {
            ForEach(videoManager.allVideos) { video in
                VideoListItemView(
                    video: video,
                    isSelected: selectedVideo?.id == video.id
                ) {
                    selectedVideo = video
                }
                .tag(video)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var detailContent: some View {
        if let video = selectedVideo, let videoURL = video.videoURL {
            VideoPlayerView(videoURL: videoURL)
        } else if let video = videoManager.currentVideo, let videoURL = video.videoURL {
            VideoPlayerView(videoURL: videoURL)
        } else {
            noSelectionView
        }
    }

    private var noSelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("Select a video to preview")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Videos recorded on iPhone or iPad will appear here")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial.opacity(0.3))
    }
}

struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: videoURL)
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}

import AVKit

#Preview {
    MacRecordingView()
        .environmentObject(VideoManagerViewModel())
}
