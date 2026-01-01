import SwiftUI

struct SyncStatusView: View {
    let syncState: SyncState

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: syncState.iconName)
                .font(.caption)
                .symbolEffect(.pulse, isActive: syncState == .syncing)

            if !syncState.displayText.isEmpty {
                Text(syncState.displayText)
                    .font(.caption)
            }
        }
        .foregroundStyle(syncState.isError ? .red : .secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 20) {
        SyncStatusView(syncState: .syncing)
        SyncStatusView(syncState: .synced)
        SyncStatusView(syncState: .offline)
        SyncStatusView(syncState: .error("Connection failed"))
    }
    .padding()
}
