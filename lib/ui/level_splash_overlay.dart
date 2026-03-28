import 'package:flutter/material.dart';

import '../game/fps_game.dart';

/// Brief splash screen shown between levels.
class LevelSplashOverlay extends StatefulWidget {
  final FpsGame game;

  const LevelSplashOverlay({super.key, required this.game});

  @override
  State<LevelSplashOverlay> createState() => _LevelSplashOverlayState();
}

class _LevelSplashOverlayState extends State<LevelSplashOverlay> {
  @override
  void initState() {
    super.initState();
    // Auto-advance after 2 seconds, then auto-save
    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted) {
        await widget.game.nextLevel();
        await widget.game.autoSave();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nextLevel = widget.game.level + 1;
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LEVEL ${widget.game.level} CLEAR',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.greenAccent,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Score: ${widget.game.score}',
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontFamily: 'Courier',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lives: ${'♥ ' * widget.game.lives}',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'ENTERING LEVEL $nextLevel',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.amber,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                color: Colors.amber,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
