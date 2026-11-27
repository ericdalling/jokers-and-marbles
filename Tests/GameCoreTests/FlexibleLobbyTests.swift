import Foundation
import Testing
import GameCore

@Test func flexibleLobbySeats() throws {
    for count in 1...6 {
        var host = HostSession()
        let ids = (0..<count).map { _ in UUID() }
        for (i, id) in ids.enumerated() {
            try host.join(id: id, name: "Player \(i)", color: i)
            try host.ready(id: id, value: true)
        }
        try host.start(seed: 42)
        let state = host.publicState()
        #expect(state.capacity == max(3, count))
        #expect(state.members.filter { $0.isBot }.count == max(0, 3-count))
        #expect(state.drawCount == 108 - 5 * max(3, count))
        for id in ids { #expect(try host.privateState(for: id).hand.count == 5) }
        if count == 1 {
            let move = try #require(host.privateState(for: ids[0]).legalPlays.first)
            try host.play(id: ids[0], expectedRevision: state.revision, move: move)
            host.finishPresentation()
            for _ in 0..<2 {
                #expect(host.botTurn)
                try host.playBot()
                #expect(host.publicState().presentingMove)
                host.finishPresentation()
            }
            #expect(!host.botTurn)
            #expect(host.publicState().activeSeat == 0)
        }
    }
}
