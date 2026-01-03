import AVFoundation
import Foundation

/// Represents timing information for a clip in the montage
struct MontageClip: Sendable {
    let date: Date
    let startTime: Double  // seconds from start of montage
    let endTime: Double    // seconds from start of montage
}

/// Result of creating a montage, includes timing data for overlays
struct MontageResult: Sendable {
    let videoURL: URL
    let clips: [MontageClip]
    let totalDuration: Double
}

/// Service for composing multiple videos into a single montage
actor VideoCompositionService {
    static let shared = VideoCompositionService()

    private let montagePrefix = "montage_"

    private init() {}

    /// Cleans up old montage files from the temp directory
    /// Call this periodically (e.g., on app launch) to prevent temp file accumulation
    func cleanupOldMontages(olderThan days: Int = 1) {
        let tempDirectory = FileManager.default.temporaryDirectory
        let expirationDate = Date().addingTimeInterval(-TimeInterval(days * 86400))

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        for url in contents {
            guard url.lastPathComponent.hasPrefix(montagePrefix),
                  url.pathExtension == "mov" else {
                continue
            }

            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let modDate = attributes[.modificationDate] as? Date,
               modDate < expirationDate {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    /// Creates a montage from an array of VideoDay objects
    /// - Parameters:
    ///   - videos: Array of VideoDay objects (will be sorted oldest to newest)
    ///   - secondsPerClip: Duration to use from each video (default 3 seconds)
    /// - Returns: MontageResult containing URL and clip timing data
    func createMontage(from videos: [VideoDay], secondsPerClip: Double = 3.0) async throws -> MontageResult {
        // Sort videos oldest to newest for chronological montage
        let sortedVideos = videos.sorted { $0.date < $1.date }

        // Filter to only videos with a selected take
        let videosWithTakes = sortedVideos.compactMap { day -> (day: VideoDay, take: VideoTake)? in
            guard let take = day.selectedTake else { return nil }
            return (day, take)
        }

        guard !videosWithTakes.isEmpty else {
            throw AppError.compositionFailed("No videos available for montage")
        }

        // Create composition
        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AppError.compositionFailed("Failed to create video track")
        }

        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var currentTime = CMTime.zero
        let clipDuration = CMTime(seconds: secondsPerClip, preferredTimescale: 600)

        // Track video settings for consistent output
        var naturalSize: CGSize = .zero
        var videoInstructions: [AVMutableVideoCompositionLayerInstruction] = []
        var montageClips: [MontageClip] = []

        for (day, take) in videosWithTakes {
            let asset = AVURLAsset(url: take.videoURL)

            // Load tracks
            guard let assetVideoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
                continue // Skip videos without video track
            }

            let assetDuration = try await asset.load(.duration)
            let duration = min(assetDuration, clipDuration)

            // Get natural size from first video
            if naturalSize == .zero {
                naturalSize = try await assetVideoTrack.load(.naturalSize)
                let transform = try await assetVideoTrack.load(.preferredTransform)
                // Adjust for rotation
                if transform.a == 0 && transform.d == 0 {
                    naturalSize = CGSize(width: naturalSize.height, height: naturalSize.width)
                }
            }

            let timeRange = CMTimeRange(start: .zero, duration: duration)

            // Insert video track
            do {
                try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)

                // Handle video orientation via layer instruction
                let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                let transform = try await assetVideoTrack.load(.preferredTransform)
                let trackSize = try await assetVideoTrack.load(.naturalSize)

                // Calculate transform to normalize orientation
                let normalizedTransform = normalizeTransform(transform, trackSize: trackSize, outputSize: naturalSize)
                instruction.setTransform(normalizedTransform, at: currentTime)
                videoInstructions.append(instruction)

                // Track clip timing for date overlay
                let startSeconds = CMTimeGetSeconds(currentTime)
                let endSeconds = startSeconds + CMTimeGetSeconds(duration)
                montageClips.append(MontageClip(
                    date: day.date,
                    startTime: startSeconds,
                    endTime: endSeconds
                ))
            } catch {
                continue // Skip problematic videos
            }

            // Insert audio track if available
            if let audioTrack = audioTrack,
               let assetAudioTrack = try? await asset.loadTracks(withMediaType: .audio).first {
                try? audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
            }

            currentTime = currentTime + duration
        }

        guard currentTime > .zero else {
            throw AppError.compositionFailed("No valid video segments to compose")
        }

        let totalDuration = CMTimeGetSeconds(currentTime)

        // Create video composition for orientation handling
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRange(start: .zero, duration: currentTime)
        mainInstruction.layerInstructions = videoInstructions
        videoComposition.instructions = [mainInstruction]

        // Export
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(montagePrefix)\(UUID().uuidString).mov")

        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw AppError.compositionFailed("Failed to create export session")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition

        await exportSession.export()

        switch exportSession.status {
        case .completed:
            return MontageResult(
                videoURL: outputURL,
                clips: montageClips,
                totalDuration: totalDuration
            )
        case .failed:
            throw exportSession.error ?? AppError.compositionFailed("Export failed")
        case .cancelled:
            throw AppError.compositionFailed("Export cancelled")
        default:
            throw AppError.compositionFailed("Unknown export error")
        }
    }

    /// Trims a video to the specified time range
    /// - Parameters:
    ///   - videoURL: Source video URL
    ///   - startTime: Start time in seconds
    ///   - endTime: End time in seconds
    /// - Returns: URL to the trimmed video file
    func trimVideo(at videoURL: URL, startTime: Double, endTime: Double) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)

        // Validate time range
        let maxSeconds = CMTimeGetSeconds(duration)
        let validStart = max(0, min(startTime, maxSeconds))
        let validEnd = max(validStart, min(endTime, maxSeconds))

        guard validEnd > validStart else {
            throw AppError.compositionFailed("Invalid trim range")
        }

        let startCMTime = CMTime(seconds: validStart, preferredTimescale: 600)
        let endCMTime = CMTime(seconds: validEnd, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startCMTime, end: endCMTime)

        // Create output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trimmed_\(UUID().uuidString).mov")

        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw AppError.compositionFailed("Failed to create export session")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.timeRange = timeRange

        await exportSession.export()

        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw exportSession.error ?? AppError.compositionFailed("Trim export failed")
        case .cancelled:
            throw AppError.compositionFailed("Trim export cancelled")
        default:
            throw AppError.compositionFailed("Unknown trim export error")
        }
    }

    /// Generates thumbnail images from a video at specified intervals
    /// - Parameters:
    ///   - videoURL: Source video URL
    ///   - count: Number of thumbnails to generate
    /// - Returns: Array of CGImages representing frames at even intervals
    func generateThumbnails(for videoURL: URL, count: Int) async throws -> [CGImage] {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)

        guard totalSeconds > 0, count > 0 else {
            return []
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 200, height: 200)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

        var thumbnails: [CGImage] = []
        let interval = totalSeconds / Double(count)

        for i in 0..<count {
            let time = CMTime(seconds: Double(i) * interval, preferredTimescale: 600)
            do {
                let (image, _) = try await generator.image(at: time)
                thumbnails.append(image)
            } catch {
                // Skip failed frames, continue with others
                continue
            }
        }

        return thumbnails
    }

    /// Normalizes a video transform to fit the output size
    private func normalizeTransform(_ transform: CGAffineTransform, trackSize: CGSize, outputSize: CGSize) -> CGAffineTransform {
        // Detect rotation from transform
        let angle = atan2(transform.b, transform.a)

        var result = CGAffineTransform.identity

        // Apply rotation around center
        let isRotated = abs(angle) > 0.1

        if isRotated {
            // Video is rotated - apply transform to center it
            if angle > 0 { // 90 degrees (portrait shot on phone)
                result = result.translatedBy(x: outputSize.width, y: 0)
                result = result.rotated(by: .pi / 2)
            } else if angle < 0 { // -90 degrees
                result = result.translatedBy(x: 0, y: outputSize.height)
                result = result.rotated(by: -.pi / 2)
            }
        }

        // Scale to fit if needed
        let scaleX = outputSize.width / (isRotated ? trackSize.height : trackSize.width)
        let scaleY = outputSize.height / (isRotated ? trackSize.width : trackSize.height)
        let scale = min(scaleX, scaleY)

        if scale != 1.0 {
            result = result.scaledBy(x: scale, y: scale)
        }

        return result
    }
}
