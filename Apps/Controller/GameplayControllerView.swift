import SwiftUI
import GameCore

struct GameplayControllerView: View {
    let state: PublicSession
    let personal: PrivateSession
    let player: UUID
    let submit: (GamePlay) -> Void
    @State private var selectedCard: Int?
    @State private var selectedMarble: Int?
    @State private var selectedMove: GamePlay?
    @State private var zoom: CGFloat = 1
    @State private var submitted = false
    @State private var replacementGlow = false
    @State private var showRules = false
    private var active: Bool { personal.seat == state.activeSeat && state.winner == nil && !state.presentingMove }
    private var member: LobbyMember? { state.members.first { $0.id == player } }
    private var options: [GamePlay] { personal.legalPlays.filter { $0.cardIndex == selectedCard } }
    private var filtered: [GamePlay] { options.filter { selectedMarble == nil || $0.steps.first?.marble == selectedMarble } }
    private var turnName: String {
        guard let seat = state.activeSeat, state.seats.indices.contains(seat) else { return "Player" }
        return state.members.first { $0.id == state.seats[seat] }?.name ?? "Player"
    }
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 16) {
                    HStack { Text(member?.name ?? "Player").font(.system(.title, design: .serif).bold()); Spacer(); Button("Rules") { showRules = true } }
                    Text(state.winner != nil ? "Game complete" : state.presentingMove ? "Resolving move…" : active ? "Your turn" : "Waiting for " + turnName)
                        .font(.headline).padding(10).background(.orange.opacity(active ? 0.35 : 0.12), in: Capsule())
                    if let partner = state.members.first(where: { $0.id == member?.partner }) {
                        Text("Teammate: " + partner.name).font(.caption)
                    }
                    if geo.size.width > 750 && geo.size.width > geo.size.height {
                        HStack(alignment: .top, spacing: 20) { board.frame(width: geo.size.width * 0.56); controls }
                    } else { board; controls }
                }.padding(16)
            }
        }
        .foregroundStyle(Color(red: 0.98, green: 0.88, blue: 0.72))
        .background(GameBackdrop())
        .sheet(isPresented: $showRules) {
            NavigationStack {
                List {
                    Section("Cards") {
                        if state.ruleset == .voorhees {
                            Text("Ace: enter START, forward 1 or 11, or backward 1")
                            Text("2–6: forward by rank")
                            Text("7: forward seven, optionally split")
                            Text("8: backward eight")
                            Text("9: forward nine or split nine in opposite directions")
                            Text("10: split ten between two distinct marbles, in either direction. Opponents may only move on the main track.")
                            Text("Jack, Queen, King: enter or move forward 11, 12, 13 respectively")
                            Text("Joker: replace another player's marble; opponents return to START, teammates go to their IN SPOT.")
                        } else {
                        Text("Ace: enter or move 1")
                        Text("2–6, 9–10: move forward by rank")
                        Text("7: move seven spaces, optionally split between two marbles")
                        Text("8: move backward eight spaces")
                        Text("Jack, Queen, King: enter or move ten")
                        Text("Joker: replace an eligible opposing or teammate marble when no ordinary move is available")
                        }
                    }
                    Section("Turns") {
                        Text("Play one card, resolve the move, then automatically draw a replacement. If no move is legal, discard a card.")
                        Text("Get all five marbles home. In team games, help your partner finish after your own marbles are home.")
                    }
                }.navigationTitle(state.ruleset.title).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showRules = false } } }
            }
        }
        .onChange(of: state.revision) { _, _ in selectedCard = nil; selectedMarble = nil; selectedMove = nil; submitted = false }
        .task(id: state.revision) {
            guard !state.presentingMove, let move = state.lastMove, move.seat == personal.seat, state.winner == nil else { return }
            replacementGlow = true
            try? await Task.sleep(for: .seconds(1))
            replacementGlow = false
        }
    }
    private var board: some View {
        ModularBoardView(playerCount: state.capacity, activePlayer: state.activeSeat ?? 0, gameMarbles: state.marbles,
                         seatColors: state.seats.map { id in state.members.first { $0.id == id }?.color ?? 0 },
                         selectableMarbles: active && !submitted ? Array(Set(options.compactMap { $0.steps.first?.marble })) : [],
                         selectedMarble: selectedMarble,
                         onMarble: { selectedMarble = $0; selectedMove = nil },
                         destinations: selectedMarble == nil || submitted ? [] : Array(Set(filtered.compactMap { $0.steps.first })),
                         onDestination: { step in
                             let matches = filtered.filter { $0.steps.first == step }
                             if matches.count == 1 { selectedMove = matches.first }
                         }, lastMove: state.lastMove)
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(zoom).clipped()
            .gesture(MagnifyGesture().onChanged { zoom = min(2.5, max(1, $0.magnification)) })
            .onTapGesture(count: 2) { zoom = 1 }
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your private hand").font(.headline)
            HStack(spacing: 5) {
                ForEach(Array(personal.hand.enumerated()), id: \.offset) { index, card in
                    Button {
                        selectedCard = index; selectedMarble = nil; selectedMove = nil
                    } label: {
                        PremiumCardView(card: card).frame(maxWidth: .infinity).frame(height: 82)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selectedCard == index || (replacementGlow && index == personal.hand.count - 1) ? .orange : .brown, lineWidth: selectedCard == index || (replacementGlow && index == personal.hand.count - 1) ? 4 : 1))
                    }.buttonStyle(.plain).disabled(!active || submitted || !personal.legalPlays.contains { $0.cardIndex == index })
                }
            }
            if active && !submitted {
                if selectedCard == nil { Text("Choose a playable card") }
                else {
                    let marbles = Array(Set(options.compactMap { $0.steps.first?.marble })).sorted()
                    if !marbles.isEmpty {
                        Text("Choose a marble").font(.headline)
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(marbles, id: \.self) { index in
                                    Button(marbleName(index)) { selectedMarble = index; selectedMove = nil }
                                        .buttonStyle(.borderedProminent).tint(selectedMarble == index ? .orange : .brown)
                                }
                            }
                        }
                    }
                    if selectedMarble != nil || marbles.isEmpty {
                        Text("Choose destination").font(.headline)
                        ForEach(filtered, id: \.self) { move in
                            Button(description(move)) { selectedMove = move }
                                .buttonStyle(.bordered).tint(selectedMove == move ? .orange : .white)
                        }
                    }
                    Button("Confirm move") {
                        if let selectedMove { submitted = true; submit(selectedMove) }
                    }.buttonStyle(.borderedProminent).tint(.orange).disabled(selectedMove == nil)
                }
            } else { Text(submitted ? "Submitting move…" : "Your cards remain private.") }
        }.padding(12).background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
    }
    private func marbleName(_ index: Int) -> String {
        guard state.marbles.indices.contains(index) else { return "Marble" }
        let m = state.marbles[index]
        let owner = state.seats.indices.contains(m.seat) ? state.members.first { $0.id == state.seats[m.seat] }?.name : nil
        return (owner ?? "Player") + " • Marble \(m.number + 1)"
    }
    private func description(_ move: GamePlay) -> String {
        if move.steps.isEmpty { return "Discard — no legal move" }
        return move.steps.map { step in
            let destination: String
            switch step.destination {
            case .start: destination = "Start"
            case .track(let i): destination = "Track \(i + 1)"
            case .home(let i): destination = "Home \(i + 1)"
            }
            return marbleName(step.marble) + " → " + destination
        }.joined(separator: " + ")
    }
}
