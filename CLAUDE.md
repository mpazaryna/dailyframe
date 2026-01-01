# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DailyFrame is a personal video diary app that captures one video per day. It's a universal Swift/SwiftUI app targeting iOS 26+, iPadOS 26+, and macOS 26+. The app is a creation-first tool: capture video, review for quality (QA), then export as standard MOV files.

**Core Philosophy:** Shoot on one device, review everywhere. DailyFrame handles capture and quality control; the iOS ecosystem handles distribution and editing.

## Xcode Project

The project uses XcodeGen. Regenerate after modifying `project.yml`:

```bash
xcodegen generate
```

Before building macOS target, set your Development Team in Xcode (required for iCloud entitlements).

## Build Commands

```bash
# Build for iOS simulator
xcodebuild -project DailyFrame.xcodeproj -scheme DailyFrame-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build

# Build for macOS (requires signing in Xcode first)
xcodebuild -project DailyFrame.xcodeproj -scheme DailyFrame-macOS -destination 'platform=macOS' build

# Clean build
xcodebuild -project DailyFrame.xcodeproj clean
```

## Architecture

### Design System
Uses Apple's LiquidGlass design language (WWDC 2025) with `.glassEffect()` modifier throughout. Key constraints:
- Blur radius ≤40px on iPhone, ≤60px on iPad/Mac
- Text contrast minimum 4.5:1 over glass backgrounds
- Must respect Reduced Transparency, Reduced Motion, High Contrast system settings

### Key Architectural Decisions

1. **Export-First Architecture (ADR-001):** In-app playback is for QA only (shoot → review → decide → export). Videos export as standard MOV files to iCloud Documents for external editing/sharing.

2. **Universal App with iCloud Sync (ADR-002):** Single codebase for all platforms. Videos stored in iCloud Documents container (`iCloud.com.paz.dailyframe`) with automatic cross-device sync.

3. **No MVVM Pattern (ADR-003):** Views own their state directly using `@State` with `ViewState` enums. Services are `@Observable` classes injected via `@Environment`. See `ai_docs/no-mvvm.md` for rationale.

4. **Centralized Platform Config (ADR-004):** All platform-adaptive layouts defined in `Configuration/PlatformConfig.swift` using composition with flattening pattern. Views use `horizontalSizeClass` on iOS and static configs on macOS. NO device-specific view folders.

### Project Structure
```
DailyFrame/
├── App/                  # Entry point, AppDelegate
├── Configuration/
│   └── PlatformConfig.swift  # All platform-adaptive configs
├── Views/
│   ├── ContentView.swift     # Root view
│   ├── HomeView.swift        # Unified home (adapts to all platforms)
│   ├── RecordingView.swift   # Unified recording (iOS only)
│   └── Shared/               # VideoQAView, VideoExportView, SyncStatusView
├── Models/               # VideoDay, VideoTake, AppError, SyncState
├── Services/
│   ├── VideoLibrary          # @Observable main service (Environment injection)
│   ├── VideoStorageService   # iCloud file I/O
│   ├── iCloudSyncService     # NSFileCoordinator/NSFilePresenter
│   ├── CameraService         # @Observable AVFoundation (iOS only)
│   └── VideoExportService    # UIActivityViewController
└── Utilities/            # DateUtilities, PlatformDetection, PermissionManager
```

### Platform Config Pattern

All views use centralized config structs that flatten base properties:

```swift
// In Configuration/PlatformConfig.swift
struct HomeLayoutConfig {
    // Flattened base properties
    let cardPadding: CGFloat
    let sectionSpacing: CGFloat
    // View-specific properties
    let heroIconSize: CGFloat
    let recordButtonSize: CGFloat

    #if os(iOS)
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> Self {
        sizeClass == .regular
            ? Self(/* iPad values */)
            : Self(/* iPhone values */)
    }
    #else
    static var current: Self { /* macOS values */ }
    #endif
}

// In Views
struct HomeView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var config: HomeLayoutConfig { HomeLayoutConfig.current(sizeClass) }
    #else
    private var config: HomeLayoutConfig { HomeLayoutConfig.current }
    #endif

    var body: some View {
        // Use config.cardPadding, config.heroIconSize, etc.
    }
}
```

### Platform-Specific Code
Use conditional compilation for platform differences:
- `#if os(iOS)` - Camera access, size class detection
- `#if os(macOS)` - NSOpenPanel, static configs
- Camera recording only available on iOS/iPadOS; macOS shows video browser only

**Important:** Do NOT use Mac Catalyst. Each platform (iOS, macOS) has its own native target. No "Designed for iPad" compatibility layer.

### Data Model
```swift
struct VideoTake: Identifiable, Equatable, Hashable {
    let id: UUID
    let date: Date
    let takeNumber: Int
    let videoURL: URL
    let createdAt: Date
    var isSelected: Bool
}

struct VideoDay: Identifiable, Equatable, Hashable {
    let id: UUID
    let date: Date              // Normalized to start of day
    var takes: [VideoTake]
    var selectedTake: VideoTake? { takes.first { $0.isSelected } ?? takes.first }
}
```

### Storage
- iCloud container: `iCloud.com.paz.dailyframe`
- Videos path: `Documents/Videos/`
- File naming: `video_YYYY-MM-DD_NNN.mov` (NNN = take number, zero-padded)
- Use `FileManager.ubiquitousContainerURL()` for iCloud path

## Key APIs

- **Video Capture:** AVFoundation (AVCaptureSession)
- **Video Playback:** AVKit (VideoPlayer)
- **File Sync:** NSFileCoordinator, NSFilePresenter
- **Sharing:** UIActivityViewController

## Required Entitlements

- iCloud Containers (`iCloud.com.paz.dailyframe`)
- File Sharing (`com.apple.developer.file-sharing-support`)

## Required Info.plist Keys

- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
