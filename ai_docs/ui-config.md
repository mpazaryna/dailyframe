# Multi-Platform UI Configuration Pattern

## Overview

DailyFrame uses a **centralized platform-adaptive configuration system** to handle layout differences across iPhone, iPad, and macOS. All platform-specific layout values are defined in a single file (`Configuration/PlatformConfig.swift`) using a **composition with flattening** pattern.

This approach eliminates device-specific view folders (no `Views/iPhone/`, `Views/iPad/`, `Views/Mac/`) in favor of unified views that adapt their layout based on configuration values.

---

## Core Principles

### 1. Single Source of Truth
All layout constants live in `PlatformConfig.swift`. When you need to adjust spacing, font sizes, or component dimensions, you change one file—not hunt through multiple view files.

### 2. Composition with Flattening
View-specific configs "flatten" base properties into their own struct. This means:
- No nested property access (`config.base.cardPadding`)
- Clean flat API (`config.cardPadding`)
- Each config struct is self-contained

### 3. Platform Detection via Size Class (iOS) or Static Config (macOS)
- **iOS**: Uses `@Environment(\.horizontalSizeClass)` to detect iPhone (`.compact`) vs iPad (`.regular`)
- **macOS**: Uses static computed property since there's no size class concept

### 4. No Device-Specific View Files
Instead of `IPhoneHomeView.swift` and `IPadHomeView.swift`, we have one `HomeView.swift` that adapts. The view reads config values and adjusts its layout accordingly.

---

## Architecture

### File Structure

```
DailyFrame/
├── Configuration/
│   └── PlatformConfig.swift    # ALL platform configs live here
├── Views/
│   ├── HomeView.swift          # Unified - uses HomeLayoutConfig
│   ├── RecordingView.swift     # Unified - uses RecordingLayoutConfig
│   └── Shared/
│       ├── VideoQAView.swift   # Uses VideoQALayoutConfig
│       └── VideoExportView.swift
```

### Config Hierarchy

```
BasePlatformConfig          # Shared primitives (spacing, fonts, control sizes)
    ↓ flattens into
HomeLayoutConfig            # Home screen specific + base properties
RecordingLayoutConfig       # Recording screen specific + base properties
VideoQALayoutConfig         # QA screen specific + base properties
VideoBrowserLayoutConfig    # macOS sidebar specific + base properties
```

---

## Implementation Details

### BasePlatformConfig

The foundation layer defines shared layout primitives that vary by platform:

```swift
struct BasePlatformConfig {
    // Spacing
    let cardPadding: CGFloat
    let cardSpacing: CGFloat
    let sectionSpacing: CGFloat

    // Typography
    let bodyFontSize: CGFloat
    let headlineFontSize: CGFloat
    let captionFontSize: CGFloat

    // Controls
    let buttonControlSize: ControlSize
    let cardCornerRadius: CGFloat

    // Sheet dimensions
    let sheetMinWidth: CGFloat
    let sheetMinHeight: CGFloat

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
```

### View-Specific Configs

Each view gets its own config that includes both:
1. **Flattened base properties** (copied from BasePlatformConfig)
2. **View-specific properties** (unique to that screen)

Example for `HomeLayoutConfig`:

```swift
struct HomeLayoutConfig {
    // MARK: Flattened Base Properties
    let cardPadding: CGFloat
    let cardSpacing: CGFloat
    let sectionSpacing: CGFloat
    let bodyFontSize: CGFloat
    let headlineFontSize: CGFloat
    let captionFontSize: CGFloat
    let buttonControlSize: ControlSize
    let cardCornerRadius: CGFloat

    // MARK: Home-Specific Properties
    let heroIconSize: CGFloat
    let recordButtonSize: CGFloat
    let recordButtonIconSize: CGFloat
    let thumbnailWidth: CGFloat
    let thumbnailHeight: CGFloat
    let usesSidebarNavigation: Bool
    let maxContentWidth: CGFloat

    #if os(iOS)
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> Self {
        let base = BasePlatformConfig.current(sizeClass)
        return sizeClass == .regular
            ? Self(  // iPad
                cardPadding: base.cardPadding,
                cardSpacing: base.cardSpacing,
                // ... flatten all base properties
                heroIconSize: 100,          // iPad-specific
                recordButtonSize: 80,
                thumbnailWidth: 72,
                usesSidebarNavigation: false,
                maxContentWidth: 600
            )
            : Self(  // iPhone
                cardPadding: base.cardPadding,
                // ... flatten all base properties
                heroIconSize: 80,           // iPhone-specific
                recordButtonSize: 72,
                thumbnailWidth: 56,
                usesSidebarNavigation: false,
                maxContentWidth: 0          // 0 = full width
            )
    }
    #else
    static var current: Self {  // macOS
        let base = BasePlatformConfig.current
        return Self(
            cardPadding: base.cardPadding,
            // ... flatten all base properties
            heroIconSize: 60,
            recordButtonSize: 0,            // No record button on Mac
            usesSidebarNavigation: true,    // Mac uses sidebar
            maxContentWidth: 0
        )
    }
    #endif
}
```

### Using Configs in Views

Views declare a computed property that returns the appropriate config:

```swift
struct HomeView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var config: HomeLayoutConfig { HomeLayoutConfig.current(sizeClass) }
    #else
    private var config: HomeLayoutConfig { HomeLayoutConfig.current }
    #endif

    var body: some View {
        VStack(spacing: config.sectionSpacing) {
            // Hero section
            Image(systemName: "video.badge.plus")
                .font(.system(size: config.heroIconSize))

            // Record button (only if size > 0)
            if config.recordButtonSize > 0 {
                RecordButton(size: config.recordButtonSize)
            }

            // Content with max width constraint
            ScrollView {
                content
                    .frame(maxWidth: config.maxContentWidth > 0
                        ? config.maxContentWidth
                        : .infinity)
            }
        }
        .padding(config.cardPadding)
    }
}
```

---

## Platform Values Reference

### iPhone (compact size class)
```
cardPadding: 16
sectionSpacing: 20
heroIconSize: 80
recordButtonSize: 72
thumbnailWidth: 56
maxContentWidth: 0 (full width)
```

### iPad (regular size class)
```
cardPadding: 20
sectionSpacing: 24
heroIconSize: 100
recordButtonSize: 80
thumbnailWidth: 72
maxContentWidth: 600 (centered content)
```

### macOS (static)
```
cardPadding: 20
sectionSpacing: 24
heroIconSize: 60
recordButtonSize: 0 (no recording on Mac)
thumbnailWidth: 80
usesSidebarNavigation: true
```

---

## Why This Pattern?

### Problem with Device-Specific Views
The traditional approach creates separate view files:
```
Views/
├── iPhone/
│   └── IPhoneHomeView.swift
├── iPad/
│   └── IPadHomeView.swift
└── Mac/
    └── MacHomeView.swift
```

**Issues:**
1. **Code duplication** - Same logic repeated with different constants
2. **Maintenance burden** - Bug fixes require changes in multiple files
3. **Inconsistency risk** - Easy for platforms to drift apart
4. **SwiftUI AttributeGraph issues** - Sharing configs across NavigationSplitView boundaries can cause crashes (see `core-swiftui-config.md`)

### Benefits of Centralized Config

1. **Single file to tune** - Adjust all platform values in one place
2. **Unified views** - One `HomeView.swift` handles all platforms
3. **Explicit differences** - Platform variations are clearly visible in config
4. **Type safety** - Compiler ensures all platforms define all required values
5. **No AttributeGraph issues** - Config is read fresh per-view, not shared

---

## Adding a New View

When creating a new view that needs platform-adaptive layout:

### Step 1: Define the Config

Add to `PlatformConfig.swift`:

```swift
struct MyNewViewLayoutConfig {
    // Flatten base properties you need
    let cardPadding: CGFloat
    let bodyFontSize: CGFloat

    // Add view-specific properties
    let specialButtonSize: CGFloat
    let showExtraControls: Bool

    #if os(iOS)
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> Self {
        let base = BasePlatformConfig.current(sizeClass)
        return sizeClass == .regular
            ? Self(
                cardPadding: base.cardPadding,
                bodyFontSize: base.bodyFontSize,
                specialButtonSize: 60,
                showExtraControls: true
            )
            : Self(
                cardPadding: base.cardPadding,
                bodyFontSize: base.bodyFontSize,
                specialButtonSize: 44,
                showExtraControls: false
            )
    }
    #else
    static var current: Self {
        let base = BasePlatformConfig.current
        return Self(
            cardPadding: base.cardPadding,
            bodyFontSize: base.bodyFontSize,
            specialButtonSize: 50,
            showExtraControls: true
        )
    }
    #endif
}
```

### Step 2: Use in View

```swift
struct MyNewView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var config: MyNewViewLayoutConfig { MyNewViewLayoutConfig.current(sizeClass) }
    #else
    private var config: MyNewViewLayoutConfig { MyNewViewLayoutConfig.current }
    #endif

    var body: some View {
        VStack {
            Button("Action") { }
                .frame(width: config.specialButtonSize)

            if config.showExtraControls {
                ExtraControlsView()
            }
        }
        .padding(config.cardPadding)
    }
}
```

---

## Conditional Platform Code

For features that only exist on certain platforms (like camera recording), use `#if os()`:

```swift
var body: some View {
    #if os(iOS)
    iOSContent
    #else
    macOSContent
    #endif
}

#if os(iOS)
private var iOSContent: some View {
    // Camera recording UI
}
#endif

#if os(macOS)
private var macOSContent: some View {
    // Browse-only UI
}
#endif
```

Or use config flags:

```swift
// In config
let supportsRecording: Bool  // true on iOS, false on macOS

// In view
if config.supportsRecording {
    RecordButton()
}
```

---

## Testing Configs

To verify configs work correctly:

1. **iOS Simulator** - Test iPhone and iPad simulators (different size classes)
2. **macOS** - Run the macOS target
3. **iPad Multitasking** - Test split view (size class changes dynamically)
4. **Rotation** - Verify layout adapts on orientation change

---

## Related Documentation

- `ai_docs/no-mvvm.md` - Why we don't use ViewModels
- `ai_docs/core-swiftui-config.md` - SwiftUI AttributeGraph considerations
- `CLAUDE.md` - Project architecture overview
