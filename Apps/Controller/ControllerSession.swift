import SwiftUI
import Combine
import MultipeerConnectivity
import GameCore

final class ControllerSession: ObservableObject {
    let transport = SessionTransport()
    @Published var state: PublicSession?
    @Published var personal: PrivateSession?
    @Published var player: UUID?
    @Published var status = ""
    @Published var room = ""
    @Published private(set) var readyForCommands = false
    private var target: MCPeerID?
    private var token: UUID?
    private var secret: String?
    private var nonce: UUID?
    private var verified = false
    private var retry: DispatchWorkItem?
    private var lastHost: MCPeerID?
    private var discovery: AnyCancellable?
    private var discoveryTimeout: DispatchWorkItem?

    private func scheduleReconnect(after delay: Double) {
        guard token != nil else { return }
        retry?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.token != nil, !self.readyForCommands else { return }
            self.target = nil
            self.verified = false
            self.nonce = nil
            self.transport.browse(code: self.room)
            self.scheduleReconnect(after: 10)
        }
        retry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func resumeAfterBackground() {
        guard let token else { return }
        readyForCommands = false
        status = "Reconnecting…"
        if verified, let target, transport.connected.contains(target) {
            transport.send(SessionCommand.resume(token), to: target)
            scheduleReconnect(after: 3)
        } else {
            scheduleReconnect(after: 0)
        }
    }

    init() {
        discovery = transport.$peers.receive(on: DispatchQueue.main).sink { [weak self] peers in
            guard let self, self.target == nil, !self.room.isEmpty, let peer = peers.first(where: { self.token == nil || $0 == self.lastHost }) else { return }
            self.discoveryTimeout?.cancel(); self.connect(peer)
        }
        transport.onConnection = { [weak self] peer, connected in
            guard let self, peer == self.target else { return }
            self.readyForCommands = false
            self.status = connected && self.token == nil ? "Connected" : "Reconnecting…"
            self.verified = connected && self.secret == nil
            self.nonce = nil
            if connected {
                if self.secret != nil {
                    let nonce = UUID()
                    self.nonce = nonce
                    self.transport.send(SessionCommand.challenge(nonce), to: peer)
                } else if let token = self.token {
                    self.transport.send(SessionCommand.resume(token), to: peer)
                } else {
                    self.readyForCommands = true
                }
                self.scheduleReconnect(after: 5)
            } else if self.token != nil {
                self.scheduleReconnect(after: 0.5)
            } else {
                self.target = nil
                self.state = nil
                self.status = "Disconnected. Connect to the room to try again."
            }
        }
        transport.onData = { [weak self] data, peer in
            guard let self, peer == self.target,
                  self.transport.connected.contains(peer),
                  let reply = try? JSONDecoder().decode(SessionReply.self, from: data) else { return }
            switch reply {
            case let .proof(proof):
                guard let secret = self.secret, let nonce = self.nonce, proof == RoomProof.make(secret: secret, nonce: nonce) else { self.status = "Host verification failed"; self.transport.stop(); return }
                self.verified = true; self.nonce = nil
                if let token = self.token { self.transport.send(SessionCommand.resume(token), to: peer) }
                else { self.readyForCommands = true }
            case let .identity(player, token):
                guard self.verified else { return }; self.player = player; self.token = token
            case let .state(state, personal):
                guard self.verified, self.token == nil || personal != nil else { return }
                self.state = state
                self.personal = personal
                self.readyForCommands = true
                self.status = "Connected"
                self.retry?.cancel()
                self.retry = nil
            case let .error(message): self.status = message
            }
        }
    }
    func browse(_ code: String, secret: String? = nil) {
        if room != code || secret != nil { self.secret = secret }
        if room == code, token != nil { resumeAfterBackground(); return }
        verified = false
        readyForCommands = false
        retry?.cancel()
        if room != code { token = nil; player = nil; lastHost = nil }
        room = code; target = nil; state = nil; personal = nil
        status = "Searching for room…"
        discoveryTimeout?.cancel()
        transport.browse(code: code)
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.target == nil else { return }
            self.status = "Room not found. Check the code and Wi-Fi, then try again."
        }
        discoveryTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
    }
    func connect(_ peer: MCPeerID) {
        guard token == nil || lastHost == peer else { status = "Original host required to reconnect"; return }
        status = token == nil ? "Connecting…" : "Reconnecting…"
        target = peer
        lastHost = peer
        transport.connect(peer, secret: secret, token: token)
    }
    func send(_ command: SessionCommand) {
        guard readyForCommands, verified, let target, transport.connected.contains(target) else { status = "Not connected"; return }
        transport.send(command, to: target)
    }
    func leave() {
        retry?.cancel()
        discoveryTimeout?.cancel()
        target = nil
        lastHost = nil
        secret = nil
        verified = false
        readyForCommands = false
        nonce = nil
        token = nil
        player = nil
        state = nil
        personal = nil
        room = ""
        status = ""
        transport.stop()
    }
}

struct ControllerLobbyView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var wasBackgrounded = false
    @StateObject private var client = ControllerSession()
    @State private var code = ""
    @State private var name = ""
    @State private var color = 0
    @State private var scan = false
    @State private var manualEntry = false
    let hostMode: (() -> Void)?
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]

    var body: some View {
        NavigationStack {
            Group {
            if let state = client.state, state.activeSeat != nil, let personal = client.personal, let player = client.player {
                GameplayControllerView(state: state, personal: personal, player: player,
                                       reconnecting: !client.readyForCommands) { move in
                    client.send(.play(revision: state.revision, move: move))
                }
            } else {
            ScrollView {
                VStack(spacing: 20) {
                    PremiumLogo()
                    if let state = client.state, let player = client.player,
                       let member = state.members.first(where: { $0.id == player }) {
                        if let invitation = state.invitations.first(where: { $0.recipient == player }),
                           let sender = state.members.first(where: { $0.id == invitation.sender }) {
                            Text("Teammate Invitation").font(.title2.bold())
                            VStack(spacing: 16) {
                                HStack {
                                    JewelMarble(color: colors[sender.color]).frame(width: 58, height: 58)
                                    Image(systemName: "person.2.fill")
                                    JewelMarble(color: colors[member.color]).frame(width: 58, height: 58)
                                }
                                Text(sender.name + " wants to be your teammate!").font(.title2.bold()).multilineTextAlignment(.center)
                            }.modifier(PremiumPanel())
                            Button("Accept Invitation") { client.send(.respond(sender: invitation.sender, accept: true)) }.buttonStyle(JewelButton(color: colors[member.color]))
                            Button("Decline") { client.send(.respond(sender: invitation.sender, accept: false)) }.buttonStyle(JewelButton(color: .brown))
                        } else {
                            if let partner = state.members.first(where: { $0.id == member.partner }) {
                                Label("Team Confirmed", systemImage: "checkmark.circle.fill").font(.title2.bold()).foregroundStyle(.green)
                                VStack {
                                    HStack {
                                        JewelMarble(color: colors[member.color]).frame(width: 48, height: 48)
                                        JewelMarble(color: colors[partner.color]).frame(width: 48, height: 48)
                                    }
                                    Text(member.name + " + " + partner.name).font(.headline)
                                }.modifier(PremiumPanel())
                            }
                            Text(!state.individual && member.partner == nil ? "Choose Your Teammate" : "Game Lobby").font(.title2.bold())
                            VStack(spacing: 12) {
                                ForEach(state.members) { other in
                                    HStack {
                                        JewelMarble(color: colors[other.color]).frame(width: 30, height: 30)
                                        Text(other.name)
                                        Spacer()
                                        if !state.individual && other.id != player && other.partner == nil && member.partner == nil {
                                            Button("Invite") { client.send(.invite(other.id)) }.buttonStyle(.bordered)
                                        } else {
                                            Text(other.ready ? "Ready" : "Waiting").font(.caption)
                                        }
                                    }
                                }
                            }.modifier(PremiumPanel())
                            if member.partner != nil { Button("Change teammate") { client.send(.unpair) } }
                            Button(member.ready ? "Not ready" : "I’m Ready") { client.send(.ready(!member.ready)) }
                                .buttonStyle(JewelButton(color: .green))
                                .disabled(!state.individual && member.partner == nil)
                        }
                    } else if let state = client.state {
                        Label("Game Found", systemImage: "checkmark.circle.fill").font(.title2.bold()).foregroundStyle(.green).modifier(PremiumPanel())
                        Text("Your Name").frame(maxWidth: .infinity, alignment: .leading)
                        TextField("Your name", text: $name).modifier(PremiumPanel())
                        Text("Choose Your Marble Color").font(.headline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 18) {
                            ForEach(0..<6, id: \.self) { i in
                                let taken = state.members.contains { $0.color == i }
                                Button { color = i } label: {
                                    JewelMarble(color: colors[i]).frame(width: 62, height: 62)
                                        .overlay { if color == i { Image(systemName: "checkmark").font(.title.bold()).foregroundStyle(.white) } }
                                        .padding(5).overlay(Circle().strokeBorder(color == i ? Color.yellow : Color.clear, lineWidth: 3))
                                }.buttonStyle(.plain).disabled(taken).opacity(taken ? 0.3 : 1)
                            }
                        }
                        Button("Continue") { client.send(.join(name: name, color: color)) }
                            .buttonStyle(JewelButton(color: colors[color]))
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || client.player != nil || state.members.contains { $0.color == color })
                    } else {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 24) {
                                joinButton
                                if let hostMode { hostButton(hostMode) }
                            }
                            VStack(spacing: 20) {
                                joinButton
                                if let hostMode { hostButton(hostMode) }
                            }
                        }
                        Button { manualEntry.toggle() } label: {
                            Label("Enter Room Code", systemImage: "keyboard")
                        }.buttonStyle(JewelButton(color: .brown))
                        if manualEntry {
                            TextField("Room code", text: $code).keyboardType(.numberPad).modifier(PremiumPanel())
                            Button("Connect to room") { client.browse(code) }.buttonStyle(JewelButton(color: .brown)).disabled(code.count != 6 || !code.allSatisfy(\.isNumber))
                        }
                    }
                    if !client.status.isEmpty { Text(client.status).font(.caption) }
                    if client.player != nil && client.state == nil { Button("Reconnect") { client.browse(code) } }
                    if !client.room.isEmpty { Button("Leave room", role: .destructive) { client.leave() } }
                }.padding(24).frame(maxWidth: hostMode != nil && client.state == nil ? 1000 : 560)
                .frame(maxWidth: .infinity)
            }.background(GameBackdrop())
            .preferredColorScheme(.dark).tint(.orange)
            }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $scan) { RoomScanner { value in scan = false; joinURL(value) } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { wasBackgrounded = true }
                if phase == .active, wasBackgrounded {
                    wasBackgrounded = false
                    client.resumeAfterBackground()
                }
            }
            .onOpenURL { joinURL($0.absoluteString) }
        }
    }
    private var joinButton: some View {
        Button { scan = true } label: {
            VStack(spacing: 12) {
                Image(systemName: "qrcode.viewfinder").font(.system(size: 54))
                Text("Join a Game").font(.system(.title, design: .serif).bold())
                Text("Scan a QR code").font(.subheadline)
            }.frame(minWidth: 180, minHeight: 150)
        }.buttonStyle(JewelButton(color: .green))
    }
    private func hostButton(_ action: @escaping () -> Void) -> some View {
        Button { client.leave(); action() } label: {
            VStack(spacing: 12) {
                Image(systemName: "person.3.fill").font(.system(size: 54))
                Text("Host a Game").font(.system(.title, design: .serif).bold())
                Text("Start a new game and invite players").font(.subheadline)
            }.frame(minWidth: 180, minHeight: 150)
        }.buttonStyle(JewelButton(color: .brown))
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
