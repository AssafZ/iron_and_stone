# Iron and Stone

A medieval macro-strategy mobile game focused on squad-based movement and tactical composition.
Players manage Companies of up to 50 soldiers — Warriors, Knights, Archers, Catapults, and
Peasants — deploying them from castle garrisons, marching them along roads, and resolving
simultaneous-round battles to achieve Total Conquest.

---

## Quickstart

### Prerequisites

- [Flutter 3.x](https://docs.flutter.dev/get-started/install) (with Dart 3.x)
- Android SDK (API 26+) or Xcode 14+ for iOS 15+

### Clone and install

```bash
git clone https://github.com/AssafZ/iron_and_stone.git
cd iron_and_stone
flutter pub get
```

### Run tests

```bash
flutter test
```

All unit, widget, and integration tests must pass before building.

### Analyze code

```bash
flutter analyze
```

Zero warnings/issues required (warnings are treated as errors per project constitution).

### Run the app

```bash
# Android (connected device or emulator)
flutter run

# iOS (connected device or simulator)
flutter run -d ios
```

---

## Project Structure

```
lib/
├── domain/          # Pure Dart — entities, value objects, game rules, use cases
│   ├── entities/    # Company, Castle, MapNode, GameMap, Battle, Match, UnitRole …
│   ├── value_objects/  # SoldierCount, Ownership
│   ├── rules/       # BattleEngine, GrowthEngine, AiController, VictoryChecker …
│   └── use_cases/   # DeployCompany, MoveCompany, ResolveBattle, TickMatch …
├── state/           # Riverpod notifiers (MatchNotifier, CompanyNotifier …)
├── ui/              # Flutter widgets and screens
│   ├── screens/     # MapScreen, BattleScreen, CastleScreen, VictoryScreen …
│   ├── widgets/     # MapNodeWidget, CompanyMarker, BattleSideView …
│   └── theme/       # AppTheme (medieval colour palette)
└── data/
    ├── drift/       # SQLite persistence (AppDatabase, MatchDao, tables)
    └── settings_repository.dart   # SharedPreferences wrapper

test/
├── domain/          # Unit tests for all domain entities, rules, and use cases
├── widget/          # Widget tests for every interactive screen flow
├── golden/          # Visual regression baselines for map and battle layouts
└── integration/     # End-to-end match flow + persistence round-trip tests
```

---

## Architecture

Iron and Stone follows a strict four-layer architecture (see `specs/001-mvp-single-player/`
and `.specify/memory/constitution.md`):

1. **Domain layer** — pure Dart, zero Flutter imports. All game rules live here.
2. **State layer** — Riverpod `AsyncNotifier` classes. Delegates to domain use cases.
3. **Presentation layer** — Flutter `ConsumerWidget` screens and widgets. No game logic.
4. **Data layer** — Drift (SQLite) for match state; `shared_preferences` for settings.

---

## Spec & Plan

Feature specification and implementation plan are in `specs/001-mvp-single-player/`:

- `spec.md` — User stories and acceptance scenarios
- `plan.md` — Technical design, file structure, constitution check
- `tasks.md` — TDD task breakdown (phase-by-phase)
- `performance-notes.md` — Game-loop and rendering benchmark results
- `playtest-notes.md` — Playtest protocol and first-run UX notes

