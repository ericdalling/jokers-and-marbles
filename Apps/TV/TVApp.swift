import SwiftUI

@main
struct TVApp: App {
    var body: some Scene {
        WindowGroup { BoardPreviewScreen() }
    }
}

private struct BoardPreviewScreen: View {
    @State private var count = 6
    @State private var active = 0
    @State private var showBoard = false
    var body: some View {
        VStack {
            if showBoard {
                ModularBoardView(playerCount: count, activePlayer: active)
                HStack {
                    ForEach(3...6, id: \.self) { n in
                        Button("\(n) players") { count = n; active = 0 }
                    }
                    Button("Rotate") { active = (active + 1) % count }
                    Button("Landing") { showBoard = false }
                }
            } else {
                Image("LandingBoard").resizable().scaledToFit()
                Button("Preview board") { showBoard = true }
            }
        }
        .padding()
        .background(Color.black)
    }
}
