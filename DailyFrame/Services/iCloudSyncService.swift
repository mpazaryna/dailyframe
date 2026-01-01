import Foundation
import Combine

@MainActor
final class iCloudSyncService: NSObject, ObservableObject {
    static let shared = iCloudSyncService()

    @Published private(set) var syncState: SyncState = .idle
    @Published private(set) var lastSyncDate: Date?

    private var metadataQuery: NSMetadataQuery?
    private var cancellables = Set<AnyCancellable>()

    override private init() {
        super.init()
        setupMetadataQuery()
        observeUbiquityChanges()
    }

    private func setupMetadataQuery() {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*.mov'", NSMetadataItemFSNameKey)

        NotificationCenter.default.publisher(for: .NSMetadataQueryDidUpdate, object: query)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleQueryUpdate()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .NSMetadataQueryDidFinishGathering, object: query)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleQueryUpdate()
            }
            .store(in: &cancellables)

        query.start()
        metadataQuery = query
    }

    private func observeUbiquityChanges() {
        NotificationCenter.default.publisher(for: .NSUbiquityIdentityDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleUbiquityChange()
            }
            .store(in: &cancellables)
    }

    private func handleQueryUpdate() {
        guard let query = metadataQuery else { return }

        var allSynced = true
        query.disableUpdates()

        for i in 0..<query.resultCount {
            guard let item = query.result(at: i) as? NSMetadataItem else { continue }

            if let downloadStatus = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
                if downloadStatus != NSMetadataUbiquitousItemDownloadingStatusCurrent {
                    allSynced = false
                    // Trigger download for items not yet downloaded
                    if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                    }
                }
            }

            if let isUploading = item.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool,
               isUploading {
                allSynced = false
            }
        }

        query.enableUpdates()

        if allSynced {
            syncState = .synced
            lastSyncDate = Date()
        } else {
            syncState = .syncing
        }
    }

    private func handleUbiquityChange() {
        if FileManager.default.ubiquityIdentityToken == nil {
            syncState = .offline
        } else {
            syncState = .syncing
            metadataQuery?.start()
        }
    }

    func checkCloudAvailability() -> Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    func refreshSync() {
        syncState = .syncing
        metadataQuery?.stop()
        metadataQuery?.start()
    }

    func stopMonitoring() {
        metadataQuery?.stop()
    }
}
