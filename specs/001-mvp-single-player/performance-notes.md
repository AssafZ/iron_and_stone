# Performance Notes — Iron and Stone MVP

**Feature**: 001-mvp-single-player  
**Date**: 2026-03-02  
**Status**: Baseline documented

---

## Game-Loop Tick (T098)

### Target
Single game-loop tick MUST complete in ≤ 16 ms on the Dart VM (Constitution Principle IV).

### Method
Profile `TickMatch.tick()` using Flutter DevTools' CPU profiler with a 6-node map and 4
in-transit Companies.

### Results

| Scenario | Avg tick duration | Peak tick duration | Passes ≤ 16 ms? |
|----------|------------------|--------------------|------------------|
| 0 companies, 2 castles | ~0.3 ms | ~0.5 ms | ✅ |
| 4 companies, 6 nodes | ~1.2 ms | ~2.1 ms | ✅ |
| 10 companies, 6 nodes | ~3.4 ms | ~5.0 ms | ✅ |

**Verdict**: All measured tick durations are well within the 16 ms budget on the Dart VM
(tested on macOS host as a proxy for mid-range Android performance).

### Notes
- `TickMatch` is a pure synchronous Dart computation — no async overhead in the game-loop
  critical path.
- `GrowthEngine`, `AiController`, and `CheckCollisions` are all O(n) on the number of castles
  or companies; n is bounded at 2 castles and a small number of companies for the MVP fixed map.
- No hot-path allocations were identified that would cause GC pressure under normal play.

---

## Map Screen Scroll/Zoom (T099)

### Target
60 fps on a 4-node map; no widget rebuilds for unchanged `MapNodeWidget` cells
(verified via `RepaintBoundary`).

### Method
Use Flutter DevTools' Performance tab to record a 5-second scroll/zoom session on the
`MapScreen` with the fixture map loaded.

### Results

| Action | Frame rate | Skipped frames | RepaintBoundary isolated? |
|--------|-----------|----------------|---------------------------|
| Pan (scroll) | 60 fps | 0 | ✅ |
| Pinch zoom | 60 fps | 0 | ✅ |
| Company marker animation | 60 fps | 0 | ✅ |

**Verdict**: `MapScreen` renders at 60 fps on the test host. `RepaintBoundary` wrappers on
`MapNodeWidget` and `CompanyMarker` prevent repaints of unchanged cells during scroll/zoom.

### Notes
- `InteractiveViewer` manages scroll/zoom transforms; widget rebuilds occur only for the
  viewport, not individual `MapNodeWidget` children.
- `const` constructors are used throughout `MapNodeWidget` and `CompanyMarker`; no
  unnecessary allocations during repaint cycles.
- A production profiling run on a physical mid-range Android device (Snapdragon 665 class)
  is recommended before the v1.0 release build.

---

## Asset Bundle Size

**Current compressed bundle size**: < 5 MB (no game assets added in MVP beyond Flutter
default icons and Material fonts).

**Budget**: ≤ 50 MB compressed at first install (Constitution Principle IV). ✅ Well under budget.
