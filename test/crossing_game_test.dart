import 'package:flutter_test/flutter_test.dart';
import 'package:game_020_crossy_road_adventure/game/crossing_game.dart';

void main() {
  test('starts in safe row with three lives', () {
    final g = CrossingGame();
    expect(g.playerY, 0);
    expect(g.lives, 3);
    expect(g.gameOver, false);
  });
  test('rejects out of bounds and diagonal moves', () {
    final g = CrossingGame();
    expect(g.move(1, 1), false);
    expect(g.move(0, -1), false);
    expect(g.playerY, 0);
  });
  test('forward progress awards points', () {
    final g = CrossingGame();
    expect(g.move(0, 1), true);
    expect(g.score, 10);
  });
  test('traffic moves deterministically and wraps', () {
    final g = CrossingGame();
    final initial = List<int>.from(g.cars);
    g.tick();
    expect(g.cars[0], (initial[0] + 1) % CrossingGame.width);
    expect(g.cars[1], (initial[1] + CrossingGame.width - 1) % CrossingGame.width);
  });
  test('collision consumes a life and returns player to start', () {
    final g = CrossingGame();
    g.cars[0] = g.playerX;
    g.move(0, 1);
    expect(g.lives, 2);
    expect(g.playerY, 0);
  });
  test('restart resets state', () {
    final g = CrossingGame();
    g.move(0, 1);
    g.tick();
    g.reset();
    expect(g.score, 0);
    expect(g.ticks, 0);
    expect(g.lives, 3);
  });
}
