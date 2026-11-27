public struct LobbyPlayer: Codable, Equatable, Sendable {
    public let seat: Int
    public let name: String
    public var ready: Bool
}
public struct LobbyState: Codable, Equatable, Sendable {
    public let seats: Int
    public let individual: Bool
    public private(set) var players: [LobbyPlayer] = []
    public init(seats: Int, individual: Bool) {
        self.seats = seats; self.individual = individual || seats % 2 != 0
    }
    public var canStart: Bool { players.count == seats && players.allSatisfy { $0.ready } }
    public mutating func join(name: String, seat: Int) -> Bool {
        guard (3...6).contains(seats), (0..<seats).contains(seat),
              !name.isEmpty, name.count <= 24, !players.contains(where: { $0.seat == seat }) else { return false }
        players.append(LobbyPlayer(seat: seat, name: name, ready: false))
        players.sort { $0.seat < $1.seat }
        return true
    }
    public mutating func ready(seat: Int, value: Bool) {
        if let i = players.firstIndex(where: { $0.seat == seat }) { players[i].ready = value }
    }
    public mutating func leave(seat: Int) { players.removeAll { $0.seat == seat } }
}
public enum LobbyMessage: Codable, Sendable {
    case join(code: String, name: String, seat: Int)
    case ready(Bool)
    case snapshot(LobbyState)
    case accepted(Int)
    case rejected(String)
}
