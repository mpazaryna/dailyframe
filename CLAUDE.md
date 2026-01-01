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

### Project Structure
```
DailyFrame/
├── App/                  # Entry point, AppDelegate
├── Views/
│   ├── iPhone/           # IPhoneRecordingView
│   ├── iPad/             # IPadRecordingView (split-view)
│   ├── Mac/              # MacRecordingView (window-based)
│   └── Shared/           # VideoRecorderView, VideoQAView, VideoExportView
├── ViewModels/           # VideoManagerViewModel, ExportViewModel
├── Models/               # VideoDay, AppError, SyncState
├── Services/
│   ├── VideoStorageService    # iCloud file I/O
│   ├── iCloudSyncService      # NSFileCoordinator/NSFilePresenter
│   ├── CameraService          # AVFoundation (iOS/iPadOS only)
│   └── VideoExportService     # UIActivityViewController
└── Utilities/            # DateUtilities, PlatformDetection, PermissionManager
```

### Platform-Specific Code
Use conditional compilation for platform differences:
- `#if os(iOS)` - Camera access (iOS/iPadOS only)
- `#if os(macOS)` - NSOpenPanel, menu bar
- Camera recording only available on iOS/iPadOS; all platforms can playback/export

**Important:** Do NOT use Mac Catalyst. Each platform (iOS, macOS) has its own native target. No "Designed for iPad" compatibility layer.

### Data Model
```swift
struct VideoDay: Identifiable {
    let id = UUID()
    let date: Date          // Normalized to start of day
    let videoURL: URL?      // nil if no video for this day
    let createdAt: Date
    var fileName: String    // Format: "video_YYYY-MM-DD.mov"
}
```

### Storage
- iCloud container: `iCloud.com.paz.dailyframe`
- Videos path: `Documents/Videos/`
- File naming: `video_YYYY-MM-DD.mov`
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
