import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/arcade_stage.dart';
import '../app/game_api.dart';
import '../app/play_kit.dart';
import '../app/services/audio.dart';
import '../core/arcade.dart';
import '../core/game_rules.dart';
import 'crossy_engine.dart';
import 'rules.dart';

void paintCrossy(Canvas c, ArcadeSim sim, ArcadePalette p, double t) {
  final s = sim as CrossySim;
  const rowH = 112.0;
  // Player drawn around y=1150; rows above.
  final hopF = s.hopping ? s.hopT / kHopTicks : 0.0;
  final camRow = s.hopping ? s.fromRow + (s.toRow - s.fromRow) * hopF : s.row.toDouble();
  double yOf(int r) => 1150 - (r - camRow) * rowH;
  final first = (camRow - 4).floor(), last = (camRow + 12).ceil();
  for (var r = math.max(0, first); r <= last; r++) {
    final l = s.lane(r);
    final y = yOf(r);
    final rect = Rect.fromLTWH(0, y - rowH / 2, kWorldW, rowH);
    switch (l.type) {
      case kGrass:
        c.drawRect(rect, Paint()..color = Color(r.isEven ? 0xFF74C69D : 0xFF6AB98F));
        for (final tr in l.trees) {
          final o = Offset((tr + 0.5) * kCell, y);
          c.drawRect(Rect.fromCenter(center: o.translate(0, 20), width: 18, height: 40), Paint()..color = const Color(0xFF7F5539));
          c.drawCircle(o.translate(0, -10), 40, Paint()..color = const Color(0xFF2D6A4F));
        }
        if (l.coin >= 0 && !s.coinTaken.contains(r)) {
          c.drawCircle(Offset((l.coin + 0.5) * kCell, y), 22, Paint()..color = const Color(0xFFFFD60A));
          paintText(c, '¢', Offset((l.coin + 0.5) * kCell, y), 28, Colors.brown);
        }
      case kRoad:
        c.drawRect(rect, Paint()..color = const Color(0xFF495057));
        for (var x = 20.0; x < kWorldW; x += 110) {
          c.drawRect(Rect.fromLTWH(x, y - 3, 50, 6), Paint()..color = Colors.white30);
        }
        for (final (x, w) in l.visible(s.ticks)) {
          final car = Rect.fromLTWH(x + 6, y - 36, w - 12, 72);
          c.drawRRect(RRect.fromRectAndRadius(car, const Radius.circular(14)), Paint()..color = p.piece(r % 6));
          c.drawRect(Rect.fromLTWH(l.speed > 0 ? car.right - 30 : car.left + 10, car.top + 10, 20, car.height - 20),
              Paint()..color = Colors.white54);
        }
      case kRiver:
        c.drawRect(rect, Paint()..color = const Color(0xFF00B4D8));
        for (final (x, w) in l.visible(s.ticks)) {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 4, y - 32, w - 8, 64), const Radius.circular(20)),
              Paint()..color = const Color(0xFF8B5E34));
        }
      case kRail:
        c.drawRect(rect, Paint()..color = const Color(0xFF6C757D));
        for (var x = 0.0; x < kWorldW; x += 60) {
          c.drawRect(Rect.fromLTWH(x, y - 30, 20, 60), Paint()..color = const Color(0xFF7F5539));
        }
        c.drawRect(Rect.fromLTWH(0, y - 22, kWorldW, 6), Paint()..color = Colors.white54);
        c.drawRect(Rect.fromLTWH(0, y + 16, kWorldW, 6), Paint()..color = Colors.white54);
        if (l.trainWarning(s.ticks)) {
          paintText(c, '⚠', Offset(60, y), 56, (s.ticks ~/ 8).isEven ? Colors.red : Colors.white);
        }
        if (l.trainHere(s.ticks)) {
          c.drawRect(Rect.fromLTWH(0, y - 44, kWorldW, 88), Paint()..color = const Color(0xFFD00000));
        }
      default:
        c.drawRect(rect, Paint()..color = const Color(0xFFFFD60A));
        paintText(c, '🏁', Offset(kWorldW / 2, y), 64, Colors.black);
    }
  }
  // player (chicken-like block)
  final px = s.hopping ? s.fromX + (s.toX - s.fromX) * hopF : s.x;
  final jump = s.hopping ? math.sin(hopF * math.pi) * 40 : 0.0;
  final o = Offset(px, 1150 - jump);
  final blink = s.shield > 0 && (s.ticks ~/ 5).isOdd;
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 64, height: 64), const Radius.circular(12)),
      Paint()..color = blink ? Colors.white38 : Colors.white);
  c.drawRect(Rect.fromCenter(center: o.translate(0, -36), width: 18, height: 14), Paint()..color = const Color(0xFFE63946));
  c.drawRect(Rect.fromCenter(center: o.translate(0, 6), width: 16, height: 10), Paint()..color = const Color(0xFFFF9F1C));
  c.drawCircle(o.translate(-14, -8), 5, Paint()..color = Colors.black);
  c.drawCircle(o.translate(14, -8), 5, Paint()..color = Colors.black);
  if (s.level.eagle && s.idle > 60 * 4) {
    paintText(c, '🦅', Offset(px, 260), 90, Colors.white);
  }
}

Sfx? crossySound(ArcadeSim sim) => switch ((sim as CrossySim).lastEvent) {
      1 => Sfx.tap,
      2 => Sfx.coin,
      3 => Sfx.lose,
      4 => Sfx.lose,
      _ => null,
    };

final gameConfig = GameConfig(
  gameId: 'game-020-crossy-road-adventure',
  title: const ['Yol Geçme Macerası', 'Crossy Road Adventure', 'Straßenquerung', 'Aventura Cruzar', 'Aventure Traversée'],
  tagline: const ['Yollardan, nehirlerden, raylardan atla!', 'Hop across roads, rivers and rails!', 'Hüpf über Straßen, Flüsse, Gleise!', '¡Salta carreteras, ríos y vías!', 'Traversez routes, rivières, rails !'],
  seedColor: const Color(0xFFFFB703),
  icon: Icons.directions_walk,
  rules: CrossyRules(),
  buildPlay: (ctx) => ArcadeStage(
    ctx: ctx,
    create: () => CrossySim((ctx.generated as GeneratedLevel<CrossyLevel>).puzzle),
    paint: paintCrossy,
    sound: crossySound,
    howTo: const [
      'İleri zıplamak için dokun, yana/geri için kaydır.',
      'Tap to hop forward, swipe to move sideways or back.',
      'Tippen zum Vorhüpfen, wischen zur Seite.',
      'Toca para avanzar, desliza a los lados.',
      'Touchez pour avancer, glissez sur les côtés.',
    ],
  ),
  tutorial: const [
    TutorialStep(Icons.touch_app, [
      'Dokun: ileri. Kaydır: sola, sağa, geri. Klavye: ok tuşları.',
      'Tap: forward. Swipe: left, right, back. Keyboard: arrows.',
      'Tippen: vor. Wischen: links/rechts/zurück.',
      'Toca: adelante. Desliza: lados, atrás.',
      'Toucher : avancer. Glisser : côtés, arrière.',
    ]),
    TutorialStep(Icons.directions_car, [
      'Arabalara ve uyarı veren trene dikkat; nehirde kütüklerin üstünde kal.',
      'Watch cars and the warned train; stay on logs in rivers.',
      'Achte auf Autos und Züge; bleib auf Stämmen.',
      'Cuidado con coches y trenes; quédate sobre troncos.',
      'Attention aux voitures et trains ; restez sur les rondins.',
    ]),
    TutorialStep(Icons.timer, [
      'Çok beklersen kartal kapar! Jetonları toplamayı unutma.',
      'Wait too long and the eagle grabs you! Collect coins.',
      'Wartest du zu lange, holt dich der Adler!',
      '¡Si esperas mucho, el águila te atrapa!',
      'Si vous attendez trop, l\'aigle vous attrape !',
    ]),
  ],
);
