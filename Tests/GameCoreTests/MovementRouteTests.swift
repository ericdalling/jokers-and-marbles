import Testing
import GameCore

@Test func movementRoutesMatchLegalPlays() throws {
    for seed in 1...12 {
        var game = try ClassicGame(seed: UInt64(seed))
        for turn in 0..<500 {
            if game.winner != nil { break }
            let plays = game.legalPlays()
            let move = try #require(plays.isEmpty ? nil : plays[(turn + seed) % plays.count])
            let routes = game.movementRoutes(for: move)
            #expect(routes.count == move.steps.count)
            for (route, step) in zip(routes, move.steps) {
                #expect(route.first == game.marbles[step.marble].position)
                #expect(route.last == step.destination)
                #expect(route.count >= 2)
                for (a, b) in zip(route, route.dropFirst()) where route.count > 2 {
                    switch (a, b) {
                    case (.track(let x), .track(let y)):
                        let delta = (y - x + game.rules.trackLength) % game.rules.trackLength
                        #expect(delta == 1 || delta == game.rules.trackLength - 1)
                    case (.track, .home(let h)): #expect(h == 0)
                    case (.home(let x), .home(let y)): #expect(y == x + 1)
                    default: Issue.record("Unexpected intermediate route transition")
                    }
                }
            }
            try game.play(move, by: game.activeSeat)
            for step in move.steps { #expect(game.marbles[step.marble].position == step.destination) }
        }
    }
}

@Test func jokersAndPassingOwnMarblesAreLegalAlongsideOrdinaryMoves() throws {
    var foundJoker = false
    var foundPass = false
    for seed in 1...12 {
        var game = try ClassicGame(seed: UInt64(seed))
        for turn in 0..<300 {
            if game.winner != nil { break }
            let plays = game.legalPlays()
            let hand = game.hand(for: game.activeSeat)
            if plays.contains(where: { hand[$0.cardIndex] != .joker && !$0.steps.isEmpty }),
               plays.contains(where: { hand[$0.cardIndex] == .joker && !$0.steps.isEmpty }) {
                foundJoker = true
            }
            if !foundPass {
                for move in plays where move.steps.count == 1 {
                    let marble = game.marbles[move.steps[0].marble]
                    guard let route = game.movementRoutes(for: move).first, route.count > 2 else { continue }
                    let intermediate = route.dropFirst().dropLast()
                    if game.marbles.contains(where: { candidate in
                        guard case .track = candidate.position else { return false }
                        return candidate.seat == marble.seat && intermediate.contains(candidate.position)
                    }) {
                        foundPass = true
                        #expect(!game.marbles.contains {
                            $0.seat == marble.seat && $0.position == move.steps[0].destination
                        })
                        break
                    }
                }
            }
            if foundJoker && foundPass { return }
            let play = try #require(plays.isEmpty ? nil : plays[(turn + seed) % plays.count])
            try game.play(play, by: game.activeSeat)
        }
    }
    #expect(foundJoker)
    #expect(foundPass)
}
