import Foundation
import Network

/// Lobby-only transport. Do not send private cards until authenticated encryption is added.
public final class LobbyConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "jokers.lobby.connection")
    private var buffer = Data()
    public init(_ connection: NWConnection) { self.connection = connection }
    public func start(onMessage: @escaping @Sendable (LobbyMessage) -> Void,
                      onClose: @escaping @Sendable () -> Void) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .failed, .cancelled: onClose()
            default: break
            }
        }
        connection.start(queue: queue)
        receive(onMessage, onClose)
    }
    public func send(_ message: LobbyMessage) {
        guard var data = try? JSONEncoder().encode(message), data.count < 8192 else { return }
        data.append(10)
        connection.send(content: data, completion: .contentProcessed { _ in })
    }
    public func cancel() { connection.cancel() }
    private func receive(_ handler: @escaping @Sendable (LobbyMessage) -> Void,
                         _ closed: @escaping @Sendable () -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, done, error in
            guard let self else { return }
            if let data { self.buffer.append(data) }
            while let end = self.buffer.firstIndex(of: 10) {
                let frame = self.buffer.prefix(upTo: end)
                guard frame.count < 8192, let message = try? JSONDecoder().decode(LobbyMessage.self, from: Data(frame)) else {
                    self.cancel(); return
                }
                self.buffer.removeSubrange(...end)
                handler(message)
            }
            if self.buffer.count >= 8192 || done || error != nil { self.cancel(); closed(); return }
            self.receive(handler, closed)
        }
    }
}
public enum LobbyDiscovery {
    public static let service = "_jokersmarbles._tcp"
}
