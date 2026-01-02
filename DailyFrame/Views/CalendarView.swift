import SwiftUI

struct CalendarView: View {
    @Environment(\.videoLibrary) private var library

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var config: CalendarLayoutConfig { CalendarLayoutConfig.current(sizeClass) }
    #else
    private var config: CalendarLayoutConfig { CalendarLayoutConfig.current }
    #endif

    let onSelectDay: (VideoDay) -> Void
    let onDismiss: () -> Void

    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Streak banner
                    if let library = library, library.currentStreak > 0 {
                        streakBanner(streak: library.currentStreak)
                    }

                    // Calendar months
                    LazyVStack(spacing: 32) {
                        ForEach(generateMonths(), id: \.self) { monthDate in
                            monthView(for: monthDate)
                        }
                    }
                    .padding(.horizontal, config.horizontalPadding)
                }
                .padding(.vertical)
            }
            #if os(iOS)
            .background(Color(.systemGroupedBackground))
            #else
            .background(.clear)
            #endif
            .navigationTitle("Calendar")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                }
            }
            #endif
        }
    }

    // MARK: - Streak Banner

    private func streakBanner(streak: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text("\(streak) day streak!")
                .font(.system(size: config.streakFontSize, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .glassEffect()
    }

    // MARK: - Month View

    private func monthView(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Month header
            Text(monthYearString(for: date))
                .font(.system(size: config.monthHeaderFontSize, weight: .bold))
                .foregroundStyle(.primary)

            // Weekday headers
            weekdayHeader

            // Days grid
            let days = daysInMonth(for: date)
            let columns = Array(repeating: GridItem(.flexible(), spacing: config.cellSpacing), count: 7)

            LazyVGrid(columns: columns, spacing: config.cellSpacing) {
                ForEach(days, id: \.self) { day in
                    if let day = day {
                        CalendarDayCell(
                            date: day,
                            hasVideo: library?.recordedDates.contains(calendar.startOfDay(for: day)) ?? false,
                            isToday: calendar.isDateInToday(day),
                            config: config
                        ) {
                            // Find and return the VideoDay for this date
                            if let videoDay = library?.allVideos.first(where: {
                                calendar.isDate($0.date, inSameDayAs: day)
                            }) {
                                onSelectDay(videoDay)
                            }
                        }
                    } else {
                        // Empty cell for padding
                        Color.clear
                            .frame(width: config.cellSize, height: config.cellSize)
                    }
                }
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: config.cellSpacing) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: config.weekdayFontSize, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Date Helpers

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func generateMonths() -> [Date] {
        let today = Date()
        let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!

        // Go back to earliest video or 6 months, whichever is more recent
        let earliestVideo = library?.earliestDate ?? today
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: today)!
        let startDate = max(calendar.startOfDay(for: earliestVideo), sixMonthsAgo)
        let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: startDate))!

        var months: [Date] = []
        var currentMonth = startOfCurrentMonth

        // Generate months from current back to start
        while currentMonth >= startMonth {
            months.append(currentMonth)
            guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) else {
                break
            }
            currentMonth = previousMonth
        }

        return months
    }

    private func daysInMonth(for monthDate: Date) -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: monthDate)!
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)

        var days: [Date?] = []

        // Add empty cells for days before the first of the month
        for _ in 1..<firstWeekday {
            days.append(nil)
        }

        // Add actual days
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }

        return days
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let hasVideo: Bool
    let isToday: Bool
    let config: CalendarLayoutConfig
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: {
            if hasVideo {
                onTap()
            }
        }) {
            ZStack {
                // Background
                if hasVideo {
                    Circle()
                        .fill(.green.opacity(0.15))
                } else if isToday {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .foregroundStyle(.blue.opacity(0.5))
                }

                // Content
                if hasVideo {
                    Image(systemName: "checkmark")
                        .font(.system(size: config.checkmarkSize, weight: .bold))
                        .foregroundStyle(.green)
                } else {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: config.dayFontSize, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? Color.blue : (isFutureDate ? Color.secondary.opacity(0.4) : Color.primary))
                }

                // Today ring
                if isToday && hasVideo {
                    Circle()
                        .strokeBorder(.blue, lineWidth: 2)
                }
            }
            .frame(width: config.cellSize, height: config.cellSize)
        }
        .buttonStyle(.plain)
        .disabled(!hasVideo)
    }

    private var isFutureDate: Bool {
        date > Date()
    }
}

#Preview {
    CalendarView(
        onSelectDay: { _ in },
        onDismiss: {}
    )
    .environment(\.videoLibrary, VideoLibrary())
}
