# Modular Board Piece v1 — original-reference revision approved 2026-11-26

The canonical approved visual baseline is [modular-board-v1.svg](modular-board-v1.svg), the vector approximation of the top piece in the user's original Etsy reference photograph. It supersedes the earlier simplified silhouette.

- Every piece must be an identical copy: same silhouette, dimensions, thickness and hole coordinates. Only rigid rotation, translation and player color may differ. Uniform scaling of the entire board is allowed.
- 17 track holes, five L-shaped home holes, five cross-shaped starting holes (27 total).
- Every hole must be fully contained in its own piece, with positive edge clearance and no overlap.
- Natural maple wood, recessed holes and glossy glass marbles.
- Default six players, three opposite-seat partnerships. Target 3–12 players, six-player MVP first.
- Rotate the assembled board to face the active player.
- Six-player topology target: 102 track spaces, 30 start and 30 home positions; 108 playing cards unchanged.

The approved SVG is a visual approximation, not mechanically validated joinery. Before implementing, verify full hole containment, connector fit and track continuity at each supported angle. The old assembly transform is superseded; derive the new transform from connector geometry. GameCore currently needs topology reconciliation. Any change to the approved master silhouette or hole coordinates requires explicit approval and a new revision. No per-seat reshaping.

Related: #2, #4, #9, #11.
