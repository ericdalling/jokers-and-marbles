import SwiftUI

@main
struct ControllerApp: App {
    var body: some Scene {
        WindowGroup {
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
            .ignoresSafeArea()
        }
    }
}
