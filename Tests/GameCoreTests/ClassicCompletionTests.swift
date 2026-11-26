import Testing
import GameCore

@Test func classicCardPowers() {
    let rules = GameRules.classic
    let expected: [CardPower] = [.enterOrForward(1), .forward(2), .forward(3), .forward(4), .forward(5), .forward(6), .splitForward(7), .backward(8), .forward(9), .forward(10), .enterOrForward(10), .enterOrForward(10), .enterOrForward(10)]
    for (rank, power) in zip(CardRank.allCases, expected) {
        #expect(rules.power(of: .standard(rank: rank, suit: .hearts)) == power)
    }
    #expect(rules.power(of: .joker) == .replace)
}

@Test(arguments: Array(0..<100))
func completeClassicGame(seed: Int) throws {
    var game = try ClassicGame(seed: UInt64(seed))
    for _ in 0..<10000 {
        if game.winner != nil { break }
        let plays = game.legalPlays()
        // Prefer progress into home, then entry, then ordinary forward movement.
        func score(_ play: GamePlay) -> Int {
            play.steps.reduce(0) { total, step in
                switch step.destination {
                case .home(let h): return total + 100 + h
                case .track: return total + (game.marbles[step.marble].position == .start ? 20 : 1)
                case .start: return total
                }
            }
        }
        let move = try #require(plays.max { score($0) < score($1) })
        try game.play(move, by: game.activeSeat)
    }
    let winner = try #require(game.winner)
    let winningMarbles = game.marbles.filter { game.rules.team(of: $0.seat) == winner }
    #expect(winningMarbles.count == 10)
    #expect(winningMarbles.allSatisfy { if case .home = $0.position { return true }; return false })
}
