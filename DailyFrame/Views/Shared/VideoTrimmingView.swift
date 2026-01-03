import SwiftUI
import AVKit

/// Video trimming view with thumbnail strip, range slider, and preview
struct VideoTrimmingView: View {
    let videoURL: URL
    let onCancel: () -> Void
    let onComplete: (URL) -> Void

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var config: VideoTrimmingConfig { VideoTrimmingConfig.current(sizeClass) }
    #else
    private var config: VideoTrimmingConfig { VideoTrimmingConfig.current }
    #endif

    // MARK: - View State

    enum ViewState {
        case loading
        case ready
        case exporting
        case error(String)
    }

    @State private var viewState: ViewState = .loading
    @State private var player: AVPlayer
    @State private var thumbnails: [CGImage] = []
    @State private var videoDuration: Double = 0
    @State private var startFraction: Double = 0
    @State private var endFraction: Double = 1
    @State private var isDragging = false
    @State private var loopObserver: NSObjectProtocol?
    @State private var timeObserver: Any?

    init(videoURL: URL, onCancel: @escaping () -> Void, onComplete: @escaping (URL) -> Void) {
        self.videoURL = videoURL
        self.onCancel = onCancel
        self.onComplete = onComplete
        self._player = State(initialValue: AVPlayer(url: videoURL))
    }

    // MARK: - Computed Properties

    private var startTime: Double { startFraction * videoDuration }
    private var endTime: Double { endFraction * videoDuration }
    private var trimmedDuration: Double { endTime - startTime }
    private var minimumRangeFraction: Double {
        guard videoDuration > 0 else { return 0.1 }
        return config.minimumDuration / videoDuration
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top bar
                    topBar

                    // Video player
                    VideoPlayer(player: player)
                        .disabled(true) // Disable built-in controls
                        .ignoresSafeArea()

                    Spacer()

                    // Trimming controls
                    trimmingControls(width: geometry.size.width)
                        .padding(.horizontal, config.cardPadding)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + config.bottomPadding)
                }

                // Loading/exporting overlay
                if case .loading = viewState {
                    loadingOverlay(message: "Loading video...")
                } else if case .exporting = viewState {
                    loadingOverlay(message: "Trimming...")
                } else if case .error(let message) = viewState {
                    errorOverlay(message: message)
                }
            }
        }
        .task {
            await loadVideo()
        }
        .onAppear {
            setupLooping()
        }
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Button {
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.system(size: config.bodyFontSize, weight: .medium))
                    .foregroundStyle(.white)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Trim Video")
                    .font(.system(size: config.headlineFontSize, weight: .semibold))
                    .foregroundStyle(.white)

                Text(formatDuration(trimmedDuration))
                    .font(.system(size: config.captionFontSize))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Button {
                Task { await trimAndComplete() }
            } label: {
                Text("Done")
                    .font(.system(size: config.bodyFontSize, weight: .semibold))
                    .foregroundStyle(.yellow)
            }
            .disabled(viewState != .ready)
        }
        .padding(.horizontal, config.cardPadding)
        .frame(height: config.topBarHeight)
        .background(.ultraThinMaterial.opacity(0.5))
    }

    private func trimmingControls(width: CGFloat) -> some View {
        VStack(spacing: 16) {
            // Time labels
            HStack {
                Text(formatDuration(startTime))
                    .font(.system(size: config.captionFontSize, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Text(formatDuration(endTime))
                    .font(.system(size: config.captionFontSize, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Thumbnail strip with range slider overlay
            ZStack {
                // Thumbnails
                if thumbnails.isEmpty {
                    ThumbnailStripPlaceholder(cornerRadius: config.thumbnailCornerRadius)
                } else {
                    ThumbnailStripView(
                        thumbnails: thumbnails,
                        cornerRadius: config.thumbnailCornerRadius
                    )
                }

                // Range slider
                TrimRangeSliderView(
                    startFraction: $startFraction,
                    endFraction: $endFraction,
                    minimumRangeFraction: minimumRangeFraction,
                    config: config,
                    onDraggingChanged: { dragging in
                        isDragging = dragging
                        if dragging {
                            player.pause()
                        } else {
                            seekToStart()
                            player.play()
                        }
                    },
                    onSeek: { fraction in
                        seekTo(fraction: fraction)
                    }
                )
            }
            .frame(height: config.thumbnailStripHeight)
        }
    }

    private func loadingOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)

                Text(message)
                    .font(.system(size: config.bodyFontSize))
                    .foregroundStyle(.white)
            }
        }
    }

    private func errorOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.yellow)

                Text(message)
                    .font(.system(size: config.bodyFontSize))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Button("Dismiss") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func loadVideo() async {
        do {
            let asset = AVURLAsset(url: videoURL)
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)

            guard durationSeconds > 0 else {
                viewState = .error("Invalid video duration")
                return
            }

            videoDuration = durationSeconds

            // Generate thumbnails
            let thumbs = try await VideoCompositionService.shared.generateThumbnails(
                for: videoURL,
                count: config.thumbnailCount
            )
            thumbnails = thumbs

            viewState = .ready
            player.play()
        } catch {
            viewState = .error("Failed to load video: \(error.localizedDescription)")
        }
    }

    private func trimAndComplete() async {
        viewState = .exporting
        player.pause()

        do {
            let trimmedURL = try await VideoCompositionService.shared.trimVideo(
                at: videoURL,
                startTime: startTime,
                endTime: endTime
            )
            onComplete(trimmedURL)
        } catch {
            viewState = .error("Failed to trim: \(error.localizedDescription)")
        }
    }

    private func seekTo(fraction: Double) {
        let time = CMTime(seconds: fraction * videoDuration, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func seekToStart() {
        let time = CMTime(seconds: startTime, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func setupLooping() {
        // Remove existing observer
        if let existing = loopObserver {
            NotificationCenter.default.removeObserver(existing)
        }

        // Set up looping within trim range
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [player] _ in
            seekToStart()
            player.play()
        }

        // Add periodic time observer to loop at end trim point
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [self] time in
            guard !isDragging else { return }
            let currentSeconds = CMTimeGetSeconds(time)
            if currentSeconds >= endTime {
                seekToStart()
            }
        }
    }

    private func cleanup() {
        player.pause()
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let fraction = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", mins, secs, fraction)
    }
}

// MARK: - State Equatable

extension VideoTrimmingView.ViewState: Equatable {
    static func == (lhs: VideoTrimmingView.ViewState, rhs: VideoTrimmingView.ViewState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading): return true
        case (.ready, .ready): return true
        case (.exporting, .exporting): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

#Preview {
    VideoTrimmingView(
        videoURL: URL(fileURLWithPath: "/sample.mov"),
        onCancel: {},
        onComplete: { _ in }
    )
}
