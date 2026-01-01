import SwiftUI

@main
struct DailyFrameApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @StateObject private var videoManager = VideoManagerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(videoManager)
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Video") {
                Button("Export Current Video") {
                    videoManager.triggerExport()
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(videoManager.currentVideo == nil)
            }
        }
        #endif
    }
}
