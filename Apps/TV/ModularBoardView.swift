import SwiftUI
import GameCore

/// Visual-only renderer of the approved SVG. Joinery and game topology are not yet validated.
struct ModularBoardView: View {
    let playerCount: Int
    var activePlayer: Int = 0
    var gameMarbles: [GameMarble]? = nil
    var seatColors: [Int]? = nil
    var selectableMarbles: [Int] = []
    var selectedMarble: Int? = nil
    var onMarble: ((Int) -> Void)? = nil
    var destinations: [MarbleStep] = []
    var onDestination: ((MarbleStep) -> Void)? = nil
    var lastMove: PublicMove? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 1
    @State private var animatedRevision: Int?
    private func color(for seat: Int) -> Color {
        let index = seatColors.flatMap { $0.indices.contains(seat) ? $0[seat] : nil } ?? seat
        return colors[colors.indices.contains(index) ? index : 0]
    }
    private let colors: [Color] = [Color(red: 0.83, green: 0.035, blue: 0.06), Color(red: 0.025, green: 0.32, blue: 0.95), Color(red: 0.025, green: 0.67, blue: 0.20), Color(red: 0.98, green: 0.76, blue: 0.015), Color(red: 0.58, green: 0.08, blue: 0.85), Color(red: 1, green: 0.36, blue: 0.025)]

    var body: some View {
        GeometryReader { geo in
        Canvas { context, size in
            guard (3...6).contains(playerCount) else { return }
            let n = Double(playerCount)
            let extent = 970 / (2 * sin(.pi / n)) + 160
            let scale = min(size.width, size.height) / CGFloat(2 * extent)
            for seat in 0..<playerCount {
                var ctx = context
                ctx.translateBy(x: size.width / 2, y: size.height / 2)
                ctx.scaleBy(x: scale, y: scale)
                ctx.rotate(by: .degrees(180 + Double(seat) * 360 / n))
                ctx.translateBy(x: -634, y: CGFloat(-485 / tan(.pi / n) - 128))
                let outline = Self.outline
                var edge = ctx
                edge.translateBy(x: 0, y: 12)
                edge.fill(outline, with: .color(Color(red: 0.43, green: 0.24, blue: 0.11)))
                ctx.fill(outline, with: .linearGradient(Gradient(colors: [Color(red: 0.99, green: 0.87, blue: 0.66), Color(red: 0.91, green: 0.73, blue: 0.48), Color(red: 0.97, green: 0.82, blue: 0.59)]), startPoint: CGPoint(x: 0, y: 60), endPoint: CGPoint(x: 0, y: 292)))
                ctx.stroke(outline, with: .color(Color(red: 0.65, green: 0.42, blue: 0.22)), lineWidth: 2)
                for point in Self.track {
                    ctx.fill(Self.hole(point), with: .radialGradient(Gradient(colors: [.brown, .black.opacity(0.8)]), center: point, startRadius: 0, endRadius: 18))
                    ctx.stroke(Self.hole(point), with: .color(.white.opacity(0.35)), lineWidth: 2)
                }
                for point in Self.home + Self.start {
                    ctx.fill(Self.hole(point), with: .radialGradient(Gradient(colors: [color(for: seat).opacity(0.85), .black.opacity(0.85)]), center: CGPoint(x: point.x, y: point.y + 5), startRadius: 0, endRadius: 22))
                    ctx.stroke(Self.hole(point), with: .color(.black.opacity(0.45)), lineWidth: 2)
                }
                if let gameMarbles {
                    for (index, marble) in gameMarbles.enumerated() {
                        if progress < 1, lastMove?.steps.contains(where: { $0.marble == index }) == true { continue }
                        let point: CGPoint
                        switch marble.position {
                        case .start:
                            guard marble.seat == seat, Self.start.indices.contains(marble.number) else { continue }
                            point = Self.start[marble.number]
                        case .home(let index):
                            guard marble.seat == seat, Self.home.indices.contains(index) else { continue }
                            point = Self.home[index]
                        case .track(let index):
                            guard index >= 0, index / Self.track.count == seat else { continue }
                            point = Self.track[index % Self.track.count]
                        }
                        Self.drawMarble(point, color: color(for: marble.seat), context: ctx)
                    }
                } else {
                    for point in Array(Self.start.prefix(3)) + [Self.track[5], Self.home[0]] {
                        Self.drawMarble(point, color: color(for: seat), context: ctx)
                    }
                }
            }
        }
        .overlay {
            Canvas { context, size in
                guard let move = lastMove, let gameMarbles else { return }
                for (stepIndex, step) in move.steps.enumerated() {
                    guard move.before.indices.contains(step.marble), gameMarbles.indices.contains(step.marble),
                          let origin = screenPoint(move.before[step.marble], size: size),
                          let end = screenPoint(gameMarbles[step.marble], size: size) else { continue }
                    let color = color(for: gameMarbles[step.marble].seat)
                    let route = move.routes.indices.contains(stepIndex) ? move.routes[stepIndex] : []
                    let points = route.compactMap { destinationPoint(move.before[step.marble], destination: $0, size: size) }
                    let path = points.count >= 2 ? points : [origin, end]
                    let lengths = move.routes.map { max(1, $0.count - 1) }
                    let total = max(1, lengths.reduce(0, +))
                    let prior = lengths.prefix(stepIndex).reduce(0, +)
                    let length = lengths.indices.contains(stepIndex) ? lengths[stepIndex] : 1
                    let local = min(1, max(0, (progress * CGFloat(total) - CGFloat(prior)) / CGFloat(length)))
                    let distance = local * CGFloat(path.count - 1)
                    let segment = min(path.count - 2, Int(distance))
                    let fraction = distance - CGFloat(segment)
                    let a = path[segment], b = path[segment + 1]
                    let point = CGPoint(x: a.x + (b.x-a.x)*fraction, y: a.y + (b.y-a.y)*fraction)
                    var trail = Path(); trail.move(to: origin)
                    for p in path.prefix(segment + 1) { trail.addLine(to: p) }
                    trail.addLine(to: point)
                    context.stroke(trail, with: .color(color.opacity(0.55)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    let radius = min(size.width, size.height) * 0.009
                    context.stroke(Path(ellipseIn: CGRect(x: origin.x-radius, y: origin.y-radius, width: radius*2, height: radius*2)), with: .color(color), lineWidth: 2)
                    context.stroke(Path(ellipseIn: CGRect(x: end.x-radius, y: end.y-radius, width: radius*2, height: radius*2)), with: .color(.yellow), lineWidth: 2)
                    if progress < 1 {
                        let sphere = Path(ellipseIn: CGRect(x: point.x-radius, y: point.y-radius, width: radius*2, height: radius*2))
                        context.fill(sphere, with: .radialGradient(Gradient(colors: [.white, color, .black]), center: CGPoint(x: point.x-radius/3, y: point.y-radius/3), startRadius: 0, endRadius: radius*1.6))
                    }
                }
            }.allowsHitTesting(false)
        }
        .overlay {
            if let gameMarbles {
                ForEach(selectableMarbles, id: \.self) { index in
                    if gameMarbles.indices.contains(index), let point = screenPoint(gameMarbles[index], size: geo.size) {
                        Circle().strokeBorder(selectedMarble == index ? .yellow : .white.opacity(0.8), lineWidth: 2)
                            .frame(width: 24, height: 24).contentShape(Circle())
                            .position(point).onTapGesture { onMarble?(index) }
                    }
                }
                ForEach(destinations, id: \.self) { step in
                    if gameMarbles.indices.contains(step.marble) {
                        let marble = gameMarbles[step.marble]
                        let point = destinationPoint(marble, destination: step.destination, size: geo.size)
                        if let point {
                            Circle().fill(.yellow.opacity(0.35)).overlay(Circle().stroke(.yellow, lineWidth: 2))
                                .frame(width: 26, height: 26).position(point)
                                .onTapGesture { onDestination?(step) }
                        }
                    }
                }
            }
        }
        .accessibilityLabel("\(playerCount)-player modular board")
        .task(id: lastMove?.revision) {
            guard let revision = lastMove?.revision, animatedRevision != revision else { return }
            animatedRevision = revision
            guard !reduceMotion else { progress = 1; return }
            progress = 0
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            let frames = max(30, (lastMove?.routes.reduce(0) { $0 + max(1, $1.count - 1) } ?? 1) * 12)
            for frame in 1...frames {
                progress = CGFloat(frame) / CGFloat(frames)
                try? await Task.sleep(for: .milliseconds(30))
                guard !Task.isCancelled else { return }
            }
        }
        }
    }

    private func destinationPoint(_ marble: GameMarble, destination: MarblePosition, size: CGSize) -> CGPoint? {
        var copy = marble; copy.position = destination
        return screenPoint(copy, size: size)
    }

    private func screenPoint(_ marble: GameMarble, size: CGSize) -> CGPoint? {
        guard (3...6).contains(playerCount) else { return nil }
        let seat: Int, point: CGPoint
        switch marble.position {
        case .start: seat = marble.seat; guard Self.start.indices.contains(marble.number) else { return nil }; point = Self.start[marble.number]
        case .home(let i): seat = marble.seat; guard Self.home.indices.contains(i) else { return nil }; point = Self.home[i]
        case .track(let i): guard i >= 0 else { return nil }; seat = i / Self.track.count; point = Self.track[i % Self.track.count]
        }
        let n = Double(playerCount)
        let extent = 970 / (2 * sin(.pi / n)) + 160
        let scale = min(size.width, size.height) / CGFloat(2 * extent)
        let angle = .pi + Double(seat) * 2 * .pi / n
        let x = point.x - 634, y = point.y - CGFloat(485 / tan(.pi / n) + 128)
        let c = CGFloat(cos(angle)), s = CGFloat(sin(angle))
        let rotatedX = x * c - y * s
        let rotatedY = x * s + y * c
        let screenX = size.width / 2 + scale * rotatedX
        let screenY = size.height / 2 + scale * rotatedY
        return CGPoint(x: screenX, y: screenY)
    }

    private static func drawMarble(_ point: CGPoint, color: Color, context: GraphicsContext) {
        let sphere = hole(point)
        let center = CGPoint(x: point.x - 7, y: point.y - 8)
        let shadow = Path(ellipseIn: CGRect(x: point.x - 18, y: point.y + 7, width: 36, height: 14))
        context.fill(shadow, with: .color(.black.opacity(0.65)))
        context.fill(sphere, with: .radialGradient(Gradient(stops: [
            .init(color: .white, location: 0),
            .init(color: color, location: 0.24),
            .init(color: color, location: 0.57),
            .init(color: .black, location: 1)
        ]), center: center, startRadius: 0, endRadius: 30))
        let reflection = Path(ellipseIn: CGRect(x: point.x - 11, y: point.y - 12, width: 10, height: 6))
        context.fill(reflection, with: .color(.white.opacity(0.9)))
        let rim = Path(ellipseIn: CGRect(x: point.x + 4, y: point.y + 8, width: 8, height: 4))
        context.fill(rim, with: .color(color.opacity(0.9)))
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
