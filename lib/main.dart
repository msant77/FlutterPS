import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/fps_game.dart';
import 'ui/hud_overlay.dart';
import 'ui/endgame_overlay.dart';
import 'ui/level_splash_overlay.dart';
import 'ui/main_menu_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const FpsRaycasterApp());
}

class FpsRaycasterApp extends StatelessWidget {
  const FpsRaycasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final game = FpsGame();

    return MaterialApp(
      title: 'FPS Raycaster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Listener(
          onPointerDown: (_) => game.handlePointerDown(),
          onPointerUp: (_) => game.handlePointerUp(),
          onPointerHover: (event) => game.handlePointerMove(event.delta.dx),
          onPointerMove: (event) => game.handlePointerMove(event.delta.dx),
          child: MouseRegion(
            cursor: game.isRunning ? SystemMouseCursors.none : SystemMouseCursors.basic,
            child: GameWidget<FpsGame>(
              game: game,
              overlayBuilderMap: {
                'hud': (context, game) => HudOverlay(game: game),
                'mainMenu': (context, game) => MainMenuOverlay(game: game),
                'endgame': (context, game) => EndgameOverlay(game: game),
                'levelSplash': (context, game) =>
                    LevelSplashOverlay(game: game),
              },
              initialActiveOverlays: const ['mainMenu'],
            ),
          ),
        ),
      ),
    );
  }
}
