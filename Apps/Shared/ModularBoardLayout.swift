import CoreGraphics
import Foundation

struct ModularBoardLayout {
    let playerCount: Int
    let centerY: CGFloat
    let extent: CGFloat

    init?(playerCount: Int) {
        guard (3...6).contains(playerCount) else { return nil }
        self.playerCount = playerCount
        let halfAngle = Double.pi / Double(playerCount)
        // Radial offsets measured against the master mesh and the full fallback outline.
        let clearance: CGFloat = [65, 55, 50, 50][playerCount - 3]
        centerY = CGFloat(485 / tan(halfAngle) + 128) + clearance
        extent = CGFloat(970 / (2 * sin(halfAngle)) + 160) + clearance
    }

    func scale(in size: CGSize) -> CGFloat {
        min(size.width, size.height) / (2 * extent)
    }

    func angle(for seat: Int) -> Double {
        .pi + Double(seat) * 2 * .pi / Double(playerCount)
    }
}
