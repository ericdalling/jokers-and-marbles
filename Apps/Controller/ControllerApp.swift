import SwiftUI

@main
struct ControllerApp: App {
    @State private var showLobby = false
    var body: some Scene {
        WindowGroup {
            if showLobby {
                JoinLobbyView { showLobby = false }
            } else {
            VStack {
            Button("Join game") { showLobby = true }.buttonStyle(.borderedProminent)
            GeometryReader { geometry in
                ScrollView([.vertical, .horizontal]) {
                    Image("EmmaInGamePreview")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width)
                        .frame(minHeight: geometry.size.height)
                }
                .background(Color(red: 0.10, green: 0.04, blue: 0.02))
                .scrollIndicators(.hidden)
                .accessibilityLabel("Jokers and Marbles in-game controller concept featuring Emma. Interactive gameplay coming soon.")
            }
            }
            }
        }
    }
}
