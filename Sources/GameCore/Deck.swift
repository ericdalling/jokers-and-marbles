/// A standard playing card; two decks may contain cards with identical rank and suit.
public enum CardSuit: String, CaseIterable, Codable, Sendable {
    case hearts, diamonds, clubs, spades
}

public enum CardRank: Int, CaseIterable, Codable, Sendable {
    case ace = 1, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king
}

public enum PlayingCard: Codable, Hashable, Sendable {
    case standard(rank: CardRank, suit: CardSuit)
    case joker
}

public struct DeckConfiguration: Codable, Equatable, Sendable {
    public let standardDecks: Int
    public let jokers: Int

    public init(standardDecks: Int = 2, jokers: Int = 4) {
        self.standardDecks = standardDecks
        self.jokers = jokers
    }

    public var cardCount: Int { standardDecks * 52 + jokers }

    public func makeCards() -> [PlayingCard] {
        guard standardDecks > 0, jokers >= 0 else { return [] }
        var cards: [PlayingCard] = []
        for _ in 0..<standardDecks {
            for suit in CardSuit.allCases {
                for rank in CardRank.allCases {
                    cards.append(.standard(rank: rank, suit: suit))
                }
            }
        }
        cards.append(contentsOf: repeatElement(.joker, count: jokers))
        return cards
    }
}
