public enum CardPower: Codable, Equatable, Sendable {
    case forward(Int), backward(Int), enterOrForward(Int), splitForward(Int), replace
}

public struct GameRules: Codable, Equatable, Sendable {
    public let version: Int
    public let seats: Int
    public let teamCount: Int
    public let marblesPerSeat: Int
    public let spacesPerSeat: Int
    public let handSize: Int
    public let deck: DeckConfiguration
    public let powers: [CardRank: CardPower]
    public static let classic = GameRules(version: 1, seats: 6, teamCount: 3,
        marblesPerSeat: 5, spacesPerSeat: 17, handSize: 5, deck: DeckConfiguration(),
        powers: [.ace: .enterOrForward(1), .two: .forward(2), .three: .forward(3),
                 .four: .forward(4), .five: .forward(5), .six: .forward(6),
                 .seven: .splitForward(7), .eight: .backward(8), .nine: .forward(9),
                 .ten: .forward(10), .jack: .enterOrForward(10),
                 .queen: .enterOrForward(10), .king: .enterOrForward(10)])
    /// Odd seat counts are individual; even counts default to opposite-seat pairs.
    public static func modular(seats: Int, individual: Bool = false) throws -> GameRules {
        guard (3...6).contains(seats) else { throw ClassicGameError.invalidRules }
        let teams = individual || seats % 2 != 0 ? seats : seats / 2
        return GameRules(version: classic.version, seats: seats, teamCount: teams,
                         marblesPerSeat: classic.marblesPerSeat, spacesPerSeat: classic.spacesPerSeat,
                         handSize: classic.handSize, deck: classic.deck, powers: classic.powers)
    }
    public var trackLength: Int { seats * spacesPerSeat }
    public func team(of seat: Int) -> Int { seat % teamCount }
    public func entry(of seat: Int) -> Int { seat * spacesPerSeat }
    func homeJunction(for seat: Int) -> Int {
        (entry(of: seat) - 5 + trackLength) % trackLength
    }

    func nextPosition(from position: MarblePosition, seat: Int, forward: Bool) -> MarblePosition? {
        switch position {
        case .start:
            return nil
        case .home(let index):
            return forward && index + 1 < marblesPerSeat ? .home(index + 1) : nil
        case .track(let index):
            // Count the track hole beside the Home lane before turning into its first hole.
            if forward && index == homeJunction(for: seat) { return .home(0) }
            return .track((index + (forward ? 1 : -1) + trackLength) % trackLength)
        }
    }

    public func power(of card: PlayingCard) -> CardPower? {
        switch card {
        case .joker: return .replace
        case let .standard(rank, _): return powers[rank]
        }
    }
}
