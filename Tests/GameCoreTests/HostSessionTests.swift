import Foundation
import Testing
import GameCore

@Test func pairedHostSession() throws {
    var host = try HostSession(capacity: 6, individual: false)
    let ids = (0..<6).map { _ in UUID() }
    for i in 0..<6 { try host.join(id: ids[i], name: "Player \(i)", color: i) }
    for i in 0..<3 {
        try host.invite(from: ids[i], to: ids[i+3])
        try host.respond(recipient: ids[i+3], sender: ids[i], accept: true)
    }
    for id in ids { try host.ready(id: id, value: true) }
    try host.start(seed: 42)
    let state = host.publicState()
    #expect(state.seats == ids)
    #expect(state.drawCount == 78)
    for id in ids {
        let privateState = try host.privateState(for: id)
        #expect(privateState.hand.count == 5)
        if id != ids[0] { #expect(privateState.legalPlays.isEmpty) }
    }
    let move = try #require(host.privateState(for: ids[0]).legalPlays.first)
    try host.play(id: ids[0], expectedRevision: state.revision, move: move)
    #expect(host.publicState().activeSeat == 1)
    #expect(host.publicState().presentingMove)
    #expect(try host.privateState(for: ids[1]).legalPlays.isEmpty)
    let event = try #require(host.publicState().lastMove)
    #expect(event.routes.count == move.steps.count)
    for (route, step) in zip(event.routes, move.steps) { #expect(route.last == step.destination) }
    host.finishPresentation()
    #expect(!host.publicState().presentingMove)
    #expect(!(try host.privateState(for: ids[1]).legalPlays.isEmpty))
    do {
        try host.play(id: ids[0], expectedRevision: state.revision, move: move)
        Issue.record("Duplicate move accepted")
    } catch HostSessionError.unauthorized {}
}

@Test func teamConsentAndColorUniqueness() throws {
    var host = try HostSession(capacity: 4, individual: false)
    let a = UUID(), b = UUID()
    try host.join(id: a, name: "A", color: 0)
    do {
        try host.join(id: b, name: "B", color: 0)
        Issue.record("Duplicate color accepted")
    } catch HostSessionError.unavailable {}
    try host.join(id: b, name: "B", color: 1)
    try host.invite(from: a, to: b)
    #expect(host.publicState().members.allSatisfy { $0.partner == nil })
    try host.respond(recipient: b, sender: a, accept: false)
    #expect(host.publicState().invitations.isEmpty)
    try host.invite(from: a, to: b)
    try host.respond(recipient: b, sender: a, accept: true)
    try host.ready(id: a, value: true)
    try host.unpair(id: b)
    #expect(host.publicState().members.allSatisfy { $0.partner == nil && !$0.ready })
}
