import SwiftUI

struct VideoListItemView: View {
    let video: VideoDay
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 60, height: 40)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                // Date info
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.displayDate)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(video.fileName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .background(.ultraThinMaterial.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 12) {
        VideoListItemView(
            video: VideoDay(date: Date(), videoURL: URL(fileURLWithPath: "/test.mov")),
            isSelected: true,
            onTap: {}
        )
        VideoListItemView(
            video: VideoDay(date: Date().addingTimeInterval(-86400), videoURL: URL(fileURLWithPath: "/test2.mov")),
            isSelected: false,
            onTap: {}
        )
    }
    .padding()
}
