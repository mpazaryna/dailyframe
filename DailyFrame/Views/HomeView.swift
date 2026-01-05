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

    enum Tab {
        case home
        case record
        case calendar
    }

    enum SidebarView: String, CaseIterable {
        case videos = "Videos"
        case calendar = "Calendar"
    }

    @State private var viewState: ViewState = .home
    @State private var selectedTab: Tab = .home
    @State private var sidebarView: SidebarView = .videos
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
            iOSTabContent
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

    /// Tab-based content with Liquid Glass bottom bar
    private var iOSTabContent: some View {
        ZStack(alignment: .bottom) {
            // Main content based on selected tab
            Group {
                switch selectedTab {
                case .home:
                    iOSHomeContent
                case .record:
                    // Record tab triggers recording immediately
                    Color.clear
                        .onAppear {
                            viewState = .recording
                            selectedTab = .home
                        }
                case .calendar:
                    iOSCalendarContent
                }
            }

            // Glass Tab Bar
            glassTabBar
        }
    }

    /// Liquid Glass bottom tab bar
    private var glassTabBar: some View {
        HStack(spacing: 0) {
            // Home Tab
            tabBarButton(
                icon: "house.fill",
                label: "Home",
                isSelected: selectedTab == .home
            ) {
                selectedTab = .home
            }

            Spacer()

            // Record Tab (prominent center button)
            Button {
                viewState = .recording
            } label: {
                ZStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 56, height: 56)
                    Image(systemName: "video.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: .red.opacity(0.4), radius: 8, y: 4)
            }
            .offset(y: -8)

            Spacer()

            // Calendar Tab
            tabBarButton(
                icon: "calendar",
                label: "Calendar",
                isSelected: selectedTab == .calendar
            ) {
                selectedTab = .calendar
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .glassEffect()
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func tabBarButton(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
    }

    /// Calendar content for calendar tab
    private var iOSCalendarContent: some View {
        NavigationStack {
            CalendarView(
                onSelectDay: { videoDay in
                    if let take = videoDay.selectedTake {
                        selectedTake = take
                        viewState = .reviewing(take)
                    }
                },
                onDismiss: {
                    selectedTab = .home
                }
            )
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SyncStatusView(syncState: library?.syncState ?? .idle)
                }
            }
        }
    }

    private var iOSHomeContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: config.sectionSpacing) {
                    heroStatsBanner

                    todayStatusCard

                    // Montage card - prominent position (show when 2+ videos)
                    if let library = library, library.allVideos.count >= 2 {
                        montageCard
                    }

                    if let library = library, !library.allVideos.isEmpty {
                        recentVideosSection
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
                    Button {
                        showImportView = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SyncStatusView(syncState: library?.syncState ?? .idle)
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
            // Segmented picker header
            HStack {
                Picker("View", selection: $sidebarView) {
                    ForEach(SidebarView.allCases, id: \.self) { view in
                        Text(view.rawValue).tag(view)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Button {
                    Task { await library?.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding()

            // Hero stats for macOS (only in videos view)
            if sidebarView == .videos, let library = library, !library.allVideos.isEmpty {
                macOSStatsBanner
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            Divider()

            // Content based on selected view
            switch sidebarView {
            case .videos:
                if library?.allVideos.isEmpty ?? true {
                    macOSEmptyState
                } else {
                    macOSVideoList
                }
            case .calendar:
                macOSSidebarCalendar
            }
        }
    }

    private var macOSSidebarCalendar: some View {
        CalendarView(
            onSelectDay: { videoDay in
                if let take = videoDay.selectedTake {
                    selectedTake = take
                }
            },
            onDismiss: {
                sidebarView = .videos
            }
        )
    }

    private var macOSStatsBanner: some View {
        HStack(spacing: 16) {
            // Days count
            HStack(spacing: 4) {
                Image(systemName: "film.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("\(library?.allVideos.count ?? 0)")
                    .font(.system(size: 13, weight: .semibold))
                    .contentTransition(.numericText())
                Text("days")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Streak
            HStack(spacing: 4) {
                Image(systemName: (library?.currentStreak ?? 0) > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 12))
                    .foregroundStyle((library?.currentStreak ?? 0) > 0 ? .orange : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                Text("\(library?.currentStreak ?? 0)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle((library?.currentStreak ?? 0) > 0 ? .orange : .primary)
                    .contentTransition(.numericText())
                Text("streak")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .animation(.spring(duration: 0.3), value: library?.allVideos.count)
        .animation(.spring(duration: 0.3), value: library?.currentStreak)
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

    // MARK: - Hero Stats Banner

    @ViewBuilder
    private var heroStatsBanner: some View {
        if let library = library, !library.allVideos.isEmpty {
            HStack(spacing: 0) {
                // Total days stat
                statItem(
                    icon: "film.fill",
                    value: "\(library.allVideos.count)",
                    label: library.allVideos.count == 1 ? "day" : "days"
                )

                Divider()
                    .frame(height: 32)
                    .padding(.horizontal, 16)

                // Streak stat (with flame when active)
                statItem(
                    icon: library.currentStreak > 0 ? "flame.fill" : "flame",
                    value: "\(library.currentStreak)",
                    label: "streak",
                    accentColor: library.currentStreak > 0 ? .orange : nil
                )

                Spacer()

                // Motivational nudge
                if library.currentStreak > 0 && !library.hasTodaysTakes {
                    Text("Keep it going!")
                        .font(.system(size: config.captionFontSize, weight: .medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.orange.opacity(0.15))
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                } else if library.currentStreak >= 7 {
                    Text("On fire! 🔥")
                        .font(.system(size: config.captionFontSize, weight: .medium))
                        .foregroundStyle(.orange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, config.cardPadding)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: config.cardCornerRadius))
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(duration: 0.4, bounce: 0.2), value: library.allVideos.count)
            .animation(.spring(duration: 0.3), value: library.currentStreak)
        }
    }

    private func statItem(icon: String, value: String, label: String, accentColor: Color? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accentColor ?? .secondary)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: config.headlineFontSize, weight: .bold))
                    .foregroundStyle(accentColor ?? .primary)
                Text(label)
                    .font(.system(size: config.captionFontSize - 1, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

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
        VStack(alignment: .leading, spacing: 16) {
            ForEach(library?.groupedVideos ?? []) { group in
                videoGroupSection(group: group)
            }
        }
    }

    private func videoGroupSection(group: VideoGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            Text(group.title)
                .font(.system(size: config.headlineFontSize, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)

            if config.recentVideosColumns > 1 {
                // Grid layout for iPad
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: config.recentVideosColumns),
                    spacing: 12
                ) {
                    ForEach(group.videos) { video in
                        videoDayCard(video: video)
                    }
                }
            } else {
                // List layout for iPhone
                LazyVStack(spacing: 8) {
                    ForEach(group.videos) { video in
                        videoDayRow(video: video)
                    }
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
                // Video thumbnail
                if let videoURL = video.videoURL {
                    VideoThumbnailView(
                        videoURL: videoURL,
                        size: CGSize(width: config.thumbnailWidth, height: config.thumbnailHeight)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        // Play indicator overlay
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                            .padding(4)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .frame(width: config.thumbnailWidth, height: config.thumbnailHeight)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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

    /// Card-style layout for iPad grid view
    private func videoDayCard(video: VideoDay) -> some View {
        Button {
            if video.takeCount > 1 {
                selectedDayForTakes = video
            } else if let take = video.selectedTake {
                selectedTake = take
                viewState = .reviewing(take)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Large thumbnail
                if let videoURL = video.videoURL {
                    VideoThumbnailView(
                        videoURL: videoURL,
                        size: CGSize(width: 160, height: 100)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .clipped()
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                            .padding(6)
                    }
                    .overlay(alignment: .topLeading) {
                        if video.takeCount > 1 {
                            HStack(spacing: 3) {
                                Image(systemName: "film.stack.fill")
                                    .font(.system(size: 9))
                                Text("\(video.takeCount)")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.6))
                            .clipShape(Capsule())
                            .padding(6)
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .frame(height: 100)
                        .overlay {
                            Image(systemName: "play.fill")
                                .foregroundStyle(.secondary)
                        }
                }

                // Date label
                Text(video.displayDate)
                    .font(.system(size: config.bodyFontSize, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: config.cardCornerRadius))
        }
        .buttonStyle(.plain)
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
