import Foundation
import SwiftUI

@MainActor
final class ExportViewModel: ObservableObject {
    @Published var isExporting = false
    @Published var exportComplete = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let exportService = VideoExportService.shared

    func exportVideo(at url: URL) async {
        isExporting = true
        defer { isExporting = false }

        do {
            try await exportService.exportVideo(at: url)
            exportComplete = true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    #if os(macOS)
    func saveVideoToLocation(from url: URL) async -> URL? {
        isExporting = true
        defer { isExporting = false }

        do {
            if let savedURL = try await exportService.saveVideoToLocation(from: url) {
                exportComplete = true
                return savedURL
            }
            return nil
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }
    #endif

    func reset() {
        exportComplete = false
        showError = false
        errorMessage = ""
    }
}
