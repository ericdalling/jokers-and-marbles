import SwiftUI
import Network
import GameCore

@MainActor final class HostLobby: ObservableObject {
    @Published private(set) var state = LobbyState(seats: 6, individual: false)
    @Published private(set) var code = ""
    @Published private(set) var status = ""
    private var listener: NWListener?
    private var connections: [UUID: LobbyConnection] = [:]
    private var seats: [UUID: Int] = [:]

    func start(count: Int, individual: Bool) {
        stop()
        state = LobbyState(seats: count, individual: individual)
        code = String(Int.random(in: 100000...999999))
        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(name: "Jokers " + code, type: LobbyDiscovery.service)
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready: self?.status = "Waiting for players"
                    case .failed(let error): self?.status = error.localizedDescription
                    default: break
                    }
                }
            }
            self.listener = listener
            listener.start(queue: .main)
        } catch { status = error.localizedDescription }
    }
    private func accept(_ raw: NWConnection) {
        guard listener != nil, connections.count < 12 else { raw.cancel(); return }
        let id = UUID()
        let connection = LobbyConnection(raw)
        connections[id] = connection
        connection.start(onMessage: { [weak self] message in
            Task { @MainActor in self?.handle(message, id: id) }
        }, onClose: { [weak self] in
            Task { @MainActor in self?.remove(id) }
        })
        connection.send(.snapshot(state))
    }
    private func handle(_ message: LobbyMessage, id: UUID) {
        guard let connection = connections[id] else { return }
        switch message {
        case let .join(input, name, seat):
            guard seats[id] == nil, input == code,
                  state.join(name: name.trimmingCharacters(in: .whitespacesAndNewlines), seat: seat) else {
                connection.send(.rejected("Check room code, name and available seat.")); return
            }
            seats[id] = seat
            connection.send(.accepted(seat))
            broadcast()
        case .ready(let value):
            guard let seat = seats[id] else { return }
            state.ready(seat: seat, value: value); broadcast()
        default: break
        }
    }
    private func broadcast() {
        for connection in connections.values { connection.send(.snapshot(state)) }
    }
    private func remove(_ id: UUID) {
        connections.removeValue(forKey: id)?.cancel()
        if let seat = seats.removeValue(forKey: id) { state.leave(seat: seat); broadcast() }
    }
    func stop() {
        listener?.cancel(); listener = nil
        for connection in connections.values { connection.cancel() }
        connections.removeAll(); seats.removeAll()
        status = ""
    }
}

struct HostLobbyView: View {
    @StateObject private var host = HostLobby()
    @State private var count = 6
    @State private var individual = false
    @State private var hosting = false
    let close: () -> Void
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]
    var body: some View {
        VStack(spacing: 24) {
            Text("Multiplayer lobby").font(.largeTitle.bold())
            if hosting {
                Text("Room code: " + host.code).font(.system(size: 64, weight: .bold, design: .monospaced))
                Text(host.status)
                HStack {
                    ForEach(0..<host.state.seats, id: \.self) { seat in
                        let player = host.state.players.first { $0.seat == seat }
                        VStack {
                            Circle().fill(colors[seat]).frame(width: 48, height: 48)
                            Text(player?.name ?? "Open seat")
                            Text(player.map { $0.ready ? "Ready" : "Not ready" } ?? "Waiting").font(.caption)
                            if !host.state.individual { Text("Team \(seat % (host.state.seats / 2) + 1)").font(.caption) }
                        }.frame(maxWidth: .infinity)
                    }
                }
                Text(host.state.canStart ? "Everyone ready • gameplay connection coming next" : "Join on your iPhone or iPad")
                Button("Close room") { host.stop(); hosting = false }
            } else {
                HStack {
                    ForEach(3...6, id: \.self) { n in Button("\(n) players") { count = n } }
                }
                Text("\(count) players • " + (individual || count % 2 != 0 ? "Individual" : "Teams"))
                if count % 2 == 0 { Button("Toggle teams / individual") { individual.toggle() } }
                Button("Open room") { host.start(count: count, individual: individual); hosting = true }
            }
            Button("Back") { host.stop(); close() }
        }.padding(40).onDisappear { host.stop() }
    }
}
