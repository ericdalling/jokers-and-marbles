public enum MarbleColor: String, CaseIterable, Codable, Sendable {
    case red, blue, green, yellow, purple, orange
}

public struct Player: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let color: MarbleColor
    public init(id: String, name: String, color: MarbleColor) {
        self.id = id
        self.name = name
        self.color = color
    }
}
