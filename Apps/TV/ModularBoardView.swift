import SwiftUI

/// Visual-only renderer of the approved SVG. Joinery and game topology are not yet validated.
struct ModularBoardView: View {
    let playerCount: Int
    var activePlayer: Int = 0
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]

    var body: some View {
        Canvas { context, size in
            guard (3...6).contains(playerCount) else { return }
            let n = Double(playerCount)
            let extent = 970 / (2 * sin(.pi / n)) + 160
            let scale = min(size.width, size.height) / CGFloat(2 * extent)
            for seat in 0..<playerCount {
                var ctx = context
                ctx.translateBy(x: size.width / 2, y: size.height / 2)
                ctx.scaleBy(x: scale, y: scale)
                ctx.rotate(by: .degrees(180 + Double(seat - activePlayer) * 360 / n))
                ctx.translateBy(x: -634, y: CGFloat(-485 / tan(.pi / n) - 128))
                let outline = Self.outline
                ctx.fill(outline, with: .color(Color(red: 0.875, green: 0.718, blue: 0.518)))
                ctx.stroke(outline, with: .color(.brown), lineWidth: 2)
                for point in Self.track {
                    ctx.fill(Self.hole(point), with: .color(.brown))
                }
                for point in Self.home + Self.start {
                    ctx.fill(Self.hole(point), with: .color(colors[seat]))
                }
            }
        }
        .accessibilityLabel("\(playerCount)-player modular board preview")
    }

    static let track = (0..<16).map { CGPoint(x: 237 + Double($0) * 55.2, y: 95) } + [CGPoint(x: 1119, y: 128)]
    static let home = [CGPoint(x: 345,y: 146), CGPoint(x: 345,y: 201), CGPoint(x: 345,y: 256), CGPoint(x: 400,y: 256), CGPoint(x: 453,y: 256)]
    static let start = [CGPoint(x: 613,y: 146), CGPoint(x: 562,y: 201), CGPoint(x: 613,y: 201), CGPoint(x: 665,y: 201), CGPoint(x: 613,y: 256)]
    static func hole(_ p: CGPoint) -> Path {
        Path(ellipseIn: CGRect(x: p.x - 18, y: p.y - 18, width: 36, height: 36))
    }
    static var outline: Path {
        var p = Path()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        p.move(to: pt(175,64))
        p.addQuadCurve(to: pt(225,60), control: pt(195,60))
        p.addLine(to: pt(1105,60))
        p.addCurve(to: pt(1110,177), control1: pt(1185,60), control2: pt(1185,173))
        p.addQuadCurve(to: pt(1058,160), control: pt(1080,180))
        p.addQuadCurve(to: pt(1024,190), control: pt(1037,146))
        p.addQuadCurve(to: pt(970,231), control: pt(1010,230))
        p.addLine(to: pt(738,231))
        p.addQuadCurve(to: pt(706,260), control: pt(715,231))
        p.addQuadCurve(to: pt(665,292), control: pt(696,292))
        p.addLine(to: pt(335,292))
        p.addQuadCurve(to: pt(286,248), control: pt(286,292))
        p.addLine(to: pt(286,219))
        p.addQuadCurve(to: pt(254,190), control: pt(286,190))
        p.addLine(to: pt(195,190))
        p.addQuadCurve(to: pt(182,163), control: pt(165,190))
        p.addCurve(to: pt(175,64), control1: pt(213,126), control2: pt(207,91))
        p.closeSubpath()
        return p
    }
}
