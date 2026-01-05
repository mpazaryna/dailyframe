# DailyFrame Roadmap

Navigational context for evolving DailyFrame. Unlike README (what it does), this document answers: **What capabilities exist? Where is the documentation? What's planned next?**

## How to Use This Document

When working on DailyFrame features:

1. Find the relevant capability below
2. Check its status and related documentation
3. Follow links to ADRs and specs for full context

---

## Core Capabilities

### Video Capture

**Status**: Production
**Platform**: iOS, iPadOS

Record daily videos with immediate quality review.

| Feature | Status | Description |
|---------|--------|-------------|
| Camera Recording | Production | AVFoundation capture with front/back toggle |
| Multiple Takes | Production | Record multiple takes per day, select best |
| QA Playback | Production | Instant review post-capture |
| Trimming | Production | Visual range slider to trim clips |

**Key Docs**:
- ADR: [001-export-first-architecture](docs/adr/001-export-first-architecture.md)
- ADR: [003-no-mvvm-pattern](docs/adr/003-no-mvvm-pattern.md)

---

### Video Library

**Status**: Production
**Platform**: All

Browse, organize, and manage video history.

| Feature | Status | Description |
|---------|--------|-------------|
| Calendar View | Production | Browse by date with streak tracking |
| Recent Videos | Production | Grouped by week/month with thumbnails |
| Hero Stats | Production | Days recorded + streak display |
| Video Import | Production | Import from Photos library |
| Thumbnail Cache | Production | Memory + disk cached first-frame extraction |

**Key Docs**:
- ADR: [004-platform-config-pattern](docs/adr/004-platform-config-pattern.md)

---

### iCloud Sync

**Status**: Production
**Platform**: All

Automatic cross-device synchronization.

| Feature | Status | Description |
|---------|--------|-------------|
| Documents Sync | Production | Videos in `iCloud.com.paz.dailyframe` container |
| Sync Status | Production | Visual indicator in toolbar |
| Conflict Resolution | Production | NSFileCoordinator for safe writes |

**Key Docs**:
- ADR: [002-universal-app-icloud-sync](docs/adr/002-universal-app-icloud-sync.md)

---

### Export & Sharing

**Status**: Production
**Platform**: All

Export videos as standard MOV files.

| Feature | Status | Description |
|---------|--------|-------------|
| Share Sheet | Production | UIActivityViewController export |
| Montage Generation | Production | Stitch all videos with date overlays |
| Standard Format | Production | QuickTime MOV, no vendor lock-in |

**Key Docs**:
- ADR: [001-export-first-architecture](docs/adr/001-export-first-architecture.md)
- ADR: [005-privacy-and-scope-boundaries](docs/adr/005-privacy-and-scope-boundaries.md)

---

### Platform Support

**Status**: Production

| Platform | Recording | Browsing | Sync |
|----------|-----------|----------|------|
| iPhone | Yes | Yes | Yes |
| iPad | Yes | Yes | Yes |
| Mac | No | Yes | Yes |

**Key Docs**:
- ADR: [002-universal-app-icloud-sync](docs/adr/002-universal-app-icloud-sync.md)
- ADR: [004-platform-config-pattern](docs/adr/004-platform-config-pattern.md)

---

## Planned / Ideas

| Feature | Priority | Description |
|---------|----------|-------------|
| Widget | Medium | Home screen widget showing streak |
| Watch App | Low | Quick capture from Apple Watch |
| Notifications | Medium | Daily reminder to record |
| Year in Review | Medium | Annual montage compilation |
| Custom Themes | Low | Alternative glass tint colors |

---

## Documentation Map

| Type | Location | Purpose |
|------|----------|---------|
| **ADRs** | `docs/adr/` | Why decisions were made |
| **Specs** | `docs/spec/` | Feature specifications |
| **Devlogs** | `docs/devlog/` | Development narrative |
| **MCP** | `docs/mcp/` | MCP server configs |

---

## Adding New Features

When starting a new feature:

1. Create spec in `docs/spec/{feature}.md` if complex
2. Create ADR in `docs/adr/` for significant decisions
3. Update this roadmap with status
4. Add entry to CHANGELOG.md when shipped

---

## See Also

- [README.md](README.md) - Project overview and quick start
- [CLAUDE.md](CLAUDE.md) - AI agent context
- [CHANGELOG.md](CHANGELOG.md) - Version history
