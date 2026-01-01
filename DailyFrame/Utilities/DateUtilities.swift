import Foundation

enum DateUtilities {
    static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let fullDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    static func startOfDay(for date: Date = Date()) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    static func fileName(for date: Date) -> String {
        "video_\(fileNameFormatter.string(from: date)).mov"
    }

    static func date(from fileName: String) -> Date? {
        let pattern = "video_(\\d{4}-\\d{2}-\\d{2})\\.mov"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: fileName, range: NSRange(fileName.startIndex..., in: fileName)),
              let dateRange = Range(match.range(at: 1), in: fileName) else {
            return nil
        }
        let dateString = String(fileName[dateRange])
        return fileNameFormatter.date(from: dateString)
    }
}
