import SwiftUI
import GameCore

struct PublicGameplayView: View {
    let state: PublicSession
    let connected: Set<UUID>
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]
    private var active: Int { state.activeSeat ?? 0 }
    private func member(_ seat: Int) -> LobbyMember? {
        guard state.seats.indices.contains(seat) else { return nil }
        return state.members.first { $0.id == state.seats[seat] }
    }
    var body: some View {
        VStack(spacing: 12) {
            Text(state.winner == nil ? "\(member(active)?.name ?? "Player")’s turn" : "Game complete")
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
                                     seatColors: state.seats.map { id in state.members.first { $0.id == id }?.color ?? 0 })
                    VStack(spacing: 5) {
                        Text("Jokers & Marbles").font(.system(.caption, design: .serif).italic())
                        HStack {
                            Text("▧").font(.title).foregroundStyle(.white).padding(8).background(.blue, in: RoundedRectangle(cornerRadius: 6))
                            Text(state.discard.map { String(describing: $0) } ?? "—").font(.caption).foregroundStyle(.black).padding(8).background(.white, in: RoundedRectangle(cornerRadius: 6))
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
    }
}
