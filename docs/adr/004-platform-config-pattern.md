# ADR-004: Platform-Adaptive Configuration Pattern

**Status:** ACCEPTED

## Context

DailyFrame runs on iPhone, iPad, and macOS. Each platform has different layout requirements:
- iPhone: Compact layouts, smaller controls
- iPad: Larger spacing, centered content with max-width
- macOS: Sidebar navigation, window-based UI

The traditional approach creates device-specific view files (`Views/iPhone/`, `Views/iPad/`, `Views/Mac/`), leading to code duplication, maintenance burden, and drift between platforms.

## Decision

DailyFrame uses a **centralized platform-adaptive configuration system**. All platform-specific layout values are defined in `Configuration/PlatformConfig.swift` using a **composition with flattening** pattern.

### Structure

```
BasePlatformConfig          # Shared primitives (spacing, fonts, control sizes)
    ↓ flattens into
HomeLayoutConfig            # Home screen specific + base properties
RecordingLayoutConfig       # Recording screen specific + base properties
CalendarLayoutConfig        # Calendar specific + base properties
```

### Implementation

```swift
struct HomeLayoutConfig {
    // Flattened base properties
    let cardPadding: CGFloat
    let sectionSpacing: CGFloat

    // View-specific properties
    let recordButtonSize: CGFloat
    let usesSidebarNavigation: Bool

    #if os(iOS)
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> Self {
        sizeClass == .regular ? Self(/* iPad */) : Self(/* iPhone */)
    }
    #else
    static var current: Self { /* macOS */ }
    #endif
}
```

### Usage in Views

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
            // Layout adapts via config values
        }
    }
}
```

## Rationale

1. **Single source of truth**: All platform values in one file
2. **No code duplication**: One view file handles all platforms
3. **Explicit differences**: Platform variations clearly visible in config
4. **Type safety**: Compiler ensures all platforms define required values
5. **No AttributeGraph crashes**: Config is read fresh per-view, not shared across NavigationSplitView boundaries

## Consequences

### Positive
- Single file to tune all platform layout values
- Unified views adapt automatically
- Easy to see exactly how platforms differ
- Adding new views follows clear pattern
- iPad multitasking "just works" (size class changes)

### Negative
- Initial config setup requires defining all platform variants
- Config structs can grow large for complex views
- Requires discipline to keep configs in sync

## Platform Detection

- **iOS**: `@Environment(\.horizontalSizeClass)` distinguishes iPhone (`.compact`) from iPad (`.regular`)
- **macOS**: Static computed property (no size class concept)
- **iPad Multitasking**: Size class changes dynamically—configs handle this automatically

## Adding a New View

1. Define config struct in `PlatformConfig.swift` with platform variants
2. Flatten needed base properties + add view-specific properties
3. Use config in view via computed property pattern

## Alternative Considered

Device-specific view files (`IPhoneHomeView.swift`, `IPadHomeView.swift`, `MacHomeView.swift`)—rejected because:
- Code duplication across 3 files per view
- Bug fixes require changes in multiple places
- Easy for platforms to drift apart
- More files to navigate and maintain
