# MemeSlayer

Retro first-person shooter built with Flutter + Flame for macOS. DDA raycasting engine (Wolfenstein 3D style) with procedural maze generation, enemy AI, and a path toward meme-themed chaos.

## Quick Start

```sh
flutter run -d macos
```

## Controls

| Key | Action |
|-----|--------|
| WASD | Move/strafe |
| Arrow keys | Turn/move |
| Q / E | Snap turn 90° |
| Space / Click | Shoot |
| Shift | Sprint |
| M | Toggle minimap |
| ESC | Menu |

## Roadmap

```mermaid
gantt
    title MemeSlayer Development Roadmap
    dateFormat YYYY-MM-DD
    axisFormat %b %Y

    section Foundation
    Core raycasting engine           :done,    core,    2026-03-01, 2026-03-15
    Procedural maze generation       :done,    maze,    2026-03-15, 2026-03-20
    Enemy AI & combat                :done,    ai,      2026-03-10, 2026-03-20
    HUD & game flow                  :done,    hud,     2026-03-18, 2026-03-22
    Test suite                       :done,    tests,   2026-03-25, 2026-03-26

    section Meme Integration
    Pixel-art meme sprites           :active,  sprites, 2026-03-27, 2026-04-05
    Hostile vs friendly alignment    :         align,   2026-04-05, 2026-04-12
    Sound effects & music            :         audio,   2026-04-10, 2026-04-18

    section Progression
    Multi-level & difficulty scaling :         levels,  2026-04-15, 2026-04-25
    Scoring & leaderboard            :         score,   2026-04-20, 2026-04-28
    Rebrand to MemeSlayer            :         brand,   2026-04-25, 2026-05-05
```

### Phase Breakdown

**Phase 1 — Foundation** (Done)
- DDA raycasting with textured walls and fog
- Procedural maze generation (recursive backtracker + room carving)
- 4 enemy types with state-machine AI (grunt, imp, brute, sentinel)
- Line-of-sight detection, hitscan combat, pickups
- Win/lose conditions, HUD, main menu, endgame stats
- 33 unit tests covering core systems

**Phase 2 — Meme Integration** (Next)
- Issue #3: Replace geometric enemies with pixel-art meme sprites
- Issue #4: Friendly vs hostile NPCs (some memes help, some attack)
- Issue #5: Sound effects and background music

**Phase 3 — Progression**
- Issue #6: Multi-level progression with scaling difficulty
- Scoring system with meme-specific point values
- Issue #7: Full rebrand — MemeSlayer identity, splash screen, polish

## Architecture

```
lib/
├── main.dart              # App entry, GameWidget + Listener for input
├── game/fps_game.dart     # FlameGame — game loop, state, rendering
├── engine/
│   ├── raycaster.dart     # DDA raycasting algorithm
│   ├── renderer.dart      # Canvas rendering (walls, enemies, minimap)
│   └── textures.dart      # Procedural texture generation
├── entities/
│   ├── player.dart        # Movement, collision, shooting
│   └── enemy.dart         # AI state machine (idle/chase/attack/dead)
├── world/
│   ├── game_map.dart      # 2D tile grid, spawn points
│   └── maze_generator.dart # Recursive backtracker maze gen
└── ui/
    ├── hud_overlay.dart
    ├── main_menu_overlay.dart
    └── endgame_overlay.dart
```

## Development

```sh
flutter analyze    # Lint
flutter test       # Run tests
flutter run -d macos
```
