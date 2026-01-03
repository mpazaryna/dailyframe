import Foundation

actor VideoStorageService {
    static let shared = VideoStorageService()

    private let containerIdentifier = "iCloud.com.paz.dailyframe"
    private let videosDirectoryName = "Videos"

    private var containerURL: URL?
    private var videosDirectoryURL: URL?
    private var isInitialized = false

    private init() {}

    func initializeStorage() async {
        guard !isInitialized else { return }

        if let url = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) {
            containerURL = url
            videosDirectoryURL = url.appendingPathComponent("Documents/\(videosDirectoryName)")
            try? FileManager.default.createDirectory(at: videosDirectoryURL!, withIntermediateDirectories: true)
            isInitialized = true
        } else {
            // Fallback to local storage if iCloud unavailable
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            videosDirectoryURL = documents.appendingPathComponent(videosDirectoryName)
            try? FileManager.default.createDirectory(at: videosDirectoryURL!, withIntermediateDirectories: true)
            isInitialized = true
        }
    }

    var isCloudAvailable: Bool {
        containerURL != nil
    }

    func getVideosDirectory() async -> URL? {
        if !isInitialized {
            await initializeStorage()
        }
        return videosDirectoryURL
    }

    func saveVideo(from temporaryURL: URL, for date: Date, takeNumber: Int) async throws -> URL {
        guard let directory = await getVideosDirectory() else {
            throw AppError.iCloudContainerNotFound
        }

        let fileName = DateUtilities.fileName(for: date, takeNumber: takeNumber)
        let destinationURL = directory.appendingPathComponent(fileName)

        // Remove existing file if present (shouldn't happen with unique take numbers)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        // Copy file to iCloud container
        try FileManager.default.copyItem(at: temporaryURL, to: destinationURL)

        // Set file protection for encryption at rest
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: destinationURL.path
        )

        return destinationURL
    }

    func deleteTake(_ take: VideoTake) async throws {
        guard FileManager.default.fileExists(atPath: take.videoURL.path) else {
            return
        }

        // Use NSFileCoordinator for safe iCloud deletion
        try await coordinatedDelete(at: take.videoURL)
    }

    func deleteAllTakes(for date: Date) async throws {
        guard let directory = await getVideosDirectory() else { return }

        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )

        let dateString = DateUtilities.fileNameFormatter.string(from: Calendar.current.startOfDay(for: date))

        for url in contents {
            if url.lastPathComponent.hasPrefix("video_\(dateString)_") {
                try await coordinatedDelete(at: url)
            }
        }
    }

    /// Performs a coordinated file deletion for safe iCloud sync
    private func coordinatedDelete(at url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?

            coordinator.coordinate(
                writingItemAt: url,
                options: .forDeleting,
                error: &coordinatorError
            ) { coordinatedURL in
                do {
                    try FileManager.default.removeItem(at: coordinatedURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            if let error = coordinatorError {
                continuation.resume(throwing: error)
            }
        }
    }

    func loadAllVideos() async -> [VideoDay] {
        guard let directory = await getVideosDirectory() else { return [] }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [
                    .creationDateKey,
                    .ubiquitousItemDownloadingStatusKey,
                    .ubiquitousItemIsDownloadingKey
                ],
                options: .skipsHiddenFiles
            )

            // Group takes by date
            var daysByDate: [Date: VideoDay] = [:]

            for url in contents {
                guard url.pathExtension == "mov",
                      let parsed = DateUtilities.parseFileName(url.lastPathComponent) else {
                    continue
                }

                // Trigger download for files not yet downloaded
                await triggerDownloadIfNeeded(for: url)

                let normalizedDate = Calendar.current.startOfDay(for: parsed.date)
                let createdAt = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? parsed.date

                let take = VideoTake(
                    date: normalizedDate,
                    takeNumber: parsed.takeNumber,
                    videoURL: url,
                    createdAt: createdAt
                )

                if var day = daysByDate[normalizedDate] {
                    day.takes.append(take)
                    day.takes.sort { $0.takeNumber < $1.takeNumber }
                    daysByDate[normalizedDate] = day
                } else {
                    daysByDate[normalizedDate] = VideoDay(date: normalizedDate, takes: [take])
                }
            }

            return daysByDate.values.sorted { $0.date > $1.date }
        } catch {
            return []
        }
    }

    /// Triggers download for iCloud files that aren't downloaded yet
    private func triggerDownloadIfNeeded(for url: URL) async {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])

            if let downloadStatus = resourceValues.ubiquitousItemDownloadingStatus {
                // If not current (fully downloaded), trigger download
                if downloadStatus != .current {
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                }
            }
        } catch {
            // Silently fail - file might not be ubiquitous or already downloading
        }
    }

    func getTodaysVideo() async -> VideoDay? {
        let today = DateUtilities.startOfDay()
        let allVideos = await loadAllVideos()
        return allVideos.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    func getNextTakeNumber(for date: Date) async -> Int {
        guard let todayVideo = await getTodaysVideo(),
              Calendar.current.isDate(todayVideo.date, inSameDayAs: date) else {
            return 1
        }
        return todayVideo.nextTakeNumber
    }
}
