import 'dart:async';
import 'package:flutter/material.dart';
import 'game/crossing_game.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: CrossingScreen()));

class CrossingScreen extends StatefulWidget {
  const CrossingScreen({super.key});
  @override
  State<CrossingScreen> createState() => _CrossingScreenState();
}

class _CrossingScreenState extends State<CrossingScreen> {
  final game = CrossingGame();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 750), (_) {
      if (mounted) setState(game.tick);
    });
  }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  void move(int dx, int dy) => setState(() => game.move(dx, dy));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Crossy Road Adventure'),
      actions: [IconButton(tooltip: 'Restart', icon: const Icon(Icons.refresh),
        onPressed: () => setState(game.reset))]),
    body: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Score: ${game.score}    Lives: ${game.lives}',
        style: Theme.of(context).textTheme.titleLarge),
      if (game.won) const Text('You crossed safely!'),
      if (game.gameOver) const Text('Game over — tap restart'),
      const SizedBox(height: 12),
      AspectRatio(aspectRatio: 7 / 9, child: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 9 * CrossingGame.width,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: CrossingGame.width),
          itemBuilder: (context, index) {
            final x = index % CrossingGame.width;
            final y = 8 - index ~/ CrossingGame.width;
            final isPlayer = game.playerX == x && game.playerY == y;
            final isCar = y > 0 && y < 8 && game.cars[y - 1] == x;
            return Container(margin: const EdgeInsets.all(1),
              color: y == 0 || y == 8 ? Colors.green.shade700 : Colors.grey.shade800,
              child: Center(child: isPlayer ? const Icon(Icons.pets, color: Colors.yellow)
                : isCar ? const Icon(Icons.directions_car, color: Colors.redAccent) : null));
          }))),
      IconButton(tooltip: 'Up', iconSize: 42, onPressed: () => move(0, 1), icon: const Icon(Icons.arrow_upward)),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(tooltip: 'Left', iconSize: 42, onPressed: () => move(-1, 0), icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 48),
        IconButton(tooltip: 'Right', iconSize: 42, onPressed: () => move(1, 0), icon: const Icon(Icons.arrow_forward)),
      ]),
      IconButton(tooltip: 'Down', iconSize: 42, onPressed: () => move(0, -1), icon: const Icon(Icons.arrow_downward)),
    ])),
  );
}
