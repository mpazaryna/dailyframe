# dailyframe

# DailyFrame - Project Specification

## Project Overview

**Project Name:** DailyFrame

**Concept:** A personal video diary application that captures one video per day. DailyFrame is a **shooting tool with immediate quality assurance**. Users record, review for quality, and then export finalized videos in QuickTime format for sharing, editing, or external playback. The app captures and vets; the iOS ecosystem distributes and edits.

**Target:** Single-person MVP—a polished, focused app that does one thing well: daily video capture with seamless integration into the iOS ecosystem.

**Platforms:** iOS 26+, iPadOS 26+, macOS 26+
**Design System:** LiquidGlass (Apple's unified design language, WWDC 2025)
**Native Universal App:** Single codebase targeting iPhone, iPad, and Mac Desktop
**No Mac Catalyst:** Each platform has its own native target. Do NOT use "Designed for iPad" compatibility layer.

**Core Philosophy:** Shoot on one device, review everywhere. DailyFrame handles capture and quality control with seamless cross-device synchronization via iCloud. One library, all your devices.

---

## Architectural Decision Record (ADR)

### ADR-001: Export-First Architecture (Playback for QA, Export for Distribution)

**Status:** ACCEPTED (MVP Requirement)

**Context:**
DailyFrame serves two distinct roles: (1) **Director/Creator Role**: immediately review shot footage to verify quality and decide to keep/reshoot, and (2) **Distribution Role**: export finalized videos to QuickTime format for external sharing, editing, or archival outside the app. The original design conflated creation with consumption; this ADR clarifies the split.

**Decision:**
DailyFrame is a **creation-first tool** with two critical features:

1. **In-App Playback (QA Only):** Minimal video viewer to review just-shot footage for quality control. Director can immediately see what was captured and decide: keep or reshoot. This is a critical creation workflow, not a consumption interface.

2. **Export to QuickTime (Distribution):** All finalized videos are exported as standard MOV files to the app's Documents/Videos directory, making them accessible for:
   - External editing (Final Cut Pro, Adobe Premiere, DaVinci Resolve, etc.)
   - Sharing via iOS ecosystem (AirDrop, Mail, iCloud Drive, Messages, Files app)
   - Archival in standard format (not locked to app)
   - Future re-import to other tools

**Rationale:**
1. **Creator Control:** Director sees footage immediately and owns quality decision
2. **No Vendor Lock-in:** All exported videos are standard MOV files in the filesystem
3. **Workflow Clarity:** App handles capture + QA; external tools handle editing + sharing
4. **Flexibility:** Users can edit in any video editor they choose
5. **Simplicity:** Clear separation of concerns (create → review → decide → export → edit)
6. **Privacy & Ownership:** Videos live in user's Documents directory, fully auditable and portable

**Consequences:**
- ✅ Creator has immediate feedback loop (shoot → review → decide)
- ✅ Exported videos are true assets, not app-proprietary
- ✅ Seamless integration with external editing tools
- ✅ Clear workflow: DailyFrame is shooting, not editing
- ❌ App includes QA playback (adds ~2 views), but it's minimal and purposeful
- ❌ Users responsible for managing video files outside app

**Alternative Considered:**
Eliminate playback entirely and use Files app for review — rejected because it breaks the director's immediate feedback loop; creators need to see footage instantly post-capture to make quality decisions.

---

### ADR-002: Universal App with iCloud Sync

**Status:** ACCEPTED (MVP Requirement)

**Context:**
Users want to shoot videos on iPhone, review on Mac, and export from iPad. A device-specific app requires duplicating workflows. Cross-device sync requires a central authority to store and synchronize video metadata and file references. iCloud provides this infrastructure seamlessly on Apple platforms.

**Decision:**
DailyFrame is a **universal native app** (single Swift codebase) targeting iOS 26+, iPadOS 26+, and macOS 15+. All videos are stored in iCloud Drive's app container, making them accessible across all devices:

1. **iCloud Documents Container:** All video files sync automatically via iCloud Drive
2. **Device-Specific UI:** Layout adapts to screen size (compact on iPhone, sidebar on iPad/Mac)
3. **Platform Integration:** Uses native file APIs; users can also access videos in Files app
4. **Seamless Sync:** Shoot on iPhone, review on Mac, no manual sync needed

**Rationale:**
1. **One Codebase, Many Devices:** SwiftUI's layout system adapts view hierarchy to available space
2. **Zero Manual Sync:** iCloud handles transport; files appear instantly across devices
3. **Transparency:** Videos in Files app on any device; no hidden database
4. **Offline Support:** Cached copies on each device; sync happens when connected
5. **Privacy:** All files stay within user's iCloud; Apple has no visibility

**Consequences:**
- ✅ Shoot anywhere, review anywhere
- ✅ One app to maintain across platforms
- ✅ iCloud handles sync complexity; app code stays simple
- ✅ Users can organize videos in Files app natively
- ❌ Requires iOS 26+ minimum (not backward compatible)
- ❌ iCloud requires active Apple ID with iCloud Drive enabled
- ❌ Storage counts against user's iCloud quota

**Implementation:**
- Use `FileManager` with `.ubiquitousContainerURL()` to access iCloud app container
- Store videos in `Documents/Videos/` within the container
- Use `NSFileCoordinator` and `NSFilePresenter` for conflict-free multi-device writes
- Implement CloudKit for metadata if richer sync needed (out of MVP scope)

**Alternative Considered:**
CloudKit database for central video metadata — rejected for MVP because iCloud file sync is simpler, requires no backend, and provides transparent file ownership.

---

**Status:** ACCEPTED (MVP Requirement)

**Context:**
DailyFrame serves two distinct roles: (1) **Director/Creator Role**: immediately review shot footage to verify quality and decide to keep/reshoot, and (2) **Distribution Role**: export finalized videos to QuickTime format for external sharing, editing, or archival outside the app. The original design conflated creation with consumption; this ADR clarifies the split.

**Decision:**
DailyFrame is a **creation-first tool** with two critical features:

1. **In-App Playback (QA Only):** Minimal video viewer to review just-shot footage for quality control. Director can immediately see what was captured and decide: keep or reshoot. This is a critical creation workflow, not a consumption interface.

2. **Export to QuickTime (Distribution):** All finalized videos are exported as standard MOV files to the app's Documents/Videos directory, making them accessible for:
   - External editing (Final Cut Pro, Adobe Premiere, DaVinci Resolve, etc.)
   - Sharing via iOS ecosystem (AirDrop, Mail, iCloud Drive, Messages, Files app)
   - Archival in standard format (not locked to app)
   - Future re-import to other tools

**Rationale:**
1. **Creator Control:** Director sees footage immediately and owns quality decision
2. **No Vendor Lock-in:** All exported videos are standard MOV files in the filesystem
3. **Workflow Clarity:** App handles capture + QA; external tools handle editing + sharing
4. **Flexibility:** Users can edit in any video editor they choose
5. **Simplicity:** Clear separation of concerns (create → review → decide → export → edit)
6. **Privacy & Ownership:** Videos live in user's Documents directory, fully auditable and portable

**Consequences:**
- ✅ Creator has immediate feedback loop (shoot → review → decide)
- ✅ Exported videos are true assets, not app-proprietary
- ✅ Seamless integration with external editing tools
- ✅ Clear workflow: DailyFrame is shooting, not editing
- ❌ App includes QA playback (adds ~2 views), but it's minimal and purposeful
- ❌ Users responsible for managing video files outside app

**Alternative Considered:**
Eliminate playback entirely and use Files app for review — rejected because it breaks the director's immediate feedback loop; creators need to see footage instantly post-capture to make quality decisions.

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

## MVP Development Approach

### Phase 1: Project Setup (1-2 hours)
1. Create new iOS project in Xcode (or use `swift package init` if using CLI)
2. Set up folder structure as outlined above
3. Configure info.plist for camera/microphone permissions:
   - `NSCameraUsageDescription`
   - `NSMicrophoneUsageDescription`
4. Set deployment target to iOS 16+

### Phase 2: Core Services (5-6 hours)
1. **iCloudSyncService**
   - Initialize iCloud Documents container (`iCloud.com.paz.dailyframe`)
   - Implement NSFileCoordinator for multi-device write safety
   - Monitor file changes via NSFilePresenter
   - Handle offline/online transitions
   - Conflict resolution (keep latest file on sync)

2. **VideoStorageService**
   - Use FileManager with `.ubiquitousContainerURL()` for iCloud path
   - Create Videos directory in iCloud container if doesn't exist
   - Save video file with date-based naming (MOV format)
   - Load all videos by scanning iCloud directory
   - Delete video from iCloud (safe deletion across devices)
   - Retrieve video metadata by date

3. **VideoExportService**
   - Implement UIActivityViewController for sharing
   - Support AirDrop, Mail, Files app, Messages, third-party editors
   - Ensure MOV file is properly formatted for external editing
   - Handle export errors gracefully

4. **CameraService** (AVFoundation wrapper, iOS/iPadOS only)
   - Initialize AVCaptureSession
   - Handle device selection (rear camera, built-in mic)
   - Start/stop recording to MOV format
   - Output video file to iCloud container
   - Handle permissions and errors

5. **PermissionManager** (iOS/iPadOS only)
   - Request camera permission
   - Request microphone permission
   - Check permission status
   - Handle denied permissions gracefully

### Phase 3: Core Views & LiquidGlass Design (4-5 hours)

**Design Principles (LiquidGlass):**
- Use `.glassEffect()` modifier for panels and controls
- Keep blur radius ≤ 40px on iPhone, ≤ 60px on iPad/Mac
- One primary glass layer per view (no nested glass)
- Text contrast minimum 4.5:1 after blur
- Respect system settings: Reduced Transparency, Reduced Motion, High Contrast
- Motion: smooth, responsive, no jank

1. **ContentView (Universal Root)**
   - Adaptive layout: iPhone (vertical), iPad (split-view sidebar), Mac (window chrome)
   - Detects platform using `#if os(iOS)` conditional compilation
   - Routes to appropriate platform-specific view
   - Manages AppDelegate for iCloud setup

2. **IPhoneRecordingView**
   - Full-screen camera preview
   - Large record button with glass effect (LiquidGlass `.glassEffect()`)
   - Pulsing recording indicator (animated glass panel)
   - Status text: "Ready to Record" or "Recording..."
   - Auto-transition to VideoQAView on save

3. **IPadRecordingView**
   - Split-view layout: sidebar (file browser) + main content (camera)
   - Left sidebar: list of recent videos with dates (LiquidGlass cards)
   - Right main area: camera feed + record button
   - Drag-drop to share videos
   - Responsive to iPad orientation changes

4. **MacRecordingView**
   - Window-based UI with menu bar
   - Main window: camera feed (if attached external camera) or placeholder
   - Toolbar: record button, export menu
   - Files sidebar: browse synced videos
   - Respects macOS window management (resizable, fullscreen, split view)

5. **VideoQAView (Shared)**
   - Full-screen video player (AVKit VideoPlayer) over dark glass background
   - Two primary buttons with glass effect:
     - **Keep**: confirms video, proceeds to export
     - **Redo**: deletes video, returns to record
   - Minimal UI—just player + buttons
   - Playback controls embedded in glass panel (LiquidGlass)

6. **VideoExportView (Shared)**
   - Share sheet using UIActivityViewController
   - Glass panel backdrop with translucent overlay
   - Built-in sharing options: AirDrop, Files, Mail, Messages
   - Cancel button (glass effect)
   - Post-share: confirmation message with subtle animation

7. **CameraViewfinder (iOS/iPadOS only)**
   - Low-level AVCaptureVideoPreviewLayer rendering
   - Embedded in VideoRecorderView
   - Handles orientation changes smoothly

### Phase 4: View Models & State Management (2-3 hours)
1. **VideoManagerViewModel**
   - Manage recording state machine (idle → recording → saved → QA)
   - Handle save/delete operations with iCloud sync
   - Track today's video status (check both local and iCloud)
   - Trigger view transitions: record → QA → export → done
   - Manage camera service lifecycle (iOS/iPadOS only)
   - Handle iCloud sync conflicts and errors

2. **ExportViewModel**
   - Manage share sheet presentation
   - Handle activity controller completion
   - Track export history (optional: which videos have been shared)

3. **SyncStateViewModel** (New)
   - Monitor iCloud sync status
   - Display sync indicator to user ("Syncing..." / "Synced" / "Offline")
   - Handle conflict resolution UI
   - Retry failed syncs

### Phase 5: Universal Integration & Polish (2-3 hours)

1. **Universal App Setup**
   - Configure entitlements for iCloud Containers
   - Set up universal binary target (iOS/iPadOS/macOS)
   - App Groups for iCloud container access
   - Handle platform detection for feature availability

2. **iCloud Integration**
   - Initialize iCloud container on app launch
   - Handle "iCloud not available" gracefully (offline mode)
   - Display sync status in UI (subtle glass indicator)
   - Test multi-device sync workflow

3. **Platform-Specific Code**
   - Use conditional compilation (`#if os(iOS)`, `#if os(macOS)`)
   - Camera access: iOS/iPadOS only
   - File picker: macOS-optimized (NSOpenPanel)
   - Menu bar: macOS-specific menu structure

4. **Error Handling & Edge Cases**
   - Camera unavailable (show "Camera not available" message)
   - iCloud container not accessible (offline mode)
   - User denies permissions (iOS/iPadOS only)
   - Storage quota exceeded (show user-friendly message)
   - Disk space warnings

5. **LiquidGlass Polish**
   - Verify glass effects render correctly on all platforms
   - Test Reduced Transparency mode
   - Test Reduced Motion mode
   - Test High Contrast mode
   - Ensure text contrast meets accessibility standards
   - Smooth animations with `.glassEffect()` modifiers
   - Dark mode + Light mode support

6. **Testing Across Devices**
   - Test on iPhone 15/16, iPad Pro/Air, Mac Studio/MacBook
   - Test cross-device sync: shoot on iPhone, verify on Mac
   - Test offline: edit locally, sync when online
   - Verify file appears in Files app on all devices

---

## MVP Scope (What's NOT Included)

The following features are intentionally excluded from MVP to keep scope tight:

- **Full calendar/journal view** (consumption interface)
- **Video browsing interface** (users access videos via Files app)
- **Additional backup services** (iCloud is the primary storage, additional redundancy out of scope)
- Video editing or trimming (external editors handle this)
- Notifications/reminders to record
- Widget support
- Settings screen
- Advanced search or filtering by date/metadata
- CloudKit (simple iCloud file sync sufficient for MVP)

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

### Commit Strategy
After each phase, commit to git:
- Phase 1: Setup
- Phase 2: Services
- Phase 3: Views
- Phase 4: View Models
- Phase 5: Polish

---

## Success Criteria for MVP

**Core Functionality**
✅ User can launch app on iOS, iPadOS, or macOS  
✅ User can record video (iOS/iPadOS only)  
✅ Video auto-saves to iCloud container on stop  
✅ QA view automatically appears post-capture  
✅ Director can keep or redo video in QA view  
✅ Keep button transitions to export interface  
✅ Redo button deletes video from iCloud and returns to record  
✅ Export interface shows native iOS/macOS share sheet  
✅ User can AirDrop, Mail, or Files-share the video  

**Cross-Device Sync (Critical)**
✅ Shoot video on iPhone, it appears in Files app on Mac within 10 seconds  
✅ Delete video on iPad, it disappears on iPhone  
✅ Offline: video saves locally, syncs when connected  
✅ Multiple devices recording same day: latest wins (no conflicts)  
✅ Sync status visible to user ("Syncing..." indicator)  

**Design & Polish**
✅ All UI elements use LiquidGlass glass effect (`.glassEffect()`)  
✅ Blur radius appropriate for platform (≤40px iPhone, ≤60px iPad/Mac)  
✅ Text contrast meets 4.5:1 minimum over glass background  
✅ Respects Reduced Transparency system setting  
✅ Respects Reduced Motion system setting  
✅ Dark mode + Light mode rendering correct  
✅ iPhone layout: vertical (compact)  
✅ iPad layout: sidebar + main content  
✅ Mac layout: window-based with menu bar  
✅ Orientation changes handled smoothly (iPad/Mac)  

**Quality & Compatibility**
✅ All videos remain standard MOV format, fully editable in external tools  
✅ App handles permissions gracefully (iOS/iPadOS only)  
✅ App handles iCloud not available (graceful offline mode)  
✅ Entitlements configured for iCloud Containers  
✅ Works on iOS 26+, iPadOS 26+, macOS 15+ (Sonoma/Tahoe)  
✅ No crashes on multi-device sync scenarios  

---

## Future Feature Roadmap (Post-MVP)

1. **CloudKit Metadata** – Richer sync using CloudKit for advanced queries (optional, not needed for basic sync)
2. **Statistics** – Show streak counter, total videos recorded, etc.
3. **Sharing Collections** – Create shareable compilations of videos
4. **Video Editing** – Trim, add filters, or captions (in-app, or delegate to external editors)
5. **Reminders** – Push notifications to record each day
6. **Widget** – Quick access to record from lock screen or home screen
7. **Search/Filter** – Find videos by date range or metadata
8. **Export Compilation** – Create reel from multiple videos
9. **Watch App** – WatchOS companion for quick control
10. **External Storage** – Direct iCloud Drive folder selection for videos

---

## Estimated Timeline

- **Phase 1 (Setup):** 1–2 hours
- **Phase 2 (Services):** 5–6 hours  
- **Phase 3 (Views):** 4–5 hours  
- **Phase 4 (View Models):** 2–3 hours  
- **Phase 5 (Integration & Polish):** 2–3 hours  

**Total MVP:** ~14–19 hours of development work

**Note:** This includes:
- iCloud Documents container sync
- Universal app (iPhone/iPad/Mac single codebase)
- LiquidGlass design system throughout
- Platform-specific optimizations
- Cross-device testing

This is realistic with Claude Code assistance and your SwiftUI + system architecture expertise. The largest time investment is handling platform-specific layouts and iCloud coordination.

**Critical Path (must complete first):**
1. Phase 1: Setup with iCloud entitlements
2. Phase 2: iCloudSyncService (foundation for everything else)
3. Phase 2: CameraService
4. Phase 3: VideoQAView (simplest, unblocks Phase 4)

---

## Next Steps

1. **Create new Xcode project:** DailyFrame (iOS + iPadOS + macOS universal app)
2. **Configure deployment targets:**
   - iOS: 26+
   - iPadOS: 26+
   - macOS: 15+ (Sonoma/Tahoe)
3. **Configure entitlements:**
   - Enable iCloud Containers
   - Add container ID: `iCloud.com.paz.dailyframe`
   - Enable Document Sync
   - Enable File Sharing (com.apple.developer.file-sharing-support)
4. **Set up folder structure** as outlined in Project Structure section
5. **Info.plist configuration:**
   - `NSCameraUsageDescription`: "DailyFrame needs camera access to record videos"
   - `NSMicrophoneUsageDescription`: "DailyFrame needs microphone access for video audio"
6. **Begin Phase 1** with Claude Code assistance
7. **Priority:** Get iCloudSyncService working before proceeding to other services (foundation for cross-device sync)
8. **Familiarize yourself with LiquidGlass:**
   - Reference: https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass
   - Key modifier: `.glassEffect()` in SwiftUI
   - Design principles: Clarity, Deference (content focus), Depth

**Key Build Settings:**
- Code Sign Entitlements: point to `.entitlements` file with iCloud container
- Supported Platforms: iOS, macOS
- Minimum Deployment Targets enforced per platform

---

Good luck! This is a modern, sophisticated app that will showcase your expertise in:
- Universal SwiftUI development
- Apple's latest design system (LiquidGlass)
- Cross-device synchronization
- AVFoundation video capture
- iCloud integration at scale

This will be a production-quality app ready for the App Store.