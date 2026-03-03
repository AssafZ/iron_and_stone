/// Special ability tags for unit roles.
enum SpecialAbility {
  /// Peasants boost castle growth rate and cap by 5% each.
  growthBonus,

  /// Knights deal 2× damage on road tiles.
  roadCharge,

  /// Archers gain 2× damage and 75% damage reduction on High Ground
  /// (castle walls) unless Warriors are present.
  highGround,

  /// Catapults remove the Archer High Ground bonus on first shot.
  wallBreaker,
}

/// A unit role in Iron and Stone with immutable combat and movement stats.
///
/// Stats sourced from FR-016 and FR-009.
enum UnitRole {
  /// Peasant: support unit that boosts castle economy.
  peasant(
    hp: 10,
    damage: 0,
    speed: 5,
    range: 1,
    specialAbility: SpecialAbility.growthBonus,
  ),

  /// Warrior: standard melee fighter.
  warrior(
    hp: 50,
    damage: 15,
    speed: 6,
    range: 1,
    specialAbility: null,
  ),

  /// Knight: heavy melee fighter with road-charge ability.
  knight(
    hp: 100,
    damage: 40,
    speed: 10,
    range: 1,
    specialAbility: SpecialAbility.roadCharge,
  ),

  /// Archer: ranged unit with high-ground defensive bonus.
  archer(
    hp: 30,
    damage: 25,
    speed: 6,
    range: 3,
    specialAbility: SpecialAbility.highGround,
  ),

  /// Catapult: siege unit that destroys archer wall bonuses.
  catapult(
    hp: 150,
    damage: 60,
    speed: 3,
    range: 5,
    specialAbility: SpecialAbility.wallBreaker,
  );

  /// Hit points of a single unit of this role.
  final int hp;

  /// Base damage per round for a single unit of this role.
  final int damage;

  /// Movement speed (map distance units per tick).
  final int speed;

  /// Attack range in battle-field distance units.
  /// Melee roles (Peasant, Warrior, Knight) = 1.
  /// Archer = 3, Catapult = 5.
  final int range;

  /// Optional special ability tag; null means no special ability.
  final SpecialAbility? specialAbility;

  const UnitRole({
    required this.hp,
    required this.damage,
    required this.speed,
    required this.range,
    required this.specialAbility,
  });

  /// Growth-rate multiplier relative to Peasant (base 1.0).
  ///
  /// - Peasant:  1.0   → 1 soldier / tick at base multiplier
  /// - Warrior:  0.5   → 1 soldier every 2 ticks
  /// - Archer:   0.5   → 1 soldier every 2 ticks
  /// - Knight:   0.25  → 1 soldier every 4 ticks
  /// - Catapult: 0.125 → 1 soldier every 8 ticks
  double get growthRate => switch (this) {
        UnitRole.peasant => 1.0,
        UnitRole.warrior => 0.5,
        UnitRole.archer => 0.5,
        UnitRole.knight => 0.25,
        UnitRole.catapult => 0.125,
      };
}
