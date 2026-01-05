# Changelog

All notable changes to DailyFrame will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-01-05

### Added
- **Video Recording** with AVFoundation (iOS/iPadOS only)
  - Front/back camera toggle
  - Multiple takes per day
- **Video Playback** for quality assurance review
- **Video Trimming** with visual range slider and thumbnail strip
- **Video Import** from Photos library with date picker
- **iCloud Sync** via Documents container for cross-device access
  - Sync status indicator in toolbar
  - NSFileCoordinator for safe writes
- **Video Export** via share sheet to standard MOV format
- **Montage Generation** stitching all videos with date overlays
- **Calendar View** for browsing video history with streak tracking
- **Home View** with dynamic landing experience
  - Hero stats banner (days recorded, current streak)
  - Video thumbnails with cached first-frame extraction
  - Weekly/monthly grouping (This Week, Last Week, by month)
  - iPad 2-column grid layout
- **Universal App** supporting iPhone, iPad, and Mac
- **LiquidGlass Design** following WWDC 2025 guidelines
- **ThumbnailService** with memory and disk caching
- XcodeGen project generation
- Architecture Decision Records
  - ADR-001: Export-first architecture
  - ADR-002: Universal app with iCloud sync
  - ADR-003: No MVVM pattern (views own state)
  - ADR-004: Centralized platform config
  - ADR-005: Privacy and scope boundaries

[Unreleased]: https://github.com/mpazarern/dailyframe/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mpazarern/dailyframe/releases/tag/v0.1.0
