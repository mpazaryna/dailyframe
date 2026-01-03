import SwiftUI
import AVKit

struct VideoQAView: View {
    let videoURL: URL
    let takeNumber: Int
    let totalTakes: Int
    let onKeep: () -> Void
    let onRedo: () -> Void
    let onDelete: () -> Void
    let onTrimmed: ((URL) -> Void)?

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var config: VideoQALayoutConfig { VideoQALayoutConfig.current(sizeClass) }
    #else
    private var config: VideoQALayoutConfig { VideoQALayoutConfig.current }
    #endif

    @State private var player: AVPlayer
    @State private var loopObserver: NSObjectProtocol?
    @State private var showTrimming = false

    init(
        videoURL: URL,
        takeNumber: Int,
        totalTakes: Int,
        onKeep: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onTrimmed: ((URL) -> Void)? = nil
    ) {
        self.videoURL = videoURL
        self.takeNumber = takeNumber
        self.totalTakes = totalTakes
        self.onKeep = onKeep
        self.onRedo = onRedo
        self.onDelete = onDelete
        self.onTrimmed = onTrimmed
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
                    // Top bar with take info
                    HStack {
                        Text("Take \(takeNumber)")
                            .font(.system(size: config.headlineFontSize, weight: .semibold))
                            .foregroundStyle(.white)

                        if totalTakes > 1 {
                            Text("of \(totalTakes)")
                                .font(.system(size: config.bodyFontSize))
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial.opacity(0.5))

                    Spacer()

                    // QA decision buttons
                    HStack(spacing: config.actionButtonSpacing) {
                        QAButton(
                            title: "Delete",
                            systemImage: "trash",
                            style: .destructive,
                            config: config
                        ) {
                            player.pause()
                            onDelete()
                        }

                        if onTrimmed != nil {
                            QAButton(
                                title: "Trim",
                                systemImage: "scissors",
                                style: .secondary,
                                config: config
                            ) {
                                player.pause()
                                showTrimming = true
                            }
                        }

                        QAButton(
                            title: "Retake",
                            systemImage: "arrow.counterclockwise",
                            style: .secondary,
                            config: config
                        ) {
                            player.pause()
                            onRedo()
                        }

                        QAButton(
                            title: "Keep",
                            systemImage: "checkmark",
                            style: .primary,
                            config: config
                        ) {
                            player.pause()
                            onKeep()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + config.bottomPadding)
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showTrimming) {
            VideoTrimmingView(
                videoURL: videoURL,
                onCancel: {
                    showTrimming = false
                    player.seek(to: .zero)
                    player.play()
                },
                onComplete: { trimmedURL in
                    showTrimming = false
                    onTrimmed?(trimmedURL)
                }
            )
        }
        #else
        .sheet(isPresented: $showTrimming) {
            VideoTrimmingView(
                videoURL: videoURL,
                onCancel: {
                    showTrimming = false
                    player.seek(to: .zero)
                    player.play()
                },
                onComplete: { trimmedURL in
                    showTrimming = false
                    onTrimmed?(trimmedURL)
                }
            )
            .frame(minWidth: 600, minHeight: 500)
        }
        #endif
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

struct QAButton: View {
    enum Style {
        case primary
        case secondary
        case destructive
    }

    let title: String
    let systemImage: String
    let style: Style
    let config: VideoQALayoutConfig
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: config.actionButtonIconSize, weight: .medium))

                Text(title)
                    .font(.system(size: config.captionFontSize, weight: .medium))
            }
            .frame(width: config.actionButtonWidth, height: config.actionButtonHeight)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: config.actionButtonCornerRadius))
            .glassEffect()
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive:
            return .white
        case .secondary:
            return .primary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return .green
        case .secondary:
            return .clear
        case .destructive:
            return .red.opacity(0.8)
        }
    }
}

#Preview {
    VideoQAView(
        videoURL: URL(fileURLWithPath: "/sample.mov"),
        takeNumber: 1,
        totalTakes: 3,
        onKeep: {},
        onRedo: {},
        onDelete: {},
        onTrimmed: { _ in }
    )
}
