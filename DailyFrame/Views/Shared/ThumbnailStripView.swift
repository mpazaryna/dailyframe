import SwiftUI
import AVFoundation

/// Displays a horizontal strip of video frame thumbnails
struct ThumbnailStripView: View {
    let thumbnails: [CGImage]
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, thumbnail in
                    Image(decorative: thumbnail, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: geometry.size.width / CGFloat(max(thumbnails.count, 1)),
                            height: geometry.size.height
                        )
                        .clipped()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Loading placeholder for thumbnail strip
struct ThumbnailStripPlaceholder: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial)
            .overlay {
                ProgressView()
                    .tint(.white)
            }
    }
}

#Preview {
    VStack {
        ThumbnailStripPlaceholder(cornerRadius: 8)
            .frame(height: 50)
            .padding()
    }
    .background(Color.black)
}
