# Architecture

- Swift package GameCore: deterministic rules, public/private projections, commands and validation; no UI dependencies.
- tvOS host: authoritative state, SwiftUI/SpriteKit board, local session lifecycle.
- iOS/iPadOS client: SwiftUI private hand and move selection.
- Network framework with Bonjour discovery, authenticated encrypted sessions, per-player reconnect tokens. Send only each player's private hand to that player; never broadcast full deck or private state.
- Versioned messages, command IDs, state revisions, host validation and reconnect snapshots.
- Test rule engine independently; integration-test six clients and disconnect/reconnect.
- Use Xcode project generation or checked-in project after selecting deployment targets; GitHub Actions builds and TestFlight signing follow after app identifiers and credentials are configured.
