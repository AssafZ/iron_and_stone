// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MatchesTableTable extends MatchesTable
    with TableInfo<$MatchesTableTable, MatchesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _elapsedSecondsMeta = const VerificationMeta(
    'elapsedSeconds',
  );
  @override
  late final GeneratedColumn<int> elapsedSeconds = GeneratedColumn<int>(
    'elapsed_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _humanPlayerMeta = const VerificationMeta(
    'humanPlayer',
  );
  @override
  late final GeneratedColumn<String> humanPlayer = GeneratedColumn<String>(
    'human_player',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    phase,
    outcome,
    elapsedSeconds,
    humanPlayer,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'matches_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    } else if (isInserting) {
      context.missing(_phaseMeta);
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    }
    if (data.containsKey('elapsed_seconds')) {
      context.handle(
        _elapsedSecondsMeta,
        elapsedSeconds.isAcceptableOrUnknown(
          data['elapsed_seconds']!,
          _elapsedSecondsMeta,
        ),
      );
    }
    if (data.containsKey('human_player')) {
      context.handle(
        _humanPlayerMeta,
        humanPlayer.isAcceptableOrUnknown(
          data['human_player']!,
          _humanPlayerMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_humanPlayerMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MatchesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      phase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phase'],
      )!,
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      )!,
      elapsedSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_seconds'],
      )!,
      humanPlayer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}human_player'],
      )!,
    );
  }

  @override
  $MatchesTableTable createAlias(String alias) {
    return $MatchesTableTable(attachedDatabase, alias);
  }
}

class MatchesTableData extends DataClass
    implements Insertable<MatchesTableData> {
  /// Unique match identifier (UUID v4 string).
  final String id;

  /// ISO-8601 timestamp when the match was created.
  final String createdAt;

  /// ISO-8601 timestamp of the last persist call.
  final String updatedAt;

  /// Current [MatchPhase] as a string ('setup' | 'playing' | 'inBattle' | 'ended').
  final String phase;

  /// [MatchOutcome] as a string ('playerWins' | 'aiWins') or empty string when null.
  final String outcome;

  /// Total elapsed game time in seconds.
  final int elapsedSeconds;

  /// Human player ownership string ('player' | 'ai').
  final String humanPlayer;
  const MatchesTableData({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.phase,
    required this.outcome,
    required this.elapsedSeconds,
    required this.humanPlayer,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['phase'] = Variable<String>(phase);
    map['outcome'] = Variable<String>(outcome);
    map['elapsed_seconds'] = Variable<int>(elapsedSeconds);
    map['human_player'] = Variable<String>(humanPlayer);
    return map;
  }

  MatchesTableCompanion toCompanion(bool nullToAbsent) {
    return MatchesTableCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      phase: Value(phase),
      outcome: Value(outcome),
      elapsedSeconds: Value(elapsedSeconds),
      humanPlayer: Value(humanPlayer),
    );
  }

  factory MatchesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchesTableData(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      phase: serializer.fromJson<String>(json['phase']),
      outcome: serializer.fromJson<String>(json['outcome']),
      elapsedSeconds: serializer.fromJson<int>(json['elapsedSeconds']),
      humanPlayer: serializer.fromJson<String>(json['humanPlayer']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'phase': serializer.toJson<String>(phase),
      'outcome': serializer.toJson<String>(outcome),
      'elapsedSeconds': serializer.toJson<int>(elapsedSeconds),
      'humanPlayer': serializer.toJson<String>(humanPlayer),
    };
  }

  MatchesTableData copyWith({
    String? id,
    String? createdAt,
    String? updatedAt,
    String? phase,
    String? outcome,
    int? elapsedSeconds,
    String? humanPlayer,
  }) => MatchesTableData(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    phase: phase ?? this.phase,
    outcome: outcome ?? this.outcome,
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    humanPlayer: humanPlayer ?? this.humanPlayer,
  );
  MatchesTableData copyWithCompanion(MatchesTableCompanion data) {
    return MatchesTableData(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      phase: data.phase.present ? data.phase.value : this.phase,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      elapsedSeconds: data.elapsedSeconds.present
          ? data.elapsedSeconds.value
          : this.elapsedSeconds,
      humanPlayer: data.humanPlayer.present
          ? data.humanPlayer.value
          : this.humanPlayer,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchesTableData(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('phase: $phase, ')
          ..write('outcome: $outcome, ')
          ..write('elapsedSeconds: $elapsedSeconds, ')
          ..write('humanPlayer: $humanPlayer')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    phase,
    outcome,
    elapsedSeconds,
    humanPlayer,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchesTableData &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.phase == this.phase &&
          other.outcome == this.outcome &&
          other.elapsedSeconds == this.elapsedSeconds &&
          other.humanPlayer == this.humanPlayer);
}

class MatchesTableCompanion extends UpdateCompanion<MatchesTableData> {
  final Value<String> id;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String> phase;
  final Value<String> outcome;
  final Value<int> elapsedSeconds;
  final Value<String> humanPlayer;
  final Value<int> rowid;
  const MatchesTableCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.phase = const Value.absent(),
    this.outcome = const Value.absent(),
    this.elapsedSeconds = const Value.absent(),
    this.humanPlayer = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchesTableCompanion.insert({
    required String id,
    required String createdAt,
    required String updatedAt,
    required String phase,
    this.outcome = const Value.absent(),
    this.elapsedSeconds = const Value.absent(),
    required String humanPlayer,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       phase = Value(phase),
       humanPlayer = Value(humanPlayer);
  static Insertable<MatchesTableData> custom({
    Expression<String>? id,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? phase,
    Expression<String>? outcome,
    Expression<int>? elapsedSeconds,
    Expression<String>? humanPlayer,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (phase != null) 'phase': phase,
      if (outcome != null) 'outcome': outcome,
      if (elapsedSeconds != null) 'elapsed_seconds': elapsedSeconds,
      if (humanPlayer != null) 'human_player': humanPlayer,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String>? phase,
    Value<String>? outcome,
    Value<int>? elapsedSeconds,
    Value<String>? humanPlayer,
    Value<int>? rowid,
  }) {
    return MatchesTableCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      phase: phase ?? this.phase,
      outcome: outcome ?? this.outcome,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      humanPlayer: humanPlayer ?? this.humanPlayer,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (elapsedSeconds.present) {
      map['elapsed_seconds'] = Variable<int>(elapsedSeconds.value);
    }
    if (humanPlayer.present) {
      map['human_player'] = Variable<String>(humanPlayer.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchesTableCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('phase: $phase, ')
          ..write('outcome: $outcome, ')
          ..write('elapsedSeconds: $elapsedSeconds, ')
          ..write('humanPlayer: $humanPlayer, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CastlesTableTable extends CastlesTable
    with TableInfo<$CastlesTableTable, CastlesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CastlesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownershipMeta = const VerificationMeta(
    'ownership',
  );
  @override
  late final GeneratedColumn<String> ownership = GeneratedColumn<String>(
    'ownership',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _garrisonJsonMeta = const VerificationMeta(
    'garrisonJson',
  );
  @override
  late final GeneratedColumn<String> garrisonJson = GeneratedColumn<String>(
    'garrison_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, matchId, ownership, garrisonJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'castles_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CastlesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('ownership')) {
      context.handle(
        _ownershipMeta,
        ownership.isAcceptableOrUnknown(data['ownership']!, _ownershipMeta),
      );
    } else if (isInserting) {
      context.missing(_ownershipMeta);
    }
    if (data.containsKey('garrison_json')) {
      context.handle(
        _garrisonJsonMeta,
        garrisonJson.isAcceptableOrUnknown(
          data['garrison_json']!,
          _garrisonJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_garrisonJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, matchId};
  @override
  CastlesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CastlesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      ownership: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ownership'],
      )!,
      garrisonJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}garrison_json'],
      )!,
    );
  }

  @override
  $CastlesTableTable createAlias(String alias) {
    return $CastlesTableTable(attachedDatabase, alias);
  }
}

class CastlesTableData extends DataClass
    implements Insertable<CastlesTableData> {
  /// Castle node ID (matches the CastleNode id on the fixed map).
  final String id;

  /// Foreign key: the owning match's ID.
  final String matchId;

  /// Ownership string: 'player' | 'ai' | 'neutral'.
  final String ownership;

  /// JSON-encoded garrison — role name to count.
  /// e.g. '{"peasant":5,"warrior":20,"knight":3,"archer":8,"catapult":1}'
  final String garrisonJson;
  const CastlesTableData({
    required this.id,
    required this.matchId,
    required this.ownership,
    required this.garrisonJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['match_id'] = Variable<String>(matchId);
    map['ownership'] = Variable<String>(ownership);
    map['garrison_json'] = Variable<String>(garrisonJson);
    return map;
  }

  CastlesTableCompanion toCompanion(bool nullToAbsent) {
    return CastlesTableCompanion(
      id: Value(id),
      matchId: Value(matchId),
      ownership: Value(ownership),
      garrisonJson: Value(garrisonJson),
    );
  }

  factory CastlesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CastlesTableData(
      id: serializer.fromJson<String>(json['id']),
      matchId: serializer.fromJson<String>(json['matchId']),
      ownership: serializer.fromJson<String>(json['ownership']),
      garrisonJson: serializer.fromJson<String>(json['garrisonJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matchId': serializer.toJson<String>(matchId),
      'ownership': serializer.toJson<String>(ownership),
      'garrisonJson': serializer.toJson<String>(garrisonJson),
    };
  }

  CastlesTableData copyWith({
    String? id,
    String? matchId,
    String? ownership,
    String? garrisonJson,
  }) => CastlesTableData(
    id: id ?? this.id,
    matchId: matchId ?? this.matchId,
    ownership: ownership ?? this.ownership,
    garrisonJson: garrisonJson ?? this.garrisonJson,
  );
  CastlesTableData copyWithCompanion(CastlesTableCompanion data) {
    return CastlesTableData(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      ownership: data.ownership.present ? data.ownership.value : this.ownership,
      garrisonJson: data.garrisonJson.present
          ? data.garrisonJson.value
          : this.garrisonJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CastlesTableData(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('ownership: $ownership, ')
          ..write('garrisonJson: $garrisonJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, matchId, ownership, garrisonJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CastlesTableData &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.ownership == this.ownership &&
          other.garrisonJson == this.garrisonJson);
}

class CastlesTableCompanion extends UpdateCompanion<CastlesTableData> {
  final Value<String> id;
  final Value<String> matchId;
  final Value<String> ownership;
  final Value<String> garrisonJson;
  final Value<int> rowid;
  const CastlesTableCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.ownership = const Value.absent(),
    this.garrisonJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CastlesTableCompanion.insert({
    required String id,
    required String matchId,
    required String ownership,
    required String garrisonJson,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       matchId = Value(matchId),
       ownership = Value(ownership),
       garrisonJson = Value(garrisonJson);
  static Insertable<CastlesTableData> custom({
    Expression<String>? id,
    Expression<String>? matchId,
    Expression<String>? ownership,
    Expression<String>? garrisonJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (ownership != null) 'ownership': ownership,
      if (garrisonJson != null) 'garrison_json': garrisonJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CastlesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? matchId,
    Value<String>? ownership,
    Value<String>? garrisonJson,
    Value<int>? rowid,
  }) {
    return CastlesTableCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      ownership: ownership ?? this.ownership,
      garrisonJson: garrisonJson ?? this.garrisonJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (ownership.present) {
      map['ownership'] = Variable<String>(ownership.value);
    }
    if (garrisonJson.present) {
      map['garrison_json'] = Variable<String>(garrisonJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CastlesTableCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('ownership: $ownership, ')
          ..write('garrisonJson: $garrisonJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CompaniesTableTable extends CompaniesTable
    with TableInfo<$CompaniesTableTable, CompaniesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompaniesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownershipMeta = const VerificationMeta(
    'ownership',
  );
  @override
  late final GeneratedColumn<String> ownership = GeneratedColumn<String>(
    'ownership',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentNodeIdMeta = const VerificationMeta(
    'currentNodeId',
  );
  @override
  late final GeneratedColumn<String> currentNodeId = GeneratedColumn<String>(
    'current_node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationNodeIdMeta = const VerificationMeta(
    'destinationNodeId',
  );
  @override
  late final GeneratedColumn<String> destinationNodeId =
      GeneratedColumn<String>(
        'destination_node_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _compositionJsonMeta = const VerificationMeta(
    'compositionJson',
  );
  @override
  late final GeneratedColumn<String> compositionJson = GeneratedColumn<String>(
    'composition_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _battleIdMeta = const VerificationMeta(
    'battleId',
  );
  @override
  late final GeneratedColumn<String> battleId = GeneratedColumn<String>(
    'battle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    matchId,
    ownership,
    currentNodeId,
    destinationNodeId,
    progress,
    compositionJson,
    battleId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'companies_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompaniesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('ownership')) {
      context.handle(
        _ownershipMeta,
        ownership.isAcceptableOrUnknown(data['ownership']!, _ownershipMeta),
      );
    } else if (isInserting) {
      context.missing(_ownershipMeta);
    }
    if (data.containsKey('current_node_id')) {
      context.handle(
        _currentNodeIdMeta,
        currentNodeId.isAcceptableOrUnknown(
          data['current_node_id']!,
          _currentNodeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentNodeIdMeta);
    }
    if (data.containsKey('destination_node_id')) {
      context.handle(
        _destinationNodeIdMeta,
        destinationNodeId.isAcceptableOrUnknown(
          data['destination_node_id']!,
          _destinationNodeIdMeta,
        ),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('composition_json')) {
      context.handle(
        _compositionJsonMeta,
        compositionJson.isAcceptableOrUnknown(
          data['composition_json']!,
          _compositionJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_compositionJsonMeta);
    }
    if (data.containsKey('battle_id')) {
      context.handle(
        _battleIdMeta,
        battleId.isAcceptableOrUnknown(data['battle_id']!, _battleIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CompaniesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompaniesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      ownership: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ownership'],
      )!,
      currentNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_node_id'],
      )!,
      destinationNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_node_id'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      compositionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}composition_json'],
      )!,
      battleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}battle_id'],
      )!,
    );
  }

  @override
  $CompaniesTableTable createAlias(String alias) {
    return $CompaniesTableTable(attachedDatabase, alias);
  }
}

class CompaniesTableData extends DataClass
    implements Insertable<CompaniesTableData> {
  /// Unique identifier for this Company instance.
  final String id;

  /// Foreign key: the owning match's ID.
  final String matchId;

  /// Ownership string: 'player' | 'ai'.
  final String ownership;

  /// Current node ID the Company is at or most recently passed through.
  final String currentNodeId;

  /// Destination node ID, or empty string when stationary.
  final String destinationNodeId;

  /// Fractional progress toward the next node [0.0, 1.0).
  final double progress;

  /// JSON-encoded composition — role name to count.
  /// e.g. '{"warrior":10,"archer":5}'
  final String compositionJson;

  /// ID of the active battle this Company is locked into, or empty string
  /// when not in battle. Matches [BattlesTable.id] format: "battle_<nodeId>".
  final String battleId;
  const CompaniesTableData({
    required this.id,
    required this.matchId,
    required this.ownership,
    required this.currentNodeId,
    required this.destinationNodeId,
    required this.progress,
    required this.compositionJson,
    required this.battleId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['match_id'] = Variable<String>(matchId);
    map['ownership'] = Variable<String>(ownership);
    map['current_node_id'] = Variable<String>(currentNodeId);
    map['destination_node_id'] = Variable<String>(destinationNodeId);
    map['progress'] = Variable<double>(progress);
    map['composition_json'] = Variable<String>(compositionJson);
    map['battle_id'] = Variable<String>(battleId);
    return map;
  }

  CompaniesTableCompanion toCompanion(bool nullToAbsent) {
    return CompaniesTableCompanion(
      id: Value(id),
      matchId: Value(matchId),
      ownership: Value(ownership),
      currentNodeId: Value(currentNodeId),
      destinationNodeId: Value(destinationNodeId),
      progress: Value(progress),
      compositionJson: Value(compositionJson),
      battleId: Value(battleId),
    );
  }

  factory CompaniesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompaniesTableData(
      id: serializer.fromJson<String>(json['id']),
      matchId: serializer.fromJson<String>(json['matchId']),
      ownership: serializer.fromJson<String>(json['ownership']),
      currentNodeId: serializer.fromJson<String>(json['currentNodeId']),
      destinationNodeId: serializer.fromJson<String>(json['destinationNodeId']),
      progress: serializer.fromJson<double>(json['progress']),
      compositionJson: serializer.fromJson<String>(json['compositionJson']),
      battleId: serializer.fromJson<String>(json['battleId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matchId': serializer.toJson<String>(matchId),
      'ownership': serializer.toJson<String>(ownership),
      'currentNodeId': serializer.toJson<String>(currentNodeId),
      'destinationNodeId': serializer.toJson<String>(destinationNodeId),
      'progress': serializer.toJson<double>(progress),
      'compositionJson': serializer.toJson<String>(compositionJson),
      'battleId': serializer.toJson<String>(battleId),
    };
  }

  CompaniesTableData copyWith({
    String? id,
    String? matchId,
    String? ownership,
    String? currentNodeId,
    String? destinationNodeId,
    double? progress,
    String? compositionJson,
    String? battleId,
  }) => CompaniesTableData(
    id: id ?? this.id,
    matchId: matchId ?? this.matchId,
    ownership: ownership ?? this.ownership,
    currentNodeId: currentNodeId ?? this.currentNodeId,
    destinationNodeId: destinationNodeId ?? this.destinationNodeId,
    progress: progress ?? this.progress,
    compositionJson: compositionJson ?? this.compositionJson,
    battleId: battleId ?? this.battleId,
  );
  CompaniesTableData copyWithCompanion(CompaniesTableCompanion data) {
    return CompaniesTableData(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      ownership: data.ownership.present ? data.ownership.value : this.ownership,
      currentNodeId: data.currentNodeId.present
          ? data.currentNodeId.value
          : this.currentNodeId,
      destinationNodeId: data.destinationNodeId.present
          ? data.destinationNodeId.value
          : this.destinationNodeId,
      progress: data.progress.present ? data.progress.value : this.progress,
      compositionJson: data.compositionJson.present
          ? data.compositionJson.value
          : this.compositionJson,
      battleId: data.battleId.present ? data.battleId.value : this.battleId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompaniesTableData(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('ownership: $ownership, ')
          ..write('currentNodeId: $currentNodeId, ')
          ..write('destinationNodeId: $destinationNodeId, ')
          ..write('progress: $progress, ')
          ..write('compositionJson: $compositionJson, ')
          ..write('battleId: $battleId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    matchId,
    ownership,
    currentNodeId,
    destinationNodeId,
    progress,
    compositionJson,
    battleId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompaniesTableData &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.ownership == this.ownership &&
          other.currentNodeId == this.currentNodeId &&
          other.destinationNodeId == this.destinationNodeId &&
          other.progress == this.progress &&
          other.compositionJson == this.compositionJson &&
          other.battleId == this.battleId);
}

class CompaniesTableCompanion extends UpdateCompanion<CompaniesTableData> {
  final Value<String> id;
  final Value<String> matchId;
  final Value<String> ownership;
  final Value<String> currentNodeId;
  final Value<String> destinationNodeId;
  final Value<double> progress;
  final Value<String> compositionJson;
  final Value<String> battleId;
  final Value<int> rowid;
  const CompaniesTableCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.ownership = const Value.absent(),
    this.currentNodeId = const Value.absent(),
    this.destinationNodeId = const Value.absent(),
    this.progress = const Value.absent(),
    this.compositionJson = const Value.absent(),
    this.battleId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompaniesTableCompanion.insert({
    required String id,
    required String matchId,
    required String ownership,
    required String currentNodeId,
    this.destinationNodeId = const Value.absent(),
    this.progress = const Value.absent(),
    required String compositionJson,
    this.battleId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       matchId = Value(matchId),
       ownership = Value(ownership),
       currentNodeId = Value(currentNodeId),
       compositionJson = Value(compositionJson);
  static Insertable<CompaniesTableData> custom({
    Expression<String>? id,
    Expression<String>? matchId,
    Expression<String>? ownership,
    Expression<String>? currentNodeId,
    Expression<String>? destinationNodeId,
    Expression<double>? progress,
    Expression<String>? compositionJson,
    Expression<String>? battleId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (ownership != null) 'ownership': ownership,
      if (currentNodeId != null) 'current_node_id': currentNodeId,
      if (destinationNodeId != null) 'destination_node_id': destinationNodeId,
      if (progress != null) 'progress': progress,
      if (compositionJson != null) 'composition_json': compositionJson,
      if (battleId != null) 'battle_id': battleId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompaniesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? matchId,
    Value<String>? ownership,
    Value<String>? currentNodeId,
    Value<String>? destinationNodeId,
    Value<double>? progress,
    Value<String>? compositionJson,
    Value<String>? battleId,
    Value<int>? rowid,
  }) {
    return CompaniesTableCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      ownership: ownership ?? this.ownership,
      currentNodeId: currentNodeId ?? this.currentNodeId,
      destinationNodeId: destinationNodeId ?? this.destinationNodeId,
      progress: progress ?? this.progress,
      compositionJson: compositionJson ?? this.compositionJson,
      battleId: battleId ?? this.battleId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (ownership.present) {
      map['ownership'] = Variable<String>(ownership.value);
    }
    if (currentNodeId.present) {
      map['current_node_id'] = Variable<String>(currentNodeId.value);
    }
    if (destinationNodeId.present) {
      map['destination_node_id'] = Variable<String>(destinationNodeId.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (compositionJson.present) {
      map['composition_json'] = Variable<String>(compositionJson.value);
    }
    if (battleId.present) {
      map['battle_id'] = Variable<String>(battleId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompaniesTableCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('ownership: $ownership, ')
          ..write('currentNodeId: $currentNodeId, ')
          ..write('destinationNodeId: $destinationNodeId, ')
          ..write('progress: $progress, ')
          ..write('compositionJson: $compositionJson, ')
          ..write('battleId: $battleId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BattlesTableTable extends BattlesTable
    with TableInfo<$BattlesTableTable, BattlesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BattlesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
    'node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attackerCompanyIdsMeta =
      const VerificationMeta('attackerCompanyIds');
  @override
  late final GeneratedColumn<String> attackerCompanyIds =
      GeneratedColumn<String>(
        'attacker_company_ids',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _defenderCompanyIdsMeta =
      const VerificationMeta('defenderCompanyIds');
  @override
  late final GeneratedColumn<String> defenderCompanyIds =
      GeneratedColumn<String>(
        'defender_company_ids',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _attackerOwnershipMeta = const VerificationMeta(
    'attackerOwnership',
  );
  @override
  late final GeneratedColumn<String> attackerOwnership =
      GeneratedColumn<String>(
        'attacker_ownership',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _battleJsonMeta = const VerificationMeta(
    'battleJson',
  );
  @override
  late final GeneratedColumn<String> battleJson = GeneratedColumn<String>(
    'battle_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    matchId,
    nodeId,
    attackerCompanyIds,
    defenderCompanyIds,
    attackerOwnership,
    battleJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'battles_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<BattlesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(
        _nodeIdMeta,
        nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('attacker_company_ids')) {
      context.handle(
        _attackerCompanyIdsMeta,
        attackerCompanyIds.isAcceptableOrUnknown(
          data['attacker_company_ids']!,
          _attackerCompanyIdsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attackerCompanyIdsMeta);
    }
    if (data.containsKey('defender_company_ids')) {
      context.handle(
        _defenderCompanyIdsMeta,
        defenderCompanyIds.isAcceptableOrUnknown(
          data['defender_company_ids']!,
          _defenderCompanyIdsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defenderCompanyIdsMeta);
    }
    if (data.containsKey('attacker_ownership')) {
      context.handle(
        _attackerOwnershipMeta,
        attackerOwnership.isAcceptableOrUnknown(
          data['attacker_ownership']!,
          _attackerOwnershipMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attackerOwnershipMeta);
    }
    if (data.containsKey('battle_json')) {
      context.handle(
        _battleJsonMeta,
        battleJson.isAcceptableOrUnknown(data['battle_json']!, _battleJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_battleJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BattlesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BattlesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      nodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_id'],
      )!,
      attackerCompanyIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attacker_company_ids'],
      )!,
      defenderCompanyIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}defender_company_ids'],
      )!,
      attackerOwnership: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attacker_ownership'],
      )!,
      battleJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}battle_json'],
      )!,
    );
  }

  @override
  $BattlesTableTable createAlias(String alias) {
    return $BattlesTableTable(attachedDatabase, alias);
  }
}

class BattlesTableData extends DataClass
    implements Insertable<BattlesTableData> {
  /// Unique battle identifier — always `"battle_<nodeId>"`.
  final String id;

  /// Foreign key: the owning match's ID.
  final String matchId;

  /// The map node ID where this battle is occurring.
  final String nodeId;

  /// JSON-encoded list of attacker company IDs.
  /// e.g. '["co_1","co_3"]'
  final String attackerCompanyIds;

  /// JSON-encoded list of defender company IDs.
  /// e.g. '["co_2"]'
  final String defenderCompanyIds;

  /// Serialized [Ownership] of the attacking side: 'player' | 'ai'.
  final String attackerOwnership;

  /// JSON-encoded [Battle] snapshot (full round state, HP maps, outcome).
  final String battleJson;
  const BattlesTableData({
    required this.id,
    required this.matchId,
    required this.nodeId,
    required this.attackerCompanyIds,
    required this.defenderCompanyIds,
    required this.attackerOwnership,
    required this.battleJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['match_id'] = Variable<String>(matchId);
    map['node_id'] = Variable<String>(nodeId);
    map['attacker_company_ids'] = Variable<String>(attackerCompanyIds);
    map['defender_company_ids'] = Variable<String>(defenderCompanyIds);
    map['attacker_ownership'] = Variable<String>(attackerOwnership);
    map['battle_json'] = Variable<String>(battleJson);
    return map;
  }

  BattlesTableCompanion toCompanion(bool nullToAbsent) {
    return BattlesTableCompanion(
      id: Value(id),
      matchId: Value(matchId),
      nodeId: Value(nodeId),
      attackerCompanyIds: Value(attackerCompanyIds),
      defenderCompanyIds: Value(defenderCompanyIds),
      attackerOwnership: Value(attackerOwnership),
      battleJson: Value(battleJson),
    );
  }

  factory BattlesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BattlesTableData(
      id: serializer.fromJson<String>(json['id']),
      matchId: serializer.fromJson<String>(json['matchId']),
      nodeId: serializer.fromJson<String>(json['nodeId']),
      attackerCompanyIds: serializer.fromJson<String>(
        json['attackerCompanyIds'],
      ),
      defenderCompanyIds: serializer.fromJson<String>(
        json['defenderCompanyIds'],
      ),
      attackerOwnership: serializer.fromJson<String>(json['attackerOwnership']),
      battleJson: serializer.fromJson<String>(json['battleJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matchId': serializer.toJson<String>(matchId),
      'nodeId': serializer.toJson<String>(nodeId),
      'attackerCompanyIds': serializer.toJson<String>(attackerCompanyIds),
      'defenderCompanyIds': serializer.toJson<String>(defenderCompanyIds),
      'attackerOwnership': serializer.toJson<String>(attackerOwnership),
      'battleJson': serializer.toJson<String>(battleJson),
    };
  }

  BattlesTableData copyWith({
    String? id,
    String? matchId,
    String? nodeId,
    String? attackerCompanyIds,
    String? defenderCompanyIds,
    String? attackerOwnership,
    String? battleJson,
  }) => BattlesTableData(
    id: id ?? this.id,
    matchId: matchId ?? this.matchId,
    nodeId: nodeId ?? this.nodeId,
    attackerCompanyIds: attackerCompanyIds ?? this.attackerCompanyIds,
    defenderCompanyIds: defenderCompanyIds ?? this.defenderCompanyIds,
    attackerOwnership: attackerOwnership ?? this.attackerOwnership,
    battleJson: battleJson ?? this.battleJson,
  );
  BattlesTableData copyWithCompanion(BattlesTableCompanion data) {
    return BattlesTableData(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      attackerCompanyIds: data.attackerCompanyIds.present
          ? data.attackerCompanyIds.value
          : this.attackerCompanyIds,
      defenderCompanyIds: data.defenderCompanyIds.present
          ? data.defenderCompanyIds.value
          : this.defenderCompanyIds,
      attackerOwnership: data.attackerOwnership.present
          ? data.attackerOwnership.value
          : this.attackerOwnership,
      battleJson: data.battleJson.present
          ? data.battleJson.value
          : this.battleJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BattlesTableData(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('nodeId: $nodeId, ')
          ..write('attackerCompanyIds: $attackerCompanyIds, ')
          ..write('defenderCompanyIds: $defenderCompanyIds, ')
          ..write('attackerOwnership: $attackerOwnership, ')
          ..write('battleJson: $battleJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    matchId,
    nodeId,
    attackerCompanyIds,
    defenderCompanyIds,
    attackerOwnership,
    battleJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BattlesTableData &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.nodeId == this.nodeId &&
          other.attackerCompanyIds == this.attackerCompanyIds &&
          other.defenderCompanyIds == this.defenderCompanyIds &&
          other.attackerOwnership == this.attackerOwnership &&
          other.battleJson == this.battleJson);
}

class BattlesTableCompanion extends UpdateCompanion<BattlesTableData> {
  final Value<String> id;
  final Value<String> matchId;
  final Value<String> nodeId;
  final Value<String> attackerCompanyIds;
  final Value<String> defenderCompanyIds;
  final Value<String> attackerOwnership;
  final Value<String> battleJson;
  final Value<int> rowid;
  const BattlesTableCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.attackerCompanyIds = const Value.absent(),
    this.defenderCompanyIds = const Value.absent(),
    this.attackerOwnership = const Value.absent(),
    this.battleJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BattlesTableCompanion.insert({
    required String id,
    required String matchId,
    required String nodeId,
    required String attackerCompanyIds,
    required String defenderCompanyIds,
    required String attackerOwnership,
    required String battleJson,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       matchId = Value(matchId),
       nodeId = Value(nodeId),
       attackerCompanyIds = Value(attackerCompanyIds),
       defenderCompanyIds = Value(defenderCompanyIds),
       attackerOwnership = Value(attackerOwnership),
       battleJson = Value(battleJson);
  static Insertable<BattlesTableData> custom({
    Expression<String>? id,
    Expression<String>? matchId,
    Expression<String>? nodeId,
    Expression<String>? attackerCompanyIds,
    Expression<String>? defenderCompanyIds,
    Expression<String>? attackerOwnership,
    Expression<String>? battleJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (nodeId != null) 'node_id': nodeId,
      if (attackerCompanyIds != null)
        'attacker_company_ids': attackerCompanyIds,
      if (defenderCompanyIds != null)
        'defender_company_ids': defenderCompanyIds,
      if (attackerOwnership != null) 'attacker_ownership': attackerOwnership,
      if (battleJson != null) 'battle_json': battleJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BattlesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? matchId,
    Value<String>? nodeId,
    Value<String>? attackerCompanyIds,
    Value<String>? defenderCompanyIds,
    Value<String>? attackerOwnership,
    Value<String>? battleJson,
    Value<int>? rowid,
  }) {
    return BattlesTableCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      nodeId: nodeId ?? this.nodeId,
      attackerCompanyIds: attackerCompanyIds ?? this.attackerCompanyIds,
      defenderCompanyIds: defenderCompanyIds ?? this.defenderCompanyIds,
      attackerOwnership: attackerOwnership ?? this.attackerOwnership,
      battleJson: battleJson ?? this.battleJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (attackerCompanyIds.present) {
      map['attacker_company_ids'] = Variable<String>(attackerCompanyIds.value);
    }
    if (defenderCompanyIds.present) {
      map['defender_company_ids'] = Variable<String>(defenderCompanyIds.value);
    }
    if (attackerOwnership.present) {
      map['attacker_ownership'] = Variable<String>(attackerOwnership.value);
    }
    if (battleJson.present) {
      map['battle_json'] = Variable<String>(battleJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BattlesTableCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('nodeId: $nodeId, ')
          ..write('attackerCompanyIds: $attackerCompanyIds, ')
          ..write('defenderCompanyIds: $defenderCompanyIds, ')
          ..write('attackerOwnership: $attackerOwnership, ')
          ..write('battleJson: $battleJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MatchesTableTable matchesTable = $MatchesTableTable(this);
  late final $CastlesTableTable castlesTable = $CastlesTableTable(this);
  late final $CompaniesTableTable companiesTable = $CompaniesTableTable(this);
  late final $BattlesTableTable battlesTable = $BattlesTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    matchesTable,
    castlesTable,
    companiesTable,
    battlesTable,
  ];
}

typedef $$MatchesTableTableCreateCompanionBuilder =
    MatchesTableCompanion Function({
      required String id,
      required String createdAt,
      required String updatedAt,
      required String phase,
      Value<String> outcome,
      Value<int> elapsedSeconds,
      required String humanPlayer,
      Value<int> rowid,
    });
typedef $$MatchesTableTableUpdateCompanionBuilder =
    MatchesTableCompanion Function({
      Value<String> id,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String> phase,
      Value<String> outcome,
      Value<int> elapsedSeconds,
      Value<String> humanPlayer,
      Value<int> rowid,
    });

class $$MatchesTableTableFilterComposer
    extends Composer<_$AppDatabase, $MatchesTableTable> {
  $$MatchesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elapsedSeconds => $composableBuilder(
    column: $table.elapsedSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get humanPlayer => $composableBuilder(
    column: $table.humanPlayer,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MatchesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchesTableTable> {
  $$MatchesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedSeconds => $composableBuilder(
    column: $table.elapsedSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get humanPlayer => $composableBuilder(
    column: $table.humanPlayer,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MatchesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchesTableTable> {
  $$MatchesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<int> get elapsedSeconds => $composableBuilder(
    column: $table.elapsedSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get humanPlayer => $composableBuilder(
    column: $table.humanPlayer,
    builder: (column) => column,
  );
}

class $$MatchesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchesTableTable,
          MatchesTableData,
          $$MatchesTableTableFilterComposer,
          $$MatchesTableTableOrderingComposer,
          $$MatchesTableTableAnnotationComposer,
          $$MatchesTableTableCreateCompanionBuilder,
          $$MatchesTableTableUpdateCompanionBuilder,
          (
            MatchesTableData,
            BaseReferences<_$AppDatabase, $MatchesTableTable, MatchesTableData>,
          ),
          MatchesTableData,
          PrefetchHooks Function()
        > {
  $$MatchesTableTableTableManager(_$AppDatabase db, $MatchesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<String> outcome = const Value.absent(),
                Value<int> elapsedSeconds = const Value.absent(),
                Value<String> humanPlayer = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchesTableCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                phase: phase,
                outcome: outcome,
                elapsedSeconds: elapsedSeconds,
                humanPlayer: humanPlayer,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String createdAt,
                required String updatedAt,
                required String phase,
                Value<String> outcome = const Value.absent(),
                Value<int> elapsedSeconds = const Value.absent(),
                required String humanPlayer,
                Value<int> rowid = const Value.absent(),
              }) => MatchesTableCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                phase: phase,
                outcome: outcome,
                elapsedSeconds: elapsedSeconds,
                humanPlayer: humanPlayer,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MatchesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchesTableTable,
      MatchesTableData,
      $$MatchesTableTableFilterComposer,
      $$MatchesTableTableOrderingComposer,
      $$MatchesTableTableAnnotationComposer,
      $$MatchesTableTableCreateCompanionBuilder,
      $$MatchesTableTableUpdateCompanionBuilder,
      (
        MatchesTableData,
        BaseReferences<_$AppDatabase, $MatchesTableTable, MatchesTableData>,
      ),
      MatchesTableData,
      PrefetchHooks Function()
    >;
typedef $$CastlesTableTableCreateCompanionBuilder =
    CastlesTableCompanion Function({
      required String id,
      required String matchId,
      required String ownership,
      required String garrisonJson,
      Value<int> rowid,
    });
typedef $$CastlesTableTableUpdateCompanionBuilder =
    CastlesTableCompanion Function({
      Value<String> id,
      Value<String> matchId,
      Value<String> ownership,
      Value<String> garrisonJson,
      Value<int> rowid,
    });

class $$CastlesTableTableFilterComposer
    extends Composer<_$AppDatabase, $CastlesTableTable> {
  $$CastlesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownership => $composableBuilder(
    column: $table.ownership,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get garrisonJson => $composableBuilder(
    column: $table.garrisonJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CastlesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CastlesTableTable> {
  $$CastlesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownership => $composableBuilder(
    column: $table.ownership,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get garrisonJson => $composableBuilder(
    column: $table.garrisonJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CastlesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CastlesTableTable> {
  $$CastlesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => column);

  GeneratedColumn<String> get ownership =>
      $composableBuilder(column: $table.ownership, builder: (column) => column);

  GeneratedColumn<String> get garrisonJson => $composableBuilder(
    column: $table.garrisonJson,
    builder: (column) => column,
  );
}

class $$CastlesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CastlesTableTable,
          CastlesTableData,
          $$CastlesTableTableFilterComposer,
          $$CastlesTableTableOrderingComposer,
          $$CastlesTableTableAnnotationComposer,
          $$CastlesTableTableCreateCompanionBuilder,
          $$CastlesTableTableUpdateCompanionBuilder,
          (
            CastlesTableData,
            BaseReferences<_$AppDatabase, $CastlesTableTable, CastlesTableData>,
          ),
          CastlesTableData,
          PrefetchHooks Function()
        > {
  $$CastlesTableTableTableManager(_$AppDatabase db, $CastlesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CastlesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CastlesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CastlesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<String> ownership = const Value.absent(),
                Value<String> garrisonJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CastlesTableCompanion(
                id: id,
                matchId: matchId,
                ownership: ownership,
                garrisonJson: garrisonJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String matchId,
                required String ownership,
                required String garrisonJson,
                Value<int> rowid = const Value.absent(),
              }) => CastlesTableCompanion.insert(
                id: id,
                matchId: matchId,
                ownership: ownership,
                garrisonJson: garrisonJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CastlesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CastlesTableTable,
      CastlesTableData,
      $$CastlesTableTableFilterComposer,
      $$CastlesTableTableOrderingComposer,
      $$CastlesTableTableAnnotationComposer,
      $$CastlesTableTableCreateCompanionBuilder,
      $$CastlesTableTableUpdateCompanionBuilder,
      (
        CastlesTableData,
        BaseReferences<_$AppDatabase, $CastlesTableTable, CastlesTableData>,
      ),
      CastlesTableData,
      PrefetchHooks Function()
    >;
typedef $$CompaniesTableTableCreateCompanionBuilder =
    CompaniesTableCompanion Function({
      required String id,
      required String matchId,
      required String ownership,
      required String currentNodeId,
      Value<String> destinationNodeId,
      Value<double> progress,
      required String compositionJson,
      Value<String> battleId,
      Value<int> rowid,
    });
typedef $$CompaniesTableTableUpdateCompanionBuilder =
    CompaniesTableCompanion Function({
      Value<String> id,
      Value<String> matchId,
      Value<String> ownership,
      Value<String> currentNodeId,
      Value<String> destinationNodeId,
      Value<double> progress,
      Value<String> compositionJson,
      Value<String> battleId,
      Value<int> rowid,
    });

class $$CompaniesTableTableFilterComposer
    extends Composer<_$AppDatabase, $CompaniesTableTable> {
  $$CompaniesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownership => $composableBuilder(
    column: $table.ownership,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentNodeId => $composableBuilder(
    column: $table.currentNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destinationNodeId => $composableBuilder(
    column: $table.destinationNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get compositionJson => $composableBuilder(
    column: $table.compositionJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get battleId => $composableBuilder(
    column: $table.battleId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CompaniesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CompaniesTableTable> {
  $$CompaniesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownership => $composableBuilder(
    column: $table.ownership,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentNodeId => $composableBuilder(
    column: $table.currentNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destinationNodeId => $composableBuilder(
    column: $table.destinationNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get compositionJson => $composableBuilder(
    column: $table.compositionJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get battleId => $composableBuilder(
    column: $table.battleId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CompaniesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompaniesTableTable> {
  $$CompaniesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => column);

  GeneratedColumn<String> get ownership =>
      $composableBuilder(column: $table.ownership, builder: (column) => column);

  GeneratedColumn<String> get currentNodeId => $composableBuilder(
    column: $table.currentNodeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get destinationNodeId => $composableBuilder(
    column: $table.destinationNodeId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get compositionJson => $composableBuilder(
    column: $table.compositionJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get battleId =>
      $composableBuilder(column: $table.battleId, builder: (column) => column);
}

class $$CompaniesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CompaniesTableTable,
          CompaniesTableData,
          $$CompaniesTableTableFilterComposer,
          $$CompaniesTableTableOrderingComposer,
          $$CompaniesTableTableAnnotationComposer,
          $$CompaniesTableTableCreateCompanionBuilder,
          $$CompaniesTableTableUpdateCompanionBuilder,
          (
            CompaniesTableData,
            BaseReferences<
              _$AppDatabase,
              $CompaniesTableTable,
              CompaniesTableData
            >,
          ),
          CompaniesTableData,
          PrefetchHooks Function()
        > {
  $$CompaniesTableTableTableManager(
    _$AppDatabase db,
    $CompaniesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompaniesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompaniesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompaniesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<String> ownership = const Value.absent(),
                Value<String> currentNodeId = const Value.absent(),
                Value<String> destinationNodeId = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String> compositionJson = const Value.absent(),
                Value<String> battleId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompaniesTableCompanion(
                id: id,
                matchId: matchId,
                ownership: ownership,
                currentNodeId: currentNodeId,
                destinationNodeId: destinationNodeId,
                progress: progress,
                compositionJson: compositionJson,
                battleId: battleId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String matchId,
                required String ownership,
                required String currentNodeId,
                Value<String> destinationNodeId = const Value.absent(),
                Value<double> progress = const Value.absent(),
                required String compositionJson,
                Value<String> battleId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompaniesTableCompanion.insert(
                id: id,
                matchId: matchId,
                ownership: ownership,
                currentNodeId: currentNodeId,
                destinationNodeId: destinationNodeId,
                progress: progress,
                compositionJson: compositionJson,
                battleId: battleId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CompaniesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CompaniesTableTable,
      CompaniesTableData,
      $$CompaniesTableTableFilterComposer,
      $$CompaniesTableTableOrderingComposer,
      $$CompaniesTableTableAnnotationComposer,
      $$CompaniesTableTableCreateCompanionBuilder,
      $$CompaniesTableTableUpdateCompanionBuilder,
      (
        CompaniesTableData,
        BaseReferences<_$AppDatabase, $CompaniesTableTable, CompaniesTableData>,
      ),
      CompaniesTableData,
      PrefetchHooks Function()
    >;
typedef $$BattlesTableTableCreateCompanionBuilder =
    BattlesTableCompanion Function({
      required String id,
      required String matchId,
      required String nodeId,
      required String attackerCompanyIds,
      required String defenderCompanyIds,
      required String attackerOwnership,
      required String battleJson,
      Value<int> rowid,
    });
typedef $$BattlesTableTableUpdateCompanionBuilder =
    BattlesTableCompanion Function({
      Value<String> id,
      Value<String> matchId,
      Value<String> nodeId,
      Value<String> attackerCompanyIds,
      Value<String> defenderCompanyIds,
      Value<String> attackerOwnership,
      Value<String> battleJson,
      Value<int> rowid,
    });

class $$BattlesTableTableFilterComposer
    extends Composer<_$AppDatabase, $BattlesTableTable> {
  $$BattlesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attackerCompanyIds => $composableBuilder(
    column: $table.attackerCompanyIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defenderCompanyIds => $composableBuilder(
    column: $table.defenderCompanyIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attackerOwnership => $composableBuilder(
    column: $table.attackerOwnership,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get battleJson => $composableBuilder(
    column: $table.battleJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BattlesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $BattlesTableTable> {
  $$BattlesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchId => $composableBuilder(
    column: $table.matchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attackerCompanyIds => $composableBuilder(
    column: $table.attackerCompanyIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defenderCompanyIds => $composableBuilder(
    column: $table.defenderCompanyIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attackerOwnership => $composableBuilder(
    column: $table.attackerOwnership,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get battleJson => $composableBuilder(
    column: $table.battleJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BattlesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $BattlesTableTable> {
  $$BattlesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => column);

  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<String> get attackerCompanyIds => $composableBuilder(
    column: $table.attackerCompanyIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defenderCompanyIds => $composableBuilder(
    column: $table.defenderCompanyIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attackerOwnership => $composableBuilder(
    column: $table.attackerOwnership,
    builder: (column) => column,
  );

  GeneratedColumn<String> get battleJson => $composableBuilder(
    column: $table.battleJson,
    builder: (column) => column,
  );
}

class $$BattlesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BattlesTableTable,
          BattlesTableData,
          $$BattlesTableTableFilterComposer,
          $$BattlesTableTableOrderingComposer,
          $$BattlesTableTableAnnotationComposer,
          $$BattlesTableTableCreateCompanionBuilder,
          $$BattlesTableTableUpdateCompanionBuilder,
          (
            BattlesTableData,
            BaseReferences<_$AppDatabase, $BattlesTableTable, BattlesTableData>,
          ),
          BattlesTableData,
          PrefetchHooks Function()
        > {
  $$BattlesTableTableTableManager(_$AppDatabase db, $BattlesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BattlesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BattlesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BattlesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<String> nodeId = const Value.absent(),
                Value<String> attackerCompanyIds = const Value.absent(),
                Value<String> defenderCompanyIds = const Value.absent(),
                Value<String> attackerOwnership = const Value.absent(),
                Value<String> battleJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BattlesTableCompanion(
                id: id,
                matchId: matchId,
                nodeId: nodeId,
                attackerCompanyIds: attackerCompanyIds,
                defenderCompanyIds: defenderCompanyIds,
                attackerOwnership: attackerOwnership,
                battleJson: battleJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String matchId,
                required String nodeId,
                required String attackerCompanyIds,
                required String defenderCompanyIds,
                required String attackerOwnership,
                required String battleJson,
                Value<int> rowid = const Value.absent(),
              }) => BattlesTableCompanion.insert(
                id: id,
                matchId: matchId,
                nodeId: nodeId,
                attackerCompanyIds: attackerCompanyIds,
                defenderCompanyIds: defenderCompanyIds,
                attackerOwnership: attackerOwnership,
                battleJson: battleJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BattlesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BattlesTableTable,
      BattlesTableData,
      $$BattlesTableTableFilterComposer,
      $$BattlesTableTableOrderingComposer,
      $$BattlesTableTableAnnotationComposer,
      $$BattlesTableTableCreateCompanionBuilder,
      $$BattlesTableTableUpdateCompanionBuilder,
      (
        BattlesTableData,
        BaseReferences<_$AppDatabase, $BattlesTableTable, BattlesTableData>,
      ),
      BattlesTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MatchesTableTableTableManager get matchesTable =>
      $$MatchesTableTableTableManager(_db, _db.matchesTable);
  $$CastlesTableTableTableManager get castlesTable =>
      $$CastlesTableTableTableManager(_db, _db.castlesTable);
  $$CompaniesTableTableTableManager get companiesTable =>
      $$CompaniesTableTableTableManager(_db, _db.companiesTable);
  $$BattlesTableTableTableManager get battlesTable =>
      $$BattlesTableTableTableManager(_db, _db.battlesTable);
}
