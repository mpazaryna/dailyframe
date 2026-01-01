import SwiftUI

struct ContentView: View {
    @EnvironmentObject var videoManager: VideoManagerViewModel

    var body: some View {
        Group {
            switch Platform.current {
            case .iPhone:
                IPhoneRecordingView()
            case .iPad:
                IPadRecordingView()
            case .mac:
                MacRecordingView()
            }
        }
        .alert("Error", isPresented: $videoManager.showError) {
            Button("OK") {
                videoManager.dismissError()
            }
        } message: {
            Text(videoManager.errorMessage)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(VideoManagerViewModel())
}
