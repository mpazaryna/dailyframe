import Foundation

struct VideoDay: Identifiable, Equatable, Hashable {
    let id: UUID
    let date: Date
    let videoURL: URL?
    let createdAt: Date

    init(id: UUID = UUID(), date: Date, videoURL: URL? = nil, createdAt: Date = Date()) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.videoURL = videoURL
        self.createdAt = createdAt
    }

    var fileName: String {
        "video_\(DateUtilities.fileNameFormatter.string(from: date)).mov"
    }

    var hasVideo: Bool {
        videoURL != nil
    }

    var displayDate: String {
        DateUtilities.displayFormatter.string(from: date)
    }

    static func == (lhs: VideoDay, rhs: VideoDay) -> Bool {
        lhs.id == rhs.id && lhs.date == rhs.date && lhs.videoURL == rhs.videoURL
    }
}
