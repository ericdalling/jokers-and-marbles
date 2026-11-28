# Classic v1

Six seats, three opposite-seat partnerships (0/3, 1/4, 2/5), five marbles each, 108 cards (two standard decks and four jokers), five-card hands. Clockwise turns: draw, play, move. A team wins with all ten marbles home.

A enters or moves 1; 2–6 and 9–10 move face value; 7 moves forward seven or splits seven between distinct marbles; 8 moves backward eight; J/Q/K enter or move ten. Joker replaces another player's track marble with a marble from start or track. Any marble may be passed on the track. Landing on your own marble is illegal. Opponents captured return to start; partners captured move to their first home space if vacant. Home is forward-only, exact movement, no passing own marbles. Once finished, help your partner. Discard only if no legal play exists.

Implementation conventions: 17 track spaces per seat, home branches from the track hole five spaces before the starting cross. Count that track hole before the first of five home holes. The active seat draws before choosing a card. Discards are shuffled when the draw pile empties. These conventions need further edge-case verification against the intended traditional variant. The engine is host-only; network privacy projections and UI integration are separate work.

## Modular MVP configurations

Three to six seats, default six. Each seat contributes 17 track holes, five start holes and five home holes. The deck remains 108 cards. Three and five seats play individually; four and six default to opposite-seat pairs, with individual play available. Individual victory requires all five own marbles home; paired victory requires all ten team marbles home.
