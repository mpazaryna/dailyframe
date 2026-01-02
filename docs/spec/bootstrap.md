# DailyFrame - Product Specification

## Project Overview

**Project Name:** DailyFrame

**Concept:** A personal video diary application that captures one video per day. DailyFrame is a **shooting tool with immediate quality assurance**. Users record, review for quality, and then export finalized videos in QuickTime format for sharing, editing, or external playback. The app captures and vets; the iOS ecosystem distributes and edits.

**Target:** Single-person MVP—a polished, focused app that does one thing well: daily video capture with seamless integration into the iOS ecosystem.

**Platforms:** iOS 26+, iPadOS 26+, macOS 26+

**Design System:** LiquidGlass (Apple's unified design language, WWDC 2025)

**Native Universal App:** Single codebase targeting iPhone, iPad, and Mac Desktop. No Mac Catalyst—each platform has its own native target.

**Core Philosophy:** Shoot on one device, review everywhere. DailyFrame handles capture and quality control with seamless cross-device synchronization via iCloud. One library, all your devices.

---

## Core MVP Features

### 1. Daily Video Recording (iPhone & iPad)
- Single record button using LiquidGlass glass panel with `.glassEffect()`
- Captures to standard **QuickTime MOV format** (iOS default)
- Records maximum 1 video per calendar day
- Prevents duplicate recording for same day (shows alert)
- Auto-saves to iCloud app container (`Documents/Videos/`)
- File naming scheme: `video_YYYY-MM-DD.mov`

### 2. Immediate QA Playback (All Platforms)
- After video saves, automatically shows minimal playback viewer
- Uses LiquidGlass design with translucent controls
- Director can immediately see captured footage
- **Make/Redo Decision:**
  - Keep: proceeds to export
  - Delete & Reshoot: removes video, returns to record
- Full-screen playback with basic controls (play/pause, scrub, mute)
- Minimal UI—focused on evaluating quality, not consumption

### 3. Cross-Device Sync via iCloud
- All videos stored in iCloud Drive's app container
- Automatic sync to iPhone, iPad, and Mac
- Visible in Files app on any device
- Offline caching on each device
- No manual sync required; changes propagate instantly
- Requires iCloud Drive enabled on user's Apple ID

### 4. Export to QuickTime / Sharing
- One-tap export via UIActivityViewController
- Supports:
  - **AirDrop** (to other devices)
  - **Files app** (save to iCloud Drive, local storage, external drives)
  - **Mail** (send to others)
  - **Messages** (share directly)
  - **Third-party apps** (FCPX, Premiere, etc. if installed)
- All exported MOV files remain in iCloud for future access
- Post-export: file is standard QuickTime format, fully portable and editable

### 5. LiquidGlass Design System (All Platforms)
- Uses Apple's Liquid Glass design language (WWDC 2025) exclusively
- Glass panels for recording button, QA controls, export interface
- Translucent UI with blur and refraction effects
- Respects system settings: Reduced Transparency, Reduced Motion, High Contrast
- Adapts layout to device: iPhone (compact), iPad (tablet), Mac (window)
- Dynamic depth and layering—content always foreground, controls glass layer

### 6. Universal App Architecture
- Single codebase for iOS 26+, iPadOS 26+, macOS 15+
- Responsive layout adapts to screen size and device type
- iPhone: vertical stack (record button → QA view → export)
- iPad: sidebar + main content (file browser on left, recording on right)
- Mac: window-based (menu bar + toolbar + content area)
- Platform-specific APIs: camera only on iOS/iPadOS, all platforms can playback/export

### 7. Permissions & Storage
- Request camera and microphone permissions on first launch (iOS/iPadOS only)
- Entitlements: iCloud Containers, File Sharing (com.apple.developer.icloud-container-identifiers)
- iCloud Documents container: `iCloud.com.paz.dailyframe`
- Storage path: `iCloud/Documents/Videos/`
- All files visible to iOS/macOS Files app

---

## Technical Architecture

### Technology Stack
- **Language:** Swift
- **UI Framework:** SwiftUI (with LiquidGlass design system)
- **Platforms:** iOS 26+, iPadOS 26+, macOS 15+
- **Design System:** LiquidGlass (Apple WWDC 2025 — translucent glass-morphism with blur and depth)
- **Video Capture:** AVFoundation (AVCaptureSession) — iPhone/iPad only
- **Video Playback:** AVKit (VideoPlayer)
- **Data Persistence:** FileManager + iCloud Documents Container
- **File Coordination:** NSFileCoordinator, NSFilePresenter (multi-device sync safety)
- **Deployment Target:** Xcode 16.1+, Swift 6.0+

### Project Structure
```
DailyFrame/
├── App/
│   ├── DailyFrameApp.swift        # Universal entry point
│   └── AppDelegate.swift           # iCloud setup, permissions
├── Views/
│   ├── ContentView.swift           # Universal root (adapts to platform)
│   ├── iPhone/
│   │   └── IPhoneRecordingView.swift     # iPhone-optimized recording UI
│   ├── iPad/
│   │   └── IPadRecordingView.swift      # iPad split-view layout
│   ├── Mac/
│   │   └── MacRecordingView.swift       # macOS window-based UI
│   ├── Shared/
│   │   ├── VideoRecorderView.swift      # Camera capture (iOS/iPadOS only)
│   │   ├── VideoQAView.swift            # Playback QA (all platforms)
│   │   └── VideoExportView.swift        # Share sheet (all platforms)
├── ViewModels/
│   ├── VideoManagerViewModel.swift      # Recording & QA workflow
│   └── ExportViewModel.swift            # Export/sharing logic
├── Models/
│   ├── VideoDay.swift                   # Video entry data model
│   ├── AppError.swift                   # Custom error types
│   └── SyncState.swift                  # iCloud sync status
├── Services/
│   ├── VideoStorageService.swift        # iCloud file I/O
│   ├── iCloudSyncService.swift          # NSFileCoordinator wrapper
│   ├── CameraService.swift              # AVFoundation (iOS/iPadOS only)
│   └── VideoExportService.swift         # UIActivityViewController
├── Utilities/
│   ├── DateUtilities.swift              # Date formatting
│   ├── PlatformDetection.swift          # Device type detection
│   └── PermissionManager.swift          # Permissions (iOS/iPadOS)
└── Resources/
    └── Assets.xcassets
```

### Data Model

**VideoDay.swift**
```swift
struct VideoDay: Identifiable {
    let id = UUID()
    let date: Date          // Normalized to start of day
    let videoURL: URL?      // nil if no video for this day
    let createdAt: Date

    var fileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "video_\(formatter.string(from: date)).mov"
    }
}
```

**Storage Locations**
- Videos: `{Documents}/Videos/` directory
- If needed for later: metadata could be stored in UserDefaults or lightweight Core Data

---

## MVP Scope (What's NOT Included)

The following features are intentionally excluded from MVP to keep scope tight:

- Video editing or trimming (external editors handle this)
- Notifications/reminders to record
- Widget support
- Settings screen
- Advanced search or filtering by date/metadata
- CloudKit (simple iCloud file sync sufficient for MVP)

---

## Success Criteria for MVP

**Core Functionality**
- User can launch app on iOS, iPadOS, or macOS
- User can record video (iOS/iPadOS only)
- Video auto-saves to iCloud container on stop
- QA view automatically appears post-capture
- Director can keep or redo video in QA view
- Keep button transitions to export interface
- Redo button deletes video from iCloud and returns to record
- Export interface shows native iOS/macOS share sheet
- User can AirDrop, Mail, or Files-share the video

**Cross-Device Sync (Critical)**
- Shoot video on iPhone, it appears in Files app on Mac within 10 seconds
- Delete video on iPad, it disappears on iPhone
- Offline: video saves locally, syncs when connected
- Multiple devices recording same day: latest wins (no conflicts)
- Sync status visible to user ("Syncing..." indicator)

**Design & Polish**
- All UI elements use LiquidGlass glass effect (`.glassEffect()`)
- Blur radius appropriate for platform (≤40px iPhone, ≤60px iPad/Mac)
- Text contrast meets 4.5:1 minimum over glass background
- Respects Reduced Transparency system setting
- Respects Reduced Motion system setting
- Dark mode + Light mode rendering correct
- iPhone layout: vertical (compact)
- iPad layout: sidebar + main content
- Mac layout: window-based with menu bar
- Orientation changes handled smoothly (iPad/Mac)

**Quality & Compatibility**
- All videos remain standard MOV format, fully editable in external tools
- App handles permissions gracefully (iOS/iPadOS only)
- App handles iCloud not available (graceful offline mode)
- Entitlements configured for iCloud Containers
- Works on iOS 26+, iPadOS 26+, macOS 15+ (Sonoma/Tahoe)
- No crashes on multi-device sync scenarios

---

## Future Feature Roadmap (Post-MVP)

1. **CloudKit Metadata** – Richer sync using CloudKit for advanced queries
2. **Statistics** – Show streak counter, total videos recorded, etc.
3. **Sharing Collections** – Create shareable compilations of videos
4. **Video Editing** – Trim, add filters, or captions
5. **Reminders** – Push notifications to record each day
6. **Widget** – Quick access to record from lock screen or home screen
7. **Search/Filter** – Find videos by date range or metadata
8. **Export Compilation** – Create reel from multiple videos
9. **Watch App** – WatchOS companion for quick control
10. **External Storage** – Direct iCloud Drive folder selection for videos

---

## Development Guidelines

### Using Claude Code
- Use Claude Code for bootstrapping folder structure and initial boilerplate
- Use it to explore AVFoundation APIs and SwiftUI components
- Ask for help on specific challenges (e.g., "calendar grid layout" or "camera preview not showing")
- Test incrementally after each phase

### Testing Strategy
- Test on physical device frequently (simulator camera doesn't work well)
- Test permission flows (grant/deny)
- Test recording at different times of day
- Test navigation between views
- Test playing back videos from different dates

### Key Build Settings
- Code Sign Entitlements: point to `.entitlements` file with iCloud container
- Supported Platforms: iOS, macOS
- Minimum Deployment Targets enforced per platform
