import SwiftUI

@main
struct DailyFrameApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @State private var library = VideoLibrary()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.videoLibrary, library)
                .task {
                    // Clean up old montage files on launch
                    await VideoCompositionService.shared.cleanupOldMontages()
                }
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        #endif
    }
}
