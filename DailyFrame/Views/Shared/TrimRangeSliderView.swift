import SwiftUI
#if os(iOS)
import UIKit
#endif

/// A range slider for video trimming with draggable start/end handles
struct TrimRangeSliderView: View {
    /// Start position as fraction (0-1)
    @Binding var startFraction: Double
    /// End position as fraction (0-1)
    @Binding var endFraction: Double
    /// Minimum range between start and end (as fraction)
    let minimumRangeFraction: Double
    /// Configuration for layout
    let config: VideoTrimmingConfig
    /// Called when user starts/stops dragging
    var onDraggingChanged: ((Bool) -> Void)?
    /// Called when playhead should seek to position
    var onSeek: ((Double) -> Void)?

    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    @State private var lastHapticPosition: Double?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let handleWidth = config.handleSize
            let usableWidth = width - (handleWidth * 2)

            ZStack(alignment: .leading) {
                // Dimmed regions outside selection
                HStack(spacing: 0) {
                    // Left dimmed region
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: handleWidth + (usableWidth * startFraction))

                    Spacer()

                    // Right dimmed region
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: handleWidth + (usableWidth * (1 - endFraction)))
                }

                // Selection border (top and bottom lines)
                let startX = handleWidth + (usableWidth * startFraction)
                let endX = handleWidth + (usableWidth * endFraction)
                let selectionWidth = endX - startX

                Rectangle()
                    .fill(Color.clear)
                    .frame(width: max(0, selectionWidth))
                    .overlay(
                        Rectangle()
                            .stroke(Color.yellow, lineWidth: 3)
                    )
                    .offset(x: startX)

                // Start handle
                TrimHandle(
                    isStart: true,
                    config: config,
                    isDragging: isDraggingStart
                )
                .offset(x: usableWidth * startFraction)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDraggingStart {
                                isDraggingStart = true
                                onDraggingChanged?(true)
                            }
                            let newFraction = value.location.x / usableWidth
                            let clampedFraction = min(
                                max(0, newFraction),
                                endFraction - minimumRangeFraction
                            )
                            startFraction = clampedFraction
                            triggerBoundaryHaptic(fraction: clampedFraction, isBoundary: clampedFraction <= 0.001)
                            onSeek?(clampedFraction)
                        }
                        .onEnded { _ in
                            isDraggingStart = false
                            onDraggingChanged?(false)
                            lastHapticPosition = nil
                        }
                )

                // End handle
                TrimHandle(
                    isStart: false,
                    config: config,
                    isDragging: isDraggingEnd
                )
                .offset(x: handleWidth + (usableWidth * endFraction))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDraggingEnd {
                                isDraggingEnd = true
                                onDraggingChanged?(true)
                            }
                            let newFraction = (value.location.x - handleWidth) / usableWidth
                            let clampedFraction = max(
                                min(1, newFraction),
                                startFraction + minimumRangeFraction
                            )
                            endFraction = clampedFraction
                            triggerBoundaryHaptic(fraction: clampedFraction, isBoundary: clampedFraction >= 0.999)
                            onSeek?(clampedFraction)
                        }
                        .onEnded { _ in
                            isDraggingEnd = false
                            onDraggingChanged?(false)
                            lastHapticPosition = nil
                        }
                )
            }
        }
        .frame(height: config.sliderTrackHeight)
    }

    private func triggerBoundaryHaptic(fraction: Double, isBoundary: Bool) {
        #if os(iOS)
        // Only trigger haptic when hitting a boundary
        if isBoundary {
            if lastHapticPosition == nil || abs(fraction - (lastHapticPosition ?? 0)) > 0.01 {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                lastHapticPosition = fraction
            }
        } else {
            lastHapticPosition = nil
        }
        #endif
    }
}

/// Individual trim handle (left or right edge)
struct TrimHandle: View {
    let isStart: Bool
    let config: VideoTrimmingConfig
    let isDragging: Bool

    var body: some View {
        ZStack {
            // Handle background
            RoundedRectangle(cornerRadius: isStart ? 8 : 8, style: .continuous)
                .fill(Color.yellow)
                .frame(width: config.handleSize, height: config.sliderTrackHeight)

            // Grip lines
            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: config.handleGripWidth, height: 12)
                }
            }
        }
        .scaleEffect(isDragging ? 1.1 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isDragging)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var start = 0.2
        @State private var end = 0.8

        #if os(iOS)
        private var config: VideoTrimmingConfig { VideoTrimmingConfig.current(nil) }
        #else
        private var config: VideoTrimmingConfig { VideoTrimmingConfig.current }
        #endif

        var body: some View {
            VStack(spacing: 20) {
                Text("Start: \(start, specifier: "%.2f") End: \(end, specifier: "%.2f")")
                    .foregroundStyle(.white)

                ZStack {
                    // Fake thumbnail background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple, .pink, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    TrimRangeSliderView(
                        startFraction: $start,
                        endFraction: $end,
                        minimumRangeFraction: 0.1,
                        config: config
                    )
                }
                .frame(height: 50)
                .padding()
            }
            .background(Color.black)
        }
    }

    return PreviewWrapper()
}
