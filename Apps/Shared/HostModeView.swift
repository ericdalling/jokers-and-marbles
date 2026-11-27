import SwiftUI
import CoreImage.CIFilterBuiltins
import GameCore

struct HostModeView: View {
    @StateObject private var host = HostCoordinator()
    @State private var count = 6
    @State private var individual = false
    @State private var confirmClose = false
    let close: () -> Void
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Jokers & Marbles").font(.system(.largeTitle, design: .serif).italic())
                Text("Host Mode").font(.headline)
                if let state = host.state {
                    if let active = state.activeSeat {
                        Text(state.winner == nil ? "Current turn: " + (state.members.first { $0.id == state.seats[active] }?.name ?? "") : "Game complete")
                        Text("Draw pile: \(state.drawCount ?? 0)")
                        ModularBoardView(playerCount: state.capacity, activePlayer: active, gameMarbles: state.marbles,
                                         seatColors: state.seats.map { id in state.members.first { $0.id == id }?.color ?? 0 })
                            .aspectRatio(1, contentMode: .fit).frame(maxHeight: 650)
                        HStack {
                            ForEach(state.seats, id: \.self) { id in
                                if let member = state.members.first(where: { $0.id == id }) {
                                    Text(member.name).padding(8)
                                        .background(colors[member.color].opacity(0.45), in: Capsule())
                                }
                            }
                        }
                        if let discard = state.discard { Text("Discard: " + String(describing: discard)) }
                    } else {
                        HStack(spacing: 30) {
                            if let image = qr(host.roomCode) {
                                Image(decorative: image, scale: 1).interpolation(.none).resizable()
                                    .frame(width: 180, height: 180).padding(12).background(.white)
                            }
                            VStack {
                                Text("Scan to join")
                                Text(host.roomCode).font(.system(size: 44, weight: .bold, design: .monospaced))
                                Text("Or enter the room code")
                            }
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                            ForEach(state.members) { member in
                                VStack {
                                    Circle().fill(colors[member.color]).frame(width: 32, height: 32)
                                    Text(member.name).font(.headline)
                                    Text(!host.connectedPlayers.contains(member.id) ? "Disconnected" : member.ready ? "Ready" : "Not ready")
                                    if let partner = state.members.first(where: { $0.id == member.partner }) {
                                        Text("With " + partner.name).font(.caption)
                                    }
                                }.padding()
                            }
                            ForEach(0..<max(0, state.capacity - state.members.count), id: \.self) { _ in
                                Text("Open seat").padding()
                            }
                        }
                        Button("Start game") { host.start() }
                            .disabled(state.members.count != state.capacity || !state.members.allSatisfy { $0.ready && host.connectedPlayers.contains($0.id) })
                    }
                    Button("Close room") { confirmClose = true }
                } else {
                    HStack {
                        ForEach(3...6, id: \.self) { n in
                            Button("\(n) players") { count = n }.tint(count == n ? .orange : .gray)
                        }
                    }
                    if count % 2 == 0 { Button(individual ? "Individual" : "Teams") { individual.toggle() } }
                    else { Text("Individual") }
                    Button("Open room") { host.open(capacity: count, individual: individual || count % 2 != 0) }
                    Button("Back", action: close)
                }
                if !host.error.isEmpty { Text(host.error).foregroundStyle(.red) }
            }.padding(30)
        }
        .foregroundStyle(Color(red: 0.98, green: 0.88, blue: 0.72))
        .background(Color(red: 0.16, green: 0.08, blue: 0.04).ignoresSafeArea())
        .confirmationDialog("End this room for everyone?", isPresented: $confirmClose) {
            Button("End room", role: .destructive) { host.close() }
            Button("Cancel", role: .cancel) {}
        }
        .onDisappear { host.close() }
    }

    private func qr(_ code: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("jokersmarbles://join?code=\(code)".utf8)
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }
}
