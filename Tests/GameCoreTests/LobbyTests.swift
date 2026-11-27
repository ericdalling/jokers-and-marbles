import Testing
import GameCore

@Test func lobbyReadinessAndSeatOwnership() {
    var lobby = LobbyState(seats: 3, individual: false)
    #expect(lobby.individual)
    let joined1 = lobby.join(name: "", seat: 0)
    #expect(!joined1)
    let joined2 = lobby.join(name: "Invalid", seat: 3)
    #expect(!joined2)
    let joined3 = lobby.join(name: "One", seat: 0)
    #expect(joined3)
    let joined4 = lobby.join(name: "Duplicate", seat: 0)
    #expect(!joined4)
    let joined5 = lobby.join(name: "Two", seat: 1)
    #expect(joined5)
    let joined6 = lobby.join(name: "Three", seat: 2)
    #expect(joined6)
    #expect(!lobby.canStart)
    for seat in 0..<3 { lobby.ready(seat: seat, value: true) }
    #expect(lobby.canStart)
    lobby.leave(seat: 1)
    #expect(!lobby.canStart)
    let joined7 = lobby.join(name: "Replacement", seat: 1)
    #expect(joined7)
    #expect(!lobby.canStart)
}
