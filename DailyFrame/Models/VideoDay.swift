import Foundation

/// Represents a single video take
struct VideoTake: Identifiable, Equatable, Hashable {
    let id: UUID
    let date: Date
    let takeNumber: Int
    let videoURL: URL
    let createdAt: Date
    var isSelected: Bool

    init(id: UUID = UUID(), date: Date, takeNumber: Int, videoURL: URL, createdAt: Date = Date(), isSelected: Bool = false) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.takeNumber = takeNumber
        self.videoURL = videoURL
        self.createdAt = createdAt
        self.isSelected = isSelected
    }

    var fileName: String {
        "video_\(DateUtilities.fileNameFormatter.string(from: date))_\(String(format: "%03d", takeNumber)).mov"
    }

    var displayName: String {
        "Take \(takeNumber)"
    }
}

/// Represents a day with potentially multiple takes
struct VideoDay: Identifiable, Equatable, Hashable {
    let id: UUID
    let date: Date
    var takes: [VideoTake]

    init(id: UUID = UUID(), date: Date, takes: [VideoTake] = []) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.takes = takes
    }

    /// The selected take (the "DailyFrame" for this day)
    var selectedTake: VideoTake? {
        takes.first(where: { $0.isSelected }) ?? takes.last
    }

    var videoURL: URL? {
        selectedTake?.videoURL
    }

    var hasVideo: Bool {
        !takes.isEmpty
    }

    var takeCount: Int {
        takes.count
    }

    var displayDate: String {
        DateUtilities.displayFormatter.string(from: date)
    }

    var nextTakeNumber: Int {
        (takes.map(\.takeNumber).max() ?? 0) + 1
    }

    static func == (lhs: VideoDay, rhs: VideoDay) -> Bool {
        lhs.id == rhs.id && lhs.date == rhs.date
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(date)
    }
}
