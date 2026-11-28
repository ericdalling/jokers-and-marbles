#if DEBUG && targetEnvironment(simulator)
import SwiftUI
import GameCore

struct VisualReviewFixture {
    let host: HostSession
    let player: UUID
    static var requested: Bool { ProcessInfo.processInfo.arguments.contains("--visual-review") }
    static func make() throws -> Self {
        let args = ProcessInfo.processInfo.arguments
        let count = args.firstIndex(of: "--players").flatMap { args.indices.contains($0 + 1) ? Int(args[$0 + 1]) : nil } ?? 6
        let names = ["Eric", "Christy", "Sophie", "Isabelle", "Emma", "Charlotte"]
        let ids = (0..<count).map { _ in UUID() }
        var host = try HostSession(capacity: count, individual: count % 2 != 0)
        for i in 0..<count { try host.join(id: ids[i], name: names[i], color: i) }
        if count % 2 == 0 {
            for i in 0..<(count / 2) {
                try host.invite(from: ids[i], to: ids[i + count / 2])
                try host.respond(recipient: ids[i + count / 2], sender: ids[i], accept: true)
            }
        }
        for id in ids { try host.ready(id: id, value: true) }
        try host.start(seed: 42)
        return Self(host: host, player: ids[0])
    }
}
struct VisualHostReview: View {
    let fixture: VisualReviewFixture
    var body: some View {
        PublicGameplayView(state: fixture.host.publicState(), connected: Set(fixture.host.publicState().seats))
            .padding(20).foregroundStyle(.white).background(GameBackdrop())
    }
}
#endif
