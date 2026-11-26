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
        marblesPerSeat: 5, spacesPerSeat: 18, handSize: 5, deck: DeckConfiguration(),
        powers: [.ace: .enterOrForward(1), .two: .forward(2), .three: .forward(3),
                 .four: .forward(4), .five: .forward(5), .six: .forward(6),
                 .seven: .splitForward(7), .eight: .backward(8), .nine: .forward(9),
                 .ten: .forward(10), .jack: .enterOrForward(10),
                 .queen: .enterOrForward(10), .king: .enterOrForward(10)])
    public var trackLength: Int { seats * spacesPerSeat }
    public func team(of seat: Int) -> Int { seat % teamCount }
    public func entry(of seat: Int) -> Int { seat * spacesPerSeat }
    public func power(of card: PlayingCard) -> CardPower? {
        switch card {
        case .joker: return .replace
        case let .standard(rank, _): return powers[rank]
        }
    }
}
