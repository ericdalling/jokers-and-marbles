import Testing
import GameCore

private func player(_ number: Int) -> Player {
    Player(id: "p\(number)", name: "Player \(number)", color: MarbleColor.allCases[number])
}

@Test func sixPlayerLobbyAndTurnWraparound() throws {
    var game = GameSession()
    for index in 0..<6 { try game.join(player(index)) }
    #expect(game.players.count == 6)
    try game.start()
    #expect(game.activePlayer?.id == "p0")
    for index in 0..<6 { try game.advanceTurn(completedBy: "p\(index)") }
    #expect(game.activePlayer?.id == "p0")
}

@Test func cannotStartWithoutSixPlayers() throws {
    var game = GameSession()
    try game.join(player(0))
    #expect(throws: SessionError.invalidPlayerCount) { try game.start() }
}

@Test func duplicateSeatColorRejected() throws {
    var game = GameSession()
    try game.join(player(0))
    #expect(throws: SessionError.duplicateColor) {
        try game.join(Player(id: "other", name: "Other", color: .red))
    }
}

@Test func cannotAdvanceAnotherPlayersTurn() throws {
    var game = GameSession()
    for index in 0..<6 { try game.join(player(index)) }
    try game.start()
    #expect(throws: SessionError.notPlayersTurn) { try game.advanceTurn(completedBy: "p1") }
    #expect(game.activePlayer?.id == "p0")
}

@Test func defaultDeckHas108Cards() {
    let deck = DeckConfiguration()
    let cards = deck.makeCards()
    #expect(deck.cardCount == 108)
    #expect(cards.count == 108)
    #expect(cards.filter { $0 == .joker }.count == 4)
}

@Test func boardRotatesByShortestPath() {
    #expect(BoardOrientation.shortestRotation(from: 5, to: 0) == 60)
    #expect(BoardOrientation.shortestRotation(from: 0, to: 5) == -60)
    #expect(BoardOrientation.shortestRotation(from: 0, to: 3) == 180)
}
