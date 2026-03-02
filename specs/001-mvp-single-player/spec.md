# Feature Specification: Iron & Stone MVP — Single-Player Mode

**Feature Branch**: `001-mvp-single-player`  
**Created**: March 2, 2026  
**Status**: Draft  
**Input**: User description: "Iron and Stone MVP — single player mode against a single AI player. A macro-strategy mobile game focused on squad-based movement and tactical composition."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Launch a Match and Control the Map (Priority: P1)

A player opens the game, starts a new single-player match, and sees the medieval map with their starting castle and the AI opponent's starting castle. They deploy a Company of units from their castle, move it along a road, and observe it traveling toward an objective.

**Why this priority**: This is the foundational interaction — without the ability to start a match, deploy units, and move them, no other part of the game can exist or be demonstrated. Delivering this alone constitutes a playable skeleton.

**Independent Test**: Can be tested by launching a match, deploying one Company of any composition, and moving it to an adjacent map node. Success is that the Company visually moves and the game does not crash.

**Acceptance Scenarios**:

1. **Given** the player is on the main screen, **When** they start a new single-player match, **Then** a medieval map loads displaying at least two castles — one for the player and one for the AI.
2. **Given** the player's castle has units available, **When** they export a Company of up to 50 soldiers, **Then** a new Company marker appears on the map adjacent to their castle.
3. **Given** a Company is on the map, **When** the player taps a destination road node, **Then** the Company begins moving toward that destination at the speed of its slowest unit type.
4. **Given** a Company contains both Warriors (speed 6) and Catapults (speed 3), **When** the Company moves, **Then** it advances at speed 3 (the slowest member's speed).

---

### User Story 2 — Battle Resolution Between Opposing Forces (Priority: P2)

A player's Company encounters the AI's Company on a road, triggering a battle. The player watches the battle resolve according to unit roles and special abilities, then sees the outcome (victory, defeat, or mutual destruction) and the surviving Company returns or continues its march.

**Why this priority**: Combat is the primary conflict mechanism of the game. Without it, map movement is purposeless. This story, combined with Story 1, produces a fully playable game loop.

**Independent Test**: Can be tested by guiding a player Company into the AI's Company on a road. The battle screen opens, resolves, and a winner is declared with correct survivor counts reflecting unit stats.

**Acceptance Scenarios**:

1. **Given** a player Company and an AI Company occupy the same road segment, **When** they meet, **Then** the Battle Detail Screen opens showing both sides in a side-view 2D layout with melee units (Warriors, Knights) at the front advancing toward opponents and ranged units (Archers, Catapults) and Peasants positioned at the rear firing from behind.
2. **Given** the Battle Detail Screen is open, **When** battle resolves, **Then** damage is calculated per the Unit Balance Sheet (Warrior: 15 DMG, Knight: 40 DMG, Archer: 25 DMG, Catapult: 60 DMG).
3. **Given** a battle occurs on a road, **When** a Knight is present in a Company, **Then** that Knight deals 2× damage (80 DMG) on the road.
4. **Given** a player Company attacks a castle wall where Archers are stationed, **When** the player's Company contains no Warriors, **Then** Archers deal 2× damage and have 75% damage reduction from incoming attacks.
5. **Given** a player Company attacking a walled castle contains Warriors, **When** battle resolves, **Then** the Archer wall bonus (High Ground) is negated.
6. **Given** friendly Companies are moving toward an active battle location, **When** they arrive during the battle, **Then** they join as reinforcement waves.
7. **Given** one side is fully eliminated, **When** the battle ends, **Then** a victory/defeat summary screen is shown before returning to the map.

---

### User Story 3 — Castle Growth and Deployment Management (Priority: P3)

A player manages the units inside their castle — watching them grow automatically over time — then strategically deploys Companies of specific compositions (e.g., all Knights, or mixed Archers and Warriors) onto the map.

**Why this priority**: Castle economy and composition choices are the primary strategic layer. This story makes the game "hard to master" and differentiates it from a simple march-and-attack game.

**Independent Test**: Can be tested by observing a castle's unit counts increase over time without player input, then deploying a customized Company using the composition interface, verifying that the deployed counts match the player's selections.

**Acceptance Scenarios**:

1. **Given** a castle has fewer total units than its Castle Cap, **When** time passes, **Then** unit counts inside the castle increase automatically.
2. **Given** a castle has 10 Peasants, **When** viewing castle stats, **Then** the growth rate shows +50% (10 × 5%) and the Castle Cap shows +50% above the base cap.
3. **Given** a Company inside the castle reaches 50 soldiers, **When** more units grow in that Company slot, **Then** growth for that Company stops (it is capped at 50).
4. **Given** the total unit count (all Companies + loose Peasants) reaches the Castle Cap, **When** more time passes, **Then** all castle growth halts until units are deployed or lost.
5. **Given** the player opens the deployment interface, **When** they select unit types and quantities up to 50 total, **Then** a Company of exactly that composition is placed on the map and those units are removed from the castle reservoir.
6. **Given** the player deploys a Company, **When** the Company count would exceed 50, **Then** the system rejects the action and indicates the cap is reached.

---

### User Story 4 — Company Merging and Splitting on the Map (Priority: P4)

A player moves two friendly Companies to the same map node and merges them, or splits an existing Company into two using a role-based slider, to adapt their tactical formation mid-game.

**Why this priority**: Merging and splitting enable mid-game tactical adaptation, a key "hard to master" mechanic. It is secondary to the core loop (Stories 1–3) but essential for the full strategic experience.

**Independent Test**: Can be tested by sending two Companies to the same node, merging them, and confirming the combined count. Then splitting by role and verifying two separate Companies with the correct compositions exist.

**Acceptance Scenarios**:

1. **Given** two friendly Companies are on the same map node, **When** the player merges them and the total ≤ 50, **Then** a single Company of the combined count is formed.
2. **Given** two friendly Companies are on the same map node totaling 70 soldiers, **When** the player merges them, **Then** a Company of 50 is formed and an overflow Company of 20 is automatically created.
3. **Given** a Company is on the map, **When** the player opens the split interface and drags the role slider (e.g., moves 10 Archers to a new Company), **Then** two Companies appear: the original minus those units, and a new Company with the selected units.

---

### User Story 5 — AI Opponent Plays Autonomously (Priority: P5)

The AI opponent deploys, moves, and battles without any player input, providing a challenge that makes the game playable as a true single-player experience.

**Why this priority**: Without a functional AI, there is no single-player game. The AI does not need to be optimal for the MVP — it only needs to act purposefully (deploy, march, attack, and defend).

**Independent Test**: Can be tested by starting a match and taking no action for 60 seconds. The AI should have deployed at least one Company and moved it toward a map objective.

**Acceptance Scenarios**:

1. **Given** a match starts, **When** 30 seconds pass without player interaction, **Then** the AI has deployed at least one Company from its castle.
2. **Given** the AI has a Company on the map, **When** no obstacles are present, **Then** it moves toward a player-controlled castle or unoccupied castle.
3. **Given** the AI Company meets a player Company on a road, **When** they occupy the same segment, **Then** the Battle Detail Screen opens as it would for any encounter.
4. **Given** the AI captures all player castles, **When** the last castle falls, **Then** the game ends and the player is shown a defeat screen.

---

### User Story 6 — Victory and Defeat Conditions (Priority: P6)

The game correctly detects and announces win/loss conditions when one side captures all castles (Total Conquest). Target Capture win condition is out of scope for the MVP.

**Why this priority**: Clear win/loss conditions complete the game session loop, making each match feel finite and meaningful.

**Independent Test**: Can be tested by using a debug/cheat scenario to set the player as owning all castles and confirming the victory screen appears.

**Acceptance Scenarios**:

1. **Given** the player captures the last AI-controlled castle, **When** the capture is confirmed, **Then** a victory screen is displayed and the match ends.
2. **Given** the AI captures the last player-controlled castle, **When** the capture is confirmed, **Then** a defeat screen is displayed and the match ends.
3. **Given** a victory or defeat screen is shown, **When** the player dismisses it, **Then** they are returned to the main menu.

---

### Edge Cases

- What happens when a Company's last unit is killed mid-march? The Company marker is removed from the map immediately.
- What happens when both sides are eliminated simultaneously in a battle? The battle ends in a draw; neither side captures the objective.
- What happens when a player attempts to deploy a Company with 0 units of a selected type? The deployment is blocked and an error message is shown.
- What happens when a castle's growth is at cap and a Company returns to merge? The merge is accepted up to the Castle Cap; overflow is rejected with a notification.
- What happens when a Company moves off a road onto terrain without a path? Navigation is restricted to defined road nodes only; off-road movement is not allowed.
- What happens when the AI has no units left and no castle growth? The AI is eliminated and the player wins by default.

## Requirements *(mandatory)*

### Functional Requirements

**Map & Session**

- **FR-001**: The game MUST load a medieval map with at least 2 castles (one per player) and a network of road connections between map nodes at the start of each match.
- **FR-002**: The game MUST support exactly one human player versus one AI opponent in each match session.
- **FR-003**: A match MUST have a single win condition: Total Conquest — the first side to control 100% of castles wins. Target Capture is out of scope for the MVP.

**Unit Management & Castle Economy**

- **FR-004**: Each castle MUST maintain an internal garrison reservoir with a base cap of 250 units.
- **FR-005**: The garrison MUST grow automatically at a base rate of 1 unit per role per 10 seconds, respecting the per-Company cap of 50 soldiers and the total Castle Cap.
- **FR-006**: For every Peasant present in a castle, the castle's growth rate MUST increase by +5% and the Castle Cap MUST increase by +5%, with effects stacking across all Peasants.
- **FR-007**: The player MUST be able to deploy a Company of up to 50 soldiers from the castle reservoir with a custom unit composition drawn from the 5 available roles (Peasant, Warrior, Knight, Archer, Catapult).
- **FR-008**: The game MUST prevent deployment of a Company that exceeds 50 soldiers total.

**Movement**

- **FR-009**: A Company on the map MUST move at the speed of its slowest unit role. Speed values: Peasant 5, Warrior 6, Knight 10, Archer 6, Catapult 3.
- **FR-010**: Movement MUST be restricted to defined road paths between map nodes; Companies cannot move off-road.
- **FR-011**: The player MUST be able to assign a destination to any of their Companies by selecting a target map node.

**Merging & Splitting**

- **FR-012**: Two friendly Companies on the same map node MUST be mergeable by the player; if the combined count exceeds 50, an overflow Company of the excess soldiers MUST be automatically created.
- **FR-013**: A player MUST be able to split a Company using a role-based slider, producing two separate Companies; the combined soldier count of both Companies MUST equal the original.

**Combat**

- **FR-014**: When two opposing Companies meet on the same road segment, the Battle Detail Screen MUST open automatically.
- **FR-015**: When a Company reaches an enemy castle, the Battle Detail Screen MUST open.
- **FR-016**: Battle damage MUST be calculated per unit role: Warrior 15 DMG / 50 HP, Knight 40 DMG / 100 HP, Archer 25 DMG / 30 HP, Catapult 60 DMG / 150 HP, Peasant 0 DMG / 10 HP.
- **FR-016a**: Battle MUST resolve in simultaneous rounds. Each round: melee units (Warriors, Knights) advance toward the nearest enemy unit at their movement speed; ranged units (Archers, Catapults) and Peasants hold their position and attack from range. All damage from all units is applied simultaneously at the end of each round; units whose HP reaches 0 are removed before the next round begins.
- **FR-016b**: Melee units (Warriors, Knights) MUST target the closest advancing enemy melee unit first; if no melee units remain, they target the nearest enemy unit. Ranged units MUST target any enemy unit within their firing range, prioritising the closest.
- **FR-017**: Knights MUST deal 2× damage when battling on a road.
- **FR-018**: Archers stationed on castle walls MUST deal 2× damage and receive 75% damage reduction unless an attacking Company contains Warriors.
- **FR-019**: If attacking Warriors are present, the Archer High Ground bonus MUST be fully negated.
- **FR-020**: Catapults MUST destroy Archer wall protection (Wall Breaker ability), removing the Archer bonus for subsequent attack rounds.
- **FR-021**: Friendly Companies that arrive at an active battle location during the battle MUST join as reinforcement waves.
- **FR-022**: After a battle concludes, a victory/defeat summary screen MUST be shown before returning to the map view.
- **FR-022a**: When all defending units in a castle are eliminated, ownership of that castle MUST transfer instantly to the attacking side; no occupation timer is required.

**AI Opponent**

- **FR-023**: The AI MUST autonomously deploy Companies from its castle within the first 30 seconds of each match.
- **FR-024**: The AI MUST move its Companies toward player-controlled or unoccupied castles.
- **FR-025**: The AI MUST engage in battle when its Companies meet player Companies on a road or reach a player castle.
- **FR-026**: The AI MUST manage its own castle growth and deployment decisions without player input.

**Victory / Defeat**

- **FR-027**: The game MUST detect and announce a player victory when all castles are under player control (Total Conquest).
- **FR-028**: The game MUST detect and announce a player defeat when all player castles are captured by the AI.
- **FR-029**: After a victory or defeat screen is dismissed, the player MUST be returned to the main menu.

### Key Entities

- **Match**: A single game session; has a Total Conquest win condition, a duration, and two participants (human player and AI). Ends when one side controls all castles.
- **Map**: The game board; composed of map nodes (castles, road intersections) and road edges connecting them. Fixed per match.
- **Castle**: A map node owned by one player or neutral; has a garrison reservoir (base cap: 250 units), current unit counts by role, a Castle Cap, and a growth rate. Ownership transfers instantly when all defending units are eliminated.
- **Company**: A mobile unit group on the map; contains up to 50 soldiers with a composition of one or more unit roles; has a current location, a destination, and a derived movement speed.
- **Unit Role**: One of five archetypes (Peasant, Warrior, Knight, Archer, Catapult); each has fixed HP, damage, speed, and a special ability.
- **Battle**: An engagement triggered when opposing Companies meet; has participants (one or more Companies per side), resolves in simultaneous rounds (melee units advance, ranged units hold and fire, damage applied simultaneously per round), and produces survivors and an outcome.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A player can start a new single-player match and have the first Company deployed and moving on the map within 60 seconds of launch.
- **SC-002**: Battle outcomes correctly reflect unit role stat differences in 100% of simulated test cases (e.g., a full Company of Knights defeats a full Company of Warriors of equal size when on a road).
- **SC-003**: The AI opponent makes at least one offensive move (deploy + march toward a player objective) within 30 seconds of match start in 100% of test runs.
- **SC-004**: Castle growth, the 50-soldier Company cap, and the Castle Cap (base: 250 units) all behave correctly in 100% of boundary-condition test cases (e.g., growth stops exactly at cap, Peasant bonus stacks correctly).
- **SC-005**: Merging two Companies that exceed 50 soldiers always produces a primary Company of exactly 50 and an overflow Company with the correct remainder.
- **SC-006**: A complete match — from launch to victory or defeat — can be played end-to-end without a crash or unrecoverable error state.
- **SC-007**: 80% of first-time players in playtesting are able to complete their first match (win or lose) without external guidance.

## Clarifications

### Session 2026-03-02

- Q: What is the base castle growth rate (tick interval and units added per tick)? → A: 1 unit per role per 10 seconds
- Q: How is a castle captured — instant on elimination, occupation timer, or garrison threshold? → A: Instant on elimination (ownership transfers the moment all defending units are destroyed)
- Q: What is the battle round structure — how do units deal damage? → A: Dynamic simultaneous rounds; melee units (Warriors, Knights) advance toward enemy units at their movement speed each round; ranged units (Archers, Catapults) and Peasants hold position and fire from behind; all damage is applied simultaneously at the end of each round, then casualties are removed before the next round begins
- Q: Which win condition does the MVP support — Total Conquest only, both selectable, or both fixed per map? → A: Total Conquest only (control 100% of castles); Target Capture deferred to post-MVP
- Q: What is the concrete base Castle Cap value (FR-004 specified a range of 200–500)? → A: 250 units

## Assumptions

- The MVP map is a fixed, hand-designed layout (not procedurally generated) with a small number of castles (4–8) sufficient to demonstrate the strategic mechanics.
- The AI difficulty is "functional" for the MVP — it plays purposefully but is not optimized or tuned for competitive challenge; difficulty tuning is a post-MVP concern.
- The MVP does not include ads, monetization, or multiplayer; these are post-MVP features per the PRD.
- Session data (match results) does not persist between sessions in the MVP; no account system or leaderboard is required.
- The game is targeted at mobile (touch interface) but the MVP may be developed and tested on a single platform first (e.g., iOS or Android) before cross-platform support is added.
- "Growth" for castle units is continuous (tick-based at a fixed interval of 10 seconds), not turn-based. The base rate is 1 unit per role per tick.
- The Battle Detail Screen resolves in real-time but the player is a spectator only — no direct control during battle in the MVP.
