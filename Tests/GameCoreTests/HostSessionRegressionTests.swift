import Foundation
import Testing
import GameCore

@Test func hostConfigurationsAndPrivateProjection() throws {
    for capacity in 3...6 {
        var host = try HostSession(capacity: capacity, individual: true)
        let ids = (0..<capacity).map { _ in UUID() }
        #expect(throws: HostSessionError.notReady) { try host.start(seed: 7) }
        for (index, id) in ids.enumerated() {
            try host.join(id: id, name: "Player \(index)", color: index)
            try host.ready(id: id, value: true)
        }
        try host.start(seed: 7)
        let snapshot = host.publicState()
        #expect(snapshot.drawCount == 108 - capacity * 5)
        #expect(snapshot.seats == ids)
        #expect(throws: HostSessionError.unauthorized) { try host.privateState(for: UUID()) }
        for id in ids {
            let personal = try host.privateState(for: id)
            #expect(personal.hand.count == 5)
            #expect(personal.seat == ids.firstIndex(of: id))
        }
        let encoded = try JSONEncoder().encode(snapshot)
        let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(json["hand"] == nil)
        #expect(json["hands"] == nil)
        #expect(json["legalPlays"] == nil)
        #expect(throws: HostSessionError.alreadyStarted) {
            try host.join(id: UUID(), name: "Late", color: 0)
        }
    }
}
