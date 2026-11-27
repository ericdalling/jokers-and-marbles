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
                        Text(String(describing: move.card))
                        Text(move.steps.isEmpty ? "Discarded" : "\(move.steps.count) marble move(s)").font(.caption)
                    } else { Text("Game starting") }
                    Divider()
                    Text("Up next").font(.headline)
                    if state.winner == nil {
                        ForEach(1...min(3, state.capacity - 1), id: \.self) { offset in
                            Text(member((active + offset) % state.capacity)?.name ?? "")
                        }
                    }
                }.padding(14).background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
                ZStack {
                    ModularBoardView(playerCount: state.capacity, activePlayer: active, gameMarbles: state.marbles,
                                     seatColors: state.seats.map { id in state.members.first { $0.id == id }?.color ?? 0 }, lastMove: state.lastMove)
                    VStack(spacing: 5) {
                        Text("Jokers & Marbles").font(.system(.caption, design: .serif).italic())
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.05, green: 0.18, blue: 0.42))
                                RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.8), lineWidth: 2).padding(4)
                                Image(systemName: "diamond.fill").foregroundStyle(.white.opacity(0.8))
                            }.frame(width: 44, height: 62)
                                .overlay {
                                    if drawing {
                                        RoundedRectangle(cornerRadius: 6).fill(.blue)
                                            .overlay(Image(systemName: "diamond.fill").foregroundStyle(.white))
                                            .offset(x: 30, y: -35).rotationEffect(.degrees(12))
                                    }
                                }
                            if let card = state.discard { PremiumCardView(card: card).frame(width: 44, height: 62) } else { RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])).frame(width: 44, height: 62) }
                        }
                        Text("Draw: \(state.drawCount ?? 0)").font(.caption)
                    }
                }.aspectRatio(1, contentMode: .fit).frame(maxHeight: 650)
                VStack(spacing: 8) {
                    ForEach(0..<state.capacity, id: \.self) { seat in
                        if let player = member(seat) {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                VStack(alignment: .leading) {
                                    Text(player.name).font(.headline)
                                    if let partner = state.members.first(where: { $0.id == player.partner }) { Text("With " + partner.name).font(.caption) }
                                    if !connected.contains(player.id) { Text("Disconnected").font(.caption) }
                                }
                            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                .background(colors[player.color].opacity(seat == active ? 0.6 : 0.15), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors[player.color], lineWidth: seat == active ? 3 : 1))
                                .shadow(color: colors[player.color].opacity(seat == active ? 0.7 : 0), radius: 10)
                        }
                    }
                }.frame(maxWidth: 220)
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
