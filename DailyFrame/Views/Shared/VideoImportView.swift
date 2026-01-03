import SwiftUI
import AVFoundation
import PhotosUI

// MARK: - Shared Components

/// Simple video thumbnail preview
struct VideoThumbnailView: View {
    let videoURL: URL
    @State private var thumbnail: CGImage?

    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(decorative: thumbnail, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)

        do {
            let (image, _) = try await generator.image(at: .zero)
            thumbnail = image
        } catch {
            // Leave as loading state
        }
    }
}

/// Extracts creation date from video metadata
func extractVideoCreationDate(from url: URL) async -> Date? {
    let asset = AVURLAsset(url: url)

    // Try to get creation date from video metadata
    do {
        let creationDate = try await asset.load(.creationDate)
        if let date = try await creationDate?.load(.dateValue) {
            return date
        }
    } catch {
        // Continue to fallbacks
    }

    // Try common metadata keys
    do {
        let metadata = try await asset.load(.metadata)
        for item in metadata {
            if item.commonKey == .commonKeyCreationDate,
               let dateValue = try await item.load(.dateValue) {
                return dateValue
            }
        }
    } catch {
        // Continue to fallbacks
    }

    // Fall back to file attributes
    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
        // Try modification date first (more likely to be original)
        if let modDate = attrs[.modificationDate] as? Date {
            return modDate
        }
        if let createDate = attrs[.creationDate] as? Date {
            return createDate
        }
    }

    return nil
}

// MARK: - iOS Implementation

#if os(iOS)
/// SwiftUI wrapper for PHPickerViewController to import videos from Photos library
struct VideoImportPicker: UIViewControllerRepresentable {
    let onVideoSelected: (URL, Date?) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .videos
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onVideoSelected: onVideoSelected, onCancel: onCancel)
    }

    @MainActor
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onVideoSelected: (URL, Date?) -> Void
        let onCancel: () -> Void

        init(onVideoSelected: @escaping (URL, Date?) -> Void, onCancel: @escaping () -> Void) {
            self.onVideoSelected = onVideoSelected
            self.onCancel = onCancel
        }

        nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                Task { @MainActor [weak self] in
                    self?.onCancel()
                }
                return
            }

            // Load video as file URL
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let url = url else {
                    Task { @MainActor [weak self] in
                        self?.onCancel()
                    }
                    return
                }

                // Copy to temp directory since the provided URL is temporary
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("import_\(UUID().uuidString).mov")

                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)

                    // Extract creation date from the video file
                    Task {
                        let creationDate = await extractVideoCreationDate(from: tempURL)
                        Task { @MainActor [weak self] in
                            self?.onVideoSelected(tempURL, creationDate)
                        }
                    }
                } catch {
                    Task { @MainActor [weak self] in
                        self?.onCancel()
                    }
                }
            }
        }
    }
}

/// View for importing a video and assigning it to a date (iOS)
struct VideoImportView: View {
    let onImport: (URL, Date) -> Void
    let onCancel: () -> Void

    @State private var importedVideoURL: URL?
    @State private var selectedDate = Date()
    @State private var isProcessing = false
    @State private var showDateConfirmation = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var config: VideoQALayoutConfig { VideoQALayoutConfig.current(sizeClass) }

    var body: some View {
        NavigationStack {
            Group {
                if showDateConfirmation, let videoURL = importedVideoURL {
                    dateConfirmationView(videoURL: videoURL)
                } else {
                    VideoImportPicker(
                        onVideoSelected: { url, date in
                            importedVideoURL = url
                            if let date = date {
                                selectedDate = date
                            }
                            showDateConfirmation = true
                        },
                        onCancel: onCancel
                    )
                }
            }
            .navigationTitle(showDateConfirmation ? "Confirm Import" : "Import Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cleanup()
                        onCancel()
                    }
                }
            }
        }
    }

    private func dateConfirmationView(videoURL: URL) -> some View {
        VStack(spacing: 24) {
            // Video preview
            VideoThumbnailView(videoURL: videoURL)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

            // Date display/edit
            VStack(alignment: .leading, spacing: 8) {
                Text("Video date")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("Date extracted from video. Adjust if needed.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)

            Spacer()

            // Import button
            Button {
                isProcessing = true
                onImport(videoURL, selectedDate)
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text(isProcessing ? "Importing..." : "Import Video")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isProcessing ? Color.gray : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isProcessing)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func cleanup() {
        if let url = importedVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
#endif

// MARK: - macOS Implementation

#if os(macOS)
import AppKit

/// SwiftUI wrapper for PHPickerViewController on macOS
struct VideoImportPicker: NSViewControllerRepresentable {
    let onVideoSelected: (URL, Date?) -> Void
    let onCancel: () -> Void

    func makeNSViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .videos
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateNSViewController(_ nsViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onVideoSelected: onVideoSelected, onCancel: onCancel)
    }

    @MainActor
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onVideoSelected: (URL, Date?) -> Void
        let onCancel: () -> Void

        init(onVideoSelected: @escaping (URL, Date?) -> Void, onCancel: @escaping () -> Void) {
            self.onVideoSelected = onVideoSelected
            self.onCancel = onCancel
        }

        nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                Task { @MainActor [weak self] in
                    self?.onCancel()
                }
                return
            }

            // Load video as file URL
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let url = url else {
                    Task { @MainActor [weak self] in
                        self?.onCancel()
                    }
                    return
                }

                // Copy to temp directory since the provided URL is temporary
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("import_\(UUID().uuidString).mov")

                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)

                    // Extract creation date from the video file
                    Task {
                        let creationDate = await extractVideoCreationDate(from: tempURL)
                        Task { @MainActor [weak self] in
                            self?.onVideoSelected(tempURL, creationDate)
                        }
                    }
                } catch {
                    Task { @MainActor [weak self] in
                        self?.onCancel()
                    }
                }
            }
        }
    }
}

/// View for importing a video and assigning it to a date (macOS)
struct VideoImportView: View {
    let onImport: (URL, Date) -> Void
    let onCancel: () -> Void

    @State private var importedVideoURL: URL?
    @State private var selectedDate = Date()
    @State private var isProcessing = false
    @State private var showDateConfirmation = false

    private var config: VideoQALayoutConfig { VideoQALayoutConfig.current }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Button("Cancel") {
                    cleanup()
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Text(showDateConfirmation ? "Confirm Import" : "Import Video")
                    .font(.headline)

                Spacer()

                // Spacer for balance
                Button("Cancel") {}
                    .hidden()
            }
            .padding()
            .background(.bar)

            Divider()

            // Content
            if showDateConfirmation, let videoURL = importedVideoURL {
                dateConfirmationView(videoURL: videoURL)
            } else {
                VideoImportPicker(
                    onVideoSelected: { url, date in
                        importedVideoURL = url
                        if let date = date {
                            selectedDate = date
                        }
                        showDateConfirmation = true
                    },
                    onCancel: onCancel
                )
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    private func dateConfirmationView(videoURL: URL) -> some View {
        VStack(spacing: 20) {
            // Video preview
            VideoThumbnailView(videoURL: videoURL)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .padding(.top)

            // Date display/edit
            VStack(alignment: .leading, spacing: 8) {
                Text("Video date")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.field)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("Date extracted from video. Adjust if needed.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)

            Spacer()

            // Import button
            HStack {
                Button("Back") {
                    showDateConfirmation = false
                    importedVideoURL = nil
                }

                Spacer()

                Button {
                    isProcessing = true
                    onImport(videoURL, selectedDate)
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(isProcessing ? "Importing..." : "Import Video")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
            .padding()
        }
    }

    private func cleanup() {
        if let url = importedVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
#endif

#Preview {
    VideoImportView(
        onImport: { _, _ in },
        onCancel: {}
    )
}
