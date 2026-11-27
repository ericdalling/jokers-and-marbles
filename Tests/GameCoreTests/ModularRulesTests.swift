import Testing
import GameCore

@Test(arguments: [3, 4, 5, 6], [false, true])
func modularConfiguration(seats: Int, individual: Bool) throws {
    let rules = try GameRules.modular(seats: seats, individual: individual)
    let paired = !individual && seats % 2 == 0
    #expect(rules.trackLength == seats * 17)
    #expect(rules.deck.cardCount == 108)
    #expect(rules.teamCount == (paired ? seats / 2 : seats))
    for seat in 0..<seats {
        #expect(rules.entry(of: seat) == seat * 17)
        if paired {
            #expect(rules.team(of: seat) == rules.team(of: (seat + seats / 2) % seats))
        } else {
            #expect(rules.team(of: seat) == seat)
        }
    }
    var game = try ClassicGame(rules: rules, seed: 42)
    #expect(game.marbles.count == seats * 5)
    #expect(game.drawCount == 108 - seats * 5 - 1)
    for _ in 0..<200 {
        if game.winner != nil { break }
        let active = game.activeSeat
        let play = try #require(game.legalPlays().first)
        try game.play(play, by: active)
        #expect(game.marbles.count == seats * 5)
        if game.winner == nil {
            #expect(game.activeSeat == (active + 1) % seats)
        }
        let track = game.marbles.compactMap { marble -> Int? in
            if case let .track(index) = marble.position { return index }
            return nil
        }
        #expect(track.allSatisfy { (0..<rules.trackLength).contains($0) })
        #expect(Set(track).count == track.count)
    }
}

@Test func rejectsUnsupportedSeatCounts() {
    #expect(throws: ClassicGameError.invalidRules) { try GameRules.modular(seats: 2) }
    #expect(throws: ClassicGameError.invalidRules) { try GameRules.modular(seats: 7) }
}
