import SwiftUI
import AVKit

struct MontageView: View {
    let videoURL: URL
    let clips: [MontageClip]
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
    @State private var timeObserver: Any?
    @State private var currentDate: Date?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    init(videoURL: URL, clips: [MontageClip], onDismiss: @escaping () -> Void) {
        self.videoURL = videoURL
        self.clips = clips
        self.onDismiss = onDismiss
        self._player = State(initialValue: AVPlayer(url: videoURL))
        // Set initial date to first clip
        self._currentDate = State(initialValue: clips.first?.date)
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
                            Text("\(clips.count) days")
                                .font(.system(size: config.captionFontSize))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding()

                    Spacer()

                    // Date overlay - subtle, bottom-left
                    HStack {
                        if let date = currentDate {
                            Text(Self.dateFormatter.string(from: date))
                                .font(.system(size: config.captionFontSize, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

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
            setupTimeObserver()
        }
        .onDisappear {
            player.pause()
            if let observer = loopObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = timeObserver {
                player.removeTimeObserver(observer)
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

    private func setupTimeObserver() {
        // Update every 0.1 seconds
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [clips] time in
            let currentSeconds = CMTimeGetSeconds(time)

            // Find which clip we're currently in
            for clip in clips {
                if currentSeconds >= clip.startTime && currentSeconds < clip.endTime {
                    if currentDate != clip.date {
                        currentDate = clip.date
                    }
                    break
                }
            }
        }
    }
}

#Preview {
    MontageView(
        videoURL: URL(fileURLWithPath: "/sample.mov"),
        clips: [
            MontageClip(date: Date(), startTime: 0, endTime: 3),
            MontageClip(date: Date().addingTimeInterval(-86400), startTime: 3, endTime: 6)
        ],
        onDismiss: {}
    )
}
