//
//  PlatformConfig.swift
//  DailyFrame
//
//  Centralized platform-adaptive configuration using composition/flattening pattern.
//
//  This file serves as the single source of truth for all platform-specific layout
//  configurations across the app. View-specific configs extend the base through
//  property flattening rather than nested composition.

import SwiftUI

// MARK: - Base Platform Configuration

/// Base platform-adaptive configuration providing shared layout primitives.
///
/// Provides foundational layout values that are consistent across different views
/// but vary by platform (iPhone, iPad, macOS). Uses **composition with flattening**
/// pattern to avoid nested property access.
///
/// ## Platform Detection
/// - **iOS**: Uses `horizontalSizeClass` environment value
///   - `.regular` = iPad (spacious layouts, larger touch targets)
///   - `.compact` = iPhone (compact layouts, optimized for smaller screens)
/// - **macOS**: Static configuration optimized for pointer precision
struct BasePlatformConfig {
    // MARK: Spacing
    /// Standard padding inside cards/containers
    let cardPadding: CGFloat
    /// Spacing between elements inside cards
    let cardSpacing: CGFloat
    /// Spacing between major sections
    let sectionSpacing: CGFloat

    // MARK: Typography
    /// Font size for body text
    let bodyFontSize: CGFloat
    /// Font size for headlines
    let headlineFontSize: CGFloat
    /// Font size for captions/secondary text
    let captionFontSize: CGFloat

    // MARK: Controls
    /// Standard button control size
    let buttonControlSize: ControlSize
    /// Corner radius for cards
    let cardCornerRadius: CGFloat

    // MARK: Sheet Dimensions
    /// Minimum width for modal sheets (0 = full screen)
    let sheetMinWidth: CGFloat
    /// Minimum height for modal sheets (0 = full screen)
    let sheetMinHeight: CGFloat

    // MARK: Semantic Font Helpers
    var headlineFont: Font { .system(size: headlineFontSize, weight: .semibold) }
    var bodyFont: Font { .system(size: bodyFontSize) }
    var captionFont: Font { .system(size: captionFontSize) }

    #if os(iOS)
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> Self {
        sizeClass == .regular
            ? Self(  // iPad - spacious, touch-optimized
                cardPadding: 20,
                cardSpacing: 16,
                sectionSpacing: 24,
                bodyFontSize: 15,
                headlineFontSize: 17,
                captionFontSize: 12,
                buttonControlSize: .regular,
                cardCornerRadius: 16,
                sheetMinWidth: 500,
                sheetMinHeight: 400
            )
            : Self(  // iPhone - compact, optimized for smaller screens
                cardPadding: 16,
                cardSpacing: 12,
                sectionSpacing: 20,
                bodyFontSize: 14,
                headlineFontSize: 16,
                captionFontSize: 11,
                buttonControlSize: .regular,
                cardCornerRadius: 12,
                sheetMinWidth: 0,
                sheetMinHeight: 0
            )
    }
    #else
    static var current: Self {  // macOS - pointer-optimized
        Self(
            cardPadding: 20,
            cardSpacing: 16,
            sectionSpacing: 24,
            bodyFontSize: 14,
            headlineFontSize: 16,
            captionFontSize: 11,
            buttonControlSize: .regular,
            cardCornerRadius: 12,
            sheetMinWidth: 400,
            sheetMinHeight: 400
        )
    }
    #endif
}

// MARK: - Home View Configuration

/// HomeView layout configuration with flattened base properties.
///
/// Adapts the home screen layout for iPhone (compact, single column),
/// iPad (comfortable, potential grid), and macOS (sidebar-based).
struct HomeLayoutConfig {
    // MARK: Inherited Base Properties (Flattened)
    let cardPadding: CGFloat
    let cardSpacing: CGFloat
    let sectionSpacing: CGFloat
    let bodyFontSize: CGFloat
    let headlineFontSize: CGFloat
    let captionFontSize: CGFloat
    let buttonControlSize: ControlSize
    let cardCornerRadius: CGFloat

    // MARK: Home-Specific Properties
    /// Size of hero icon in empty state
    let heroIconSize: CGFloat
    /// Size of record button
    let recordButtonSize: CGFloat
    /// Record button icon size
    let recordButtonIconSize: CGFloat
    /// Thumbnail width for video rows
    let thumbnailWidth: CGFloat
    /// Thumbnail height for video rows
    let thumbnailHeight: CGFloat
    /// Whether to show sidebar navigation (macOS)
    let usesSidebarNavigation: Bool
    /// Maximum content width (0 = full width)
    let maxContentWidth: CGFloat
    /// Number of columns for recent videos grid (1 = list, 2+ = grid)
    let recentVideosColumns: Int

    #if os(iOS)
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> Self {
        let base = BasePlatformConfig.current(sizeClass)
        return sizeClass == .regular
            ? Self(  // iPad
                cardPadding: base.cardPadding,
                cardSpacing: base.cardSpacing,
                sectionSpacing: base.sectionSpacing,
                bodyFontSize: base.bodyFontSize,
                headlineFontSize: base.headlineFontSize,
                captionFontSize: base.captionFontSize,
                buttonControlSize: base.buttonControlSize,
                cardCornerRadius: base.cardCornerRadius,
                heroIconSize: 100,
                recordButtonSize: 80,
                recordButtonIconSize: 32,
                thumbnailWidth: 72,
                thumbnailHeight: 48,
                usesSidebarNavigation: false,
                maxContentWidth: 700,
                recentVideosColumns: 2
            )
            : Self(  // iPhone
                cardPadding: base.cardPadding,
                cardSpacing: base.cardSpacing,
                sectionSpacing: base.sectionSpacing,
                bodyFontSize: base.bodyFontSize,
                headlineFontSize: base.headlineFontSize,
                captionFontSize: base.captionFontSize,
                buttonControlSize: base.buttonControlSize,
                cardCornerRadius: base.cardCornerRadius,
                heroIconSize: 80,
                recordButtonSize: 72,
                recordButtonIconSize: 28,
                thumbnailWidth: 56,
                thumbnailHeight: 40,
                usesSidebarNavigation: false,
                maxContentWidth: 0,
                recentVideosColumns: 1
            )
    }
    #else
    static var current: Self {  // macOS
        let base = BasePlatformConfig.current
        return Self(
            cardPadding: base.cardPadding,
            cardSpacing: base.cardSpacing,
            sectionSpacing: base.sectionSpacing,
            bodyFontSize: base.bodyFontSize,
            headlineFontSize: base.headlineFontSize,
            captionFontSize: base.captionFontSize,
            buttonControlSize: base.buttonControlSize,
            cardCornerRadius: base.cardCornerRadius,
            heroIconSize: 60,
            recordButtonSize: 0,  // No record button on Mac
            recordButtonIconSize: 0,
            thumbnailWidth: 80,
            thumbnailHeight: 54,
            usesSidebarNavigation: true,
            maxContentWidth: 0,
            recentVideosColumns: 1  // macOS uses sidebar, not grid
        )
    }
    #endif
}

// MARK: - Recording View Configuration

/// RecordingView layout configuration with flattened base properties.
///
/// Adapts camera recording UI for iPhone and iPad. macOS doesn't support recording.
struct RecordingLayoutConfig {
    // MARK: Inherited Base Properties (Flattened)
    let cardPadding: CGFloat
    let cardSpacing: CGFloat
    let bodyFontSize: CGFloat
    let captionFontSize: CGFloat

    // MARK: Recording-Specific Properties
    /// Record button outer size
    let recordButtonSize: CGFloat
    /// Record button inner circle size (not recording)
    let recordButtonInnerSize: CGFloat
    /// Record button inner size when recording
    let recordButtonRecordingSize: CGFloat
    /// Top bar padding
    let topBarPadding: CGFloat
    /// Bottom padding for controls
    let bottomPadding: CGFloat
    /// Cancel button size
    let cancelButtonSize: CGFloat

    #if os(iOS)
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> Self {
        let base = BasePlatformConfig.current(sizeClass)
        return sizeClass == .regular
            ? Self(  // iPad
                cardPadding: base.cardPadding,
                cardSpacing: base.cardSpacing,
                bodyFontSize: base.bodyFontSize,
                captionFontSize: base.captionFontSize,
                recordButtonSize: 90,
                recordButtonInnerSize: 70,
                recordButtonRecordingSize: 36,
                topBarPadding: 20,
                bottomPadding: 50,
                cancelButtonSize: 44
            )
            : Self(  // iPhone
                cardPadding: base.cardPadding,
                cardSpacing: base.cardSpacing,
                bodyFontSize: base.bodyFontSize,
                captionFontSize: base.captionFontSize,
                recordButtonSize: 80,
                recordButtonInnerSize: 60,
                recordButtonRecordingSize: 30,
                topBarPadding: 16,
                bottomPadding: 40,
                cancelButtonSize: 36
            )
    }
    #else
    static var current: Self {  // macOS - stub (no camera)
        let base = BasePlatformConfig.current
        return Self(
            cardPadding: base.cardPadding,
            cardSpacing: base.cardSpacing,
            bodyFontSize: base.bodyFontSize,
            captionFontSize: base.captionFontSize,
            recordButtonSize: 0,
            recordButtonInnerSize: 0,
            recordButtonRecordingSize: 0,
            topBarPadding: 0,
            bottomPadding: 0,
            cancelButtonSize: 0
        )
    }
    #endif
}

// MARK: - Video QA/Review Configuration

/// VideoQAView layout configuration with flattened base properties.
///
/// Adapts video review/QA interface for all platforms.
struct VideoQALayoutConfig {
    // MARK: Inherited Base Properties (Flattened)
    let cardPadding: CGFloat
    let cardSpacing: CGFloat
    let bodyFontSize: CGFloat
    let headlineFontSize: CGFloat
    let captionFontSize: CGFloat
    let buttonControlSize: ControlSize

    // MARK: QA-Specific Properties
    /// QA action button width
    let actionButtonWidth: CGFloat
    /// QA action button height
    let actionButtonHeight: CGFloat
    /// Action button icon size
    let actionButtonIconSize: CGFloat
    /// Action button corner radius
    let actionButtonCornerRadius: CGFloat
    /// Spacing between action buttons
    let actionButtonSpacing: CGFloat
    /// Bottom padding for action buttons
    let bottomPadding: CGFloat

    #if os(iOS)
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> Self {
        let base = BasePlatformConfig.current(sizeClass)
        return sizeClass == .regular
            ? Self(  // iPad
                cardPadding: base.cardPadding,
                cardSpacing: base.cardSpacing,
                bodyFontSize: base.bodyFontSize,
                headlineFontSize: base.headlineFontSize,
                captionFontSize: base.captionFontSize,
                buttonControlSize: base.buttonControlSize,
                actionButtonWidth: 100,
                actionButtonHeight: 80,
                actionButtonIconSize: 28,
                actionButtonCornerRadius: 20,
                actionButtonSpacing: 24,
                bottomPadding: 50
            )
            : Self(  // iPhone
                cardPadding: base.cardPadding,
                cardSpacing: base.cardSpacing,
                bodyFontSize: base.bodyFontSize,
                headlineFontSize: base.headlineFontSize,
                captionFontSize: base.captionFontSize,
                buttonControlSize: base.buttonControlSize,
                actionButtonWidth: 80,
                actionButtonHeight: 70,
                actionButtonIconSize: 24,
                actionButtonCornerRadius: 16,
                actionButtonSpacing: 20,
                bottomPadding: 40
            )
    }
    #else
    static var current: Self {  // macOS
        let base = BasePlatformConfig.current
        return Self(
            cardPadding: base.cardPadding,
            cardSpacing: base.cardSpacing,
            bodyFontSize: base.bodyFontSize,
            headlineFontSize: base.headlineFontSize,
            captionFontSize: base.captionFontSize,
            buttonControlSize: base.buttonControlSize,
            actionButtonWidth: 100,
            actionButtonHeight: 80,
            actionButtonIconSize: 28,
            actionButtonCornerRadius: 16,
            actionButtonSpacing: 24,
            bottomPadding: 40
        )
    }
    #endif
}

// MARK: - Video Browser Configuration (macOS sidebar)

/// VideoBrowserView layout configuration for macOS sidebar-based browsing.
struct VideoBrowserLayoutConfig {
    // MARK: Inherited Base Properties (Flattened)
    let cardPadding: CGFloat
    let cardSpacing: CGFloat
    let bodyFontSize: CGFloat
    let headlineFontSize: CGFloat
    let captionFontSize: CGFloat

    // MARK: Browser-Specific Properties
    /// Sidebar minimum width
    let sidebarMinWidth: CGFloat
    /// Sidebar ideal width
    let sidebarIdealWidth: CGFloat
    /// Sidebar maximum width
    let sidebarMaxWidth: CGFloat
    /// Empty state icon size
    let emptyStateIconSize: CGFloat
    /// Export sheet minimum size
    let exportSheetMinSize: CGSize

    #if os(iOS)
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> Self {
        let base = BasePlatformConfig.current(sizeClass)
        return sizeClass == .regular
            ? Self(  // iPad
                cardPadding: base.cardPadding,
                cardSpacing: base.cardSpacing,
                bodyFontSize: base.bodyFontSize,
                headlineFontSize: base.headlineFontSize,
                captionFontSize: base.captionFontSize,
                sidebarMinWidth: 280,
                sidebarIdealWidth: 320,
                sidebarMaxWidth: 400,
                emptyStateIconSize: 48,
                exportSheetMinSize: CGSize(width: 400, height: 400)
            )
            : Self(  // iPhone - no sidebar
                cardPadding: base.cardPadding,
                cardSpacing: base.cardSpacing,
                bodyFontSize: base.bodyFontSize,
                headlineFontSize: base.headlineFontSize,
                captionFontSize: base.captionFontSize,
                sidebarMinWidth: 0,
                sidebarIdealWidth: 0,
                sidebarMaxWidth: 0,
                emptyStateIconSize: 48,
                exportSheetMinSize: CGSize(width: 0, height: 0)
            )
    }
    #else
    static var current: Self {  // macOS
        let base = BasePlatformConfig.current
        return Self(
            cardPadding: base.cardPadding,
            cardSpacing: base.cardSpacing,
            bodyFontSize: base.bodyFontSize,
            headlineFontSize: base.headlineFontSize,
            captionFontSize: base.captionFontSize,
            sidebarMinWidth: 220,
            sidebarIdealWidth: 280,
            sidebarMaxWidth: 350,
            emptyStateIconSize: 60,
            exportSheetMinSize: CGSize(width: 400, height: 400)
        )
    }
    #endif
}

// MARK: - Video Trimming Configuration

/// VideoTrimmingView layout configuration with flattened base properties.
///
/// Adapts video trimming interface for all platforms with thumbnail strip,
/// range slider, and playback controls.
struct VideoTrimmingConfig {
    // MARK: Inherited Base Properties (Flattened)
    let cardPadding: CGFloat
    let bodyFontSize: CGFloat
    let headlineFontSize: CGFloat
    let captionFontSize: CGFloat

    // MARK: Trimming-Specific Properties
    /// Height of the thumbnail strip
    let thumbnailStripHeight: CGFloat
    /// Number of thumbnails to generate
    let thumbnailCount: Int
    /// Corner radius for thumbnails
    let thumbnailCornerRadius: CGFloat
    /// Height of the range slider track
    let sliderTrackHeight: CGFloat
    /// Size of the range slider handles
    let handleSize: CGFloat
    /// Width of the handle grip lines
    let handleGripWidth: CGFloat
    /// Minimum selectable duration in seconds
    let minimumDuration: Double
    /// Bottom padding for controls
    let bottomPadding: CGFloat
    /// Top bar height
    let topBarHeight: CGFloat
    /// Action button width
    let actionButtonWidth: CGFloat
    /// Action button height
    let actionButtonHeight: CGFloat

    #if os(iOS)
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> Self {
        let base = BasePlatformConfig.current(sizeClass)
        return sizeClass == .regular
            ? Self(  // iPad
                cardPadding: base.cardPadding,
                bodyFontSize: base.bodyFontSize,
                headlineFontSize: base.headlineFontSize,
                captionFontSize: base.captionFontSize,
                thumbnailStripHeight: 60,
                thumbnailCount: 12,
                thumbnailCornerRadius: 6,
                sliderTrackHeight: 60,
                handleSize: 24,
                handleGripWidth: 3,
                minimumDuration: 1.0,
                bottomPadding: 50,
                topBarHeight: 60,
                actionButtonWidth: 120,
                actionButtonHeight: 50
            )
            : Self(  // iPhone
                cardPadding: base.cardPadding,
                bodyFontSize: base.bodyFontSize,
                headlineFontSize: base.headlineFontSize,
                captionFontSize: base.captionFontSize,
                thumbnailStripHeight: 50,
                thumbnailCount: 10,
                thumbnailCornerRadius: 4,
                sliderTrackHeight: 50,
                handleSize: 20,
                handleGripWidth: 2,
                minimumDuration: 1.0,
                bottomPadding: 40,
                topBarHeight: 50,
                actionButtonWidth: 100,
                actionButtonHeight: 44
            )
    }
    #else
    static var current: Self {  // macOS
        let base = BasePlatformConfig.current
        return Self(
            cardPadding: base.cardPadding,
            bodyFontSize: base.bodyFontSize,
            headlineFontSize: base.headlineFontSize,
            captionFontSize: base.captionFontSize,
            thumbnailStripHeight: 50,
            thumbnailCount: 12,
            thumbnailCornerRadius: 4,
            sliderTrackHeight: 50,
            handleSize: 20,
            handleGripWidth: 2,
            minimumDuration: 1.0,
            bottomPadding: 30,
            topBarHeight: 50,
            actionButtonWidth: 100,
            actionButtonHeight: 36
        )
    }
    #endif
}

// MARK: - Calendar Layout Config

struct CalendarLayoutConfig {
    let cellSize: CGFloat
    let cellSpacing: CGFloat
    let monthHeaderFontSize: CGFloat
    let weekdayFontSize: CGFloat
    let dayFontSize: CGFloat
    let checkmarkSize: CGFloat
    let streakFontSize: CGFloat
    let horizontalPadding: CGFloat

    #if os(iOS)
    static func current(_ sizeClass: UserInterfaceSizeClass?) -> Self {
        sizeClass == .regular
            ? Self(  // iPad
                cellSize: 44,
                cellSpacing: 8,
                monthHeaderFontSize: 20,
                weekdayFontSize: 12,
                dayFontSize: 15,
                checkmarkSize: 20,
                streakFontSize: 14,
                horizontalPadding: 24
            )
            : Self(  // iPhone
                cellSize: 40,
                cellSpacing: 6,
                monthHeaderFontSize: 18,
                weekdayFontSize: 11,
                dayFontSize: 14,
                checkmarkSize: 18,
                streakFontSize: 13,
                horizontalPadding: 16
            )
    }
    #else
    static var current: Self {  // macOS
        Self(
            cellSize: 36,
            cellSpacing: 6,
            monthHeaderFontSize: 16,
            weekdayFontSize: 11,
            dayFontSize: 13,
            checkmarkSize: 16,
            streakFontSize: 12,
            horizontalPadding: 20
        )
    }
    #endif
}
