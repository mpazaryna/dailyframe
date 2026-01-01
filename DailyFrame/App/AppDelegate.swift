import Foundation
#if os(iOS)
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        setupiCloudContainer()
        return true
    }

    private func setupiCloudContainer() {
        Task {
            await VideoStorageService.shared.initializeStorage()
        }
    }
}

#elseif os(macOS)
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupiCloudContainer()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func setupiCloudContainer() {
        Task {
            await VideoStorageService.shared.initializeStorage()
        }
    }
}
#endif
