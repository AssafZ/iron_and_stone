# Feature Specification: Battle Trigger & Live Battle View

**Feature Branch**: `003-battle-trigger-and-live-battle`  
**Created**: March 4, 2026  
**Status**: Draft  
**Input**: User description: "When two opponent companies pass one through the other getting to the same road junction, or when a company tries to enter a castle of an opponent that has garrison companies in it, a battle should start. Currently companies just pass through opponent companies or enter into opponent castles even when there are garrison companies. When opponents meet a battle starts, the map shows a battle indicator, the user can tap battling companies to view the live battle. At battle end the soldier counts are updated and companies that lost all soldiers are eliminated."

## User Scenarios & Testing *(mandatory)*

<!--
  Stories are ordered by priority. Each story is independently testable and
  delivers stand-alone value once implemented.
-->

### User Story 1 — Road-Junction Collision Triggers a Battle (Priority: P1)

When a moving company reaches a road junction node that is occupied by one or more companies of the opposing owner (or passes through the same node as an opposing company moving in the opposite direction), the movement of both parties stops immediately and a battle is triggered at that node. Neither company may continue its march until the battle is resolved.

**Why this priority**: This is the core missing mechanic reported by the user. Without it, the entire tactical conflict on the map is broken — opponents pass through each other as if they do not exist. All subsequent stories depend on a battle actually being triggered.

**Independent Test**: Deploy a player company and an AI company on opposite ends of the same road. Let the game loop run. When the two companies share the same junction node, both must halt and a battle must be registered in the game state. Confirm that neither company has a destination or has moved past the node in the same tick.

**Acceptance Scenarios**:

1. **Given** a player company is marching toward a road junction node, **When** an AI company is stationary at that node at the moment the player company's tick arrives, **Then** both companies halt at the node and `CheckCollisions` emits a `BattleTrigger` of kind `roadCollision`.
2. **Given** a player company and an AI company are both moving toward the same road junction from opposite directions, **When** both arrive at the node within the same tick, **Then** both halt and a `roadCollision` trigger is emitted.
3. **Given** a `roadCollision` trigger is emitted, **When** `TickMatch` processes the trigger, **Then** both involved companies are placed into the `inBattle` state (assigned a `battleId`) and their movement is frozen — their `destination` fields are preserved so movement resumes automatically when the battle ends.
4. **Given** a company is in the `inBattle` state, **When** the game loop ticks, **Then** that company's position does not advance — it remains frozen at the battle node.
5. **Given** two friendly (same-owner) companies are at the same road junction, **When** the game loop ticks, **Then** no battle trigger is emitted — only opposing companies trigger a battle.

---

### User Story 2 — Castle-Entry with Garrison Triggers a Battle (Priority: P2)

When a company reaches an enemy castle node that contains one or more garrison companies belonging to the castle's owner, a battle is triggered between the attacking company and the defending garrison companies. The attacking company halts at the castle node. If the enemy castle has no garrison companies (it is empty), no battle is triggered and ownership transfers immediately.

**Why this priority**: The second reported bug. An empty castle should be capturable immediately (as per FR-022a from the MVP spec), but a garrisoned castle must be contested in battle. This story restores the intended siege mechanic.

**Independent Test**: Place an AI company inside a player castle. Send a player company to that castle. When the player company arrives, a `castleAssault` trigger must be emitted. The player company halts. The defending AI company is designated as the defending side. Separately, send a player company to an empty neutral castle — no battle trigger should fire and ownership should transfer.

**Acceptance Scenarios**:

1. **Given** an enemy castle has one or more garrison companies belonging to its owner, **When** an attacking company arrives at that castle node, **Then** a `castleAssault` trigger is emitted with the attacking company as attacker and all garrison companies of the castle owner as defenders.
2. **Given** an enemy castle is empty (no garrison companies at the castle node), **When** an attacking company arrives, **Then** no battle is triggered and castle ownership transfers immediately to the attacking company's owner.
3. **Given** a `castleAssault` trigger is emitted, **When** `TickMatch` processes it, **Then** the attacking company and all defending garrison companies are placed into the `inBattle` state (assigned a `battleId`) and their movement is frozen — their `destination` fields are preserved.
4. **Given** a castle battle is in progress, **When** additional friendly companies of the attacking side arrive at the castle node during the battle, **Then** they join the battle as reinforcements on the attacking side (consistent with FR-021 from the MVP spec).
5. **Given** a castle battle is in progress, **When** additional companies of the defending side arrive at the castle node, **Then** they join as reinforcements on the defending side.

---

### User Story 3 — Battle Indicator on the Map (Priority: P3)

While a battle is in progress at a node (road junction or castle), the map shows a persistent visual indicator at that location so that the player can immediately identify that a battle is occurring. The indicator is visible at all map zoom levels where the node itself is visible.

**Why this priority**: Without a visual cue, the player has no way of knowing that a battle has been triggered. The indicator is the primary affordance that leads to Story 4 (tapping to view the live battle). It must exist before the detail-view story delivers value.

**Independent Test**: Trigger a battle at any node (road junction or castle). Observe the map. A visually distinct marker (e.g., crossed-swords icon, animated pulse, or colour change) must appear at the battle node. The marker must remain until the battle resolves.

**Acceptance Scenarios**:

1. **Given** a battle is triggered at a road junction node, **When** the map screen renders, **Then** a battle indicator widget is rendered at that node's map coordinate — visually distinct from normal company markers and node widgets.
2. **Given** a battle is triggered at a castle node, **When** the map screen renders, **Then** a battle indicator is rendered at the castle's map coordinate, overlaying or replacing the normal castle view for the duration of the battle.
3. **Given** a battle is in progress, **When** the player pans or zooms the map, **Then** the battle indicator remains correctly anchored to the battle node across all zoom and pan states.
4. **Given** a battle is resolved (both sides have a final outcome), **When** the map screen renders on the next frame, **Then** the battle indicator is removed and the node reverts to its normal appearance.
5. **Given** two separate battles are in progress on the map simultaneously (one on a road, one at a castle), **When** the map renders, **Then** both battle indicators are shown independently at their respective nodes.

---

### User Story 4 — Tap Battle Indicator to View Live Battle (Priority: P4)

When a battle indicator is visible on the map, the player can tap it to open the Battle Detail Screen for that battle. The screen shows the live state of the ongoing battle — both sides, current round, and soldier counts — and the player can watch it progress round by round. If multiple battles are in progress, tapping each indicator opens the corresponding battle.

**Why this priority**: The map indicator provides awareness; this story provides actionability. Watching the live battle unfold gives the player the tactical feedback they need to understand troop losses before deciding their next move.

**Independent Test**: Trigger a battle. Tap the battle indicator on the map. The Battle Detail Screen must open showing the correct attacker and defender companies for that battle. Advance one round and confirm the soldier counts update. Return to the map — the indicator is still present because the battle is ongoing.

**Acceptance Scenarios**:

1. **Given** a battle is in progress and a battle indicator is visible on the map, **When** the player taps the indicator, **Then** the Battle Detail Screen opens showing the correct attacker and defender companies for that specific battle.
2. **Given** the Battle Detail Screen is open for an in-progress battle, **When** the player taps "Next Round", **Then** one round resolves immediately in the UI (in addition to the automatic tick-driven advancement), unit HP and soldier counts update, and the round log entry is appended.
3. **Given** the Battle Detail Screen is open, **When** the player navigates back to the map (back gesture or back button), **Then** the map is displayed and the battle indicator is still visible (battle is still in progress unless it resolved while the screen was open).
4. **Given** two battles are in progress simultaneously, **When** the player taps each battle indicator in turn, **Then** each tap opens the Battle Detail Screen for the correct battle (the companies shown correspond to the tapped location, not a shared global battle state).
5. **Given** a battle resolves while the Battle Detail Screen is open (outcome becomes non-null), **When** the last round completes, **Then** the in-screen battle summary is shown (consistent with the existing MVP `_BattleSummary` widget) before the player returns to the map.

---

### User Story 5 — Post-Battle State: Soldier Counts Updated, Eliminated Companies Removed (Priority: P5)

After a battle resolves, the surviving companies have their soldier counts updated to reflect the losses sustained during the battle. Any company that lost all of its soldiers is eliminated and removed from the map immediately. Castle ownership transfers when all defending companies are eliminated (consistent with FR-022a). The map returns to its normal traversable state for any surviving companies.

**Why this priority**: Without post-battle cleanup, the game state is corrupt — dead companies remain on the map and soldier counts are stale. This story closes the full battle loop and is the final piece needed for a playable combat cycle.

**Independent Test**: Trigger a battle. Resolve all rounds until an outcome is determined. Verify that the surviving side's companies have soldier counts equal to their HP-adjusted survivors. Verify that companies with 0 soldiers are absent from the map. If the battle was a castle assault and attackers won, verify the castle's ownership has changed. If both sides were eliminated (draw), verify both companies are removed.

**Acceptance Scenarios**:

1. **Given** a battle resolves with the attacker winning, **When** the post-battle state is applied, **Then** the surviving attacker companies have their `composition` updated to match the soldiers remaining after the final round; the defender companies are removed from the map.
2. **Given** a battle resolves with the defender winning, **When** the post-battle state is applied, **Then** the surviving defender companies retain their updated soldier counts; the attacker companies are removed from the map.
3. **Given** a battle resolves as a draw (both sides eliminated in the same round), **When** the post-battle state is applied, **Then** both the attacker and defender companies are removed from the map.
4. **Given** a `castleAssault` battle resolves with attackers winning, **When** the post-battle state is applied, **Then** the castle node's ownership changes to the attacking side's owner (consistent with FR-022a).
5. **Given** a `castleAssault` battle resolves with defenders winning, **When** the post-battle state is applied, **Then** castle ownership does not change; surviving defender companies remain garrisoned at the castle.
6. **Given** a post-battle surviving company has soldiers remaining, **When** the map renders after battle cleanup, **Then** that company's marker shows the correct updated soldier count; the company retains its pre-battle destination and resumes marching toward it on the next game-loop tick automatically.
7. **Given** a battle is resolved and the battle indicator was present on the map, **When** post-battle cleanup completes, **Then** the battle indicator is removed from the map.

---

### Edge Cases

- **Simultaneous multi-battle tick**: If two separate battles are triggered in the same tick (e.g., one road collision and one castle assault), both must be independently tracked; each has its own `Battle` object, `BattleNotifier` instance, and map indicator.
- **Company in transit passes an occupied enemy node mid-edge**: If a company's progress crosses the boundary of an enemy-occupied node within a single tick (i.e., `newProgress >= 1.0` and the next node is enemy-occupied), the company must stop at that node and a collision must be detected — it must not continue past to the next segment.
- **Castle with garrison but no living soldiers**: If a castle node has companies present but all have 0 soldiers (e.g., all peasants just deployed), those companies are considered eliminated before the collision check; an attacking company arriving at such a castle captures it without a battle.
- **Battle started then company reinforcement arrives the same tick**: Reinforcement companies that arrive at a battle node in the same tick as the battle starts must be included in the initial `Battle` object construction, not added as a second trigger.
- **Player company attacking a castle it owns**: No battle is triggered; the company is treated as garrisoning.
- **AI company attacking a road node with multiple player companies**: All player companies at the node are included as defenders in a single `roadCollision` trigger — not as separate battles per pair.
- **Both sides reduced to 0 soldiers simultaneously (draw) during a castle assault**: Ownership does not transfer; the castle remains with the original owner (or neutral if it was neutral).
- **Survivor destination equals the battle node**: If a surviving company's retained pre-battle destination is the node where the battle was fought (i.e., the battle node was the company's final destination), the company remains stationary at that node after cleanup (`destination` is effectively already reached); it does not attempt to re-enter the node.

## Requirements *(mandatory)*

### Functional Requirements

**Battle Triggering**

- **FR-001**: When a company's movement tick causes it to arrive at a road junction node occupied by one or more companies of the opposing owner, the system MUST immediately halt both the arriving company and all opposing companies at that node and emit a `BattleTrigger` of kind `roadCollision`.
- **FR-002**: When a company arrives at a road junction node that is occupied only by same-owner companies (or is empty), the system MUST NOT emit a battle trigger; the arriving company may continue or stop as normal.
- **FR-003**: When a moving company's progress within a single tick would carry it past (`newProgress >= 1.0`) a road junction node that is occupied by one or more opposing companies, the system MUST stop the company at that node (clamp progress to 0.0 at the node) and emit a `roadCollision` trigger — the company MUST NOT advance past an enemy-occupied node without combat.
- **FR-004**: When a company arrives at a `CastleNode` whose current owner differs from the arriving company's owner, **and** one or more companies belonging to the castle's owner are stationed at that castle node, the system MUST emit a `BattleTrigger` of kind `castleAssault`; the arriving company is the attacker and all stationed owner-companies are defenders.
- **FR-005**: When a company arrives at a `CastleNode` whose current owner differs from the arriving company's owner, **and** no companies belonging to the castle's owner are stationed at that node, the system MUST NOT emit a battle trigger; castle ownership MUST transfer immediately to the arriving company's owner (consistent with FR-022a of the MVP spec).
- **FR-006**: All companies involved in an active battle MUST be assigned a non-null `battleId` and MUST NOT advance in position during any game-loop tick while the battle is in progress. The company's `destination` field is **preserved unchanged** during the battle; the movement engine skips advancement solely on the presence of a non-null `battleId`. `destination` MUST NOT be cleared when a battle starts.
- **FR-007**: The `CheckCollisions` use case MUST correctly identify all opposing-company pairs at each node type (road junction and castle) and group them into the minimum number of `BattleTrigger` objects — one per contested node. Multiple opposing companies at the same node produce one trigger, not one per pair.

**Battle State Management**

- **FR-008**: The game state MUST support zero or more simultaneously active `Battle` objects. Each active battle is independently tracked with its own attacker list, defender list, round number, HP maps, and outcome. Every game-loop tick (10 s) MUST advance each active battle by exactly one round automatically — battle rounds do not pause while the player is on the map.
- **FR-009**: Each active battle MUST be associated with the map node at which it was triggered. This association is used to render the map indicator and to route tap events to the correct `Battle` instance.
- **FR-010**: Companies that are part of an active battle MUST be tagged in the game state (e.g., via a `battleId` field on `CompanyOnMap`) so that the game loop can skip their movement and the map renderer can suppress their normal company markers in favour of the battle indicator.
- **FR-011**: When additional companies of either side arrive at an active battle node during subsequent ticks, they MUST be added to the correct side of the existing `Battle` object as reinforcements (consistent with FR-021 of the MVP spec) — a second `Battle` object MUST NOT be created for the same node.

**Map Indicator (Presentation)**

- **FR-012**: The map screen MUST render a visually distinct battle indicator at the map coordinate of every active battle node. The indicator MUST be visible at all zoom levels at which the node itself is visible and MUST be anchored to the node's canvas position exactly as company markers are anchored.
- **FR-013**: The battle indicator MUST use imagery or colour that unambiguously communicates "battle in progress" — for example, a crossed-swords icon, a pulsing red highlight, or an animated war-banner widget. It MUST be visually differentiated from all other map widgets (company markers, castle icons, road junction dots).
- **FR-014**: The battle indicator's tap target MUST be at least 44 × 44 points (consistent with the platform tap-target minimum established in spec 002) to ensure reliable detection on all supported devices.
- **FR-015**: When a battle resolves, the battle indicator MUST be removed from the map within one render frame of the post-battle state being applied.

**Live Battle View (Presentation)**

- **FR-016**: Tapping the battle indicator on the map MUST navigate to the Battle Detail Screen for the corresponding `Battle` object. The screen MUST be populated with the correct attacker and defender companies for the tapped battle.
- **FR-017**: The Battle Detail Screen MUST display live soldier counts for both sides that reflect the current round's HP state — not the pre-battle composition.
- **FR-018**: Each game-loop tick MUST automatically advance every active battle by one round (calling `BattleEngine.resolveRound`) and write the result back to `MatchState.activeBattles`. The Battle Detail Screen "Next Round" button MUST also advance the battle by one round on demand (in addition to the automatic tick), allowing the player to step through rounds faster than the tick cadence. The UI MUST update to show the new survivor counts, round number, and latest round log entry after either advancement source.
- **FR-019**: The Battle Detail Screen MUST allow the player to navigate back to the map without resolving the battle — the battle continues to exist in the game state and the map indicator remains visible.
- **FR-020**: If the player is viewing the Battle Detail Screen for a battle that has resolved (outcome is non-null), the existing `_BattleSummary` widget MUST be shown immediately upon opening the screen.

**Post-Battle Cleanup**

- **FR-021**: After a battle resolves, the soldier `composition` of each surviving company MUST be updated to exactly match the soldiers remaining in the final HP map — no surplus or deficit. The updated company MUST be written back to `MatchState.companies`.
- **FR-022**: After a battle resolves, every company whose total soldier count is 0 (all soldiers killed) MUST be removed from `MatchState.companies` immediately. No zero-soldier company marker may remain on the map.
- **FR-023**: After a `castleAssault` battle resolves with `BattleOutcome.attackersWin`, the `Castle` object for the contested castle node MUST have its `ownership` updated to the attacking side's owner.
- **FR-024**: After a `castleAssault` battle resolves with `BattleOutcome.draw`, the castle's ownership MUST remain unchanged.
- **FR-025**: After post-battle cleanup, surviving companies that are no longer in a battle MUST have their `battleId` cleared (set to `null`). Because `destination` was preserved unchanged throughout the battle (see FR-006), movement toward the original destination resumes automatically on the next game-loop tick without any player input required.
- **FR-026**: `MatchDao` MUST persist the full `activeBattles` list — including each `ActiveBattle`'s node ID, attacker/defender company IDs, current `Battle` round number, HP maps (`attackerHp`, `defenderHp`), and round log — as part of every `saveMatch` call. On `loadMatch`, `activeBattles` MUST be fully restored so that in-progress battles continue from the exact round they were interrupted, with no loss of accumulated damage.

### Key Entities

- **Battle** (existing, `lib/domain/entities/battle.dart`): Tracks one engagement — attackers, defenders, round number, HP maps, outcome, kind. No changes to structure required beyond confirming it already supports multiple-company sides.
- **BattleTrigger** (existing, `lib/domain/use_cases/check_collisions.dart`): Describes a detected collision — kind, location node, and company IDs involved. Already complete; collision-detection logic needs a fix to account for FR-003 (mid-edge pass-through).
- **CompanyOnMap** (existing, `lib/domain/use_cases/check_collisions.dart`): Needs a new optional `battleId` field (`String?`) to mark that a company is currently engaged in a battle. The `destination` field is **not** modified when a battle starts or ends; the movement engine gates advancement on `battleId != null`.
- **ActiveBattle**: A new entity pairing a `Battle` with its `MapNode` location and the IDs of the `CompanyOnMap` entries involved. Its `id` is derived as `"battle_<nodeId>"` (e.g., `"battle_junction_42"`), making it stable, unique per node, and human-readable. Stored in `MatchState` as `List<ActiveBattle>`. MUST be fully serialisable (including HP maps, round logs, and node association) so that `MatchDao` can persist and restore it.
- **MatchState** (existing, `lib/state/match_notifier.dart`): Needs a new `activeBattles` field of type `List<ActiveBattle>` to track all in-progress battles independently. The field MUST be included in every `MatchDao.saveMatch` / `loadMatch` round-trip so that battles survive app restarts.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 100% of tested scenarios, an opposing company arriving at or passing through a road junction node occupied by an enemy company triggers a `roadCollision` battle — zero instances of an enemy company continuing past an enemy-occupied node without combat.
- **SC-002**: In 100% of tested scenarios, an attacking company arriving at a garrisoned enemy castle triggers a `castleAssault` battle — zero instances of a company entering a garrisoned enemy castle without triggering a battle.
- **SC-003**: In 100% of tested scenarios, an attacking company arriving at an **empty** enemy castle captures it immediately without a battle (consistent with FR-022a).
- **SC-004**: For every active battle in the game state, exactly one battle indicator is rendered on the map at the correct node coordinate, visible without zooming in, with a tap target of at least 44 × 44 points.
- **SC-005**: Tapping a battle indicator opens the Battle Detail Screen for the correct battle (verified by matching the displayed company compositions to the attacker/defender companies stored in the `ActiveBattle`). With two simultaneous battles, tapping each indicator opens its respective screen in 100% of attempts.
- **SC-006**: After a battle resolves, each surviving company's total soldier count in `MatchState.companies` equals the exact number of soldiers alive at the end of the final round — verified by comparing the final HP map to the updated `composition`.
- **SC-007**: After a battle resolves, zero companies with 0 total soldiers remain in `MatchState.companies` or are rendered on the map.
- **SC-008**: After a `castleAssault` battle resolves with an attacker win, the `Castle.ownership` in `MatchState.castles` equals the attacker's owner — verified immediately after post-battle cleanup, in 100% of test cases.
- **SC-009**: The full battle loop (trigger → indicator visible → tap to view → advance rounds → outcome → map updated) completes without a crash or unrecoverable error state in end-to-end integration testing.
- **SC-010**: After a cold app restart with one or more battles in progress, all `ActiveBattle` objects are restored from SQLite with the correct round number, HP maps, and node association — each battle continues from the exact round it was at before the restart, with no damage reset.

## Clarifications

### Session 2026-03-04

- Q: When a battle is in progress and the player is not viewing the Battle Detail Screen, how do battle rounds advance? → A: The game-loop tick (every 10 s) automatically advances each active battle by one round, regardless of whether the player is viewing the Battle Detail Screen.
- Q: After a road-junction battle resolves, what is the movement state of surviving companies? → A: All survivors remain at the battle node but retain their pre-battle destination, which resumes on the next tick without player input.
- Q: Should `activeBattles` (including in-progress HP maps and round logs) be persisted to SQLite and restored on cold start? → A: Yes — persist `activeBattles` fully (HP maps, round logs, node association); restore on cold start so battles resume exactly where they left off.
- Q: Where is the pre-battle destination stored for surviving companies during a battle? → A: Keep the original destination on `CompanyOnMap.destination`; the movement engine skips companies with a non-null `battleId` regardless of `destination`.
- Q: Should the Battle Detail Screen auto-advance rounds (real-time simulation) or require the player to tap "Next Round" manually? → A: Manual tap ("Next Round") only, consistent with the existing MVP Battle Detail Screen behaviour. Auto-advance is a post-MVP enhancement.
- Q: When a battle is in progress and the player has no other companies to control, can the player still pan/zoom the map? → A: Yes — the map remains fully interactive during a battle; tapping the battle indicator opens the detail view, but no other actions are blocked.
- Q: Can the player issue move orders to a company that is in battle? → A: No — companies with an active `battleId` are locked; movement orders MUST be rejected until the battle resolves and the `battleId` is cleared.
- Q: What happens if the AI company that is in battle is also the AI's only company? → A: The AI has no special interrupt; it simply cannot make any action for that company until the battle resolves. AI decision logic skips companies tagged as in-battle.
- Q: How many simultaneous battles can be in progress at once? → A: Unlimited — one per contested node. Each is independently tracked. The UI shows all indicators simultaneously.
- Q: Should the battle indicator animate (pulse, glow) or be static? → A: Animated (e.g., pulsing) is preferred for clarity, but a static crossed-swords icon is acceptable for the initial implementation. Animation MUST NOT cause frame drops below 60 fps on the target devices (Principle IV).
- Q: How should `battleId` values be generated? → A: Use `"battle_<nodeId>"` as the `battleId`. Battles are one-per-node (FR-007/FR-011), so the node ID is a natural stable unique key — no additional ID state or UUID generation is required.

## Assumptions

- The existing `Battle`, `BattleEngine`, `BattleNotifier`, and `CheckCollisions` domain objects are structurally sound for this feature. The main gaps are: (1) collision detection does not yet prevent mid-edge pass-through (FR-003); (2) `MatchState` has no `activeBattles` list; (3) `CompanyOnMap` has no `battleId`; (4) `TickMatch` does not yet freeze battling companies or apply post-battle cleanup; (5) `MatchDao` does not yet serialise `activeBattles`.
- A single `ActiveBattle` entity (new) pairs a `Battle` with its node and involved company IDs. This is sufficient to satisfy all map-indicator, navigation, and cleanup requirements without redesigning existing types.
- "Garrison companies" in the context of this spec means `CompanyOnMap` entries whose `currentNode` is the castle node and whose `destination` is `null` (stationary) — consistent with how the MVP and spec 002 define a company stationed at a castle.
- The Battle Detail Screen already exists (`lib/ui/screens/battle_screen.dart`) and already handles the round-advance and summary flow for a single `Battle`. The primary change needed is making it accept an `ActiveBattle` (or battle ID) parameter rather than relying on a single global `battleNotifierProvider`.
- Post-battle HP-to-composition conversion follows the existing `buildHpMap` / `_companiesFromHp` pattern in `BattleEngine`. The surviving composition per role is derived from the count of still-living HP entries for that role in the final HP map.
- The game loop (`TickMatch`) must be updated to: (a) detect in-battle companies (non-null `battleId`) and skip their movement without touching `destination`; (b) call post-battle cleanup when a `Battle.outcome` becomes non-null; (c) apply castle ownership transfer for won assaults; (d) clear `battleId` on survivors after cleanup.
- All new domain-layer code (entity fields, use-case logic) MUST be covered by unit tests following Red-Green-Refactor (Principle III). All new presentation code MUST be covered by widget tests.
