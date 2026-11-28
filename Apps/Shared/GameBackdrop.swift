import SwiftUI
import UIKit

struct GameBackdrop: View {
    var body: some View {
        Group {
        if let url = Bundle.main.url(forResource: "walnut", withExtension: "jpg"), let image = UIImage(contentsOfFile: url.path) {
            GeometryReader { geo in
                Image(uiImage: image.resizableImage(withCapInsets: .zero, resizingMode: .tile))
                    .resizable(resizingMode: .tile)
                    .frame(width: geo.size.width, height: geo.size.height).clipped()
            }
        } else {
        Canvas { context, size in
            let bounds = Path(CGRect(origin: .zero, size: size))
            context.fill(bounds, with: .color(Color(red: 0.055, green: 0.045, blue: 0.038)))
            for i in 0..<320 {
                let y = CGFloat(i) * size.height / 320
                var grain = Path()
                grain.move(to: CGPoint(x: 0, y: y))
                for j in 1...16 {
                    let x = CGFloat(j) * size.width / 16
                    let wave = sin(Double(j) * 0.4 + Double(i) * 0.23) * 3 + sin(Double(j) * 0.17 + Double(i) * 0.07) * 6
                    grain.addLine(to: CGPoint(x: x, y: y + CGFloat(wave)))
                }
                context.stroke(grain, with: .color(Color(red: 0.48, green: 0.37, blue: 0.25).opacity(Double(i % 7 + 1) * 0.012)), lineWidth: 1)
            }
        }
        }
        }.overlay(Color.black.opacity(0.16)).overlay {
            RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center, startRadius: 40, endRadius: 900)
        }.ignoresSafeArea().allowsHitTesting(false)
    }
}
