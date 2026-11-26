# Modular Board Piece v1 — original-reference revision approved 2026-11-26

The canonical approved visual baseline is [modular-board-v1.svg](modular-board-v1.svg), the vector approximation of the top piece in the user's original Etsy reference photograph. It supersedes the earlier simplified silhouette.

- Every piece must be an identical copy: same silhouette, dimensions, thickness and hole coordinates. Only rigid rotation, translation and player color may differ. Uniform scaling of the entire board is allowed.
- 17 track holes, five L-shaped home holes, five cross-shaped starting holes (27 total).
- Every hole must be fully contained in its own piece, with positive edge clearance and no overlap.
- Natural maple wood, recessed holes and glossy glass marbles.
- Default six players, three opposite-seat partnerships. MVP supports 3–6 players inclusive; 7–12 are post-MVP.
- Rotate the assembled board to face the active player.
- Six-player topology target: 102 track spaces, 30 start and 30 home positions; 108 playing cards unchanged.

The approved SVG is a visual approximation, not mechanically validated joinery. Before implementing, verify full hole containment, connector fit and track continuity at each supported angle. The old assembly transform is superseded; derive the new transform from connector geometry. GameCore currently needs topology reconciliation. Any change to the approved master silhouette or hole coordinates requires explicit approval and a new revision. No per-seat reshaping.

Related: #2, #4, #9, #11.

## Approved assembly layouts — 2026-11-26
All ten regular polygon visual previews (3 through 12 players) are approved. Each uses the unchanged canonical SVG, with preview transform rotate(i * 360/N) translate(-634, -485/tan(pi/N)-128) in original SVG units. Uniform whole-board scaling is allowed. This is the approved visual assembly baseline, not proof of connector fit. Track count = 17*N; total holes = 27*N; marbles = 5*N. Six players remains the default and MVP maximum. Validate connector alignment, overlaps, hole clearance and track continuity before runtime implementation; any master geometry changes require explicit approval.

## MVP scope clarification
MVP gameplay, board rendering and tests cover 3, 4, 5 and 6 players. Seven through twelve are approved visual designs only and deferred. Six-player default retains three opposite-seat partnerships. Approved competition modes: 3 and 5 players individual; 4 players individual or two teams of two; 6 players individual or three teams of two. Default is six players with three opposite-seat partnerships. Deck requirements for non-default player counts remain to be confirmed.

MVP scope approved and locked. Do not expand beyond six players without explicit approval.
