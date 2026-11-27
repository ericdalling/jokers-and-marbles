import SwiftUI
import GameCore

struct PremiumCardView: View {
    let card: PlayingCard
    private var description: String { String(describing: card) }
    private var suit: String {
        let value = description.lowercased()
        if value.contains("heart") { return "♥" }
        if value.contains("diamond") { return "♦" }
        if value.contains("club") { return "♣" }
        if value.contains("spade") { return "♠" }
        return "★"
    }
    private var rank: String {
        let value = description.lowercased()
        for (word, symbol) in [("joker","JOKER"),("ace","A"),("king","K"),("queen","Q"),("jack","J"),("ten","10"),("nine","9"),("eight","8"),("seven","7"),("six","6"),("five","5"),("four","4"),("three","3"),("two","2")] {
            if value.contains(word) { return symbol }
        }
        return description
    }
    private var ink: Color { suit == "♥" || suit == "♦" ? Color(red: 0.65, green: 0.05, blue: 0.09) : .black }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [.white, Color(red: 0.94, green: 0.87, blue: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 6).strokeBorder(Color(red: 0.48, green: 0.32, blue: 0.17).opacity(0.65), lineWidth: 1).padding(3)
            RoundedRectangle(cornerRadius: 4).strokeBorder(.brown.opacity(0.25), lineWidth: 0.5).padding(6)
            Text(suit).font(.system(size: 30, weight: .regular, design: .serif))
            VStack {
                HStack { Text(rank); Spacer() }
                Spacer()
                HStack { Spacer(); Text(rank).rotationEffect(.degrees(180)) }
            }.font(.system(.caption, design: .serif).bold()).padding(7)
        }.foregroundStyle(ink).shadow(color: .black.opacity(0.45), radius: 3, x: 1, y: 3).accessibilityLabel(description)
    }
}

struct PremiumCardBack: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.04, green: 0.12, blue: 0.28))
                Canvas { context, size in
                    let step = max(4, size.width / 7)
                    for row in 0..<12 {
                        for col in 0..<8 {
                            let x = CGFloat(col) * step
                            let y = CGFloat(row) * step
                            var diamond = Path()
                            diamond.move(to: CGPoint(x: x, y: y-step/2))
                            diamond.addLine(to: CGPoint(x: x+step/2, y: y))
                            diamond.addLine(to: CGPoint(x: x, y: y+step/2))
                            diamond.addLine(to: CGPoint(x: x-step/2, y: y))
                            diamond.closeSubpath()
                            context.stroke(diamond, with: .color(.white.opacity(0.22)), lineWidth: 0.6)
                        }
                    }
                }.padding(5).clipped()
                RoundedRectangle(cornerRadius: 5).strokeBorder(Color(red: 0.87, green: 0.75, blue: 0.49), lineWidth: 1.5).padding(3)
                Image(systemName: "suit.spade.fill").font(.system(size: geo.size.width * 0.35)).foregroundStyle(Color(red: 0.94, green: 0.85, blue: 0.65))
            }
        }.shadow(color: .black.opacity(0.5), radius: 3, y: 3).accessibilityLabel("Face-down card")
    }
}
