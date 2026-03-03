import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';

void main() {
  late Company attackerCompany;
  late Company defenderCompany;

  setUp(() {
    attackerCompany = Company(composition: {UnitRole.warrior: 10});
    defenderCompany = Company(composition: {UnitRole.archer: 5});
  });

  group('Battle', () {
    group('construction', () {
      test('can be constructed with non-empty attacker and defender lists', () {
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );
        expect(battle.attackers, isNotEmpty);
        expect(battle.defenders, isNotEmpty);
      });

      test('throws when attackers list is empty', () {
        expect(
          () => Battle(attackers: [], defenders: [defenderCompany]),
          throwsArgumentError,
        );
      });

      test('throws when defenders list is empty', () {
        expect(
          () => Battle(attackers: [attackerCompany], defenders: []),
          throwsArgumentError,
        );
      });
    });

    group('initial round state', () {
      test('roundNumber starts at zero', () {
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );
        expect(battle.roundNumber, equals(0));
      });

      test('roundLog starts empty', () {
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );
        expect(battle.roundLog, isEmpty);
      });
    });

    group('outcome field', () {
      test('outcome starts null (battle not yet resolved)', () {
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany],
        );
        expect(battle.outcome, isNull);
      });
    });

    group('participants', () {
      test('multiple attackers are supported', () {
        final second = Company(composition: {UnitRole.knight: 5});
        final battle = Battle(
          attackers: [attackerCompany, second],
          defenders: [defenderCompany],
        );
        expect(battle.attackers.length, equals(2));
      });

      test('multiple defenders are supported', () {
        final second = Company(composition: {UnitRole.knight: 5});
        final battle = Battle(
          attackers: [attackerCompany],
          defenders: [defenderCompany, second],
        );
        expect(battle.defenders.length, equals(2));
      });
    });
  });
}
