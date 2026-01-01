import Foundation
import SwiftUI
import Combine

@MainActor
final class VideoManagerViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var recordingState: RecordingState = .idle
    @Published private(set) var syncState: SyncState = .idle
    @Published private(set) var currentVideo: VideoDay?
    @Published private(set) var allVideos: [VideoDay] = []
    @Published private(set) var todayHasVideo: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var showExportSheet: Bool = false

    // MARK: - Services

    private let cameraService = CameraService()
    private let storageService = VideoStorageService.shared
    private let syncService = iCloudSyncService.shared
    private let exportService = VideoExportService.shared

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var canRecord: Bool {
        Platform.current.supportsCamera && recordingState.canRecord && !todayHasVideo
    }

    var isRecording: Bool {
        recordingState.isRecording
    }

    // MARK: - Initialization

    init() {
        setupBindings()
        Task {
            await loadVideos()
        }
    }

    private func setupBindings() {
        syncService.$syncState
            .receive(on: DispatchQueue.main)
            .assign(to: &$syncState)
    }

    // MARK: - Video Management

    func loadVideos() async {
        allVideos = await storageService.loadAllVideos()
        todayHasVideo = await storageService.videoExists(for: DateUtilities.startOfDay())
        currentVideo = await storageService.getTodaysVideo()
    }

    func refreshVideos() {
        Task {
            await loadVideos()
            syncService.refreshSync()
        }
    }

    // MARK: - Recording

    func prepareCamera() async {
        guard Platform.current.supportsCamera else { return }

        do {
            recordingState = .preparing
            try await cameraService.setupSession()
            cameraService.startSession()
            recordingState = .idle
        } catch let error as AppError {
            handleError(error)
        } catch {
            handleError(.unknown(error.localizedDescription))
        }
    }

    func startRecording() async {
        guard canRecord else {
            if todayHasVideo {
                handleError(.alreadyRecordedToday)
            }
            return
        }

        do {
            recordingState = .recording
            let tempURL = try await cameraService.startRecording()

            // Recording stopped, now save
            recordingState = .saving
            let savedURL = try await storageService.saveVideo(from: tempURL, for: Date())

            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)

            currentVideo = VideoDay(date: Date(), videoURL: savedURL)
            todayHasVideo = true
            recordingState = .saved(savedURL)

            // Transition to review
            recordingState = .reviewing
        } catch let error as AppError {
            recordingState = .error(error.localizedDescription)
            handleError(error)
        } catch {
            recordingState = .error(error.localizedDescription)
            handleError(.recordingFailed(error.localizedDescription))
        }
    }

    func stopRecording() {
        cameraService.stopRecording()
    }

    func stopCamera() {
        cameraService.stopSession()
    }

    // MARK: - QA Actions

    func keepVideo() {
        showExportSheet = true
    }

    func redoVideo() async {
        guard let video = currentVideo else { return }

        do {
            try await storageService.deleteVideo(for: video.date)
            currentVideo = nil
            todayHasVideo = false
            recordingState = .idle
            await loadVideos()
        } catch {
            handleError(.unknown(error.localizedDescription))
        }
    }

    func finishReview() {
        recordingState = .idle
        showExportSheet = false
    }

    // MARK: - Export

    func triggerExport() {
        showExportSheet = true
    }

    func exportCurrentVideo() async {
        guard let video = currentVideo, let url = video.videoURL else { return }

        do {
            try await exportService.exportVideo(at: url)
        } catch let error as AppError {
            handleError(error)
        } catch {
            handleError(.exportFailed(error.localizedDescription))
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: AppError) {
        errorMessage = error.localizedDescription
        showError = true
        recordingState = .error(error.localizedDescription)
    }

    func dismissError() {
        showError = false
        errorMessage = ""
        if case .error = recordingState {
            recordingState = .idle
        }
    }
}
