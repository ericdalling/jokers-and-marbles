import Foundation

public enum SessionError: Error, Equatable, Sendable {
    case lobbyFull
    case duplicatePlayer
    case duplicateColor
    case invalidPlayerCount
    case notInLobby
    case notPlayersTurn
    case unknownPlayer
}

public enum GamePhase: String, Codable, Sendable {
    case lobby
    case playing
    case finished
}

public struct GameSession: Codable, Equatable, Sendable {
    public private(set) var players: [Player] = []
    public private(set) var phase: GamePhase = .lobby
    public private(set) var activePlayerIndex: Int = 0
    public let maximumPlayers: Int = 6

    public init() {}

    public var activePlayer: Player? {
        guard phase == .playing, players.indices.contains(activePlayerIndex) else { return nil }
        return players[activePlayerIndex]
    }

    public mutating func join(_ player: Player) throws {
        guard phase == .lobby else { throw SessionError.notInLobby }
        guard players.count < maximumPlayers else { throw SessionError.lobbyFull }
        guard !players.contains(where: { $0.id == player.id }) else { throw SessionError.duplicatePlayer }
        guard !players.contains(where: { $0.color == player.color }) else { throw SessionError.duplicateColor }
        players.append(player)
    }

    public mutating func start() throws {
        guard phase == .lobby else { throw SessionError.notInLobby }
        guard players.count == maximumPlayers else { throw SessionError.invalidPlayerCount }
        activePlayerIndex = 0
        phase = .playing
    }

    /// The authoritative host calls this only after validating a completed move.
    public mutating func advanceTurn(completedBy playerID: String) throws {
        guard phase == .playing else { throw SessionError.notInLobby }
        guard players.contains(where: { $0.id == playerID }) else { throw SessionError.unknownPlayer }
        guard activePlayer?.id == playerID else { throw SessionError.notPlayersTurn }
        activePlayerIndex = (activePlayerIndex + 1) % players.count
    }
}
