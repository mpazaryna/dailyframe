import SwiftUI
import AVKit

struct MontageView: View {
    let videoURL: URL
    let videoCount: Int
    let onDismiss: () -> Void

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var config: VideoQALayoutConfig { VideoQALayoutConfig.current(sizeClass) }
    #else
    private var config: VideoQALayoutConfig { VideoQALayoutConfig.current }
    #endif

    @State private var player: AVPlayer
    @State private var showExportSheet = false
    @State private var loopObserver: NSObjectProtocol?

    init(videoURL: URL, videoCount: Int, onDismiss: @escaping () -> Void) {
        self.videoURL = videoURL
        self.videoCount = videoCount
        self.onDismiss = onDismiss
        self._player = State(initialValue: AVPlayer(url: videoURL))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VideoPlayer(player: player)
                    .ignoresSafeArea()

                VStack {
                    // Top bar
                    HStack {
                        Button {
                            player.pause()
                            onDismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Montage")
                                .font(.system(size: config.headlineFontSize, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("\(videoCount) days")
                                .font(.system(size: config.captionFontSize))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding()

                    Spacer()

                    // Bottom action button
                    HStack(spacing: 20) {
                        Button {
                            showExportSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Share")
                                    .font(.system(size: config.bodyFontSize, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(.blue)
                            .clipShape(Capsule())
                            .glassEffect()
                        }
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom + config.bottomPadding)
                }
            }
        }
        .onAppear {
            player.play()
            setupLooping()
        }
        .onDisappear {
            player.pause()
            if let observer = loopObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            VideoExportView(videoURL: videoURL) {
                showExportSheet = false
            }
            #if os(iOS)
            .presentationDetents([.medium])
            #endif
        }
    }

    private func setupLooping() {
        // Remove any existing observer first
        if let existing = loopObserver {
            NotificationCenter.default.removeObserver(existing)
        }

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [player] _ in
            player.seek(to: .zero)
            player.play()
        }
    }
}

#Preview {
    MontageView(
        videoURL: URL(fileURLWithPath: "/sample.mov"),
        videoCount: 5,
        onDismiss: {}
    )
}
