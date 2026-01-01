import SwiftUI

enum Platform {
    case iPhone
    case iPad
    case mac

    static var current: Platform {
        #if os(macOS)
        return .mac
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPad
        }
        return .iPhone
        #endif
    }

    var supportsCamera: Bool {
        switch self {
        case .iPhone, .iPad:
            return true
        case .mac:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .iPhone:
            return "iPhone"
        case .iPad:
            return "iPad"
        case .mac:
            return "Mac"
        }
    }
}

enum DeviceOrientation {
    case portrait
    case landscape

    #if os(iOS)
    static var current: DeviceOrientation {
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .landscapeLeft, .landscapeRight:
            return .landscape
        default:
            return .portrait
        }
    }
    #else
    static var current: DeviceOrientation {
        .landscape
    }
    #endif
}
