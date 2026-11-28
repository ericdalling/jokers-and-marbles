import SwiftUI
@main struct ControllerApp: App {
    @State private var hosting = false
    var body: some Scene {
        WindowGroup {
            #if DEBUG && targetEnvironment(simulator)
            if VisualReviewFixture.requested {
                if let fixture = try? VisualReviewFixture.make(), let personal = try? fixture.host.privateState(for: fixture.player) {
                    GameplayControllerView(state: fixture.host.publicState(), personal: personal, player: fixture.player) { _ in }
                } else { Text("Visual fixture failed") }
            } else { normalView }
            #else
            normalView
            #endif
        }
    }
    @ViewBuilder private var normalView: some View {
            if hosting { HostModeView { hosting = false } }
            else { ControllerLobbyView(hostMode: UIDevice.current.userInterfaceIdiom == .pad ? { hosting = true } : nil) }
    }
}
