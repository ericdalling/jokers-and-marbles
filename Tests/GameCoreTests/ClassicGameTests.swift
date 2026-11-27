import Testing
import GameCore

@Test func classicConfiguration() throws {
    let rules = GameRules.classic
    #expect(rules.trackLength == 102)
    #expect(rules.teamCount == 3)
    #expect(rules.team(of: 0) == rules.team(of: 3))
    #expect(rules.team(of: 1) != rules.team(of: 0))
    let game = try ClassicGame(seed: 42)
    #expect(game.marbles.count == 30)
    #expect(game.drawCount == 78)
    #expect(game.topDiscard == nil)
    #expect(game.handCount(for: 0) == 5)
    #expect(game.hand(for: 0).count == 5)
    #expect(game.hand(for: 1).count == 5)
}
@Test func rejectsInvalidCommands() throws {
    var game = try ClassicGame(seed: 42)
    let move = try #require(game.legalPlays().first)
    #expect(throws: ClassicGameError.wrongTurn) { try game.play(move, by: 1) }
    #expect(throws: ClassicGameError.illegalPlay) {
        try game.play(GamePlay(cardIndex: 999, steps: []), by: 0)
    }
    #expect(game.activeSeat == 0)
}
@Test func deterministicSimulation() throws {
    var a = try ClassicGame(seed: 42)
    var b = try ClassicGame(seed: 42)
    for _ in 0..<500 {
        if a.winner != nil { break }
        #expect(a.legalPlays() == b.legalPlays())
        let move = try #require(a.legalPlays().first)
        try a.play(move, by: a.activeSeat)
        try b.play(move, by: b.activeSeat)
        #expect(a.marbles == b.marbles)
        #expect(a.winner == b.winner)
        let track = a.marbles.compactMap { marble -> Int? in
            if case let .track(t) = marble.position { return t }; return nil
        }
        #expect(Set(track).count == track.count)
    }
}

@Test func replacementDrawBelongsToOutgoingPlayer() throws {
    var game = try ClassicGame(seed: 42)
    let incomingHand = game.hand(for: 1)
    let oldHand = game.hand(for: 0)
    let move = try #require(game.legalPlays().first)
    try game.play(move, by: 0)
    #expect(game.activeSeat == 1)
    #expect(game.hand(for: 1) == incomingHand)
    #expect(game.handCount(for: 0) == 5)
    #expect(game.topDiscard == oldHand[move.cardIndex])
    #expect(game.drawCount == 77)
}

@Test func sharedDeckRecyclesDeterministically() throws {
    var a = try ClassicGame(seed: 42)
    var b = try ClassicGame(seed: 42)
    var recycled = false
    for _ in 0..<300 {
        if a.winner != nil { break }
        let seat = a.activeSeat
        let before = a.drawCount
        let hand = a.hand(for: seat)
        let move = try #require(a.legalPlays().first)
        try a.play(move, by: seat)
        try b.play(move, by: seat)
        #expect(a.topDiscard == hand[move.cardIndex])
        #expect(a.drawCount == b.drawCount)
        for player in 0..<6 {
            #expect(a.hand(for: player) == b.hand(for: player))
            if a.winner == nil { #expect(a.handCount(for: player) == 5) }
        }
        if a.winner == nil {
            if before == 0 {
                #expect(a.drawCount == 77)
                recycled = true
            } else {
                #expect(a.drawCount == before - 1)
            }
        }
        if recycled { break }
    }
    #expect(recycled)
}
