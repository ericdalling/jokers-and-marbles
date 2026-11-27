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
            RoundedRectangle(cornerRadius: 6).strokeBorder(.brown.opacity(0.45), lineWidth: 1).padding(3)
            Text(suit).font(.system(size: 30, weight: .regular, design: .serif))
            VStack {
                HStack { Text(rank); Spacer() }
                Spacer()
                HStack { Spacer(); Text(rank).rotationEffect(.degrees(180)) }
            }.font(.system(.caption, design: .serif).bold()).padding(7)
        }.foregroundStyle(ink).accessibilityLabel(description)
    }
}
