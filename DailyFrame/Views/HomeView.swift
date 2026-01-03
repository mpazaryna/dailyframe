import SwiftUI
import AVKit

// MARK: - Home View

/// Unified home view that adapts to iPhone, iPad, and macOS.
/// - iPhone/iPad: Shows today's status, recent videos, and record button
/// - macOS: Shows sidebar-based video browser (no recording)
struct HomeView: View {
    @Environment(\.videoLibrary) private var library

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var config: HomeLayoutConfig { HomeLayoutConfig.current(sizeClass) }
    #else
    private var config: HomeLayoutConfig { HomeLayoutConfig.current }
    #endif

    enum ViewState: Equatable {
        case home
        case recording
        case reviewing(VideoTake)
        case montage(MontageResult)

        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.home, .home), (.recording, .recording):
                return true
            case let (.reviewing(t1), .reviewing(t2)):
                return t1 == t2
            case let (.montage(r1), .montage(r2)):
                return r1.videoURL == r2.videoURL
            default:
                return false
            }
        }
    }

    @State private var viewState: ViewState = .home
    @State private var showTakeSelector = false
    @State private var showExportSheet = false
    @State private var showCalendar = false
    @State private var selectedTake: VideoTake?
    @State private var selectedVideo: VideoDay?
    @State private var selectedDayForTakes: VideoDay?
    @State private var isGeneratingMontage = false
    @State private var showMontage = false
    @State private var montageResult: MontageResult?
    @State private var showImportView = false

    var body: some View {
        Group {
            #if os(macOS)
            macOSContent
            #else
            iOSContent
            #endif
        }
    }

    // MARK: - iOS Content

    #if os(iOS)
    @ViewBuilder
    private var iOSContent: some View {
        switch viewState {
        case .home:
            iOSHomeContent
        case .recording:
            RecordingView(
                onComplete: { take in
                    selectedTake = take
                    viewState = .reviewing(take)
                },
                onCancel: {
                    viewState = .home
                }
            )
        case .reviewing(let take):
            VideoQAView(
                videoURL: take.videoURL,
                takeNumber: take.takeNumber,
                totalTakes: library?.todaysTakes.count ?? 1,
                onKeep: {
                    selectedTake = take
                    showExportSheet = true
                    viewState = .home
                },
                onRedo: {
                    viewState = .recording
                    selectedTake = nil
                },
                onDelete: {
                    Task {
                        try? await library?.deleteTake(take)
                        viewState = .home
                        selectedTake = nil
                    }
                },
                onTrimmed: { trimmedURL in
                    Task {
                        if let newTake = try? await library?.replaceTakeWithTrimmed(take, trimmedURL: trimmedURL) {
                            selectedTake = newTake
                            showExportSheet = true
                        }
                        viewState = .home
                    }
                }
            )
        case .montage(let result):
            MontageView(
                videoURL: result.videoURL,
                clips: result.clips,
                onDismiss: {
                    viewState = .home
                }
            )
        }
    }

    private var iOSHomeContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: config.sectionSpacing) {
                    todayStatusCard

                    if let library = library, !library.allVideos.isEmpty {
                        recentVideosSection

                        // Montage card (show when 2+ videos)
                        if library.allVideos.count >= 2 {
                            montageCard
                        }
                    }

                    Spacer(minLength: 120)
                }
                .padding(config.cardPadding)
                .frame(maxWidth: config.maxContentWidth > 0 ? config.maxContentWidth : .infinity)
            }
            .refreshable {
                await library?.refresh()
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("DailyFrame")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 16) {
                        Button {
                            showCalendar = true
                        } label: {
                            Image(systemName: "calendar")
                        }

                        Button {
                            showImportView = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SyncStatusView(syncState: library?.syncState ?? .idle)
                }
            }
            .overlay(alignment: .bottom) {
                if config.recordButtonSize > 0 {
                    recordButton
                        .padding(.bottom, 30)
                }
            }
        }
        .sheet(isPresented: $showTakeSelector) {
            takeSelectorSheet
        }
        .sheet(item: $selectedDayForTakes) { day in
            dayTakeSelectorSheet(for: day)
        }
        .sheet(isPresented: $showExportSheet) {
            if let take = selectedTake {
                VideoExportView(videoURL: take.videoURL) {
                    showExportSheet = false
                    selectedTake = nil
                }
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showCalendar) {
            CalendarView(
                onSelectDay: { videoDay in
                    showCalendar = false
                    if let take = videoDay.selectedTake {
                        selectedTake = take
                        viewState = .reviewing(take)
                    }
                },
                onDismiss: {
                    showCalendar = false
                }
            )
        }
        .sheet(isPresented: $showImportView) {
            VideoImportView(
                onImport: { videoURL, date in
                    Task {
                        if let newTake = try? await library?.importVideo(from: videoURL, for: date) {
                            showImportView = false
                            selectedTake = newTake
                            viewState = .reviewing(newTake)
                        } else {
                            showImportView = false
                        }
                    }
                },
                onCancel: {
                    showImportView = false
                }
            )
        }
    }
    #endif

    // MARK: - macOS Content

    #if os(macOS)
    private var macOSContent: some View {
        NavigationSplitView {
            macOSSidebar
                .navigationSplitViewColumnWidth(
                    min: VideoBrowserLayoutConfig.current.sidebarMinWidth,
                    ideal: VideoBrowserLayoutConfig.current.sidebarIdealWidth,
                    max: VideoBrowserLayoutConfig.current.sidebarMaxWidth
                )
        } detail: {
            macOSDetail
        }
        .sheet(isPresented: $showExportSheet) {
            if let take = selectedTake {
                VideoExportView(videoURL: take.videoURL) {
                    showExportSheet = false
                }
                .frame(
                    minWidth: VideoBrowserLayoutConfig.current.exportSheetMinSize.width,
                    minHeight: VideoBrowserLayoutConfig.current.exportSheetMinSize.height
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Calendar button
                Button {
                    showCalendar = true
                } label: {
                    Label("Calendar", systemImage: "calendar")
                }

                // Import button
                Button {
                    showImportView = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }

                SyncStatusView(syncState: library?.syncState ?? .idle)

                // Montage button
                if let library = library, library.allVideos.count >= 2 {
                    Button {
                        Task { await generateMontageMacOS() }
                    } label: {
                        if isGeneratingMontage {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Label("Montage", systemImage: "film.stack")
                        }
                    }
                    .disabled(isGeneratingMontage)
                }

                if selectedTake != nil {
                    Button {
                        showExportSheet = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showMontage) {
            if let result = montageResult {
                MontageView(
                    videoURL: result.videoURL,
                    clips: result.clips,
                    onDismiss: {
                        showMontage = false
                    }
                )
                .frame(minWidth: 600, minHeight: 450)
            }
        }
        .sheet(isPresented: $showCalendar) {
            CalendarView(
                onSelectDay: { videoDay in
                    showCalendar = false
                    if let take = videoDay.selectedTake {
                        selectedTake = take
                    }
                },
                onDismiss: {
                    showCalendar = false
                }
            )
            .frame(minWidth: 400, minHeight: 500)
        }
        .sheet(isPresented: $showImportView) {
            VideoImportView(
                onImport: { videoURL, date in
                    Task {
                        if let newTake = try? await library?.importVideo(from: videoURL, for: date) {
                            showImportView = false
                            selectedTake = newTake
                        } else {
                            showImportView = false
                        }
                    }
                },
                onCancel: {
                    showImportView = false
                }
            )
        }
        .task {
            await library?.loadVideos()
        }
    }

    private func generateMontageMacOS() async {
        guard let library = library, !library.allVideos.isEmpty else { return }

        isGeneratingMontage = true
        defer { isGeneratingMontage = false }

        do {
            let result = try await VideoCompositionService.shared.createMontage(from: library.allVideos)
            montageResult = result
            showMontage = true
        } catch {
            print("Montage generation failed: \(error)")
        }
    }

    private var macOSSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Videos")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await library?.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            if library?.allVideos.isEmpty ?? true {
                macOSEmptyState
            } else {
                macOSVideoList
            }
        }
    }

    private var macOSEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "video.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No videos yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Record videos on your iPhone or iPad")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private var macOSVideoList: some View {
        List(selection: $selectedVideo) {
            ForEach(library?.allVideos ?? []) { video in
                DisclosureGroup {
                    ForEach(video.takes) { take in
                        Button {
                            selectedTake = take
                        } label: {
                            HStack {
                                Image(systemName: "film")
                                    .foregroundStyle(.secondary)
                                Text(take.displayName)
                                    .font(.subheadline)
                                Spacer()
                                Text(take.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(selectedTake?.id == take.id ? Color.accentColor.opacity(0.2) : nil)
                    }
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text(video.displayDate)
                            .font(.subheadline)
                        Spacer()
                        if video.takeCount > 1 {
                            Text("\(video.takeCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var macOSDetail: some View {
        if let take = selectedTake {
            MacVideoDetailView(
                take: take,
                onDelete: {
                    Task {
                        try? await library?.deleteTake(take)
                        selectedTake = nil
                    }
                },
                onTrimmed: { trimmedURL in
                    Task {
                        if let newTake = try? await library?.replaceTakeWithTrimmed(take, trimmedURL: trimmedURL) {
                            selectedTake = newTake
                            showExportSheet = true
                        }
                    }
                },
                onExport: {
                    showExportSheet = true
                }
            )
        } else if let video = selectedVideo, let take = video.selectedTake {
            MacVideoDetailView(
                take: take,
                onDelete: {
                    Task {
                        try? await library?.deleteTake(take)
                        selectedVideo = nil
                    }
                },
                onTrimmed: { trimmedURL in
                    Task {
                        if let newTake = try? await library?.replaceTakeWithTrimmed(take, trimmedURL: trimmedURL) {
                            selectedTake = newTake
                            showExportSheet = true
                        }
                    }
                },
                onExport: {
                    selectedTake = take
                    showExportSheet = true
                }
            )
        } else {
            VStack(spacing: 16) {
                Image(systemName: "play.rectangle")
                    .font(.system(size: VideoBrowserLayoutConfig.current.emptyStateIconSize))
                    .foregroundStyle(.tertiary)
                Text("Select a video to preview")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Videos recorded on iPhone or iPad will appear here")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial.opacity(0.3))
        }
    }
    #endif

    // MARK: - Shared Components

    #if os(iOS)
    private var todayStatusCard: some View {
        HStack(spacing: 14) {
            // Status icon
            ZStack {
                Circle()
                    .fill(library?.hasTodaysTakes == true ? .green.opacity(0.15) : .secondary.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: library?.hasTodaysTakes == true ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(library?.hasTodaysTakes == true ? Color.green : Color.secondary.opacity(0.5))
            }

            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(.system(size: config.captionFontSize, weight: .medium))
                    .foregroundStyle(.secondary)
                if library?.hasTodaysTakes == true {
                    let count = library?.todaysTakes.count ?? 0
                    Text("\(count) take\(count == 1 ? "" : "s") recorded")
                        .font(.system(size: config.headlineFontSize, weight: .semibold))
                } else {
                    Text("Ready to record")
                        .font(.system(size: config.headlineFontSize, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.8))
                }
            }

            Spacer()

            // Action button (only when has takes)
            if library?.hasTodaysTakes == true {
                Button {
                    showTakeSelector = true
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(config.cardPadding)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: config.cardCornerRadius))
        .glassEffect()
    }

    private var recentVideosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.system(size: config.headlineFontSize, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVStack(spacing: 8) {
                ForEach(library?.allVideos.prefix(7) ?? []) { video in
                    videoDayRow(video: video)
                }
            }
        }
    }

    private var montageCard: some View {
        Button {
            Task { await generateMontage() }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: isGeneratingMontage ? "hourglass" : "film.stack.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.blue)
                        .symbolEffect(.rotate, isActive: isGeneratingMontage)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Montage")
                        .font(.system(size: config.captionFontSize, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(isGeneratingMontage ? "Creating..." : "Watch your journey")
                        .font(.system(size: config.headlineFontSize, weight: .semibold))
                }

                Spacer()

                if !isGeneratingMontage {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)
                }
            }
            .padding(config.cardPadding)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: config.cardCornerRadius))
            .glassEffect()
        }
        .buttonStyle(.plain)
        .disabled(isGeneratingMontage)
    }

    private func generateMontage() async {
        guard let library = library, !library.allVideos.isEmpty else { return }

        isGeneratingMontage = true
        defer { isGeneratingMontage = false }

        do {
            let result = try await VideoCompositionService.shared.createMontage(from: library.allVideos)
            viewState = .montage(result)
        } catch {
            // TODO: Show error alert
            print("Montage generation failed: \(error)")
        }
    }

    private func videoDayRow(video: VideoDay) -> some View {
        Button {
            if video.takeCount > 1 {
                // Multiple takes - show selector
                selectedDayForTakes = video
            } else if let take = video.selectedTake {
                // Single take - go directly to review
                selectedTake = take
                viewState = .reviewing(take)
            }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: config.thumbnailWidth, height: config.thumbnailHeight)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(video.displayDate)
                        .font(.system(size: config.bodyFontSize, weight: .medium))
                        .foregroundStyle(.primary)
                    if video.takeCount > 1 {
                        Text("\(video.takeCount) takes")
                            .font(.system(size: config.captionFontSize))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if video.takeCount > 1 {
                    Image(systemName: "film.stack")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: config.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }

    private var recordButton: some View {
        Button {
            viewState = .recording
        } label: {
            ZStack {
                Circle()
                    .fill(.red)
                    .frame(width: config.recordButtonSize, height: config.recordButtonSize)
                Image(systemName: "video.fill")
                    .font(.system(size: config.recordButtonIconSize, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: .red.opacity(0.4), radius: 10, y: 5)
        }
        .glassEffect()
    }

    private var takeSelectorSheet: some View {
        NavigationStack {
            List {
                ForEach(library?.todaysTakes ?? []) { take in
                    Button {
                        selectedTake = take
                        viewState = .reviewing(take)
                        showTakeSelector = false
                    } label: {
                        HStack {
                            Image(systemName: "film")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                Text(take.displayName)
                                    .font(.headline)
                                Text(take.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task { try? await library?.deleteTake(take) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Today's Takes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showTakeSelector = false }
                }
            }
        }
    }

    private func dayTakeSelectorSheet(for day: VideoDay) -> some View {
        NavigationStack {
            List {
                ForEach(day.takes) { take in
                    Button {
                        selectedTake = take
                        viewState = .reviewing(take)
                        selectedDayForTakes = nil
                    } label: {
                        HStack {
                            Image(systemName: "film")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                Text(take.displayName)
                                    .font(.headline)
                                Text(take.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task { try? await library?.deleteTake(take) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(day.displayDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { selectedDayForTakes = nil }
                }
            }
        }
    }
    #endif
}

// MARK: - macOS Video Player with Actions

#if os(macOS)
private struct MacVideoDetailView: View {
    let take: VideoTake
    let onDelete: () -> Void
    let onTrimmed: (URL) -> Void
    let onExport: () -> Void

    @State private var player: AVPlayer?
    @State private var showTrimming = false

    private var config: VideoQALayoutConfig { VideoQALayoutConfig.current }

    var body: some View {
        VStack(spacing: 0) {
            // Video player
            VideoPlayer(player: player)
                .onAppear {
                    player = AVPlayer(url: take.videoURL)
                }
                .onDisappear {
                    player?.pause()
                    player = nil
                }
                .onChange(of: take.videoURL) { _, newURL in
                    player?.pause()
                    player = AVPlayer(url: newURL)
                }

            // Action buttons bar
            HStack(spacing: 20) {
                Button {
                    player?.pause()
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button {
                    player?.pause()
                    showTrimming = true
                } label: {
                    Label("Trim", systemImage: "scissors")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    player?.pause()
                    onExport()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.bar)
        }
        .sheet(isPresented: $showTrimming) {
            VideoTrimmingView(
                videoURL: take.videoURL,
                onCancel: {
                    showTrimming = false
                    player?.seek(to: .zero)
                    player?.play()
                },
                onComplete: { trimmedURL in
                    showTrimming = false
                    onTrimmed(trimmedURL)
                }
            )
            .frame(minWidth: 600, minHeight: 500)
        }
    }
}
#endif

#Preview {
    HomeView()
        .environment(\.videoLibrary, VideoLibrary())
}
