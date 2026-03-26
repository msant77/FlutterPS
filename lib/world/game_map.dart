import 'dart:ui';

import '../entities/enemy.dart';

/// Tile types for the game map.
enum Tile {
  empty,
  wall,
  wallAlt,
  door,
  spawn,
  enemySpawn,
  healthPickup,
  ammoPickup,
  exit,
}

/// Spawn point with position and enemy type.
class EnemySpawnPoint {
  final Offset position;
  final EnemyType type;

  const EnemySpawnPoint(this.position, this.type);
}

/// The game world defined as a 2D grid.
class GameMap {
  final int width;
  final int height;
  final List<List<Tile>> grid;
  Offset playerSpawn;
  Offset? exitPosition;
  final List<EnemySpawnPoint> enemySpawns;

  GameMap._({
    required this.width,
    required this.height,
    required this.grid,
    required this.playerSpawn,
    required this.exitPosition,
    required this.enemySpawns,
  });

  factory GameMap({
    required int width,
    required int height,
    required List<List<Tile>> grid,
  }) {
    Offset spawn = Offset(width / 2.0, height / 2.0);
    Offset? exit;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (grid[y][x] == Tile.spawn) {
          spawn = Offset(x + 0.5, y + 0.5);
        } else if (grid[y][x] == Tile.exit) {
          exit = Offset(x + 0.5, y + 0.5);
        }
      }
    }

    return GameMap._(
      width: width,
      height: height,
      grid: grid,
      playerSpawn: spawn,
      exitPosition: exit,
      enemySpawns: [],
    );
  }

  bool isWall(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return true;
    final tile = grid[y][x];
    return tile == Tile.wall || tile == Tile.wallAlt;
  }

  bool isSolid(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return true;
    return grid[y][x] == Tile.wall || grid[y][x] == Tile.wallAlt;
  }

  Tile tileAt(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return Tile.wall;
    return grid[y][x];
  }
}
