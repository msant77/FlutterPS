# FPS Raycaster

Retro first-person shooter built with Flutter + Flame for macOS. Uses a DDA raycasting engine (Wolfenstein 3D style) rendering pseudo-3D from a 2D tile map.

## Architecture

```
lib/
├── main.dart              # App entry, GameWidget setup
├── game/
│   └── fps_game.dart      # FlameGame subclass — game loop, input, state
├── engine/
│   ├── raycaster.dart     # DDA raycasting algorithm
│   └── renderer.dart      # Canvas rendering (walls, sky, floor, minimap, weapon)
├── entities/
│   ├── player.dart        # Player state, movement, collision, shooting
│   └── enemy.dart         # Enemy AI state machine (idle/chase/attack/dead)
├── world/
│   └── game_map.dart      # 2D tile grid, level layout, spawn points
└── ui/
    ├── hud_overlay.dart   # Health, ammo, score overlay
    └── main_menu_overlay.dart  # Title screen with controls
```

## Quick Commands

```sh
flutter analyze
flutter test
flutter run -d macos
```

## Controls

| Key | Action |
|-----|--------|
| WASD | Move/strafe |
| Arrow keys | Turn/move |
| Space | Shoot |
| Shift | Sprint |
| M | Toggle minimap |
| ESC | Menu |

## Key Design Decisions

- **DDA raycasting** over true 3D for simplicity and performance in Flutter's Canvas API
- **Flame** provides game loop and keyboard input handling; rendering is custom Canvas
- **No textures yet** — walls are procedurally colored by tile type and face orientation
- **Hitscan shooting** — instant ray check from player to crosshair direction
- **Enemies** are simple billboard sprites drawn with Canvas shapes (no image assets)

## Next Steps (ideas)

- Wall textures via image sampling
- More enemy types and behaviors
- Sound effects (flame_audio)
- Multiple levels
- Mouse look support
- Weapon switching
