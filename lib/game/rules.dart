import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';
import 'crossy_engine.dart';

class CrossyRules extends ArcadeRules<CrossyLevel> {
  @override
  String get gameId => 'game-020-crossy-road-adventure';

  @override
  List<String> get optionalMechanics => const ['rivers', 'rails', 'eagle', 'busy', 'coins'];

  @override
  List<GameStat> get gameStats => const [
        GameStat('rows_crossed', 'Geçilen satır', 'Rows crossed', scale: 100),
        GameStat('coins', 'Jeton', 'Coins', scale: 30),
        GameStat('hops', 'Zıplama', 'Hops', scale: 300),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('rows_crossed', 'rows_crossed', [33, 66, 100]),
        MissionTemplate('coins', 'coins', [10, 20, 30]),
      ];

  @override
  CrossyLevel generate(LevelSpec spec) => generateCrossyLevel(spec);

  @override
  ArcadeMeta metaOf(CrossyLevel l) => l.meta;

  @override
  ArcadeSim createSim(CrossyLevel l) => CrossySim(l);

  @override
  ArcadeInput bot(ArcadeSim sim) => crossyBot(sim);
}

ArcadeRules createRules() => CrossyRules();
