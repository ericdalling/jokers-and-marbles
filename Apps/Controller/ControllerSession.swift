import SwiftUI
import MultipeerConnectivity
import GameCore

final class ControllerSession: ObservableObject {
    let transport = SessionTransport()
    @Published var state: PublicSession?
    @Published var personal: PrivateSession?
    @Published var player: UUID?
    @Published var status = ""
    @Published var room = ""
    private var target: MCPeerID?
    private var token: UUID?
    private var secret: String?
    private var nonce: UUID?
    private var verified = false
    private var retry: DispatchWorkItem?
    private var retryCount = 0
    private var lastHost: MCPeerID?
    private func scheduleReconnect() {
        guard token != nil, retryCount < 5 else { return }
        retry?.cancel()
        retryCount += 1
        let work = DispatchWorkItem { [weak self] in
            guard let self, let peer = self.lastHost else { return }
            if self.transport.peers.contains(peer) { self.connect(peer) }
            else { self.scheduleReconnect() }
        }
        retry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount * 2), execute: work)
    }

    init() {
        transport.onConnection = { [weak self] peer, connected in
            guard let self, peer == self.target else { return }
            self.status = connected ? "Connected" : "Disconnected — reconnect to resume"
            if connected {
                self.retry?.cancel(); self.retryCount = 0
                self.verified = self.secret == nil
                if self.secret != nil {
                    let nonce = UUID(); self.nonce = nonce
                    self.transport.send(SessionCommand.challenge(nonce), to: peer)
                } else if let token = self.token { self.send(.resume(token)) }
            }
            if !connected { self.personal = nil; self.state = nil; self.scheduleReconnect() }
        }
        transport.onData = { [weak self] data, peer in
            guard let self, peer == self.target,
                  let reply = try? JSONDecoder().decode(SessionReply.self, from: data) else { return }
            switch reply {
            case let .proof(proof):
                guard let secret = self.secret, let nonce = self.nonce, proof == RoomProof.make(secret: secret, nonce: nonce) else { self.status = "Host verification failed"; self.transport.stop(); return }
                self.verified = true; self.nonce = nil
                if let token = self.token { self.send(.resume(token)) }
            case let .identity(player, token):
                guard self.verified else { return }; self.player = player; self.token = token
            case let .state(state, personal):
                guard self.verified else { return }; self.state = state; self.personal = personal
            case let .error(message): self.status = message
            }
        }
    }
    func browse(_ code: String, secret: String? = nil) {
        if room != code || secret != nil { self.secret = secret }
        verified = false
        retry?.cancel(); retryCount = 0
        if room != code { token = nil; player = nil; lastHost = nil }
        room = code; target = nil; state = nil; personal = nil
        transport.browse(code: code)
    }
    func connect(_ peer: MCPeerID) {
        guard token == nil || lastHost == peer else { status = "Original host required to reconnect"; return }
        target = peer; lastHost = peer; transport.connect(peer, secret: secret, token: token)
    }
    func send(_ command: SessionCommand) {
        guard verified, let target, transport.connected.contains(target) else { status = "Not connected"; return }
        transport.send(command, to: target)
    }
    func leave() {
        retry?.cancel(); retryCount = 0; lastHost = nil; secret = nil; verified = false; nonce = nil
        transport.stop(); target = nil; token = nil; player = nil; state = nil; personal = nil
    }
}

struct ControllerLobbyView: View {
    @StateObject private var client = ControllerSession()
    @State private var code = ""
    @State private var name = ""
    @State private var color = 0
    @State private var scan = false
    let hostMode: (() -> Void)?
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]

    var body: some View {
        NavigationStack {
            Group {
            if let state = client.state, state.activeSeat != nil, let personal = client.personal, let player = client.player {
                GameplayControllerView(state: state, personal: personal, player: player) { move in
                    client.send(.play(revision: state.revision, move: move))
                }
            } else {
            Form {
                if let state = client.state, let player = client.player,
                   let member = state.members.first(where: { $0.id == player }) {
                    Section("Players") {
                        ForEach(state.members) { other in
                            HStack {
                                Circle().fill(colors[other.color]).frame(width: 20, height: 20)
                                Text(other.name)
                                Spacer()
                                Text(other.ready ? "Ready" : "Waiting")
                                if !state.individual, state.activeSeat == nil, other.id != player,
                                   other.partner == nil, member.partner == nil {
                                    Button("Invite") { client.send(.invite(other.id)) }
                                }
                            }
                        }
                    }
                    if state.activeSeat == nil {
                        ForEach(state.invitations.filter { $0.recipient == player }, id: \.sender) { invitation in
                            Text("Invitation from " + (state.members.first { $0.id == invitation.sender }?.name ?? "Player"))
                            Button("Accept") { client.send(.respond(sender: invitation.sender, accept: true)) }
                            Button("Decline") { client.send(.respond(sender: invitation.sender, accept: false)) }
                        }
                        if member.partner != nil { Button("Change teammate") { client.send(.unpair) } }
                        Button(member.ready ? "Not ready" : "Ready") { client.send(.ready(!member.ready)) }
                            .disabled(!state.individual && member.partner == nil)
                    } else if let personal = client.personal {
                        Section("Your private hand") {
                            ForEach(Array(personal.hand.enumerated()), id: \.offset) { _, card in Text(String(describing: card)) }
                        }
                        Section("Legal moves") {
                            ForEach(Array(personal.legalPlays.enumerated()), id: \.offset) { index, move in
                                Button("Play card \(move.cardIndex + 1) • option \(index + 1)") {
                                    client.send(.play(revision: state.revision, move: move))
                                }
                            }
                        }
                    }
                } else {
                    Section("Join game") {
                        Button("Scan QR code") { scan = true }
                        TextField("Room code", text: $code).keyboardType(.numberPad)
                        Button("Find room") { client.browse(code) }.disabled(code.count != 6)
                        PeerList(transport: client.transport, connect: client.connect)
                        TextField("Your name", text: $name)
                        Picker("Marble color", selection: $color) {
                            ForEach((0..<6).filter { i in !(client.state?.members.contains { $0.color == i } ?? false) }, id: \.self) { i in Circle().fill(colors[i]).frame(width: 24, height: 24).tag(i) }
                        }
                        Button("Join") { client.send(.join(name: name, color: color)) }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || client.player != nil || client.state == nil || (client.state?.members.contains { $0.color == color } ?? false))
                    }
                    if let hostMode, client.player == nil { Button("Switch to Host Mode") { client.leave(); hostMode() } }
                }
                Text(client.status)
                Button("Reconnect") { client.browse(code) }.disabled(code.count != 6)
                Button("Leave room", role: .destructive) { client.leave() }
            }.scrollContentBackground(.hidden)
            .background(LinearGradient(colors: [Color(red: 0.27, green: 0.14, blue: 0.07), Color(red: 0.09, green: 0.04, blue: 0.02)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .preferredColorScheme(.dark).tint(.orange)
            }
            }
            .navigationTitle("Jokers & Marbles")
            .sheet(isPresented: $scan) { RoomScanner { value in scan = false; joinURL(value) } }
            .onOpenURL { joinURL($0.absoluteString) }
        }
    }
    private func joinURL(_ value: String) {
        guard let url = URLComponents(string: value), url.scheme == "jokersmarbles", url.host == "join",
              let room = url.queryItems?.first(where: { $0.name == "code" })?.value,
              room.count == 6, room.allSatisfy(\.isNumber) else { return }
        code = room; client.browse(room, secret: url.queryItems?.first(where: { $0.name == "secret" })?.value)
    }
}

private struct PeerList: View {
    @ObservedObject var transport: SessionTransport
    let connect: (MCPeerID) -> Void
    var body: some View {
        ForEach(transport.peers, id: \.self) { peer in Button("Connect to room") { connect(peer) } }
        Text(transport.status)
    }
}
