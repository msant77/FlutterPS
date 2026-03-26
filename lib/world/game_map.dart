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
  late final Offset playerSpawn;
  late final List<EnemySpawnPoint> enemySpawns;

  GameMap({required this.width, required this.height, required this.grid}) {
    enemySpawns = [];
    playerSpawn = _findSpawns();
  }

  Offset _findSpawns() {
    Offset spawn = Offset(width / 2.0, height / 2.0);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (grid[y][x] == Tile.spawn) {
          spawn = Offset(x + 0.5, y + 0.5);
        }
        // Enemy spawns are parsed from the extended layout chars
      }
    }
    return spawn;
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

  /// Level 1: A classic maze-like FPS level.
  /// E = grunt, I = imp, B = brute, T = sentinel (T for turret/tower)
  factory GameMap.level1() {
    // All rooms interconnect — no dead ends. Enemies always reachable.
    // W = wall, A = alt wall, S = spawn, E = grunt, I = imp,
    // B = brute, T = sentinel, H = health, M = ammo
    const layout = [
      'WWWWWWWWWWWWWWWWWWWWWWWWW',
      'W...........W...........W',
      'W..S........W.....E.....W',
      'W...........W...........W',
      'W.......WWWWW...........W',
      'W.......A...............W',
      'W.......A.....I...H.....W',
      'WWWAW...A.......WWWWWWW.W',
      'W.......A.......W.......W',
      'W...I...AAAA.AAAW...M...W',
      'W...............W.......W',
      'W.......WWWWW...W...E...W',
      'W.......W.......W.......W',
      'W...M...W...B...........W',
      'W.......W...............W',
      'WWWWW...WWWWWWWWWAWWWWW.W',
      'W...................W...W',
      'W...E...........T...W...W',
      'W...................W...W',
      'W...........WWWWW...W...W',
      'W...H.......W.......W...W',
      'W...........W...I.......W',
      'WWWWW.WWWWWWW...........W',
      'W...........W.....T.M...W',
      'WWWWWWWWWWWWWWWWWWWWWWWWW',
    ];

    final height = layout.length;
    final width = layout[0].length;
    final grid = <List<Tile>>[];
    final spawns = <EnemySpawnPoint>[];

    for (int y = 0; y < layout.length; y++) {
      final row = layout[y];
      final tiles = <Tile>[];
      for (int x = 0; x < row.length; x++) {
        switch (row[x]) {
          case 'W':
            tiles.add(Tile.wall);
          case 'A':
            tiles.add(Tile.wallAlt);
          case 'S':
            tiles.add(Tile.spawn);
          case 'E':
            tiles.add(Tile.empty);
            spawns.add(EnemySpawnPoint(
              Offset(x + 0.5, y + 0.5),
              EnemyType.grunt,
            ));
          case 'I':
            tiles.add(Tile.empty);
            spawns.add(EnemySpawnPoint(
              Offset(x + 0.5, y + 0.5),
              EnemyType.imp,
            ));
          case 'B':
            tiles.add(Tile.empty);
            spawns.add(EnemySpawnPoint(
              Offset(x + 0.5, y + 0.5),
              EnemyType.brute,
            ));
          case 'T':
            tiles.add(Tile.empty);
            spawns.add(EnemySpawnPoint(
              Offset(x + 0.5, y + 0.5),
              EnemyType.sentinel,
            ));
          case 'H':
            tiles.add(Tile.healthPickup);
          case 'M':
            tiles.add(Tile.ammoPickup);
          default:
            tiles.add(Tile.empty);
        }
      }
      grid.add(tiles);
    }

    final map = GameMap(width: width, height: height, grid: grid);
    map.enemySpawns.addAll(spawns);
    return map;
  }
}
