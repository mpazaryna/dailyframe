import Foundation
import SwiftUI

#if os(iOS)
import UIKit

@MainActor
final class VideoExportService: ObservableObject {
    static let shared = VideoExportService()

    @Published var isExporting = false
    @Published var exportError: AppError?

    private init() {}

    func exportVideo(at url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AppError.fileNotFound(url.lastPathComponent)
        }

        isExporting = true
        defer { isExporting = false }

        await withCheckedContinuation { continuation in
            let activityController = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )

            activityController.completionWithItemsHandler = { _, _, _, error in
                if let error = error {
                    self.exportError = AppError.exportFailed(error.localizedDescription)
                }
                continuation.resume()
            }

            // Present the activity controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                var topController = rootViewController
                while let presented = topController.presentedViewController {
                    topController = presented
                }

                // iPad requires popover presentation
                if let popover = activityController.popoverPresentationController {
                    popover.sourceView = topController.view
                    popover.sourceRect = CGRect(
                        x: topController.view.bounds.midX,
                        y: topController.view.bounds.midY,
                        width: 0,
                        height: 0
                    )
                    popover.permittedArrowDirections = []
                }

                topController.present(activityController, animated: true)
            }
        }
    }
}

#elseif os(macOS)
import AppKit

@MainActor
final class VideoExportService: ObservableObject {
    static let shared = VideoExportService()

    @Published var isExporting = false
    @Published var exportError: AppError?

    private init() {}

    func exportVideo(at url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AppError.fileNotFound(url.lastPathComponent)
        }

        isExporting = true
        defer { isExporting = false }

        let picker = NSSharingServicePicker(items: [url])

        guard let window = NSApplication.shared.keyWindow,
              let contentView = window.contentView else {
            throw AppError.exportFailed("No window available")
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)

            // NSSharingServicePicker doesn't have a completion handler
            // We just resume immediately after showing
            continuation.resume()
        }
    }

    func saveVideoToLocation(from url: URL) async throws -> URL? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AppError.fileNotFound(url.lastPathComponent)
        }

        return await withCheckedContinuation { continuation in
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.quickTimeMovie]
            savePanel.nameFieldStringValue = url.lastPathComponent
            savePanel.canCreateDirectories = true

            savePanel.begin { response in
                if response == .OK, let destinationURL = savePanel.url {
                    do {
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try FileManager.default.removeItem(at: destinationURL)
                        }
                        try FileManager.default.copyItem(at: url, to: destinationURL)
                        continuation.resume(returning: destinationURL)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
#endif
