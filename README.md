# DailyFrame

A personal video diary app for iOS 26+, iPadOS 26+, and macOS 26+. Capture one video per day, review instantly, sync everywhere.

## Quick Start

```bash
xcodegen generate && open DailyFrame.xcodeproj
```

## What It Does

- **Record** one video per day (multiple takes allowed)
- **Review** immediately for quality assurance
- **Sync** automatically via iCloud across all devices
- **Export** as standard QuickTime MOV for editing elsewhere
- **Montage** stitch all videos into a compilation
- **Calendar** track your recording streak

## Tech Stack

- **Swift** + **SwiftUI** with LiquidGlass design system
- **AVFoundation** for video capture
- **iCloud Documents** for cross-device sync
- **XcodeGen** for project generation

## Project Structure

```
DailyFrame/
├── App/              # Entry point
├── Configuration/    # Platform configs
├── Models/           # Data models (VideoDay, VideoTake)
├── Services/         # Business logic (VideoLibrary, CameraService)
├── Views/            # SwiftUI views
└── Resources/        # Assets
```

---

## Documentation

For AI agents, see [CLAUDE.md](CLAUDE.md) for codebase context and conventions.

### [Specifications](docs/spec/)

Specs define what we're building before we build it. Each spec captures requirements, success criteria, and scope boundaries for a feature or milestone. Writing specs first forces clarity of thought and provides a reference point for both human developers and AI agents to align on intent.

### [Architecture Decision Records](docs/adr/)

ADRs capture the *why* behind significant technical decisions. When we choose a pattern, reject an alternative, or establish a convention, we record it as an ADR. This creates institutional memory—future contributors (human or AI) can understand not just what the code does, but why it was built that way. Each ADR follows a consistent format: Status, Context, Decision, Rationale, Consequences, and Alternatives Considered.

### [Development Log](docs/devlog/)

The devlog is a chronological record of significant development sessions. Unlike commit messages (which describe *what* changed), devlog entries capture the narrative—problems encountered, solutions discovered, and context that doesn't fit elsewhere. It's the story of how the project evolved, useful for onboarding and for remembering why certain rabbit holes were explored.

---

## Issues & Tracking

See [GitHub Issues](https://github.com/mpazarern/dailyframe/issues) for bugs and feature requests.
