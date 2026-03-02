<!--
SYNC IMPACT REPORT
==================
Version change: (none) → 1.0.0  (initial ratification)
Modified principles: N/A — all principles are new
Added sections:
  - Core Principles (5 principles)
  - Technology Stack & Platform Constraints
  - Development Workflow & Quality Gates
  - Governance
Templates requiring updates:
  - .specify/templates/plan-template.md  ✅ reviewed — no changes required; Constitution Check
    gates now have concrete basis (see principles below)
  - .specify/templates/spec-template.md  ✅ reviewed — template is technology-agnostic; no
    changes required
  - .specify/templates/tasks-template.md ✅ reviewed — task categories (widget tests, game-loop
    tests) align with Principle III; no structural changes needed
Deferred TODOs: none
-->

# Iron and Stone Constitution

## Core Principles

### I. Domain Model First

Every feature MUST begin with a pure Dart domain model — entities, value objects, and game rules —
before any Flutter widget or platform code is written. Game logic (squad movement, combat
resolution, castle capture) MUST live in model/domain classes with zero Flutter dependencies so
that it can be unit-tested in isolation without a running app or device.

**Rationale**: Tactical game rules are the core value of Iron and Stone. Keeping them
framework-free prevents UI churn from corrupting rule integrity and enables fast, headless
testing of every strategic scenario.

### II. Widget & Layer Separation (NON-NEGOTIABLE)

The codebase MUST maintain strict layer separation:

- **Domain layer** (`lib/domain/`): Pure Dart — entities, value objects, game rules, use cases.
  No Flutter imports.
- **State layer** (`lib/state/` or `lib/blocs/`): State management only (e.g., Riverpod, Bloc).
  No direct UI rendering logic.
- **Presentation layer** (`lib/ui/`): Flutter widgets only. MUST NOT contain business logic or
  direct model mutation.
- **Data layer** (`lib/data/`): Persistence, remote, and platform adapters.

A pull request that places game-rule logic inside a widget MUST be rejected without exception.

**Rationale**: Mobile games accumulate technical debt fastest when UI and logic are entangled.
Clean layers make AI-assisted development, onboarding, and refactoring tractable at scale.

### III. Test-First for Game Rules (NON-NEGOTIABLE)

All domain-layer changes MUST follow Red-Green-Refactor TDD:

1. Write a failing unit test that captures the rule (squad capacity, movement range, victory
   condition, etc.).
2. Get explicit approval that the test correctly expresses intent before writing implementation.
3. Implement the minimum code to make the test pass.
4. Refactor while keeping all tests green.

Widget tests MUST cover every interactive screen flow. Integration/golden tests MUST cover
critical tactical UI compositions (map rendering, squad panel, action bar).

**Rationale**: Game rules are dense with edge cases (50-soldier Companies, simultaneous
captures, terrain modifiers). Tests are the living specification; they prevent silent regressions
across releases.

### IV. Performance & Frame Budget

The game MUST maintain 60 fps on mid-range Android devices (≥ 2 GB RAM, Snapdragon 665 class)
and iOS devices (iPhone XR or equivalent, iOS 15+).

Constraints:
- A single game-loop tick MUST complete in ≤ 16 ms on the Dart VM.
- Map rendering MUST NOT rebuild widgets for unchanged cells (use `const` constructors and
  `RepaintBoundary` at castle/squad boundaries).
- Asset bundles MUST NOT exceed 50 MB compressed at first install.
- Any operation causing a frame drop MUST be profiled with Flutter DevTools before the PR is
  merged.

**Rationale**: Macro-strategy games with large maps risk janky scrolling and input lag. Frame
budget discipline enforced at PR-time is cheaper than post-release optimisation.

### V. Simplicity & Incremental Complexity

Features MUST be introduced at the smallest viable scope. YAGNI strictly applies:

- No speculative abstractions (no generic "engine" layers until a concrete second use case
  exists).
- A new dependency MUST be justified with a written rationale in the PR description; prefer
  packages already in use.
- Squad AI behaviour MUST start with deterministic, rule-based logic before any probabilistic
  or ML approach is considered.
- Each feature MUST be independently playable/demonstrable before building the next.

**Rationale**: A mobile game with a small team must ship and iterate quickly. Premature
abstraction creates invisible complexity that slows every future change.

## Technology Stack & Platform Constraints

**Language**: Dart 3.x (sound null-safety required; no `dynamic` unless justified in PR)

**Framework**: Flutter 3.x — targets iOS and Android; no web or desktop target in v1.

**State Management**: Riverpod (preferred) or Bloc — one approach per feature area; mixing MUST
be approved by a constitution amendment.

**Persistence**: `shared_preferences` for settings; `drift` (SQLite) for game state.
No remote backend in v1; all game data is local.

**Testing stack**:
- `flutter_test` for unit and widget tests (MUST be present for every domain change).
- `integration_test` package for end-to-end game flows.
- `golden_toolkit` for visual regression on critical UI components.

**Target platforms**: Android 8.0+ (API 26+), iOS 15+.

**CI gate**: All tests MUST pass on `flutter test` before a PR can be merged.
The pipeline MUST include `flutter analyze` with zero warnings (treat warnings as errors).

## Development Workflow & Quality Gates

**Branch convention**: `###-short-description` (e.g., `001-squad-movement`).

**PR requirements**:
1. Constitution Check section in plan.md reviewed and signed off.
2. All domain changes covered by new or updated unit tests (Red-Green-Refactor confirmed).
3. `flutter analyze` — zero issues.
4. `flutter test` — all passing.
5. Frame-budget evidence (DevTools screenshot or benchmark) for any rendering change.
6. No bracketed `[TODO]` tokens left in spec or plan documents unless explicitly deferred with
   a `TODO(<FIELD>): explanation` annotation.

**Spec lifecycle**: Every feature MUST have a `spec.md` approved before `plan.md` is written,
and a `plan.md` approved before implementation begins.

**Commit message convention**: `<type>(<scope>): <description>`
Types: `feat`, `fix`, `test`, `refactor`, `docs`, `perf`, `chore`.

## Governance

This constitution supersedes all other development practices and informal agreements. Any
practice that conflicts with these principles MUST be resolved by amending the constitution, not
by silently violating it.

**Amendment procedure**:
1. Open a PR that modifies `.specify/memory/constitution.md` using the `speckit.constitution`
   agent workflow.
2. Increment `CONSTITUTION_VERSION` following semantic versioning (see version policy below).
3. Update all dependent templates and agent files (run the Sync Impact Report checklist).
4. PR MUST be reviewed and merged before the amended principle takes effect.

**Versioning policy**:
- MAJOR: Removal or redefinition of a core principle; backward-incompatible governance change.
- MINOR: New principle or section added; material expansion of existing guidance.
- PATCH: Wording clarifications, typo fixes, non-semantic refinements.

**Compliance review**: Every PR description MUST include a "Constitution Check" confirming no
principles are violated. Violations not documented with a justified exception MUST block merge.

**Version**: 1.0.0 | **Ratified**: 2026-03-02 | **Last Amended**: 2026-03-02
