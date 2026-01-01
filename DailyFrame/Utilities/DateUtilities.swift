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

    static func fileName(for date: Date, takeNumber: Int) -> String {
        "video_\(fileNameFormatter.string(from: date))_\(String(format: "%03d", takeNumber)).mov"
    }

    /// Parse filename to extract date and take number
    /// Format: video_YYYY-MM-DD_NNN.mov
    static func parseFileName(_ fileName: String) -> (date: Date, takeNumber: Int)? {
        let pattern = "video_(\\d{4}-\\d{2}-\\d{2})_(\\d{3})\\.mov"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: fileName, range: NSRange(fileName.startIndex..., in: fileName)),
              let dateRange = Range(match.range(at: 1), in: fileName),
              let takeRange = Range(match.range(at: 2), in: fileName) else {
            return nil
        }
        let dateString = String(fileName[dateRange])
        let takeString = String(fileName[takeRange])
        guard let date = fileNameFormatter.date(from: dateString),
              let takeNumber = Int(takeString) else {
            return nil
        }
        return (date, takeNumber)
    }
}
