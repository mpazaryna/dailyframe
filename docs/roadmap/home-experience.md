# Home Experience Roadmap

**Status**: Production
**Last Updated**: 2026-01-05

The home view is the primary landing experience for DailyFrame, providing at-a-glance status and quick access to all features.

## Current Features

### Hero Stats Banner
Displays total days recorded and current streak with motivational nudges.

- Shows "Keep it going!" when streak active but no recording today
- Shows "On fire!" when streak reaches 7+ days
- Animated transitions on value changes

### Today Status Card
Quick view of today's recording status with action to view takes.

### Montage Card
Prominent call-to-action for "Watch your journey" montage generation.

### Recent Videos
Grouped video history with thumbnails.

| Feature | Platform | Description |
|---------|----------|-------------|
| Weekly/Monthly Groups | All | This Week, Last Week, Earlier This Month, by month |
| Video Thumbnails | All | Cached first-frame extraction |
| 2-Column Grid | iPad | Adaptive layout for larger screens |
| Single-Column List | iPhone | Compact list with inline thumbnails |

## Technical Implementation

- `HomeView.swift` - Main view with platform-specific layouts
- `ThumbnailService.swift` - Memory + disk cached thumbnail generation
- `VideoLibrary.groupedVideos` - Computed property for date grouping
- `PlatformConfig.recentVideosColumns` - Adaptive column count

## Related Docs

- ADR: [004-platform-config-pattern](../adr/004-platform-config-pattern.md)

## Future Considerations

- [ ] Video preview on long-press
- [ ] Customizable grouping (by week vs month)
- [ ] Search/filter videos
- [ ] Home screen widget showing streak
