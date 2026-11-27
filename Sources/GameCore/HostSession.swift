import Foundation

public enum HostSessionError: Error, Equatable, Sendable {
    case invalidConfiguration, unavailable, unauthorized, invalidInvitation, notReady, alreadyStarted
}

public struct LobbyMember: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let color: Int
    public var ready: Bool
    public var partner: UUID?
}

public struct TeamInvitation: Codable, Equatable, Sendable {
    public let sender: UUID
    public let recipient: UUID
}

public struct PublicMove: Codable, Sendable {
    public let seat: Int
    public let card: PlayingCard
    public let steps: [MarbleStep]
    public let before: [GameMarble]
    public let routes: [[MarblePosition]]
    public let revision: Int
}

public struct PublicSession: Codable, Sendable {
    public let capacity: Int
    public let individual: Bool
    public let members: [LobbyMember]
    public let invitations: [TeamInvitation]
    public let seats: [UUID]
    public let activeSeat: Int?
    public let marbles: [GameMarble]
    public let drawCount: Int?
    public let discard: PlayingCard?
    public let winner: Int?
    public let revision: Int
    public let lastMove: PublicMove?
    public let presentingMove: Bool
}

public struct PrivateSession: Codable, Sendable {
    public let seat: Int?
    public let hand: [PlayingCard]
    public let legalPlays: [GamePlay]
}

public struct HostSession: Sendable {
    public let capacity: Int
    public let individual: Bool
    private var members: [LobbyMember] = []
    private var invitations: [TeamInvitation] = []
    private var seats: [UUID] = []
    private var game: ClassicGame?
    private var revision = 0
    private var lastMove: PublicMove?
    private var presentingMove = false

    public init(capacity: Int, individual: Bool) throws {
        guard (3...6).contains(capacity), individual || capacity % 2 == 0 else {
            throw HostSessionError.invalidConfiguration
        }
        self.capacity = capacity
        self.individual = individual
    }

    public mutating func join(id: UUID, name: String, color: Int) throws {
        guard game == nil else { throw HostSessionError.alreadyStarted }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 40, (0..<6).contains(color),
              members.count < capacity, !members.contains(where: { $0.id == id || $0.color == color }) else {
            throw HostSessionError.unavailable
        }
        members.append(LobbyMember(id: id, name: name, color: color, ready: false, partner: nil))
        revision += 1
    }

    private func index(_ id: UUID) throws -> Int {
        guard let i = members.firstIndex(where: { $0.id == id }) else { throw HostSessionError.unauthorized }
        return i
    }

    public mutating func invite(from sender: UUID, to recipient: UUID) throws {
        guard game == nil, !individual, sender != recipient else { throw HostSessionError.invalidInvitation }
        let a = try index(sender), b = try index(recipient)
        guard members[a].partner == nil, members[b].partner == nil,
              !invitations.contains(where: { $0.sender == sender && $0.recipient == recipient }) else {
            throw HostSessionError.invalidInvitation
        }
        invitations.append(TeamInvitation(sender: sender, recipient: recipient))
        revision += 1
    }

    public mutating func respond(recipient: UUID, sender: UUID, accept: Bool) throws {
        guard game == nil, let i = invitations.firstIndex(where: { $0.sender == sender && $0.recipient == recipient }) else {
            throw HostSessionError.invalidInvitation
        }
        let a = try index(sender), b = try index(recipient)
        guard members[a].partner == nil, members[b].partner == nil else { throw HostSessionError.invalidInvitation }
        invitations.remove(at: i)
        if accept {
            members[a].partner = recipient
            members[b].partner = sender
            members[a].ready = false
            members[b].ready = false
            invitations.removeAll { [sender, recipient].contains($0.sender) || [sender, recipient].contains($0.recipient) }
        }
        revision += 1
    }

    public mutating func unpair(id: UUID) throws {
        guard game == nil else { throw HostSessionError.alreadyStarted }
        let a = try index(id)
        guard let partner = members[a].partner else { return }
        let b = try index(partner)
        members[a].partner = nil; members[b].partner = nil
        members[a].ready = false; members[b].ready = false
        revision += 1
    }

    public mutating func ready(id: UUID, value: Bool) throws {
        guard game == nil else { throw HostSessionError.alreadyStarted }
        let i = try index(id)
        guard !value || individual || members[i].partner != nil else { throw HostSessionError.notReady }
        members[i].ready = value
        revision += 1
    }

    public mutating func start(seed: UInt64) throws {
        guard game == nil else { throw HostSessionError.alreadyStarted }
        guard members.count == capacity, members.allSatisfy({ $0.ready }) else { throw HostSessionError.notReady }
        var order: [UUID] = []
        if individual { order = members.map { $0.id } }
        else {
            var first: [UUID] = [], second: [UUID] = []
            for member in members where !first.contains(member.id) && !second.contains(member.id) {
                guard let partner = member.partner, members.contains(where: { $0.id == partner && $0.partner == member.id }) else {
                    throw HostSessionError.notReady
                }
                first.append(member.id); second.append(partner)
            }
            order = first + second
        }
        let rules = try GameRules.modular(seats: capacity, individual: individual)
        game = try ClassicGame(rules: rules, seed: seed)
        seats = order
        revision += 1
    }

    public func publicState() -> PublicSession {
        PublicSession(capacity: capacity, individual: individual, members: members, invitations: invitations,
                      seats: seats, activeSeat: game?.activeSeat, marbles: game?.marbles ?? [],
                      drawCount: game?.drawCount, discard: game?.topDiscard, winner: game?.winner, revision: revision, lastMove: lastMove, presentingMove: presentingMove)
    }

    // Caller must bind id to an authenticated connection, never trust a client-supplied identity.
    public func privateState(for id: UUID) throws -> PrivateSession {
        _ = try index(id)
        let seat = seats.firstIndex(of: id)
        guard let seat, let game else { return PrivateSession(seat: nil, hand: [], legalPlays: []) }
        return PrivateSession(seat: seat, hand: game.hand(for: seat),
                              legalPlays: game.activeSeat == seat && !presentingMove ? game.legalPlays() : [])
    }

    public mutating func finishPresentation() {
        guard presentingMove else { return }
        presentingMove = false; revision += 1
    }

    public mutating func play(id: UUID, expectedRevision: Int, move: GamePlay) throws {
        guard !presentingMove, expectedRevision == revision, let seat = seats.firstIndex(of: id), var current = game else {
            throw HostSessionError.unauthorized
        }
        let before = current.marbles
        let routes = current.movementRoutes(for: move)
        try current.play(move, by: seat)
        if let card = current.topDiscard {
            lastMove = PublicMove(seat: seat, card: card, steps: move.steps, before: before, routes: routes, revision: revision + 1)
        }
        game = current
        presentingMove = true
        revision += 1
    }
}
