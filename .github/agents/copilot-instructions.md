# iron_and_stone Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-03-03

## Active Technologies
- Dart 3.x (sound null-safety) + Flutter 3.x, Riverpod (state), drift/drift_flutter (SQLite persistence) (003-battle-trigger-and-live-battle)
- drift SQLite — new `battles_table` added; `companies_table` gains a `battleId` column (003-battle-trigger-and-live-battle)
- Dart 3.x (sound null-safety, no `dynamic`) + Flutter 3.x, flutter_riverpod (state), drift/SQLite (persistence), flutter_test + golden_toolkit (testing) (004-road-free-movement)
- `drift` (SQLite) for game state persistence (mid-road position stored as segment ID + fractional progress); `shared_preferences` for settings (004-road-free-movement)

- (002-company-map-positioning)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for 

## Code Style

: Follow standard conventions

## Recent Changes
- 004-road-free-movement: Added Dart 3.x (sound null-safety, no `dynamic`) + Flutter 3.x, flutter_riverpod (state), drift/SQLite (persistence), flutter_test + golden_toolkit (testing)
- 003-battle-trigger-and-live-battle: Added Dart 3.x (sound null-safety) + Flutter 3.x, Riverpod (state), drift/drift_flutter (SQLite persistence)
- 003-battle-trigger-and-live-battle: Added [if applicable, e.g., PostgreSQL, CoreData, files or N/A]


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
