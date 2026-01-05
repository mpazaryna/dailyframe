# Changelog

All notable changes to DailyFrame will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-01-05

### Added
- **Hero Stats Banner** on home view showing total days recorded and current streak
  - Motivational nudges ("Keep it going!", "On fire!") based on streak status
  - Animated transitions on value changes
- **Video Thumbnails** for recent videos list
  - ThumbnailService with memory and disk caching
  - Async loading with AVAssetImageGenerator
- **iPad Grid Layout** for recent videos (2-column grid vs single-column list on iPhone)
- **Weekly/Monthly Grouping** for video history
  - Groups: This Week, Last Week, Earlier This Month, then by month name
  - VideoGroup model and groupedVideos computed property

### Changed
- Moved "Watch your journey" montage card above recent videos for better visibility
- Updated VideoThumbnailView to use centralized ThumbnailService
- Added recentVideosColumns to PlatformConfig

## [0.2.0] - 2026-01-03

### Added
- **Video Import** from Photos library with date picker
- **Video Trimming** with visual range slider and thumbnail strip
- **Date Overlay** on montage playback showing recording date per clip
- **ADR-005**: Privacy and scope boundaries documentation
- Philosophy section in README (video only, privacy first, export to people)

### Fixed
- Concurrency and storage issues for TestFlight readiness
- Swift 6 strict concurrency compliance

### Changed
- Calendar view with streak tracking
- Montage compilation with date overlays
- Documentation restructure (devlogs, ADRs)

## [0.1.0] - 2026-01-01

### Added
- Initial release with core video diary functionality
- **Video Recording** with AVFoundation (iOS/iPadOS only)
- **Video Playback** for quality assurance review
- **iCloud Sync** via Documents container for cross-device access
- **Video Export** via share sheet to standard MOV format
- **Montage Generation** stitching all videos into compilation
- **Calendar View** for browsing video history
- **Universal App** supporting iPhone, iPad, and Mac
- **LiquidGlass Design** following WWDC 2025 guidelines
- XcodeGen project generation
- Architecture Decision Records (ADR-001 through ADR-004)
  - Export-first architecture
  - Universal app with iCloud sync
  - No MVVM pattern (views own state)
  - Centralized platform config

[Unreleased]: https://github.com/mpazarern/dailyframe/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/mpazarern/dailyframe/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/mpazarern/dailyframe/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/mpazarern/dailyframe/releases/tag/v0.1.0
