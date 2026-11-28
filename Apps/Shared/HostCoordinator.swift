import Foundation
import Combine
import MultipeerConnectivity
import GameCore

final class HostCoordinator: ObservableObject {
    let transport = SessionTransport()
    @Published private(set) var state: PublicSession?
    @Published private(set) var roomCode = ""
    @Published private(set) var roomSecret = ""
    @Published private(set) var error = ""
    @Published private(set) var connectedPlayers: Set<UUID> = []
    @Published private(set) var pendingConnection = false
    private var usedNonces: Set<UUID> = []
    private var approval: ((Bool) -> Void)?
    func approveConnection(_ allow: Bool) {
        let callback = approval; approval = nil; pendingConnection = false; callback?(allow)
    }
    private var host: HostSession?
    private var presentation: DispatchWorkItem?
    private var identities: [MCPeerID: UUID] = [:]
    private var tokens: [UUID: UUID] = [:]

    init() {
        transport.onInvitation = { [weak self] peer, admission, reply in
            guard let self, let state = self.state else { reply(false); return }
            if let token = admission.resumeToken, let id = self.tokens[token],
               self.identities[peer] == id || !self.identities.values.contains(id) {
                reply(true); return
            }
            guard state.activeSeat == nil, state.members.count < 6 else { reply(false); return }
            if let proof = admission.proof {
                guard proof == RoomProof.make(secret: self.roomSecret, nonce: admission.nonce),
                      self.usedNonces.insert(admission.nonce).inserted else { reply(false); return }
                reply(true); return
            }
            guard self.approval == nil else { reply(false); return }
            self.approval = reply; self.pendingConnection = true
        }
        transport.onData = { [weak self] data, peer in self?.receive(data, from: peer) }
        transport.onConnection = { [weak self] peer, connected in
            if !connected { self?.identities.removeValue(forKey: peer) }
            self?.publish()
        }
    }

    func open() {
        do {
            transport.stop()
            host = HostSession()
            identities = [:]; tokens = [:]; usedNonces = []
            roomCode = String(format: "%06d", Int.random(in: 0...999999))
            roomSecret = UUID().uuidString + UUID().uuidString
            transport.host(code: roomCode)
            publish()
        } catch { self.error = String(describing: error) }
    }

    func configureTeams(_ enabled: Bool) {
        do { try host?.configureTeams(enabled); publish() } catch { self.error = String(describing: error) }
    }

    func start() {
        do {
            guard let host, host.publicState().members.allSatisfy({ identities.values.contains($0.id) }) else { throw HostSessionError.notReady }
            try self.host?.start(seed: UInt64.random(in: 0...UInt64.max))
            publish()
        } catch { self.error = String(describing: error) }
    }

    func close() {
        presentation?.cancel(); presentation = nil
        approveConnection(false)
        transport.stop()
        host = nil; state = nil; connectedPlayers = []; identities = [:]; tokens = [:]; roomCode = ""
    }

    private func receive(_ data: Data, from peer: MCPeerID) {
        guard var current = host, transport.connected.contains(peer) else { return }
        do {
            let command = try JSONDecoder().decode(SessionCommand.self, from: data)
            switch command {
            case let .challenge(nonce):
                transport.send(SessionReply.proof(RoomProof.make(secret: roomSecret, nonce: nonce)), to: peer)
                transport.send(SessionReply.state(current.publicState(), nil), to: peer)
                return
            case let .join(name, color):
                guard identities[peer] == nil else { throw HostSessionError.unauthorized }
                let id = UUID(), token = UUID()
                try current.join(id: id, name: name, color: color)
                identities[peer] = id; tokens[token] = id
                transport.send(SessionReply.identity(player: id, token: token), to: peer)
            case let .resume(token):
                guard let id = tokens[token],
                      identities[peer] == id || (identities[peer] == nil && !identities.values.contains(id)) else { throw HostSessionError.unauthorized }
                identities[peer] = id
                transport.send(SessionReply.identity(player: id, token: token), to: peer)
            default:
                guard let id = identities[peer] else { throw HostSessionError.unauthorized }
                switch command {
                case let .invite(recipient): try current.invite(from: id, to: recipient)
                case let .respond(sender, accept): try current.respond(recipient: id, sender: sender, accept: accept)
                case .unpair: try current.unpair(id: id)
                case let .ready(value): try current.ready(id: id, value: value)
                case let .play(revision, move): try current.play(id: id, expectedRevision: revision, move: move)
                default: throw HostSessionError.unauthorized
                }
            }
            host = current
            publish()

        } catch {
            transport.send(SessionReply.error(String(describing: error)), to: peer)
        }
    }

    private func publish() {
        guard let host else { return }
        connectedPlayers = Set(identities.values).union(host.publicState().members.filter { $0.isBot }.map { $0.id })
        let snapshot = host.publicState()
        state = snapshot
            if snapshot.presentingMove, presentation == nil {
                let duration = snapshot.lastMove?.animationDuration ?? 0.24
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.presentation = nil
                    self.host?.finishPresentation()
                    self.publish()
                }
                presentation = work
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.35, execute: work)
            }
        if host.botTurn, presentation == nil {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.presentation = nil
                do { try self.host?.playBot(); self.publish() } catch { self.error = String(describing: error) }
            }
            presentation = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
        }
        for peer in transport.connected {
            let personal = identities[peer].flatMap { try? host.privateState(for: $0) }
            transport.send(SessionReply.state(snapshot, personal), to: peer)
        }
    }
}
