import 'dart:ui';

import '../entities/enemy.dart';

/// Tile types for the game map.
enum Tile {
  empty,
  wall,
  wallAlt,
  door,
  lockedDoor,
  spawn,
  enemySpawn,
  healthPickup,
  ammoPickup,
  exit,
  mazeGoal,
}

/// Spawn point with position, enemy type, and alignment.
class EnemySpawnPoint {
  final Offset position;
  final EnemyType type;
  final EnemyAlignment alignment;

  const EnemySpawnPoint(this.position, this.type,
      [this.alignment = EnemyAlignment.hostile]);
}

/// The game world defined as a 2D grid.
class GameMap {
  final int width;
  final int height;
  final List<List<Tile>> grid;
  Offset playerSpawn;
  Offset? exitPosition;
  Offset? mazeGoalPosition;
  final List<EnemySpawnPoint> enemySpawns;
  bool exitUnlocked = false;

  GameMap._({
    required this.width,
    required this.height,
    required this.grid,
    required this.playerSpawn,
    required this.exitPosition,
    required this.mazeGoalPosition,
    required this.enemySpawns,
  });

  factory GameMap({
    required int width,
    required int height,
    required List<List<Tile>> grid,
  }) {
    Offset spawn = Offset(width / 2.0, height / 2.0);
    Offset? exit;
    Offset? goal;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (grid[y][x] == Tile.spawn) {
          spawn = Offset(x + 0.5, y + 0.5);
        } else if (grid[y][x] == Tile.exit) {
          exit = Offset(x + 0.5, y + 0.5);
        } else if (grid[y][x] == Tile.mazeGoal) {
          goal = Offset(x + 0.5, y + 0.5);
        }
      }
    }

    return GameMap._(
      width: width,
      height: height,
      grid: grid,
      playerSpawn: spawn,
      exitPosition: exit,
      mazeGoalPosition: goal,
      enemySpawns: [],
    );
  }

  /// Unlock the exit door — converts lockedDoor tiles to door tiles.
  void unlockExit() {
    exitUnlocked = true;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (grid[y][x] == Tile.lockedDoor) {
          grid[y][x] = Tile.door;
        }
      }
    }
  }

  bool isWall(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return true;
    final tile = grid[y][x];
    return tile == Tile.wall || tile == Tile.wallAlt || tile == Tile.lockedDoor;
  }

  bool isSolid(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return true;
    final t = grid[y][x];
    return t == Tile.wall || t == Tile.wallAlt || t == Tile.lockedDoor;
  }

  Tile tileAt(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return Tile.wall;
    return grid[y][x];
  }
}
