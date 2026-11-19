import 'package:flutter_test/flutter_test.dart';
import 'package:game_020_crossy_road_adventure/core/arcade.dart';
import 'package:game_020_crossy_road_adventure/core/level_plan.dart';
import 'package:game_020_crossy_road_adventure/game/crossy_engine.dart';
import 'package:game_020_crossy_road_adventure/game/rules.dart';

void main() {
  final rules = CrossyRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('tap hops forward one row', () {
    final s = CrossySim(rules.build(planner.spec(1)).puzzle);
    s.tick(const ArcadeInput(tap: true));
    for (var i = 0; i < kHopTicks + 1; i++) {
      s.tick(ArcadeInput.idle);
    }
    expect(s.row, 1);
    expect(s.maxRow, 1);
  });

  test('lanes are deterministic and never more than 4 hazards in a row', () {
    final a = CrossySim(rules.build(planner.spec(200)).puzzle);
    final b = CrossySim(rules.build(planner.spec(200)).puzzle);
    var run = 0;
    for (var r = 0; r < 80; r++) {
      expect(a.lane(r).type, b.lane(r).type);
      final t = a.lane(r).type;
      run = t == kGrass || t == kFinish ? 0 : run + 1;
      expect(run, lessThanOrEqualTo(4));
    }
  });

  test('standing in the river drowns, a copy does not touch the original', () {
    final s = CrossySim(rules.build(planner.spec(1)).puzzle);
    final c = s.copy();
    c.row = 5;
    expect(s.row, 0);
    expect(c.lane(3).type, s.lane(3).type);
  });
}
