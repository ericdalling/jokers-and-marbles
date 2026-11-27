import SwiftUI
import GameCore

@main
struct TVApp: App {
    var body: some Scene {
        WindowGroup { BoardPreviewScreen() }
    }
}

private struct BoardPreviewScreen: View {
    @State private var count = 6
    @State private var individual = false
    private var paired: Bool { !individual && count % 2 == 0 }
    @State private var previewActive = 0
    @State private var game: ClassicGame?
    @State private var errorMessage: String?
    private var active: Int { game?.activeSeat ?? previewActive }
    @State private var showBoard = false
    private let names = ["Eric", "Christy", "Sophie", "Isabelle", "Emma", "Charlotte"]
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]

    var body: some View {
        VStack(spacing: 12) {
            if showBoard {
                HStack {
                    Text("Jokers & Marbles").font(.system(size: 42, weight: .bold, design: .serif)).italic().foregroundStyle(Color(red: 0.98, green: 0.88, blue: 0.72))
                    Spacer()
                    Text(game?.winner.map { paired ? "Team \($0 + 1) wins!" : names[$0] + " wins!" } ?? (names[active] + "’s Turn")).font(.title2.bold())
                        .padding(12).background(colors[active].opacity(0.4), in: Capsule())
                    Spacer()
                    if paired {
                        HStack(spacing: 18) {
                            ForEach(0..<(count / 2)) { team in
                                HStack(spacing: 4) {
                                    Circle().fill(colors[team]).frame(width: 18, height: 18)
                                    Circle().fill(colors[team + count / 2]).frame(width: 18, height: 18)
                                }
                            }
                        }.accessibilityLabel("Opposite-seat teams")
                    }
                }
                Text(game == nil ? "Gameplay preview" : "Local engine test • automatic legal moves • controllers pending").font(.caption)
                if game != nil { Text("Up next: " + names[(active + 1) % count]).font(.headline) }
                if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
                GeometryReader { proxy in
                    let side = min(proxy.size.height, proxy.size.width * 0.65)
                    ZStack {
                        ModularBoardView(playerCount: count, activePlayer: active, gameMarbles: game?.marbles)
                            .frame(width: side, height: side)
                        HStack(spacing: 18) {
                            card("▧", label: game.map { "Draw: \($0.drawCount)" } ?? "Draw pile", color: .blue)
                            card(game == nil ? "9♥" : face(game?.topDiscard), label: "Discard pile", color: .red)
                        }
                        ForEach(0..<count, id: \.self) { seat in
                            let angle = Double.pi / 2 + Double(seat) * 2 * Double.pi / Double(count)
                            VStack(spacing: 3) {
                                Image(systemName: "person.crop.circle.fill").font(.title2)
                                Text(names[seat]).font(.headline)
                                Text("\(game?.handCount(for: seat) ?? 5) cards").font(.caption)
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
                    if game == nil {
                        ForEach(3...6, id: \.self) { n in
                            Button("\(n) players") { count = n; previewActive = 0 }
                        }
                        if count % 2 == 0 {
                            Button(individual ? "Individual" : "Teams") { individual.toggle() }
                        }
                        Button("Next player preview") { previewActive = (previewActive + 1) % count }
                        Button("Start game test") { startGame() }
                    } else {
                        Button("Next legal move") { advance() }.disabled(game?.winner != nil)
                        Button("Restart") { startGame() }
                        Button("End test") { game = nil; errorMessage = nil }
                    }
                    Button("Landing") { showBoard = false; game = nil; errorMessage = nil }
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

    private func startGame() {
        do {
            let rules = try GameRules.modular(seats: count, individual: individual)
            game = try ClassicGame(rules: rules, seed: UInt64.random(in: 0...UInt64.max))
            errorMessage = nil
        } catch { errorMessage = String(describing: error) }
    }

    private func advance() {
        guard var current = game, current.winner == nil else { return }
        let plays = current.legalPlays()
        func score(_ play: GamePlay) -> Int {
            play.steps.reduce(0) { total, step in
                switch step.destination {
                case .home(let h): return total + 100 + h
                case .track: return total + (current.marbles[step.marble].position == .start ? 20 : 1)
                case .start: return total
                }
            }
        }
        guard let play = plays.max(by: { score($0) < score($1) }) else {
            errorMessage = "No legal play returned"; return
        }
        do {
            try current.play(play, by: current.activeSeat)
            withAnimation(.easeInOut(duration: 0.35)) { game = current }
        } catch { errorMessage = String(describing: error) }
    }

    private func face(_ card: PlayingCard?) -> String {
        guard let card else { return "—" }
        switch card {
        case .joker: return "Joker"
        case .standard(let rank, let suit):
            let ranks = [1: "A", 11: "J", 12: "Q", 13: "K"]
            let symbols: [CardSuit: String] = [.hearts: "♥", .diamonds: "♦", .clubs: "♣", .spades: "♠"]
            return (ranks[rank.rawValue] ?? String(rank.rawValue)) + (symbols[suit] ?? "")
        }
    }

    private func card(_ face: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(face).font(.system(size: 40, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 76, height: 100)
                .background(Color(red: 0.99, green: 0.94, blue: 0.83), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.68, green: 0.48, blue: 0.26), lineWidth: 2))
            Text(label).font(.caption)
        }
    }
}
