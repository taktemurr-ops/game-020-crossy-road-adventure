import 'dart:math' as math;

import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';

const int kGrass = 0, kRoad = 1, kRiver = 2, kRail = 3, kFinish = 4;
const int kCols = 9;
const double kCell = kWorldW / kCols;
const int kHopTicks = 8;

class Lane {
  final int type;
  final double speed; // units per tick, signed
  final double period;
  final double offset;
  final List<(double, double)> segs; // (start, length) within period
  final Set<int> trees;
  final int coin; // column or -1
  final int railCycle;
  final int railPhase;

  const Lane(this.type,
      {this.speed = 0,
      this.period = 1,
      this.offset = 0,
      this.segs = const [],
      this.trees = const {},
      this.coin = -1,
      this.railCycle = 0,
      this.railPhase = 0});

  double _u(double x, int t) {
    var u = (x - offset - speed * t) % period;
    if (u < 0) u += period;
    return u;
  }

  /// True if something occupies [x-hw, x+hw] at tick t.
  bool occupied(double x, int t, double hw) {
    final u = _u(x, t);
    for (final s in segs) {
      for (final base in [s.$1, s.$1 - period, s.$1 + period]) {
        if (u + hw > base && u - hw < base + s.$2) return true;
      }
    }
    return false;
  }

  /// Logs: x is safely on a log.
  bool onLog(double x, int t) {
    final u = _u(x, t);
    for (final s in segs) {
      for (final base in [s.$1, s.$1 - period, s.$1 + period]) {
        if (u > base + 12 && u < base + s.$2 - 12) return true;
      }
    }
    return false;
  }

  /// Segment world x positions at tick t (for painting).
  List<(double, double)> visible(int t) {
    final out = <(double, double)>[];
    for (final s in segs) {
      var x = (s.$1 + offset + speed * t) % period;
      if (x < 0) x += period;
      for (var k = -1; k <= 1; k++) {
        final xx = x + k * period;
        if (xx + s.$2 > -50 && xx < kWorldW + 50) out.add((xx, s.$2));
      }
    }
    return out;
  }

  int railT(int t) => (t + railPhase) % railCycle;
  bool trainWarning(int t) => type == kRail && railT(t) >= railCycle - 70;
  bool trainHere(int t) => type == kRail && railT(t) < 45;
}

class CrossyLevel {
  final ArcadeMeta meta;
  final int target; // rows, 0 = endless
  final bool rivers, rails, eagle, busy, coins;

  const CrossyLevel({
    required this.meta,
    required this.target,
    required this.rivers,
    required this.rails,
    required this.eagle,
    required this.busy,
    required this.coins,
  });
}

CrossyLevel generateCrossyLevel(LevelSpec spec) {
  final m = ArcadeMeta.of(spec);
  final d = spec.difficulty;
  return CrossyLevel(
    meta: m,
    target: m.goal ? 25 + d * 8 : 0,
    rivers: spec.has('rivers') || d >= 3,
    rails: spec.has('rails') || d >= 5,
    eagle: spec.has('eagle') || !m.goal,
    busy: spec.has('busy'),
    coins: spec.has('coins') || !m.goal,
  );
}

class CrossySim extends ArcadeSim {
  final CrossyLevel level;
  final Map<int, Lane> _lanes;
  int row = 0;
  double x = (kCols ~/ 2 + 0.5) * kCell;
  int hopT = 0;
  int fromRow = 0, toRow = 0;
  double fromX = 0, toX = 0;
  int maxRow = 0;
  int idle = 0;
  int coins = 0, hops = 0;
  final Set<int> coinTaken = {};
  int lastEvent = 0; // 1 hop, 2 coin, 3 splash, 4 crash

  /// Autopilot memory (not part of the game state).
  int botWait = 0;

  CrossySim(this.level) : _lanes = {}, super(level.meta);

  CrossySim._copy(CrossySim o)
      : level = o.level,
        _lanes = o._lanes,
        super(o.meta) {
    row = o.row;
    x = o.x;
    hopT = o.hopT;
    fromRow = o.fromRow;
    toRow = o.toRow;
    fromX = o.fromX;
    toX = o.toX;
    maxRow = o.maxRow;
    idle = o.idle;
    ticks = o.ticks;
    lives = o.lives;
    shield = o.shield;
    slow = o.slow;
    score = o.score;
    coinTaken.addAll(o.coinTaken);
  }

  CrossySim copy() => CrossySim._copy(this);

  int get difficulty => meta.difficulty;

  Lane lane(int r) {
    final l = _lanes[r];
    if (l != null) return l;
    final n = _makeLane(r);
    _lanes[r] = n;
    return n;
  }

  int typeOf(int r) {
    if (r <= 1) return kGrass;
    if (level.target > 0 && r >= level.target) return kFinish;
    final rr = SeededRandom(mixSeed([meta.seed, r, 2020]));
    // Never more than 4 hazard rows in a row.
    var run = 0;
    for (var k = r - 1; k >= 0 && k >= r - 4; k--) {
      if (typeOf0(k) == kGrass) break;
      run++;
    }
    if (run >= 4) return kGrass;
    final w = [
      4,
      5 + difficulty ~/ 2 + (level.busy ? 2 : 0),
      level.rivers ? 3 : 0,
      level.rails ? 2 : 0,
    ];
    return rr.weighted(w);
  }

  int typeOf0(int r) => lane(r).type;

  Lane _makeLane(int r) {
    final t = typeOf(r);
    final rr = SeededRandom(mixSeed([meta.seed, r, 77]));
    final d = difficulty;
    switch (t) {
      case kRoad:
        final speed = (1.6 + rr.nextDouble() * (1.2 + d * 0.35)) * (rr.chance(0.5) ? 1 : -1);
        final period = 1200 + rr.nextDouble() * 600;
        final cars = 1 + rr.nextInt(2 + (level.busy ? 1 : 0));
        final segs = <(double, double)>[];
        for (var i = 0; i < cars; i++) {
          segs.add((i * period / cars + rr.nextDouble() * 80, rr.chance(0.3) ? kCell * 1.9 : kCell * 0.95));
        }
        return Lane(kRoad, speed: speed, period: period, offset: rr.nextDouble() * period, segs: segs);
      case kRiver:
        final speed = (1.2 + rr.nextDouble() * (0.8 + d * 0.2)) * (r.isEven ? 1 : -1);
        final period = 1100 + rr.nextDouble() * 300;
        final logs = 3;
        final segs = <(double, double)>[];
        for (var i = 0; i < logs; i++) {
          segs.add((i * period / logs, kCell * (2.2 + rr.nextDouble() * 1.3)));
        }
        return Lane(kRiver, speed: speed, period: period, offset: rr.nextDouble() * period, segs: segs);
      case kRail:
        return Lane(kRail, railCycle: 300 + rr.nextInt(240), railPhase: rr.nextInt(400));
      case kFinish:
        return const Lane(kFinish);
      default:
        final trees = <int>{};
        if (r > 1) {
          final n = rr.nextInt(3 + d ~/ 3);
          for (var i = 0; i < n; i++) {
            final c = rr.nextInt(kCols);
            if (c != kCols ~/ 2) trees.add(c);
          }
        }
        var coin = -1;
        if (level.coins && rr.chance(0.3)) {
          coin = rr.nextInt(kCols);
          if (trees.contains(coin)) coin = -1;
        }
        return Lane(kGrass, trees: trees, coin: coin);
    }
  }

  int get col => (x / kCell).floor().clamp(0, kCols - 1);

  bool get hopping => hopT > 0;

  /// 0 up, 1 right, 2 down, 3 left.
  bool hop(int dir) {
    if (hopping || over) return false;
    var nr = row, nx = x;
    if (dir == 0) nr++;
    if (dir == 2) nr = math.max(0, row - 1);
    if (dir == 1) nx = x + kCell;
    if (dir == 3) nx = x - kCell;
    if (nx < kCell * 0.3 || nx > kWorldW - kCell * 0.3) return false;
    final targetLane = lane(nr);
    if (targetLane.type != kRiver) {
      nx = ((nx / kCell).floor().clamp(0, kCols - 1) + 0.5) * kCell;
    }
    if (targetLane.type == kGrass && targetLane.trees.contains((nx / kCell).floor())) return false;
    if (nr == row && nx == x) return false;
    fromRow = row;
    toRow = nr;
    fromX = x;
    toX = nx;
    hopT = 1;
    hops++;
    lastEvent = 1;
    return true;
  }

  @override
  void update(ArcadeInput input) {
    lastEvent = 0;
    if (!hopping) {
      if (input.swipe >= 0) {
        hop(input.swipe);
      } else if (input.tap) {
        hop(0);
      } else if (input.dirY < 0) {
        hop(0);
      }
    }
    final l = lane(row);
    if (hopping) {
      hopT++;
      // Logs carry the target position too.
      final tl = lane(toRow);
      if (tl.type == kRiver) toX += tl.speed;
      if (hopT > kHopTicks) {
        hopT = 0;
        row = toRow;
        x = toX;
        _arrive();
      }
    } else if (l.type == kRiver) {
      x += l.speed;
    }
    if (!hopping) _check();
    idle++;
    if (level.eagle && idle > 60 * 7) {
      idle = 0;
      lastEvent = 4;
      hit();
    }
  }

  void _arrive() {
    if (row > maxRow) {
      score += 10 * (row - maxRow);
      maxRow = row;
      idle = 0;
    }
    final l = lane(row);
    if (l.type == kGrass && l.coin == col && coinTaken.add(row)) {
      coins++;
      score += 25;
      lastEvent = 2;
    }
    if (l.type == kFinish || (level.target > 0 && row >= level.target)) win();
  }

  void _check() {
    if (over) return;
    final l = lane(row);
    switch (l.type) {
      case kRoad:
        if (l.occupied(x, ticks, 38)) {
          lastEvent = 4;
          hit();
        }
      case kRiver:
        if (!l.onLog(x, ticks) || x < 0 || x > kWorldW) {
          lastEvent = 3;
          hit();
        }
      case kRail:
        if (l.trainHere(ticks)) {
          lastEvent = 4;
          hit();
        }
    }
  }

  @override
  void onLifeLost() {
    var r = row;
    while (r > 0 && lane(r).type != kGrass) {
      r--;
    }
    row = r;
    hopT = 0;
    idle = 0;
    var c = kCols ~/ 2;
    while (lane(r).trees.contains(c)) {
      c = (c + 1) % kCols;
    }
    x = (c + 0.5) * kCell;
  }

  @override
  void hit() {
    if (meta.zen && !over) {
      onLifeLost();
      return;
    }
    super.hit();
  }

  @override
  double get progress => level.target == 0 ? 0 : maxRow / level.target;

  @override
  String get goalText => level.target == 0 ? '$maxRow' : '$maxRow/${level.target}';

  @override
  Map<String, int> get stats => {'rows_crossed': maxRow, 'coins': coins, 'hops': hops};

  @override
  int get stars => lifeStars(this, 3);
}

/// Autopilot: short look-ahead search over hop/wait actions using copies
/// of the (deterministic) simulation.
ArcadeInput crossyBot(ArcadeSim sim) {
  final s = sim as CrossySim;
  if (s.hopping || s.ticks < s.botWait) return ArcadeInput.idle;
  final best = _search(s, 3);
  if (best.$2 < 0) {
    s.botWait = s.ticks + 4;
    return ArcadeInput.idle; // wait
  }
  return ArcadeInput(swipe: best.$2);
}

/// Returns (value, firstAction) where action -1 = wait.
(double, int) _search(CrossySim s, int depth) {
  const actions = [0, -1, 1, 3, 2];
  var bestV = -1e9;
  var bestA = -1;
  for (final a in actions) {
    final c = s.copy();
    final lives = c.lives;
    var ok = true;
    if (a >= 0) {
      if (!c.hop(a)) continue;
      for (var i = 0; i <= kHopTicks && ok; i++) {
        c.tick(ArcadeInput.idle);
        if (c.lives < lives || c.over && !c.won) ok = false;
      }
    } else {
      for (var i = 0; i < 5 && ok; i++) {
        c.tick(ArcadeInput.idle);
        if (c.lives < lives || c.over && !c.won) ok = false;
      }
    }
    if (!ok) continue;
    double v;
    if (c.won) {
      v = 1e6;
    } else if (depth > 1) {
      v = _search(c, depth - 1).$1;
      if (v <= -1e9) continue;
    } else {
      // Leaf: must survive a short wait too.
      final w = c.copy();
      var safe = true;
      for (var i = 0; i < 6; i++) {
        w.tick(ArcadeInput.idle);
        if (w.lives < lives) safe = false;
      }
      final mid = (c.x - kWorldW / 2).abs() / kWorldW;
      v = c.row * 10.0 - mid * 3 + (safe ? 0 : -6);
    }
    v -= a == -1 ? 0.5 : 0;
    if (v > bestV) {
      bestV = v;
      bestA = a;
    }
  }
  return (bestV, bestA);
}
