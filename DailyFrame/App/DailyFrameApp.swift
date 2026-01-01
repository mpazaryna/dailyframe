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
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        #endif
    }
}
