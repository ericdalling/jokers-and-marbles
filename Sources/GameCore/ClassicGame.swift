public enum Ruleset: String, Codable, CaseIterable, Sendable {
    case classic, voorhees
    public var title: String { self == .classic ? "Classic Rules" : "Voorhees House Rules" }
}
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
    public let ruleset: Ruleset
    public private(set) var marbles: [GameMarble]
    public private(set) var activeSeat = 0
    public private(set) var winner: Int?
    private var hands: [[PlayingCard]]
    private var deck: [PlayingCard]
    private var discard: [PlayingCard] = []
    private var random: SeededRandom

    public init(rules: GameRules = .classic, seed: UInt64, ruleset: Ruleset = .classic) throws {
        guard rules.seats > 1, rules.teamCount > 0, rules.seats % rules.teamCount == 0,
              rules.marblesPerSeat > 0, rules.spacesPerSeat > 10, rules.handSize > 0,
              rules.deck.cardCount > rules.seats * rules.handSize else { throw ClassicGameError.invalidRules }
        self.rules = rules
        self.ruleset = ruleset
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
    }
    public var drawCount: Int { deck.count }
    public var topDiscard: PlayingCard? { discard.last }
    public func handCount(for seat: Int) -> Int { hand(for: seat).count }
    public func hand(for seat: Int) -> [PlayingCard] {
        hands.indices.contains(seat) ? hands[seat] : []
    }
    private mutating func draw() {
        if deck.isEmpty, discard.count > 1 {
            let top = discard.removeLast()
            deck = discard; discard = [top]; deck.shuffle(using: &random)
        }
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
            guard let next = rules.nextPosition(from: pos, seat: marble.seat, forward: distance > 0) else { return nil }
            pos = next
            if let other = occupant(pos, seat: marble.seat), other != index {
                if case .home = pos { return nil }
                if n == abs(distance), marbles[other].seat == marble.seat || !canCapture(other) { return nil }
            }
        }
        return MarbleStep(marble: index, destination: pos)
    }
    private func teammateBumpDestination(for seat: Int) -> MarblePosition {
        ruleset == .voorhees ? .track(rules.homeJunction(for: seat)) : .home(0)
    }

    private func canCapture(_ index: Int) -> Bool {
        let target = marbles[index]
        if rules.team(of: target.seat) != rules.team(of: activeSeat) { return true }
        return occupant(teammateBumpDestination(for: target.seat), seat: target.seat) == nil
    }
    private mutating func apply(_ step: MarbleStep) {
        let seat = marbles[step.marble].seat
        if let other = occupant(step.destination, seat: seat), other != step.marble {
            let targetSeat = marbles[other].seat
            let movingTeam = rules.team(of: ruleset == .voorhees ? activeSeat : seat)
            marbles[other].position = rules.team(of: targetSeat) == movingTeam ? teammateBumpDestination(for: targetSeat) : .start
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
            if ruleset == .voorhees, case .standard(let rank, _) = card {
                let value = rank.rawValue
                if [1, 9, 10, 11, 12, 13].contains(value) {
                    if value == 1 || value >= 11 {
                        for distance in (value == 1 ? [1, -1, 11] : [value]) {
                            options += singleSteps(distance: distance, seat: seat).map { [$0] }
                        }
                        let entry = MarblePosition.track(rules.entry(of: seat))
                        if let index = marbles.firstIndex(where: { $0.seat == seat && $0.position == .start }),
                           occupant(entry, seat: seat).map({ marbles[$0].seat != seat && canCapture($0) }) ?? true {
                            options.append([MarbleStep(marble: index, destination: entry)])
                        }
                    } else {
                        if value == 9 { options += singleSteps(distance: 9, seat: seat).map { [$0] } }
                        func candidates(_ game: ClassicGame, _ distance: Int) -> [MarbleStep] {
                            game.marbles.indices.compactMap { i in
                                let m = game.marbles[i]
                                if value == 9 && m.seat != seat { return nil }
                                let opponent = rules.team(of: m.seat) != rules.team(of: activeSeat)
                                if opponent, case .track = m.position {} else if opponent { return nil }
                                guard let move = game.step(i, distance: distance) else { return nil }
                                if opponent, case .track = move.destination {} else if opponent { return nil }
                                return move
                            }
                        }
                        for first in 1..<value {
                            for sign in [-1, 1] {
                                for a in candidates(self, first * sign) {
                                    var copy = self; copy.apply(a)
                                    for secondSign in (value == 9 ? [-sign] : [-1, 1]) {
                                        for b in candidates(copy, (value-first)*secondSign) where a.marble != b.marble {
                                            options.append([a,b])
                                        }
                                    }
                                }
                            }
                        }
                    }
                    plays += options.map { GamePlay(cardIndex: cardIndex, steps: $0) }
                    continue
                }
            }
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
    /// Reconstructs the exact legal route before applying a validated play.
    public func movementRoutes(for play: GamePlay) -> [[MarblePosition]] {
        guard legalPlays().contains(play) else { return [] }
        var copy = self
        let card = hands[activeSeat][play.cardIndex]
        var routes: [[MarblePosition]] = []
        for step in play.steps {
            let marble = copy.marbles[step.marble]
            let route: [MarblePosition]
            if marble.position == .start || card == .joker {
                route = [marble.position, step.destination]
            } else {
                // Legal moves cover at most 13 holes, less than half the shortest track.
                let candidates = [true, false].compactMap { forward -> [MarblePosition]? in
                    var position = marble.position
                    var path = [position]
                    for _ in 0..<13 {
                        guard let next = rules.nextPosition(from: position, seat: marble.seat, forward: forward) else { break }
                        position = next
                        path.append(next)
                        if next == step.destination { return path }
                    }
                    return nil
                }
                route = candidates.min { $0.count < $1.count } ?? [marble.position, step.destination]
            }
            routes.append(route)
            copy.apply(step)
        }
        return routes
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
        draw()
        activeSeat = (activeSeat + 1) % rules.seats
    }
}
