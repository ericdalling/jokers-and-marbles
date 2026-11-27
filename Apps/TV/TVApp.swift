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
    private let names = ["Alex", "Mom", "Ethan", "Emma", "Sophie", "Grandpa"]
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]

    var body: some View {
        VStack(spacing: 12) {
            if showBoard {
                HStack {
                    Text("Jokers & Marbles").font(.system(size: 42, weight: .bold, design: .serif))
                    Spacer()
                    Text(names[active] + "’s Turn").font(.title2.bold())
                        .padding(12).background(colors[active].opacity(0.4), in: Capsule())
                    Spacer()
                    if count == 6 {
                        HStack(spacing: 18) {
                            ForEach(0..<3) { team in
                                HStack(spacing: 4) {
                                    Circle().fill(colors[team]).frame(width: 18, height: 18)
                                    Circle().fill(colors[team + 3]).frame(width: 18, height: 18)
                                }
                            }
                        }.accessibilityLabel("Three opposite-seat teams")
                    }
                }
                Text("Gameplay preview • controller connection pending").font(.caption)
                GeometryReader { proxy in
                    let side = min(proxy.size.height, proxy.size.width * 0.65)
                    ZStack {
                        ModularBoardView(playerCount: count, activePlayer: active)
                            .frame(width: side, height: side)
                        HStack(spacing: 18) {
                            card("▧", label: "Draw pile", color: .blue)
                            card("9♥", label: "Discard pile", color: .red)
                        }
                        ForEach(0..<count, id: \.self) { seat in
                            let angle = Double.pi / 2 + Double(seat - active) * 2 * Double.pi / Double(count)
                            VStack(spacing: 3) {
                                Image(systemName: "person.crop.circle.fill").font(.title2)
                                Text(names[seat]).font(.headline)
                                Text("5 cards").font(.caption)
                            }
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(colors[seat].opacity(seat == active ? 0.8 : 0.35), in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(seat == active ? colors[seat] : .clear, lineWidth: 3))
                            .position(x: proxy.size.width / 2 + CGFloat(cos(angle)) * side * 0.68,
                                      y: proxy.size.height / 2 + CGFloat(sin(angle)) * side * 0.40)
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                HStack {
                    ForEach(3...6, id: \.self) { n in
                        Button("\(n) players") { count = n; active = 0 }
                    }
                    Button("Rotate") { active = (active + 1) % count }
                    Button("Landing") { showBoard = false }
                }
            } else {
                Image("LandingBoard").resizable().scaledToFit()
                Button("Preview gameplay") { showBoard = true }
            }
        }
        .padding(30)
        .foregroundStyle(.white)
        .background(LinearGradient(colors: [Color(red: 0.36, green: 0.19, blue: 0.10), Color(red: 0.13, green: 0.06, blue: 0.03)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
    }

    private func card(_ face: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(face).font(.system(size: 40, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 76, height: 100)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
            Text(label).font(.caption)
        }
    }
}
