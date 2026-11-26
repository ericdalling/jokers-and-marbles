import SwiftUI
import GameCore

@main
struct TVApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 40) {
                Text("Jokers & Marbles").font(.largeTitle.bold())
                HStack(spacing: 24) {
                    ForEach(MarbleColor.allCases, id: \.self) { marble in
                        Text(marble.rawValue.capitalized)
                    }
                }
                Text("Shared game board — coming soon").foregroundStyle(.secondary)
            }
        }
    }
}
