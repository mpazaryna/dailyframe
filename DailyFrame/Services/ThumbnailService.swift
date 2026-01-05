import Foundation
import AVFoundation
#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

/// Service for generating and caching video thumbnails
actor ThumbnailService {
    static let shared = ThumbnailService()

    private var cacheDirectory: URL?
    private var memoryCache: [URL: PlatformImage] = [:]
    private let maxMemoryCacheSize = 50
    private var isInitialized = false

    private init() {
        // Cache directory setup deferred to first use
    }

    private func ensureInitialized() {
        guard !isInitialized else { return }
        isInitialized = true

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("Thumbnails")
        try? FileManager.default.createDirectory(at: cacheDirectory!, withIntermediateDirectories: true)
    }

    /// Gets a thumbnail for a video, generating and caching if needed
    func thumbnail(for videoURL: URL, size: CGSize) async -> PlatformImage? {
        ensureInitialized()

        // Check memory cache first
        if let cached = memoryCache[videoURL] {
            return cached
        }

        // Check disk cache
        if let diskCached = loadFromDisk(for: videoURL) {
            addToMemoryCache(diskCached, for: videoURL)
            return diskCached
        }

        // Generate new thumbnail
        guard let generated = await generateThumbnail(for: videoURL, size: size) else {
            return nil
        }

        // Cache it
        addToMemoryCache(generated, for: videoURL)
        saveToDisk(generated, for: videoURL)

        return generated
    }

    private func generateThumbnail(for videoURL: URL, size: CGSize) async -> PlatformImage? {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: size.width * 2, height: size.height * 2) // 2x for retina

        do {
            let cgImage = try await generator.image(at: .zero).image

            #if os(iOS)
            return UIImage(cgImage: cgImage)
            #else
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            #endif
        } catch {
            return nil
        }
    }

    private func cacheKey(for videoURL: URL) -> String {
        // Use video filename as cache key
        videoURL.deletingPathExtension().lastPathComponent + ".jpg"
    }

    private func loadFromDisk(for videoURL: URL) -> PlatformImage? {
        guard let cacheDir = cacheDirectory else { return nil }
        let cachePath = cacheDir.appendingPathComponent(cacheKey(for: videoURL))

        guard FileManager.default.fileExists(atPath: cachePath.path) else { return nil }

        #if os(iOS)
        return UIImage(contentsOfFile: cachePath.path)
        #else
        return NSImage(contentsOfFile: cachePath.path)
        #endif
    }

    private func saveToDisk(_ image: PlatformImage, for videoURL: URL) {
        guard let cacheDir = cacheDirectory else { return }
        let cachePath = cacheDir.appendingPathComponent(cacheKey(for: videoURL))

        #if os(iOS)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: cachePath)
        }
        #else
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            try? jpegData.write(to: cachePath)
        }
        #endif
    }

    private func addToMemoryCache(_ image: PlatformImage, for videoURL: URL) {
        // Simple LRU-like behavior: clear oldest if over limit
        if memoryCache.count >= maxMemoryCacheSize {
            memoryCache.removeAll()
        }
        memoryCache[videoURL] = image
    }

    /// Clears all cached thumbnails
    func clearCache() {
        memoryCache.removeAll()
        if let cacheDir = cacheDirectory {
            try? FileManager.default.removeItem(at: cacheDir)
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
    }

    /// Removes cached thumbnail for a specific video (call when video is deleted)
    func removeThumbnail(for videoURL: URL) {
        memoryCache.removeValue(forKey: videoURL)
        if let cacheDir = cacheDirectory {
            let cachePath = cacheDir.appendingPathComponent(cacheKey(for: videoURL))
            try? FileManager.default.removeItem(at: cachePath)
        }
    }
}
