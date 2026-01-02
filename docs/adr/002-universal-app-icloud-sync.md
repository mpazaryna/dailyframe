# ADR-002: Universal App with iCloud Sync

**Status:** ACCEPTED (MVP Requirement)

## Context

Users want to shoot videos on iPhone, review on Mac, and export from iPad. A device-specific app requires duplicating workflows. Cross-device sync requires a central authority to store and synchronize video metadata and file references. iCloud provides this infrastructure seamlessly on Apple platforms.

## Decision

DailyFrame is a **universal native app** (single Swift codebase) targeting iOS 26+, iPadOS 26+, and macOS 15+. All videos are stored in iCloud Drive's app container, making them accessible across all devices:

1. **iCloud Documents Container:** All video files sync automatically via iCloud Drive
2. **Device-Specific UI:** Layout adapts to screen size (compact on iPhone, sidebar on iPad/Mac)
3. **Platform Integration:** Uses native file APIs; users can also access videos in Files app
4. **Seamless Sync:** Shoot on iPhone, review on Mac, no manual sync needed

## Rationale

1. **One Codebase, Many Devices:** SwiftUI's layout system adapts view hierarchy to available space
2. **Zero Manual Sync:** iCloud handles transport; files appear instantly across devices
3. **Transparency:** Videos in Files app on any device; no hidden database
4. **Offline Support:** Cached copies on each device; sync happens when connected
5. **Privacy:** All files stay within user's iCloud; Apple has no visibility

## Consequences

### Positive
- Shoot anywhere, review anywhere
- One app to maintain across platforms
- iCloud handles sync complexity; app code stays simple
- Users can organize videos in Files app natively

### Negative
- Requires iOS 26+ minimum (not backward compatible)
- iCloud requires active Apple ID with iCloud Drive enabled
- Storage counts against user's iCloud quota

## Implementation

- Use `FileManager` with `.ubiquitousContainerURL()` to access iCloud app container
- Store videos in `Documents/Videos/` within the container
- Use `NSFileCoordinator` and `NSFilePresenter` for conflict-free multi-device writes
- Implement CloudKit for metadata if richer sync needed (out of MVP scope)

## Alternative Considered

CloudKit database for central video metadata - rejected for MVP because iCloud file sync is simpler, requires no backend, and provides transparent file ownership.
