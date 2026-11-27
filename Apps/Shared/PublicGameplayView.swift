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
    var body: some View {
        VStack(spacing: 12) {
            Text(state.presentingMove ? "Resolving move…" : state.winner == nil ? "\(member(active)?.name ?? "Player")’s turn" : "Game complete")
                .font(.system(.title, design: .serif).bold())
                .padding(12).frame(maxWidth: .infinity)
                .background(colors[member(active)?.color ?? 0].opacity(0.35), in: Capsule())
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Last move").font(.headline)
                    if let move = state.lastMove {
                        Text(member(move.seat)?.name ?? "Player")
                        Text(cardLabel(move.card))
                        Text(move.steps.isEmpty ? "Discarded" : "\(move.steps.count) marble move(s)").font(.caption)
                    } else { Text("Game starting") }
                    Divider()
                    Text("Up next").font(.headline)
                    if state.winner == nil {
                        ForEach(1...min(3, state.capacity - 1), id: \.self) { offset in
                            Text(member((active + offset) % state.capacity)?.name ?? "")
                        }
                    }
                }.padding(14).frame(width: 210, alignment: .leading).background(Color(red: 0.08, green: 0.065, blue: 0.05), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(red: 0.55, green: 0.39, blue: 0.23), lineWidth: 1))
                ZStack {
                    ModularBoardView(playerCount: state.capacity, activePlayer: active, gameMarbles: state.marbles,
                                     seatColors: state.seats.map { id in state.members.first { $0.id == id }?.color ?? 0 }, lastMove: state.lastMove)
                    VStack(spacing: 5) {
                        
                        HStack {
                            PremiumCardBack().frame(width: 44, height: 62)
                                .overlay {
                                    if drawing {
                                        PremiumCardBack()
                                            .offset(x: 30, y: -35).rotationEffect(.degrees(12))
                                    }
                                }
                            if let card = state.discard { PremiumCardView(card: card).frame(width: 44, height: 62) } else { RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])).frame(width: 44, height: 62) }
                        }
                        Text("Draw: \(state.drawCount ?? 0)").font(.caption)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(spacing: 8) {
                    ForEach(0..<state.capacity, id: \.self) { seat in
                        if let player = member(seat) {
                            HStack {
                                Image(systemName: player.isBot ? "cpu" : "person.crop.circle.fill")
                                    .font(.title2).foregroundStyle(colors[player.color])
                                VStack(alignment: .leading) {
                                    Text(player.name).font(.system(.headline, design: .serif)).lineLimit(1).minimumScaleFactor(0.7)
                                    if let partner = state.members.first(where: { $0.id == player.partner }) { Text("With " + partner.name).font(.caption) }
                                    if !connected.contains(player.id) { Text("Disconnected").font(.caption) }
                                }
                            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(red: 0.075, green: 0.06, blue: 0.05), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors[player.color], lineWidth: seat == active ? 3 : 1))
                                .shadow(color: colors[player.color].opacity(seat == active ? 0.7 : 0), radius: 10)
                        }
                    }
                }.frame(width: 240)
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
