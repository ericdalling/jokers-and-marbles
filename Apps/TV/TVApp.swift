import SwiftUI

@main
struct TVApp: App {
    var body: some Scene {
        WindowGroup {
            GeometryReader { geometry in
                Image("LandingBoard")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(Color.black)
                    .accessibilityLabel("Jokers and Marbles game board preview. Gameplay coming soon.")
            }
            .ignoresSafeArea()
        }
    }
}
