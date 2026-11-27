import SwiftUI
@main struct ControllerApp: App {
    @State private var hosting = false
    var body: some Scene {
        WindowGroup {
            if hosting { HostModeView { hosting = false } }
            else { ControllerLobbyView(hostMode: UIDevice.current.userInterfaceIdiom == .pad ? { hosting = true } : nil) }
        }
    }
}
