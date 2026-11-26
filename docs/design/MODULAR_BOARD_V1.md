# Modular Board Piece v1 — approved 2026-11-26

The canonical visual baseline is [modular-board-v1.svg](modular-board-v1.svg), preserving the exact vector path and hole coordinates from the approved 6/8/10/12/16/20-player geometry study.

## Non-negotiable
- One master piece, identical dimensions, silhouette, thickness and hole coordinates for every seat and player count.
- No stretching, warping, mirroring or per-seat redesign. Only rigid rotation, translation and player color may differ; uniform scaling of the entire board to fit a screen is allowed.
- 18 track holes, five L-shaped home holes and five cross-shaped start holes per piece.
- Natural maple wood, recessed holes, glossy colored marbles.
- Assemble N copies into a regular N-sided polygon. Study transform: rotate(i * 360/N) then translate(0, -48/tan(pi/N)).
- Default six players, three opposite-seat partnerships. Target architecture 3–12 players; six-player MVP first. Other player counts require rules and deck validation.
- Rotate the assembled board to the active player's perspective; never change its topology.

## Validation before implementation
The approved study is a visual baseline, not mechanically validated joinery. Verify connector fit, hole containment and continuity at all supported angles. Any necessary change to the master path or hole coordinates requires explicit approval and a new design version; do not silently alter individual pieces. Verify the track/start/home mapping against GameCore. The SVG is a reference, not yet a native renderer.

Related: #2, #4, #9, #11.
