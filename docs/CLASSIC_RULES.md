# Classic v1

Six seats, three opposite-seat partnerships (0/3, 1/4, 2/5), five marbles each, 108 cards (two standard decks and four jokers), five-card hands. Clockwise turns: draw, play, move. A team wins with all ten marbles home.

A enters or moves 1; 2–6 and 9–10 move face value; 7 moves forward seven or splits seven between distinct marbles; 8 moves backward eight; J/Q/K enter or move ten. Joker replaces another player's track marble with a marble from start or track. Own marbles block passage. Other colors can be passed. Opponents captured return to start; partners captured move to their first home space if vacant. Home is forward-only, exact movement, no passing own marbles. Once finished, help your partner. Discard only if no legal play exists.

Implementation conventions: 17 track spaces per seat, home branch at the seat entry, five indexed home spaces. The active seat draws before choosing a card. Discards are shuffled when the draw pile empties. These conventions and joker priority need further edge-case verification against the intended traditional variant. The engine is host-only; network privacy projections and UI integration are separate work.
