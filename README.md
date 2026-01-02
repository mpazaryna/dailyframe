# DailyFrame

A personal video diary app for iOS 26+, iPadOS 26+, and macOS 26+. Capture one video per day, review instantly, sync everywhere.

## Quick Start

```bash
# Generate Xcode project
xcodegen generate

# Open in Xcode
open DailyFrame.xcodeproj
```

## What It Does

- **Record** one video per day (multiple takes allowed)
- **Review** immediately for quality assurance
- **Sync** automatically via iCloud across all devices
- **Export** as standard QuickTime MOV for editing elsewhere
- **Montage** stitch all videos into a compilation
- **Calendar** track your recording streak

## Documentation

| Document | Description |
|----------|-------------|
| [CLAUDE.md](CLAUDE.md) | AI agent context and codebase overview |

### Specifications

| Spec | Description |
|------|-------------|
| [Bootstrap](docs/spec/bootstrap.md) | Initial MVP specification and success criteria |

### Architecture Decisions (ADRs)

| ADR | Decision |
|-----|----------|
| [ADR-001](docs/adr/001-export-first-architecture.md) | Export-first architecture (playback for QA, export for distribution) |
| [ADR-002](docs/adr/002-universal-app-icloud-sync.md) | Universal app with iCloud sync |
| [ADR-003](docs/adr/003-no-mvvm-pattern.md) | No-MVVM pattern (@Observable + @Environment) |
| [ADR-004](docs/adr/004-platform-config-pattern.md) | Platform-adaptive configuration structs |

### Development Log

| Date | Entry |
|------|-------|
| [2026-01-01](docs/devlog/2026-01-01-architecture-refactor.md) | Architecture refactor |

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

## Issues & Tracking

See [GitHub Issues](https://github.com/mpazarern/dailyframe/issues) for bugs and feature requests.
