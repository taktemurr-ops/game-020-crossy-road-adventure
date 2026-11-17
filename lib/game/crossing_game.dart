import 'dart:math';

class CrossingGame {
  static const int width = 7;
  static const int goalRow = 8;
  final Random random;
  late List<int> cars;
  int playerX = 3;
  int playerY = 0;
  int score = 0;
  int lives = 3;
  int ticks = 0;
  bool get gameOver => lives <= 0;
  bool get won => playerY >= goalRow;
  CrossingGame({Random? random}) : random = random ?? Random() { reset(); }
  void reset() {
    playerX = 3; playerY = 0; score = 0; lives = 3; ticks = 0;
    cars = List.generate(goalRow - 1, (i) => (i * 3 + 1) % width);
  }
  bool get collision => playerY > 0 && playerY < goalRow &&
      cars[playerY - 1] == playerX;
  void _checkCollision() {
    if (collision) {
      lives--;
      playerX = 3;
      playerY = 0;
    }
  }
  bool move(int dx, int dy) {
    if (gameOver || won || dx.abs() + dy.abs() != 1) return false;
    final nx = playerX + dx, ny = playerY + dy;
    if (nx < 0 || nx >= width || ny < 0 || ny > goalRow) return false;
    playerX = nx; playerY = ny;
    if (dy > 0) score += 10;
    _checkCollision();
    return true;
  }
  void tick() {
    if (gameOver || won) return;
    ticks++;
    for (var i = 0; i < cars.length; i++) {
      cars[i] = (cars[i] + (i.isEven ? 1 : width - 1)) % width;
    }
    _checkCollision();
  }
}
