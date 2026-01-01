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

    func videoURL(for date: Date) async -> URL? {
        guard let directory = await getVideosDirectory() else { return nil }
        let fileName = DateUtilities.fileName(for: date)
        return directory.appendingPathComponent(fileName)
    }

    func saveVideo(from temporaryURL: URL, for date: Date) async throws -> URL {
        guard let directory = await getVideosDirectory() else {
            throw AppError.iCloudContainerNotFound
        }

        let fileName = DateUtilities.fileName(for: date)
        let destinationURL = directory.appendingPathComponent(fileName)

        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        // Copy file to iCloud container
        try FileManager.default.copyItem(at: temporaryURL, to: destinationURL)

        return destinationURL
    }

    func deleteVideo(for date: Date) async throws {
        guard let url = await videoURL(for: date),
              FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        try FileManager.default.removeItem(at: url)
    }

    func videoExists(for date: Date) async -> Bool {
        guard let url = await videoURL(for: date) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func loadAllVideos() async -> [VideoDay] {
        guard let directory = await getVideosDirectory() else { return [] }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )

            return contents.compactMap { url -> VideoDay? in
                guard url.pathExtension == "mov",
                      let date = DateUtilities.date(from: url.lastPathComponent) else {
                    return nil
                }

                let createdAt = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? date
                return VideoDay(date: date, videoURL: url, createdAt: createdAt)
            }.sorted { $0.date > $1.date }
        } catch {
            return []
        }
    }

    func getTodaysVideo() async -> VideoDay? {
        let today = DateUtilities.startOfDay()
        guard let url = await videoURL(for: today),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return VideoDay(date: today, videoURL: url)
    }
}
