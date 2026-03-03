# Playtest Notes — Iron and Stone MVP

**Feature**: 001-mvp-single-player  
**Date**: 2026-03-02  
**Status**: Protocol defined; first-run UX implemented

---

## SC-007 Measurement Criteria

**Success criterion**: A first-time player completes a full match (deploy → march → battle →
Total Conquest) without external guidance within a single session.

### Measurement protocol

1. **Participant profile**: Player unfamiliar with Iron and Stone; experience with mobile
   strategy games is acceptable.
2. **Session setup**: Fresh install on a physical device (no prior state). Tester observes
   silently without prompting.
3. **Metrics captured**:
   - Time from app launch to first Company deployment.
   - Whether the player discovers the two-step tap-to-select / tap-to-move gesture without
     guidance (success = within 90 s of map appearing).
   - Number of battles triggered before match end.
   - Total session duration from "New Game" to victory/defeat screen.
   - Player self-reported confusion rating (1–5) immediately after session.
4. **Pass threshold**: Player deploys ≥ 1 Company and reaches a Victory or Defeat screen
   without abandoning the session. No mandatory guidance from the tester.

### First-run contextual hints (implemented)

The following hints are shown once on first launch and then hidden permanently (persisted
via `SettingsRepository.firstRunHintShown`):

| Hint | Location | Trigger condition |
|------|----------|------------------|
| "Tap a castle to deploy your first Company" | `MapScreen` overlay | First time `MapScreen` builds AND `firstRunHintShown == false` |
| Hint auto-dismisses after 5 seconds or on tap | Same overlay | Either condition |

The hint overlay is implemented as a `FirstRunHintOverlay` widget inside `MapScreen`.
It is shown only when `SettingsRepository.firstRunHintShown` is `false`, and calls
`markFirstRunHintShown()` on first display so it never repeats after the first session.

---

## Playtest Log

*(Placeholder — to be populated after physical device playtests.)*

| Session | Date | Device | Deploy time (s) | Gesture found? | Match completed? | Confusion rating |
|---------|------|--------|----------------|----------------|-----------------|-----------------|
| P01 | TBD | TBD | TBD | TBD | TBD | TBD |
| P02 | TBD | TBD | TBD | TBD | TBD | TBD |
| P03 | TBD | TBD | TBD | TBD | TBD | TBD |

---

## Known UX Friction Points (pre-playtest assessment)

1. **Two-step Company movement**: Selecting a Company then tapping a destination is not
   immediately obvious. The first-run hint addresses this, but a persistent "selected"
   visual highlight on the Company marker is the primary discoverability signal.
2. **Castle tap target**: The castle icon must be large enough to tap comfortably on small
   devices (minimum 44 × 44 dp touch target per platform guidelines).
3. **Battle auto-start**: When opposing Companies collide the Battle Screen opens
   automatically. No explicit "Fight!" confirmation is shown. This may surprise new players
   but was a deliberate MVP simplification (spec § User Story 2).

---

## Deferred Items

- SC-007 pass/fail determination is deferred until at least 3 playtest sessions are
  completed on physical devices.
- Sound effects and music (deferred to post-MVP — not in v1 scope).
