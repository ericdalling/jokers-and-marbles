import Testing
import GameCore

@Test func lobbyReadinessAndSeatOwnership() {
    var lobby = LobbyState(seats: 3, individual: false)
    #expect(lobby.individual)
    #expect(!lobby.join(name: "", seat: 0))
    #expect(!lobby.join(name: "Invalid", seat: 3))
    #expect(lobby.join(name: "One", seat: 0))
    #expect(!lobby.join(name: "Duplicate", seat: 0))
    #expect(lobby.join(name: "Two", seat: 1))
    #expect(lobby.join(name: "Three", seat: 2))
    #expect(!lobby.canStart)
    for seat in 0..<3 { lobby.ready(seat: seat, value: true) }
    #expect(lobby.canStart)
    lobby.leave(seat: 1)
    #expect(!lobby.canStart)
    #expect(lobby.join(name: "Replacement", seat: 1))
    #expect(!lobby.canStart)
}
