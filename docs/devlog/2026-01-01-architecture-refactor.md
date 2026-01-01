# Architecture Refactor: MVVM to View-Owned State

**Date:** 2026-01-01

## Summary

Major architectural overhaul removing MVVM in favor of SwiftUI's native view-owned state pattern. Consolidated platform-specific views into unified views with centralized configuration.

## Changes

- **Deleted ViewModels:**
  - `ExportViewModel.swift` (53 lines)
  - `VideoManagerViewModel.swift` (184 lines)

- **Created Services:**
  - `VideoLibrary.swift` - New `@Observable` service for video management, injected via `@Environment`

- **Consolidated Views:**
  - Deleted: `IPhoneRecordingView.swift`, `IPadRecordingView.swift`, `MacRecordingView.swift`, `VideoRecorderView.swift`, `VideoListItemView.swift`
  - Created: `HomeView.swift` (485 lines) - Unified home view adapting to all platforms
  - Created: `RecordingView.swift` (275 lines) - Unified recording view for iOS

- **Platform Configuration:**
  - Created `Configuration/PlatformConfig.swift` (427 lines) - Centralized layout configs for all platforms

- **Documentation:**
  - `ai_docs/no-mvvm.md` - Rationale for removing MVVM pattern
  - `ai_docs/core-swiftui-config.md` - Deep dive on SwiftUI AttributeGraph and config patterns

## Technical Details

**Pattern adopted:** Views own state directly via `@State` with `ViewState` enums. Services are `@Observable` classes injected through `@Environment`.

```swift
struct RecordingView: View {
    @Environment(\.videoLibrary) private var library
    @State private var camera = CameraService()

    enum ViewState: Equatable {
        case camera
        case recording
        case reviewing(VideoTake)
    }

    @State private var viewState: ViewState = .camera
}
```

**Platform config pattern:** Centralized configs in `PlatformConfig.swift` using composition with flattening. Views use `horizontalSizeClass` on iOS and static configs on macOS.

```swift
struct HomeLayoutConfig {
    let cardPadding: CGFloat
    let heroIconSize: CGFloat

    #if os(iOS)
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> Self
    #else
    static var current: Self
    #endif
}
```

**Why no MVVM:** SwiftUI views are structs designed to be lightweight state expressions. ViewModels add unnecessary indirection and fight the framework's reactive design. Apple's own SwiftData uses `@Query` directly in views, not ViewModels.

**Config scoping lessons:** The `core-swiftui-config.md` documents critical findings about NavigationSplitView and AttributeGraph. Shared config patterns can cause cascading updates and freezes when multiple views share reactive dependencies. Local configs are safer for mission-critical features with high-frequency state updates.

## Next Steps

- Wire up camera preview and recording functionality in `RecordingView`
- Implement video QA flow with take selection
- Add iCloud sync status indicators to `HomeView`
