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

    /// Videos grouped by time period (This Week, Last Week, Earlier this month, etc.)
    var groupedVideos: [VideoGroup] {
        guard !allVideos.isEmpty else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        // Calculate week boundaries
        let startOfThisWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek)!
        let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        var thisWeek: [VideoDay] = []
        var lastWeek: [VideoDay] = []
        var earlierThisMonth: [VideoDay] = []
        var olderByMonth: [Date: [VideoDay]] = [:]

        for video in allVideos {
            // Skip today's video (shown separately in todayStatusCard)
            if calendar.isDate(video.date, inSameDayAs: startOfToday) {
                continue
            }

            if video.date >= startOfThisWeek {
                thisWeek.append(video)
            } else if video.date >= startOfLastWeek {
                lastWeek.append(video)
            } else if video.date >= startOfThisMonth {
                earlierThisMonth.append(video)
            } else {
                // Group by month for older videos
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: video.date))!
                olderByMonth[monthStart, default: []].append(video)
            }
        }

        var groups: [VideoGroup] = []

        if !thisWeek.isEmpty {
            groups.append(VideoGroup(title: "This Week", videos: thisWeek))
        }
        if !lastWeek.isEmpty {
            groups.append(VideoGroup(title: "Last Week", videos: lastWeek))
        }
        if !earlierThisMonth.isEmpty {
            groups.append(VideoGroup(title: "Earlier This Month", videos: earlierThisMonth))
        }

        // Add older months sorted by date (most recent first)
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"

        for monthStart in olderByMonth.keys.sorted(by: >) {
            if let videos = olderByMonth[monthStart], !videos.isEmpty {
                groups.append(VideoGroup(title: monthFormatter.string(from: monthStart), videos: videos))
            }
        }

        return groups
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

    /// Imports a video from external source (e.g., Photos library) for a specific date
    /// - Parameters:
    ///   - tempURL: URL to the video in temp directory
    ///   - date: The date to assign this video to
    /// - Returns: The newly created take
    func importVideo(from tempURL: URL, for date: Date) async throws -> VideoTake {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let takeNumber = await storageService.getNextTakeNumber(for: normalizedDate)
        let savedURL = try await storageService.saveVideo(from: tempURL, for: normalizedDate, takeNumber: takeNumber)

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)

        let newTake = VideoTake(
            date: normalizedDate,
            takeNumber: takeNumber,
            videoURL: savedURL,
            isSelected: false
        )

        await loadVideos()
        return newTake
    }

    /// Replaces a take with a trimmed version
    /// - Parameters:
    ///   - take: The original take to replace
    ///   - trimmedURL: URL to the trimmed video in temp directory
    /// - Returns: The new take with trimmed video
    func replaceTakeWithTrimmed(_ take: VideoTake, trimmedURL: URL) async throws -> VideoTake {
        // Delete the original take first
        try await storageService.deleteTake(take)

        // Save the trimmed video with the same date and take number
        let savedURL = try await storageService.saveVideo(
            from: trimmedURL,
            for: take.date,
            takeNumber: take.takeNumber
        )

        // Clean up temp file
        try? FileManager.default.removeItem(at: trimmedURL)

        let newTake = VideoTake(
            date: take.date,
            takeNumber: take.takeNumber,
            videoURL: savedURL,
            isSelected: take.isSelected
        )

        await loadVideos()
        return newTake
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
