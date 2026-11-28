import SwiftUI
import UIKit
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
    var presentingMove = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 1
    @State private var animatedRevision: Int?
    private var moveProgress: CGFloat {
        animatedRevision == lastMove?.revision ? progress : 1
    }
    private func color(for seat: Int) -> Color {
        let index = seatColors.flatMap { $0.indices.contains(seat) ? $0[seat] : nil } ?? seat
        return colors[colors.indices.contains(index) ? index : 0]
    }
    private let colors: [Color] = [Color(red: 0.83, green: 0.035, blue: 0.06), Color(red: 0.025, green: 0.32, blue: 0.95), Color(red: 0.025, green: 0.67, blue: 0.20), Color(red: 0.98, green: 0.76, blue: 0.015), Color(red: 0.58, green: 0.08, blue: 0.85), Color(red: 1, green: 0.36, blue: 0.025)]

    private static let mapleTexture: UIImage? = Bundle.main.url(forResource: "maple", withExtension: "jpg").flatMap { UIImage(contentsOfFile: $0.path) }

    var body: some View {
        GeometryReader { geo in
        let bumped = lastMove?.bumpedMarbles(after: gameMarbles ?? []) ?? []
        ZStack {
        if ApprovedMeshBoard.available {
            ApprovedMeshBoard(playerCount: playerCount, seatColors: seatColors ?? Array(0..<playerCount), marbles: meshMarbles(size: geo.size, bumped: bumped))
        }
        Canvas { context, size in
            guard (3...6).contains(playerCount) else { return }
            let n = Double(playerCount)
            let extent = 970 / (2 * sin(.pi / n)) + 160
            let scale = min(size.width, size.height) / CGFloat(2 * extent)
            for layer in 0..<2 {
            for seat in 0..<playerCount {
                var ctx = context
                ctx.translateBy(x: size.width / 2, y: size.height / 2)
                ctx.scaleBy(x: scale, y: scale)
                ctx.rotate(by: .degrees(180 + Double(seat) * 360 / n))
                ctx.translateBy(x: -634, y: CGFloat(-485 / tan(.pi / n) - 128))
                let outline = Self.outline
                if layer == 0 {
                if ApprovedMeshBoard.available { continue }
                if playerCount < 6 {
                    // Keep each piece inside its own angular sector; no adjacent piece can cover its holes.
                    let centerY = CGFloat(485 / tan(.pi / n) + 128)
                    let slope = CGFloat(tan(.pi / n))
                    var sector = Path()
                    sector.move(to: CGPoint(x: 634, y: centerY))
                    sector.addLine(to: CGPoint(x: 634 - (centerY + 1000) * slope, y: -1000))
                    sector.addLine(to: CGPoint(x: 634 + (centerY + 1000) * slope, y: -1000))
                    sector.closeSubpath()
                    ctx.clip(to: sector)
                }
                var edge = ctx
                edge.translateBy(x: 0, y: 12)
                edge.fill(outline, with: .color(Color(red: 0.43, green: 0.24, blue: 0.11)))
                ctx.fill(outline, with: .linearGradient(Gradient(colors: [Color(red: 0.99, green: 0.87, blue: 0.66), Color(red: 0.91, green: 0.73, blue: 0.48), Color(red: 0.97, green: 0.82, blue: 0.59)]), startPoint: CGPoint(x: 0, y: 60), endPoint: CGPoint(x: 0, y: 292)))
                if let texture = Self.mapleTexture {
                    var wood = ctx
                    wood.clip(to: outline)
                    wood.draw(Image(uiImage: texture), in: CGRect(x: 160, y: 60, width: 1030, height: 232))
                } else {
                var grain = ctx
                grain.clip(to: outline)
                for i in 0..<100 {
                    let y = CGFloat(i) * 2.5 + 60
                    var line = Path()
                    line.move(to: CGPoint(x: 160, y: y))
                    for j in 1...24 {
                        let x = CGFloat(j) * 44 + 160
                        let wave = CGFloat(sin(Double(j) * 0.29 + Double(i) * 0.17)) * 2
                        line.addLine(to: CGPoint(x: x, y: y + wave))
                    }
                    grain.stroke(line, with: .color(Color(red: 0.47, green: 0.29, blue: 0.13).opacity(Double(i % 5 + 1) * 0.012)), lineWidth: 1)
                }
                }
                ctx.stroke(outline, with: .color(Color(red: 0.65, green: 0.42, blue: 0.22)), lineWidth: 2)
                ctx.stroke(outline, with: .color(.white.opacity(0.22)), lineWidth: 0.7)
                continue
                }
                if !ApprovedMeshBoard.available {
                for point in Self.track {
                    ctx.fill(Self.hole(point), with: .radialGradient(Gradient(colors: [.brown, .black.opacity(0.8)]), center: point, startRadius: 0, endRadius: 18))
                    ctx.stroke(Self.hole(point), with: .color(.white.opacity(0.35)), lineWidth: 2)
                }
                for point in Self.home + Self.start {
                    ctx.fill(Self.hole(point), with: .radialGradient(Gradient(colors: [color(for: seat).opacity(0.85), .black.opacity(0.85)]), center: CGPoint(x: point.x, y: point.y + 5), startRadius: 0, endRadius: 22))
                    ctx.stroke(Self.hole(point), with: .color(.black.opacity(0.45)), lineWidth: 2)
                }
                }
                if let gameMarbles {
                    for (index, marble) in gameMarbles.enumerated() {
                        if moveProgress < 1,
                           bumped.contains(index) || lastMove?.steps.contains(where: { $0.marble == index }) == true { continue }
                        let point: CGPoint
                        switch marble.position {
                        case .start:
                            guard marble.seat == seat, Self.start.indices.contains(marble.number) else { continue }
                            point = Self.start[marble.number]
                        case .home(let index):
                            guard marble.seat == seat, Self.home.indices.contains(index) else { continue }
                            point = Self.home[index]
                        case .track(let index):
                            guard index >= 0 else { continue }
                            let mapped = Self.trackPoint(index)
                            guard mapped.seat % playerCount == seat else { continue }
                            point = mapped.point
                        }
                        if !ApprovedMeshBoard.available { Self.drawMarble(point, color: color(for: marble.seat), context: ctx) }
                    }
                } else {
                    for point in Array(Self.start.prefix(3)) + [Self.track[5], Self.home[0]] {
                        Self.drawMarble(point, color: color(for: seat), context: ctx)
                    }
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
                    let local = progress(for: stepIndex, move: move)
                    let distance = local * CGFloat(path.count - 1)
                    let segment = min(path.count - 2, Int(distance))
                    let point = interpolate(path[segment], path[segment + 1], fraction: distance - CGFloat(segment))
                    var trail = Path(); trail.move(to: origin)
                    for p in path.prefix(segment + 1) { trail.addLine(to: p) }
                    trail.addLine(to: point)
                    context.stroke(trail, with: .color(color.opacity(0.55)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    let radius = min(size.width, size.height) * 0.009
                    context.stroke(Path(ellipseIn: CGRect(x: origin.x-radius, y: origin.y-radius, width: radius*2, height: radius*2)), with: .color(color), lineWidth: 2)
                    context.stroke(Path(ellipseIn: CGRect(x: end.x-radius, y: end.y-radius, width: radius*2, height: radius*2)), with: .color(.yellow), lineWidth: 2)
                    if moveProgress < 1 && !ApprovedMeshBoard.available {
                        let sphere = Path(ellipseIn: CGRect(x: point.x-radius, y: point.y-radius, width: radius*2, height: radius*2))
                        context.fill(sphere, with: .radialGradient(Gradient(colors: [.white, color, .black]), center: CGPoint(x: point.x-radius/3, y: point.y-radius/3), startRadius: 0, endRadius: radius*1.6))
                    }
                }
                for index in bumped {
                    let marble = gameMarbles[index]
                    guard let origin = screenPoint(move.before[index], size: size),
                          let end = screenPoint(marble, size: size) else { continue }
                    let radius = min(size.width, size.height) * 0.018
                    if moveProgress < 1 && !ApprovedMeshBoard.available {
                        let point = bumpPoint(index, move: move, origin: origin, end: end)
                        let sphere = Path(ellipseIn: CGRect(x: point.x-radius/2, y: point.y-radius/2, width: radius, height: radius))
                        context.fill(sphere, with: .radialGradient(Gradient(colors: [.white, color(for: marble.seat), .black]),
                                                                   center: point, startRadius: 0, endRadius: radius))
                    }
                    let ring = Path(ellipseIn: CGRect(x: end.x-radius, y: end.y-radius, width: radius*2, height: radius*2))
                    context.stroke(ring, with: .color(.white), style: StrokeStyle(lineWidth: 3, dash: [4, 3]))
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
        }
        .accessibilityLabel("\(playerCount)-player modular board")
        .task(id: lastMove?.revision) {
            guard let move = lastMove, animatedRevision != move.revision, presentingMove,
                  !reduceMotion, !move.steps.isEmpty else { return }
            animatedRevision = move.revision
            progress = 0
            let clock = ContinuousClock()
            let start = clock.now
            while !Task.isCancelled {
                let elapsed = start.duration(to: clock.now).components
                let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
                progress = min(1, CGFloat(seconds / move.animationDuration))
                if progress == 1 { return }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
        }
    }

    private func progress(for stepIndex: Int, move: PublicMove) -> CGFloat {
        let lengths = move.steps.indices.map { move.routes.indices.contains($0) ? max(1, move.routes[$0].count - 1) : 1 }
        let total = max(1, lengths.reduce(0, +))
        let prior = lengths.prefix(stepIndex).reduce(0, +)
        return min(1, max(0, (moveProgress * CGFloat(total) - CGFloat(prior)) / CGFloat(lengths[stepIndex])))
    }

    private func interpolate(_ a: CGPoint, _ b: CGPoint, fraction: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction)
    }

    private func bumpPoint(_ index: Int, move: PublicMove, origin: CGPoint, end: CGPoint) -> CGPoint {
        guard let stepIndex = move.steps.firstIndex(where: { $0.destination == move.before[index].position }) else { return end }
        let local = progress(for: stepIndex, move: move)
        return interpolate(origin, end, fraction: max(0, (local - 0.8) / 0.2))
    }

    private func meshMarbles(size: CGSize, bumped: [Int]) -> [MeshMarble] {
        guard let gameMarbles else { return [] }
        return gameMarbles.enumerated().compactMap { index, marble in
            guard var point = screenPoint(marble, size: size) else { return nil }
            if moveProgress < 1, let move = lastMove,
               let stepIndex = move.steps.firstIndex(where: { $0.marble == index }),
               move.before.indices.contains(index),
               let origin = screenPoint(move.before[index], size: size) {
                let route = move.routes.indices.contains(stepIndex) ? move.routes[stepIndex] : []
                let points = route.compactMap { destinationPoint(move.before[index], destination: $0, size: size) }
                let path = points.count >= 2 ? points : [origin, point]
                let distance = progress(for: stepIndex, move: move) * CGFloat(path.count - 1)
                let segment = min(path.count - 2, Int(distance))
                point = interpolate(path[segment], path[segment + 1], fraction: distance - CGFloat(segment))
            } else if moveProgress < 1, let move = lastMove, bumped.contains(index),
                      let origin = screenPoint(move.before[index], size: size) {
                point = bumpPoint(index, move: move, origin: origin, end: point)
            }
            let colorIndex = seatColors.flatMap { $0.indices.contains(marble.seat) ? $0[marble.seat] : nil } ?? marble.seat
            return MeshMarble(point: point, color: colorIndex)
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
        case .track(let i): guard i >= 0 else { return nil }; let mapped = Self.trackPoint(i); seat = mapped.seat % playerCount; point = mapped.point
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
        ]), center: center, startRadius: 0, endRadius: 28))
        let reflection = Path(ellipseIn: CGRect(x: point.x - 11, y: point.y - 12, width: 10, height: 6))
        context.fill(reflection, with: .color(.white.opacity(0.9)))
        let rim = Path(ellipseIn: CGRect(x: point.x + 4, y: point.y + 8, width: 8, height: 4))
        context.fill(rim, with: .color(color.opacity(0.9)))
    }

    static let track = (0..<16).map { CGPoint(x: 237 + Double($0) * 55.2, y: 95) } + [CGPoint(x: 1119, y: 128)]
    // Logical index zero is the track hole directly below the starting cross.
    private static func trackPoint(_ index: Int) -> (seat: Int, point: CGPoint) {
        let shifted = index + 7
        return (shifted / 17, track[shifted % 17])
    }
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
