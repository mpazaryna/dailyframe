import SwiftUI
import AVKit

struct VideoQAView: View {
    let videoURL: URL
    let onKeep: () -> Void
    let onRedo: () -> Void

    @State private var player: AVPlayer?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()

                // Video player
                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                }

                // Controls overlay
                VStack {
                    Spacer()

                    // QA decision buttons
                    HStack(spacing: 40) {
                        // Redo button
                        QAButton(
                            title: "Redo",
                            systemImage: "arrow.counterclockwise",
                            style: .secondary
                        ) {
                            player?.pause()
                            onRedo()
                        }

                        // Keep button
                        QAButton(
                            title: "Keep",
                            systemImage: "checkmark",
                            style: .primary
                        ) {
                            player?.pause()
                            onKeep()
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 40)
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        let avPlayer = AVPlayer(url: videoURL)
        avPlayer.play()
        player = avPlayer

        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            avPlayer.play()
        }
    }
}

struct QAButton: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let systemImage: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .medium))

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(width: 100, height: 80)
            .foregroundStyle(style == .primary ? .white : .primary)
            .background(style == .primary ? Color.green : Color.clear)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .glassEffect()
        }
    }
}

#Preview {
    VideoQAView(
        videoURL: URL(fileURLWithPath: "/sample.mov"),
        onKeep: {},
        onRedo: {}
    )
}
