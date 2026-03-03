# Feature Specification: Company Map Positioning — Stacking & Overlap Resolution

**Feature Branch**: `002-company-map-positioning`  
**Created**: March 3, 2026  
**Status**: Draft  
**Input**: User description: "Companies positioning on the game map — companies placed at the same point or within the same castle are placed one above the other, making lower ones unclickable. Fix castle company selection (frontmost unit), prevent overlap on road junction nodes, and allow passing-through without blocking."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Select Any Company at a Road Junction Node (Priority: P1)

When two or more companies — whether friendly, enemy, or mixed — arrive at the same road junction node, the player can tap each company individually without one being hidden beneath another. Companies are visually offset or presented in a selection panel so all are reachable by tap.

**Why this priority**: This is the most critical blocker. Overlapping company markers on road nodes make companies completely unreachable by touch, breaking the core game loop for any scenario where two companies occupy the same waypoint.

**Independent Test**: Place two companies (one player, one AI) on the same road junction node. Both companies must be individually tappable — tapping the node area must present a choice between them, and selecting each must open its action panel.

**Acceptance Scenarios**:

1. **Given** two companies from the same owner are stationary at the same road junction node, **When** the player taps that node area, **Then** both companies are individually selectable (either via visual offset or a disambiguation panel).
2. **Given** a player company and an AI company are both stationary at the same road junction node, **When** the player taps that node area, **Then** both companies are individually visible and the player company is tappable.
3. **Given** three or more companies are at the same road junction node, **When** the player taps that area, **Then** all companies are individually selectable — none are obscured by others.
4. **Given** multiple companies are shown at a shared road junction node, **When** the player selects one company, **Then** the selected company receives the tap correctly and no other company is inadvertently selected.
5. **Given** the player has one company selected and taps a second friendly company at the same node, **When** both companies are player-owned, **Then** the merge prompt is presented exactly as it would be in the MVP — the offset UI does not suppress the merge flow.

---

### User Story 2 — Select Any Company Inside a Castle (Priority: P2)

When multiple companies are garrisoned inside a castle (whether waiting to deploy, returning, or defending), the player can choose which company to bring to the front for action. A "front" company is the one that can be interacted with; other garrisoned companies are accessible through a selection mechanism.

**Why this priority**: Castle garrison management is central to the deployment and tactical strategy. If garrisoned companies cannot be selected, the player cannot deploy a specific company or give orders to a chosen unit inside the castle.

**Independent Test**: Place two or more player companies inside one castle. A visible control must allow the player to cycle through or choose which garrisoned company is in "front" (active/selectable). Selecting each company must open that company's action options.

**Acceptance Scenarios**:

1. **Given** two or more companies are garrisoned inside a **player-owned** castle, **When** the player taps the castle, **Then** a company roster or carousel is shown listing all garrisoned companies individually.
2. **Given** the castle company roster is visible, **When** the player selects a specific company, **Then** that company becomes the active (front) company and the player can perform actions on it (deploy, view composition, split).
3. **Given** a castle has one garrisoned company and one that is defending against an incoming attack, **When** the player views the castle, **Then** garrisoned and defending companies are distinguishable in the roster.
4. **Given** a castle roster is open, **When** the player dismisses it without selecting, **Then** no unintended action is triggered.
5. **Given** the player taps an **enemy-controlled or neutral** castle, **When** the tap is registered, **Then** a read-only summary is shown displaying the current owner and the exact total soldier count defending that castle (e.g., "32 soldiers") — no company roster or action options are presented.

---

### User Story 3 — Companies Arriving Later at an Occupied Node Are Offset, Not Overlapping (Priority: P3)

When a company arrives at a road junction node already occupied by one or more stationary companies, the arriving company is placed in a visible offset position next to the existing companies — not stacked on top of them. All companies at the node remain individually tappable.

**Why this priority**: Prevents the accumulation problem: the first company occupying a node should not permanently block all subsequent arrivals from being clickable, whether they are from the player or the AI.

**Independent Test**: Send a second player company to a node already occupied by a first company. The second company's marker must appear at a visually distinct position (offset) adjacent to the first — not overlapping it. Both must be tappable.

**Acceptance Scenarios**:

1. **Given** a company is already stationary at a road junction node, **When** a second company arrives and stops at that node, **Then** the second company's marker is rendered at a visually offset position, not directly over the first.
2. **Given** two companies are already at a node, **When** a third company arrives and stops, **Then** all three are visible at distinct offset positions and all are individually tappable.
3. **Given** multiple companies from opposing owners are at the same node outside of a battle, **When** the player views the node, **Then** all companies (player and AI) are visible at offset positions.
4. **Given** companies are offset at a shared node, **When** a battle is triggered between them, **Then** the battle resolution proceeds normally; the offset is a presentation concern only.

---

### User Story 4 — Friendly Companies Passing Through an Occupied Node Are Not Blocked (Priority: P4)

When a friendly company's route passes through a road junction node that already has one or more stationary companies belonging to the same player, the passing company moves through without stopping or being blocked. Pass-through applies only between companies of the same owner. When an enemy company's route crosses a node occupied by a player company (or vice versa), the two companies engage in battle — they cannot pass through each other.

**Why this priority**: Without same-owner pass-through, a player's own parked company becomes a permanent road block for their own other companies, disrupting planned marches across the map. Opponent companies must still be intercepted — that is the core conflict mechanic.

**Independent Test**: Park a player company at an intermediate road junction node. Order a second player company to march to a destination beyond that node. The second company must pass through without stopping. Then verify that an AI company marching through a node occupied by a player company triggers a battle instead of passing through.

**Acceptance Scenarios**:

1. **Given** a player company is stationary at a road junction node, **When** a second player company is ordered to march to a destination past that node, **Then** the second company passes through the node without stopping and continues to its destination.
2. **Given** a player company is passing through a node occupied by another player company, **When** it passes through, **Then** the stationary company is not displaced, merged with, or visually affected.
3. **Given** an AI company's route passes through a road junction node occupied by a player company, **When** the AI company reaches that node, **Then** a battle is triggered between the two companies — the AI company does not pass through.
4. **Given** a player company's route passes through a road junction node occupied by an AI company, **When** the player company reaches that node, **Then** a battle is triggered — the player company does not pass through the enemy.
5. **Given** a friendly company is in transit through a node, **When** viewed on the map, **Then** it is visually distinguishable from stationary companies at that same node.

---

### Edge Cases

- What happens when the maximum number of offset positions at a node is exhausted (e.g., more than 5 companies at one node)? Additional companies continue to be offset using an extended pattern; no company is rendered directly on top of another.
- What happens when a company is split at an occupied node? The new split-off company takes the next available offset slot at that same node.
- What happens when a castle is under siege (battle in progress) and a new company arrives? The arriving company joins as a reinforcement wave per existing rules; the roster display updates to include it.
- What happens when the player taps between two closely offset companies and the touch target is ambiguous? The frontmost rendered company is selected; the player can cycle to others by tapping the node area again or using a "next" control.
- What happens when an enemy company's route passes through a node occupied by a player company? A battle is triggered immediately — enemy companies cannot pass through player companies (or vice versa). The passing rule applies only between companies of the same owner.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST display all companies at a shared map node (road junction or castle) as individually tappable — no company may be rendered directly on top of another company's active tap target. Each company marker MUST have a minimum tap target of 44 × 44 points to ensure reliable touch detection on all supported devices without requiring zoom.
- **FR-002**: When two or more companies are stationary at the same road junction node, the system MUST render each company marker at a visually distinct offset position relative to the node's centre point.
- **FR-003**: The offset layout at a road junction node MUST accommodate at least 5 simultaneous companies without overlap; additional companies beyond 5 MUST continue to be offset in an extended pattern.
- **FR-004**: When the player taps a **player-owned** castle, the system MUST present a company roster (list or carousel) showing all garrisoned companies individually. When the player taps an **enemy-controlled or neutral** castle, the system MUST show a read-only summary displaying the current owner and the exact total soldier count defending that castle (e.g., "32 soldiers") — no roster or action options are shown.
- **FR-005**: The castle company roster MUST allow the player to designate one company as the "front" (active) company, enabling actions such as deploy, split, and view composition for that specific company.
- **FR-006**: A company whose ordered route passes through a road junction node occupied by one or more companies belonging to the **same owner** MUST continue to its destination without stopping, unless that node is its final destination.
- **FR-007**: When a company's route passes through a road junction node occupied by one or more companies belonging to the **opposing owner**, a battle MUST be triggered at that node — the passing company MUST NOT continue through an enemy-occupied node without combat.
- **FR-008**: The visual representation of a company in transit through a node MUST be distinguishable from a company that is stationary at that node.
- **FR-009**: When a new company arrives and stops at a node already occupied by others, the system MUST assign it the next available offset slot in arrival order — it MUST NOT displace existing companies from their assigned offset positions. When a company departs, remaining companies MUST compact inward so the first-arrival company always occupies the centre slot and no gaps appear between slots.
- **FR-010**: All offset positions and roster entries MUST remain correct after a game-loop tick, a merge, a split, or a reinforcement event — no event may cause companies to revert to overlapping positions.
- **FR-011**: The offset and roster selection UI MUST NOT suppress any existing player interaction — selecting a company via an offset marker or roster entry and then tapping a second friendly company at the same node MUST trigger the merge prompt identical to the MVP behaviour.

### Key Entities

- **MapNode occupancy**: The set of companies currently stationary at a given map node, with their assigned offset slots.
- **Company transit state**: Whether a company is stationary at a node or passing through it en route to a further destination.
- **Castle garrison roster**: An ordered list of companies currently inside a castle, with a designated "front" company index.
- **Offset slot**: A position relative to a node's centre assigned to a stationary company to prevent visual overlap.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In any game state with 2 or more companies at the same node, 100% of those companies are individually tappable — each marker maintains a minimum 44 × 44 point tap target — without requiring zoom or special navigation.
- **SC-002**: The company roster inside a player-owned castle correctly lists all garrisoned companies, with zero instances of a company being inaccessible due to overlap or hidden stacking. Tapping an enemy-controlled or neutral castle displays the exact total soldier count and owner — verified to match the authoritative game state at the moment of the tap.
- **SC-003**: A player company ordered to march through a node occupied only by other player companies reaches its destination without stopping at the intermediate node in 100% of tested scenarios.
- **SC-004**: An enemy company that reaches a node occupied by a player company (or vice versa) always triggers a battle — zero instances of an enemy company passing through a player-occupied node without combat.
- **SC-005**: The offset layout renders without visual overlap for up to 5 simultaneous companies at a single road junction node, verified in both player-only and mixed-owner scenarios.
- **SC-006**: After any game event (tick, merge, split, reinforcement), no company markers revert to an overlapping state at a shared node.

## Clarifications

### Session 2026-03-03

- Q: When a company departs a multi-company node, how are remaining offset slots managed? → A: The first-arrival company always holds the centre slot; when any company departs, remaining companies compact inward to fill the vacated slot, maintaining a dense, centre-anchored layout.
- Q: When the player taps an enemy-controlled or neutral castle, what is shown? → A: A read-only summary showing the current owner and approximate defending strength — no company roster is shown for castles not owned by the player.
- Q: How should "approximate defending strength" be expressed for enemy/neutral castles? → A: The exact total soldier count is shown (e.g., "32 soldiers").
- Q: When the player selects one company via the offset/roster UI and taps a second friendly company at the same node, does the existing merge prompt still appear? → A: Yes — the merge prompt appears unchanged from the MVP behaviour; the offset/roster UI is a navigation layer that does not suppress existing interactions.
- Q: What is the minimum guaranteed tap target size for an individual company marker at an offset node? → A: 44 × 44 points — the platform accessibility minimum — ensuring reliable tap detection on all supported devices without requiring zoom.

## Assumptions

- Company markers are rendered as fixed-size circular icons on a 2D canvas; offset positions are calculated as small displacements in cardinal or diagonal directions from the node centre. Each marker's tap target is sized to a minimum of 44 × 44 points regardless of the visual icon size, in line with platform accessibility guidelines (Apple HIG / Material Design).
- Offset slots are centre-anchored and arrival-ordered: the first company to arrive occupies the centre; subsequent companies take the next outer slot. When any company departs, all remaining companies compact inward so the first-arrival company is always at the centre and no empty slots appear between occupied ones.
- "Passing through" applies exclusively to companies belonging to the same owner. A company traversing a node occupied by a friendly company is in transit; a company traversing a node occupied by an enemy company is intercepted and a battle begins.
- Battle triggering logic remains unchanged for all other cases: opposing companies that both arrive at or stop at the same node contest it.
- The castle roster UI is distinct from the road-junction offset layout; these are treated as two independent solutions to the same underlying problem (overlapping, unreachable companies).
- A "front" company in a castle is a presentation concept only — it does not confer any in-game stat advantage; it is simply the company the player interacts with first when opening the castle view.
- The offset solution applies to all node types where multiple companies can coexist: road junctions and castles. Castles additionally use the roster view.
