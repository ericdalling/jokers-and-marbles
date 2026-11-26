public enum MarblePosition: Codable, Hashable, Sendable {
    case start, track(Int), home(Int)
}
public struct GameMarble: Codable, Hashable, Sendable {
    public let seat: Int
    public let number: Int
    public var position: MarblePosition
}
public struct MarbleStep: Codable, Hashable, Sendable {
    public let marble: Int
    public let destination: MarblePosition
    public init(marble: Int, destination: MarblePosition) {
        self.marble = marble; self.destination = destination
    }
}
public struct GamePlay: Codable, Hashable, Sendable {
    public let cardIndex: Int
    public let steps: [MarbleStep]
    public init(cardIndex: Int, steps: [MarbleStep]) {
        self.cardIndex = cardIndex; self.steps = steps
    }
}
public enum ClassicGameError: Error, Equatable, Sendable {
    case invalidRules, wrongTurn, illegalPlay, finished
}
private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
public struct ClassicGame: Sendable {
    public let rules: GameRules
    public private(set) var marbles: [GameMarble]
    public private(set) var activeSeat = 0
    public private(set) var winner: Int?
    private var hands: [[PlayingCard]]
    private var deck: [PlayingCard]
    private var discard: [PlayingCard] = []
    private var random: SeededRandom

    public init(rules: GameRules = .classic, seed: UInt64) throws {
        guard rules.seats > 1, rules.teamCount > 0, rules.seats % rules.teamCount == 0,
              rules.marblesPerSeat > 0, rules.spacesPerSeat > 10, rules.handSize > 0,
              rules.deck.cardCount > rules.seats * rules.handSize else { throw ClassicGameError.invalidRules }
        self.rules = rules
        marbles = (0..<rules.seats).flatMap { seat in
            (0..<rules.marblesPerSeat).map { GameMarble(seat: seat, number: $0, position: .start) }
        }
        random = SeededRandom(state: seed)
        deck = rules.deck.makeCards()
        hands = Array(repeating: [], count: rules.seats)
        deck.shuffle(using: &random)
        for seat in 0..<rules.seats {
            for _ in 0..<rules.handSize { hands[seat].append(deck.removeLast()) }
        }
        draw()
    }
    public func hand(for seat: Int) -> [PlayingCard] {
        hands.indices.contains(seat) ? hands[seat] : []
    }
    private mutating func draw() {
        if deck.isEmpty { deck = discard; discard = []; deck.shuffle(using: &random) }
        if let card = deck.popLast() { hands[activeSeat].append(card) }
    }
    private func complete(_ seat: Int) -> Bool {
        marbles.filter { $0.seat == seat }.allSatisfy {
            if case .home = $0.position { return true }; return false
        }
    }
    private var controlledSeat: Int {
        if !complete(activeSeat) { return activeSeat }
        for offset in 1..<rules.seats {
            let seat = (activeSeat + offset) % rules.seats
            if rules.team(of: seat) == rules.team(of: activeSeat), !complete(seat) { return seat }
        }
        return activeSeat
    }
    private func occupant(_ position: MarblePosition, seat: Int) -> Int? {
        marbles.firstIndex {
            guard $0.position == position else { return false }
            switch position {
            case .start: return false
            case .track: return true
            case .home: return $0.seat == seat
            }
        }
    }
    private func step(_ index: Int, distance: Int) -> MarbleStep? {
        let marble = marbles[index]
        var pos = marble.position
        guard distance != 0 else { return nil }
        for n in 1...abs(distance) {
            switch pos {
            case .start: return nil
            case let .home(h):
                guard distance > 0, h + 1 < rules.marblesPerSeat else { return nil }
                pos = .home(h + 1)
            case let .track(t):
                let next = (t + (distance > 0 ? 1 : -1) + rules.trackLength) % rules.trackLength
                if distance > 0 && next == rules.entry(of: marble.seat) {
                    pos = .home(0)
                } else { pos = .track(next) }
            }
            if let other = occupant(pos, seat: marble.seat), other != index {
                if marbles[other].seat == marble.seat { return nil }
                if n == abs(distance), !canCapture(other) { return nil }
            }
        }
        return MarbleStep(marble: index, destination: pos)
    }
    private func canCapture(_ index: Int) -> Bool {
        let target = marbles[index]
        if rules.team(of: target.seat) != rules.team(of: activeSeat) { return true }
        return occupant(.home(0), seat: target.seat) == nil
    }
    private mutating func apply(_ step: MarbleStep) {
        let seat = marbles[step.marble].seat
        if let other = occupant(step.destination, seat: seat), other != step.marble {
            marbles[other].position = rules.team(of: marbles[other].seat) == rules.team(of: seat) ? .home(0) : .start
        }
        marbles[step.marble].position = step.destination
    }
    private func singleSteps(distance: Int, seat: Int) -> [MarbleStep] {
        marbles.indices.filter { marbles[$0].seat == seat }.compactMap { step($0, distance: distance) }
    }
    public func legalPlays() -> [GamePlay] {
        guard winner == nil else { return [] }
        let seat = controlledSeat
        var plays: [GamePlay] = []
        for (cardIndex, card) in hands[activeSeat].enumerated() {
            guard let power = rules.power(of: card) else { continue }
            var options: [[MarbleStep]] = []
            switch power {
            case let .forward(n): options = singleSteps(distance: n, seat: seat).map { [$0] }
            case let .backward(n): options = singleSteps(distance: -n, seat: seat).map { [$0] }
            case let .enterOrForward(n):
                options = singleSteps(distance: n, seat: seat).map { [$0] }
                let entry = MarblePosition.track(rules.entry(of: seat))
                if let index = marbles.firstIndex(where: { $0.seat == seat && $0.position == .start }) {
                    if let other = occupant(entry, seat: seat) {
                        if marbles[other].seat != seat && canCapture(other) { options.append([MarbleStep(marble: index, destination: entry)]) }
                    } else { options.append([MarbleStep(marble: index, destination: entry)]) }
                }
            case let .splitForward(n):
                options = singleSteps(distance: n, seat: seat).map { [$0] }
                if n > 1 {
                    for first in 1..<n {
                        for a in singleSteps(distance: first, seat: seat) {
                            var copy = self; copy.apply(a)
                            for b in copy.singleSteps(distance: n-first, seat: seat) where b.marble != a.marble {
                                options.append([a,b])
                            }
                        }
                    }
                }
            case .replace:
                for index in marbles.indices where marbles[index].seat == seat {
                    if case .home = marbles[index].position { continue }
                    for other in marbles.indices where marbles[other].seat != seat {
                        if case .track = marbles[other].position, canCapture(other) {
                            options.append([MarbleStep(marble: index, destination: marbles[other].position)])
                        }
                    }
                }
            }
            plays += options.map { GamePlay(cardIndex: cardIndex, steps: $0) }
        }
        if plays.isEmpty {
            return hands[activeSeat].indices.map { GamePlay(cardIndex: $0, steps: []) }
        }
        return plays
    }
    public mutating func play(_ play: GamePlay, by seat: Int) throws {
        guard winner == nil else { throw ClassicGameError.finished }
        guard seat == activeSeat else { throw ClassicGameError.wrongTurn }
        guard legalPlays().contains(play) else { throw ClassicGameError.illegalPlay }
        for step in play.steps { apply(step) }
        discard.append(hands[seat].remove(at: play.cardIndex))
        let team = rules.team(of: seat)
        if (0..<rules.seats).filter({ rules.team(of: $0) == team }).allSatisfy({ complete($0) }) {
            winner = team; return
        }
        activeSeat = (activeSeat + 1) % rules.seats
        draw()
    }
}
