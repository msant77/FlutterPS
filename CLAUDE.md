# MemeSlayer

Meme-themed maze escape FPS built with Flutter + Flame for macOS. DDA raycasting engine (Wolfenstein 3D style) with procedural generation for everything — mazes, textures, sprites, sounds.

## Quick Commands

```sh
flutter analyze
flutter test
flutter run -d macos
```

## Architecture

```
lib/
├── main.dart                  # App entry, GameWidget + Listener for input
├── game/fps_game.dart         # FlameGame — game loop, state, level progression
├── engine/
│   ├── raycaster.dart         # DDA raycasting algorithm
│   ├── renderer.dart          # Canvas rendering (walls, enemies, minimap)
│   ├── textures.dart          # Procedural wall textures (64x64 Uint32List → ui.Image)
│   ├── sprites.dart           # Pixel-art meme sprites (Trollface, Doge, Grumpy Cat, Stonks Man)
│   └── audio.dart             # Synthesized WAV sounds (sine waves + noise → BytesSource)
├── entities/
│   ├── player.dart            # Movement, collision, shooting, 4-corner bounding box
│   └── enemy.dart             # AI state machine + alignment (hostile/friendly/neutral)
├── world/
│   ├── game_map.dart          # 2D tile grid, spawn points with alignment
│   └── maze_generator.dart    # Recursive backtracker + room carving
└── ui/
    ├── hud_overlay.dart       # Health, ammo, score, level, lives
    ├── main_menu_overlay.dart # MemeSlayer title screen
    ├── level_splash_overlay.dart # Between-level transition
    └── endgame_overlay.dart   # Win/lose/game over with kill breakdown
```

## Key Design Decisions

- **DDA raycasting** over true 3D for simplicity and performance in Flutter's Canvas API
- **Flame** provides game loop and keyboard input; all rendering is custom Canvas
- **Zero external assets** — textures, sprites, and sounds all procedurally generated
- **Hitscan shooting** — instant ray check from player to crosshair direction
- **Alignment system** — hostile/friendly/neutral NPCs with scoring consequences
- **Progressive difficulty** — maze size and enemy types scale with level
- **Mouse smoothing** — accumulated delta with decay factor for trackpad input
- **Keyboard turn acceleration** — ramp-up/decel curve for arrow key turning
