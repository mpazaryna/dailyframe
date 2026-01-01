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
    }

    @State private var viewState: ViewState = .home
    @State private var showTakeSelector = false
    @State private var showExportSheet = false
    @State private var selectedTake: VideoTake?
    @State private var selectedVideo: VideoDay?

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
                    }

                    Spacer(minLength: 120)
                }
                .padding(config.cardPadding)
                .frame(maxWidth: config.maxContentWidth > 0 ? config.maxContentWidth : .infinity)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("DailyFrame")
            .toolbar {
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
        .sheet(isPresented: $showExportSheet) {
            if let take = selectedTake {
                VideoExportView(videoURL: take.videoURL) {
                    showExportSheet = false
                    selectedTake = nil
                }
                .presentationDetents([.medium])
            }
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
                SyncStatusView(syncState: library?.syncState ?? .idle)

                if selectedTake != nil {
                    Button {
                        showExportSheet = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            await library?.loadVideos()
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
            MacVideoPlayer(videoURL: take.videoURL)
        } else if let video = selectedVideo, let take = video.selectedTake {
            MacVideoPlayer(videoURL: take.videoURL)
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
        VStack(spacing: config.cardSpacing) {
            if library?.hasTodaysTakes == true {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.system(size: config.headlineFontSize, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("\(library?.todaysTakes.count ?? 0) take\(library?.todaysTakes.count == 1 ? "" : "s")")
                            .font(.system(size: config.headlineFontSize + 4, weight: .semibold))
                    }
                    Spacer()
                    Button {
                        showTakeSelector = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "film.stack")
                            Text("View")
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: config.heroIconSize))
                        .foregroundStyle(.tertiary)
                    Text("No video yet today")
                        .font(.system(size: config.headlineFontSize, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Tap the record button to capture your daily moment")
                        .font(.system(size: config.captionFontSize))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
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

    private func videoDayRow(video: VideoDay) -> some View {
        Button {
            if let take = video.selectedTake {
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

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
    #endif
}

// MARK: - macOS Video Player

#if os(macOS)
private struct MacVideoPlayer: View {
    let videoURL: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: videoURL)
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
            .onChange(of: videoURL) { _, newURL in
                player?.pause()
                player = AVPlayer(url: newURL)
            }
    }
}
#endif

#Preview {
    HomeView()
        .environment(\.videoLibrary, VideoLibrary())
}
