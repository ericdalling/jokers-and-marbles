import SwiftUI
import GameCore

struct PublicGameplayView: View {
    let state: PublicSession
    let connected: Set<UUID>
    @State private var drawing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]
    private var active: Int { state.presentingMove ? (state.lastMove?.seat ?? state.activeSeat ?? 0) : (state.activeSeat ?? 0) }
    private func member(_ seat: Int) -> LobbyMember? {
        guard state.seats.indices.contains(seat) else { return nil }
        return state.members.first { $0.id == state.seats[seat] }
    }
    private func cardLabel(_ card: PlayingCard) -> String {
        switch card {
        case .joker: return "Joker"
        case .standard(let rank, let suit):
            let ranks = [1: "A", 11: "J", 12: "Q", 13: "K"]
            let suits: [CardSuit: String] = [.hearts: "♥", .diamonds: "♦", .clubs: "♣", .spades: "♠"]
            return (ranks[rank.rawValue] ?? String(rank.rawValue)) + (suits[suit] ?? "")
        }
    }
    private func badge(_ player: LobbyMember, active: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: player.isBot ? "cpu" : "person.fill")
            Text(player.name).lineLimit(1).minimumScaleFactor(0.5)
        }.font(.headline).padding(.horizontal, 12).padding(.vertical, 6)
            .background(LinearGradient(colors: [colors[player.color].opacity(0.85), .black], startPoint: .top, endPoint: .bottom), in: Capsule())
            .overlay(Capsule().strokeBorder(colors[player.color], lineWidth: 2))
            .shadow(color: colors[player.color].opacity(active ? 0.9 : 0.4), radius: active ? 8 : 3)
    }
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 14) {
                    PremiumLogo()
                    Divider()
                    Text("\(state.capacity) Players").font(.headline)
                    Text(state.individual ? "Individual game" : "\(state.capacity / 2) Teams")
                    ForEach(0..<state.capacity, id: \.self) { seat in
                        if let player = member(seat), state.individual || seat < state.capacity / 2 {
                            HStack {
                                JewelMarble(color: colors[player.color]).frame(width: 24, height: 24)
                                Text(player.name + (state.members.first(where: { $0.id == player.partner }).map { " + " + $0.name } ?? "")).font(.caption)
                            }
                        }
                    }
                    Divider()
                    Label("Cards", systemImage: "rectangle.on.rectangle").font(.headline)
                    Text("Draw pile: \(state.drawCount ?? 0)")
                    Text("Discard: " + (state.discard.map(cardLabel) ?? "Empty"))
                }.modifier(PremiumPanel()).frame(width: geo.size.width * 0.19)
                GeometryReader { board in
                    ZStack {
                        ModularBoardView(playerCount: state.capacity, activePlayer: active, gameMarbles: state.marbles,
                            seatColors: state.seats.map { id in state.members.first { $0.id == id }?.color ?? 0 }, lastMove: state.lastMove)
                            .padding(28)
                        VStack(spacing: 8) {
                            if state.capacity >= 4 { PremiumLogo().frame(maxWidth: board.size.width * 0.34) }
                            HStack(spacing: 14) {
                                VStack {
                                    PremiumCardBack().frame(width: 48, height: 68)
                                    Text("Draw pile").font(.caption2)
                                }
                                VStack {
                                    if let card = state.discard { PremiumCardView(card: card).frame(width: 48, height: 68) }
                                    else { RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.5)).frame(width: 48, height: 68).overlay(Text("Empty").font(.caption2)) }
                                    Text("Discard").font(.caption2)
                                }
                            }
                        }.scaleEffect(state.capacity == 3 ? 0.65 : 1)
                        ForEach(0..<state.capacity, id: \.self) { seat in
                            if let player = member(seat) {
                                let angle = Double.pi / 2 + Double(seat) * 2 * Double.pi / Double(state.capacity)
                                let radius = min(board.size.width, board.size.height) * 0.43
                                badge(player, active: seat == active)
                                    .position(x: board.size.width / 2 + CGFloat(cos(angle)) * radius, y: board.size.height / 2 + CGFloat(sin(angle)) * radius)
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("CURRENT TURN").font(.caption)
                    if let player = member(active) { badge(player, active: true) }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Last Move").font(.headline)
                        if let move = state.lastMove {
                            Text(member(move.seat)?.name ?? "Player")
                            Text(cardLabel(move.card))
                        } else { Text("No moves yet"); Text("The game is ready.").font(.caption) }
                        Divider()
                        Text("Next").font(.headline)
                        if state.winner == nil {
                            ForEach(1...min(2, state.capacity - 1), id: \.self) { offset in
                                Text(member((active + offset) % state.capacity)?.name ?? "")
                            }
                        }
                    }.modifier(PremiumPanel())
                }.frame(width: geo.size.width * 0.19)
            }
        }
        .task(id: state.revision) {
            guard !state.presentingMove, state.lastMove != nil, state.winner == nil, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.35)) { drawing = true }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeIn(duration: 0.25)) { drawing = false }
        }
    }
}
