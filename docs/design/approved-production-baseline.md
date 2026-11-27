# Approved production baseline — 2026-11-26

This specification records the approved design decisions. It does not certify that implementation or binary assets are complete.

## Visual foundation
- Preserve the approved modular board geometry; use docs/design/modular-board-v1.svg as geometry reference and reconcile against the approved V3 GLB before shipping. Six identical maple pieces for six players, each with 17 track, five cross-shaped start and five L-shaped destination holes. Five marbles per player. Support 3–6 player assemblies. Validate joints, hole alignment and track continuity.
- Uniform light maple, rich fine-grained walnut tabletop, realistic recessed holes, bevels and contact shadows. No two-tone pieces or generated substitute geometry.
- Final premium marble refinement: saturated red, blue, green, yellow, purple, orange; glossy glass, directional reflections, spherical depth and clear contrast against empty colored holes. Preserve dimensions. Verify on actual devices.
- V4 Apple TV visual identity: compact floating espresso panels, bronze trim, ivory serif branding, illuminated color badges with silhouettes, realistic blue-backed cards, decorative center logo. Rebuild low-resolution extracted assets at native resolution. Stationary board, no rotation between turns.

## Host and controller
- Apple TV defaults to Host Mode; iPad defaults to Controller Mode with Switch to Host Mode; iPhone controller only. Shared host engine and shared public display components. One authoritative host per session. Confirm before switching during active session.
- Host lobby: dynamic QR and fallback room code, player slots, readiness, settings, teams, start control. QR opens correct session from native camera or in-app scanner. No manual IP. Handle expired sessions and reconnects.
- iOS default landing: Scan to Join Game, camera permission, manual code, rules. Player enters name and selects available color.
- Individual play for 3–6; team play for 4 or 6 only, exactly two per team. Invite available player, accept/decline on recipient device, mutually confirmed partners seated opposite, retain chosen colors. Separate home areas. Allow changes before start. Synchronize readiness and team assignments.

## Gameplay
- Deal five cards per player. Begin turn with five; play/discard one, resolve move, automatically draw replacement for outgoing player, then advance. No manual draw or sixth card. Define deck exhaustion and game-end behavior consistently with rules. Test duplicate commands and reconnects.
- Public host display: board, player names, current turn, teams, public draw count and discard, last move, upcoming players. Never show private card faces or controller move-selection controls.
- Controller: private hand, identity and teammate, waiting state, playable card selection, marble and legal destination selection, preview and confirm, special actions including split seven, no-legal-move discard per rules, rules reference. iPhone portrait-first; iPad landscape side-by-side board and hand, adaptive portrait. Pinch zoom and precise hit testing.
- Movement: stationary board, origin ring, visible step-by-step trail, persistent destination and last-move summary. Reference timing: origin 1s, travel ~3.1s for eight spaces, destination .6s, transition ~2.3s; tune for accessibility and shorter moves. Public draw animation face-down; private replacement briefly highlighted. Optional sound and haptics.
- Host validates all commands; private hands sent only to owning authenticated controller, including protection from teammates. Secure transport, session identity, reconnect, idempotency and state revision checks.

## Approved reference inventory (not yet committed by this change)
- premium-marble-board.glb; apple-tv-marble-refinement.png
- apple-tv-gameplay-v4.png; emma-move-preview.mp4
- apple-tv-lobby-v2.png
- iOS scan/setup/team invitation/lobby storyboard
- iphone-controller-1.png through iphone-controller-4.png
- ipad-controller-active.png; ipad-controller-waiting.png
- ipad-mode-landing.png; ipad-tv-lobby.png; ipad-tv-gameplay.png (rename UI terminology to Host Mode)
These are reference filenames from design reviews, not claims of repository availability. Static previews may contain illustrative card counts or state; engine is authoritative. Do not ship illustrative QR or incorrect board geometry from concept images.

## Delivery gates
1. Archive actual approved assets and validate geometry/materials.
2. Shared visual foundation and adaptive public/controller layouts.
3. Shared hosting, QR and secure onboarding.
4. Team invitations and seating.
5. Authoritative gameplay, private hands and end-turn draw tests.
6. Controller interactions and animations.
7. Device validation for 3–6 players, both hosts, reconnect, privacy and TestFlight.
Use incremental PRs with passing CI. No visual redesign without approval. Do not claim TestFlight availability until verified.
