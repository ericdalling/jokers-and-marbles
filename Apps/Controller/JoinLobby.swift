import SwiftUI
import Network
import GameCore

@MainActor final class JoinLobby: ObservableObject {
    @Published var rooms: [NWEndpoint] = []
    @Published var state: LobbyState?
    @Published var seat: Int?
    @Published var status = ""
    private var browser: NWBrowser?
    private var connection: LobbyConnection?
    private var generation = UUID()
    func browse() {
        browser?.cancel()
        let browser = NWBrowser(for: .bonjour(type: LobbyDiscovery.service, domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let endpoints = results.map(\.endpoint)
            Task { @MainActor in self?.rooms = endpoints }
        }
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                if case .failed(let error) = state { self?.status = error.localizedDescription }
            }
        }
        self.browser = browser
        browser.start(queue: .main)
    }
    func connect(_ endpoint: NWEndpoint) {
        disconnect()
        let id = generation
        let link = LobbyConnection(NWConnection(to: endpoint, using: .tcp))
        connection = link
        status = "Connecting…"
        link.start(onMessage: { [weak self] message in
            Task { @MainActor in
                guard let self, self.generation == id else { return }
                switch message {
                case .snapshot(let state): self.state = state; self.status = ""
                case .accepted(let seat): self.seat = seat
                case .rejected(let reason): self.status = reason
                default: break
                }
            }
        }, onClose: { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == id else { return }
                self.disconnect(); self.status = "Disconnected"
            }
        })
    }
    func join(code: String, name: String, seat: Int) {
        connection?.send(.join(code: code, name: name, seat: seat))
    }
    func ready(_ value: Bool) { connection?.send(.ready(value)) }
    func disconnect() {
        generation = UUID()
        connection?.cancel(); connection = nil; state = nil; seat = nil
    }
    func stop() { disconnect(); browser?.cancel(); browser = nil; rooms = [] }
}

struct JoinLobbyView: View {
    @StateObject private var client = JoinLobby()
    @State private var name = ""
    @State private var code = ""
    let close: () -> Void
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]
    var body: some View {
        NavigationStack {
            Form {
                if let state = client.state {
                    Section("Players") {
                        ForEach(0..<state.seats, id: \.self) { seat in
                            let player = state.players.first { $0.seat == seat }
                            HStack {
                                Circle().fill(colors[seat]).frame(width: 22, height: 22)
                                Text(player?.name ?? "Open seat")
                                Spacer()
                                if let player { Text(player.ready ? "Ready" : "Not ready") }
                                else if client.seat == nil {
                                    Button("Join") { client.join(code: code, name: name, seat: seat) }
                                        .disabled(name.isEmpty || code.count != 6)
                                }
                            }
                        }
                    }
                    if let seat = client.seat {
                        let ready = state.players.first { $0.seat == seat }?.ready ?? false
                        Button(ready ? "Not ready" : "Ready") { client.ready(!ready) }
                        if state.canStart { Text("Everyone ready") }
                    } else {
                        TextField("Your name", text: $name)
                        TextField("Room code", text: $code).keyboardType(.numberPad)
                    }
                    Button("Leave room") { client.disconnect() }
                } else {
                    Section("Nearby rooms") {
                        ForEach(client.rooms, id: \.self) { endpoint in
                            Button(roomName(endpoint)) { client.connect(endpoint) }
                        }
                        if client.rooms.isEmpty { Text("Looking for Apple TV rooms…") }
                    }
                }
                if !client.status.isEmpty { Text(client.status) }
            }
            .navigationTitle("Join game")
            .toolbar { Button("Back") { client.stop(); close() } }
        }.onAppear { client.browse() }.onDisappear { client.stop() }
    }
    private func roomName(_ endpoint: NWEndpoint) -> String {
        if case .service(let name, _, _, _) = endpoint { return name }
        return "Apple TV room"
    }
}
