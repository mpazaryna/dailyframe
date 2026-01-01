import SwiftUI

struct VideoExportView: View {
    let videoURL: URL
    let onDismiss: () -> Void

    @StateObject private var exportViewModel = ExportViewModel()

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)

                Text("Export Video")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(videoURL.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Export options
            VStack(spacing: 12) {
                ExportOptionButton(
                    title: "Share",
                    subtitle: "AirDrop, Messages, Mail, and more",
                    systemImage: "square.and.arrow.up"
                ) {
                    Task {
                        await exportViewModel.exportVideo(at: videoURL)
                    }
                }

                #if os(macOS)
                ExportOptionButton(
                    title: "Save As...",
                    subtitle: "Save to a specific location",
                    systemImage: "folder"
                ) {
                    Task {
                        _ = await exportViewModel.saveVideoToLocation(from: videoURL)
                    }
                }
                #endif
            }

            Spacer()

            // Done button
            Button("Done") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .frame(minWidth: 300, minHeight: 350)
        .background(.ultraThinMaterial)
        .glassEffect()
        .alert("Export Error", isPresented: $exportViewModel.showError) {
            Button("OK") {
                exportViewModel.reset()
            }
        } message: {
            Text(exportViewModel.errorMessage)
        }
    }
}

struct ExportOptionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VideoExportView(
        videoURL: URL(fileURLWithPath: "/sample.mov"),
        onDismiss: {}
    )
}
