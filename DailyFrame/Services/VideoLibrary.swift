import Foundation
import SwiftUI
import Combine

/// Main service for video storage and sync - injected via Environment
@Observable
@MainActor
final class VideoLibrary {
    private(set) var allVideos: [VideoDay] = []
    private(set) var todayVideo: VideoDay?
    private(set) var syncState: SyncState = .idle
    private(set) var isCloudAvailable: Bool = false

    private let storageService = VideoStorageService.shared
    private let syncService = iCloudSyncService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSyncObserver()
        Task {
            await initializeAndLoad()
        }
    }

    var todaysTakes: [VideoTake] {
        todayVideo?.takes ?? []
    }

    var hasTodaysTakes: Bool {
        !todaysTakes.isEmpty
    }

    /// Set of all dates that have recorded videos (normalized to start of day)
    var recordedDates: Set<Date> {
        Set(allVideos.map { Calendar.current.startOfDay(for: $0.date) })
    }

    /// Current streak of consecutive days with recordings
    var currentStreak: Int {
        guard !allVideos.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let recorded = recordedDates

        // Start from today or yesterday (allow for not having recorded today yet)
        var checkDate = today
        if !recorded.contains(today) {
            // Check if yesterday has a recording to continue streak
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  recorded.contains(yesterday) else {
                return 0
            }
            checkDate = yesterday
        }

        // Count consecutive days backward
        var streak = 0
        while recorded.contains(checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previousDay
        }

        return streak
    }

    /// Earliest recorded date (for calendar range)
    var earliestDate: Date? {
        allVideos.last?.date
    }

    // MARK: - Initialization

    private func setupSyncObserver() {
        // Observe sync state changes and reload videos when sync updates
        syncService.$syncState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.syncState = newState
                // Reload when sync completes or updates
                if newState == .synced {
                    Task { [weak self] in
                        await self?.loadVideos()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func initializeAndLoad() async {
        // Initialize storage first
        await storageService.initializeStorage()
        isCloudAvailable = await storageService.isCloudAvailable

        // Load videos
        await loadVideos()

        // Trigger initial sync check
        syncService.refreshSync()
    }

    // MARK: - Video Management

    func loadVideos() async {
        allVideos = await storageService.loadAllVideos()
        todayVideo = await storageService.getTodaysVideo()
        syncState = syncService.syncState
    }

    func refresh() async {
        syncService.refreshSync()
        // Small delay to allow sync to start downloading
        try? await Task.sleep(for: .milliseconds(500))
        await loadVideos()
    }

    // MARK: - Recording

    func saveRecording(from tempURL: URL) async throws -> VideoTake {
        let takeNumber = await storageService.getNextTakeNumber(for: Date())
        let savedURL = try await storageService.saveVideo(from: tempURL, for: Date(), takeNumber: takeNumber)

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)

        let newTake = VideoTake(
            date: Date(),
            takeNumber: takeNumber,
            videoURL: savedURL,
            isSelected: false
        )

        await loadVideos()
        return newTake
    }

    // MARK: - Take Management

    func deleteTake(_ take: VideoTake) async throws {
        try await storageService.deleteTake(take)
        await loadVideos()
    }

    func deleteAllTodaysTakes() async throws {
        try await storageService.deleteAllTakes(for: Date())
        await loadVideos()
    }

    func getNextTakeNumber() async -> Int {
        await storageService.getNextTakeNumber(for: Date())
    }
}

// MARK: - Environment Key

struct VideoLibraryKey: EnvironmentKey {
    static let defaultValue: VideoLibrary? = nil
}

extension EnvironmentValues {
    var videoLibrary: VideoLibrary? {
        get { self[VideoLibraryKey.self] }
        set { self[VideoLibraryKey.self] = newValue }
    }
}
