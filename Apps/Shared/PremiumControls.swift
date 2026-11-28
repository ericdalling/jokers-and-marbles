import SwiftUI

struct PremiumLogo: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("Jokers & Marbles").font(.system(size: 34, weight: .bold, design: .serif)).italic()
                .minimumScaleFactor(0.5).lineLimit(1)
                .foregroundStyle(LinearGradient(colors: [.white, Color(red: 1, green: 0.83, blue: 0.42), .orange], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black, radius: 2, x: 1, y: 3)
            Text("━━━━  ♣ ♦ ♠ ♥  ━━━━").font(.title3)
        }.foregroundStyle(Color(red: 1, green: 0.86, blue: 0.61))
    }
}
struct PremiumPanel: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(16)
            .background(Color(red: 0.10, green: 0.055, blue: 0.025).opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(red: 0.73, green: 0.49, blue: 0.24), lineWidth: 1.3))
    }
}
struct JewelButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    var color: Color = .purple
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.headline, design: .serif)).foregroundStyle(.white)
            .padding(.vertical, 14).frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [color, color.opacity(0.65), .black], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color(red: 1, green: 0.76, blue: 0.39), lineWidth: 2))
            .shadow(color: .orange.opacity(enabled ? 0.45 : 0), radius: 8)
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
struct JewelMarble: View {
    let color: Color
    var body: some View {
        Circle().fill(RadialGradient(colors: [.white, color, color, .black], center: .init(x: 0.29, y: 0.23), startRadius: 0, endRadius: 38))
            .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.8), radius: 3, y: 3)
    }
}
