# ADR-003: No-MVVM Pattern

**Status:** ACCEPTED

## Context

SwiftUI was designed with a different philosophy than UIKit. When SwiftUI launched in 2019, many developers brought their UIKit patterns (MVVM) with them. However, SwiftUI views are structs—lightweight, disposable, and recreated frequently. Adding ViewModels fights against this fundamental design.

Apple's own WWDC sessions (Data Flow Through SwiftUI 2019, Data Essentials in SwiftUI 2020) barely mention ViewModels because they're alien to SwiftUI's data flow model.

## Decision

DailyFrame uses **@Observable + @Environment** instead of MVVM. Views are pure state expressions with:

1. **@State for view-local state**: UI state like loading, error, expanded flags
2. **@Environment for shared services**: VideoLibrary, CameraService injected at app root
3. **View-level async with .task()**: Data fetching happens in view lifecycle
4. **.onChange() for side effects**: React to state changes declaratively

```swift
struct HomeView: View {
    @Environment(\.videoLibrary) private var library
    @State private var isLoading = false

    var body: some View {
        // View is a pure expression of state
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        await library.refresh()
    }
}
```

## Rationale

1. **Framework alignment**: SwiftUI was built for this pattern; ViewModels add unnecessary indirection
2. **Less boilerplate**: No ViewModel classes, no manual state synchronization
3. **Better testability**: Test services independently; views are too simple to need unit tests
4. **SwiftData compatibility**: @Query and modelContext work directly in views—ViewModels break this
5. **Simpler mental model**: State flows down, actions flow up, no intermediary objects

## Consequences

### Positive
- Views are simple, readable state expressions
- Services are tested thoroughly; views are validated visually via previews
- No ViewModel bloat or state synchronization bugs
- SwiftData @Query works naturally
- Easier onboarding—less architecture to learn

### Negative
- Large views may need decomposition into smaller subviews (not ViewModels)
- Developers with UIKit background may need adjustment period
- No single place for "view logic" (but this is a feature, not a bug)

## Testing Strategy

- **Unit test services**: VideoLibrary, CameraService, VideoCompositionService
- **SwiftUI Previews**: Visual regression testing for views
- **ViewInspector**: If view introspection needed for specific cases
- **UI automation**: End-to-end tests for critical flows

## Alternative Considered

Traditional MVVM with ObservableObject ViewModels—rejected because:
- Adds complexity without benefit in SwiftUI
- Breaks SwiftData's @Query pattern
- Requires manual state sync between VM and View
- Apple doesn't recommend it for SwiftUI

## References

- [Data Flow Through SwiftUI - WWDC19](https://developer.apple.com/videos/play/wwdc2019/226/)
- [Data Essentials in SwiftUI - WWDC20](https://developer.apple.com/videos/play/wwdc2020/10040/)
