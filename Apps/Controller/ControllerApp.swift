import SwiftUI
import GameCore

@main
struct ControllerApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 24) {
                Image(systemName: "suit.club.fill").font(.system(size: 64))
                Text("Jokers & Marbles").font(.largeTitle.bold())
                Text("Player controller").font(.title2)
                Text("Multiplayer coming soon").foregroundStyle(.secondary)
            }.padding()
        }
    }
}
