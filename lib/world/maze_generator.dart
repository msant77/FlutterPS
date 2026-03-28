import 'dart:math';
import 'dart:ui';

import '../entities/enemy.dart';
import 'game_map.dart';

/// Difficulty presets for maze generation.
enum MazeDifficulty {
  small(mazeW: 12, mazeH: 10, rooms: 3, enemies: 5, pickups: 4),
  medium(mazeW: 18, mazeH: 14, rooms: 5, enemies: 8, pickups: 5),
  large(mazeW: 25, mazeH: 20, rooms: 7, enemies: 12, pickups: 7);

  final int mazeW; // In maze cells (actual grid = mazeW*2+1)
  final int mazeH;
  final int rooms;
  final int enemies;
  final int pickups;

  const MazeDifficulty({
    required this.mazeW,
    required this.mazeH,
    required this.rooms,
    required this.enemies,
    required this.pickups,
  });
}

/// Starting room dimensions (in tiles).
const int _startRoomW = 11;
const int _startRoomH = 9;

/// Generates a solvable maze using recursive backtracker,
/// with a starting room that has a maze entrance door and a locked exit door.
class MazeGenerator {
  final MazeDifficulty difficulty;
  final Random _rng;

  MazeGenerator({required this.difficulty, int? seed})
      : _rng = Random(seed);

  /// Generate a complete GameMap with starting room + maze.
  GameMap generate() {
    final cellW = difficulty.mazeW;
    final cellH = difficulty.mazeH;

    // Maze grid dimensions
    final mazeW = cellW * 2 + 1;
    final mazeH = cellH * 2 + 1;

    // Total grid: starting room below the maze, separated by a wall row
    final totalW = max(mazeW, _startRoomW + 4); // Ensure room fits
    final totalH = mazeH + _startRoomH + 1; // +1 for the dividing wall

    // Start with all walls
    final grid = List.generate(
      totalH,
      (_) => List.filled(totalW, Tile.wall),
    );

    // ── Carve the maze in the upper portion ─────────────────────
    _carveMaze(grid, cellW, cellH);
    _carveRooms(grid, mazeW, mazeH);
    _assignWallTypes(grid, mazeW, mazeH);

    // ── Carve the starting room in the lower portion ────────────
    final roomLeft = (totalW - _startRoomW) ~/ 2;
    final roomTop = mazeH + 1; // One row below maze for the wall
    _carveStartingRoom(grid, roomLeft, roomTop, totalW);

    // ── Place the maze entrance door (top wall of starting room) ─
    // Find an open maze cell in the bottom rows, closest to room center.
    // Maze passages live at odd coordinates, so search for the nearest one.
    final roomCenterX = roomLeft + _startRoomW ~/ 2;
    final mazeDoorY = mazeH; // The dividing wall row

    // Search bottom rows of maze for an open cell near the room center
    int mazeDoorX = roomCenterX;
    int bestConnectDist = 999;
    for (int y = mazeH - 2; y >= mazeH - 6 && y >= 1; y--) {
      for (int x = 1; x < mazeW - 1; x++) {
        if (grid[y][x] == Tile.empty) {
          final d = (x - roomCenterX).abs();
          if (d < bestConnectDist) {
            bestConnectDist = d;
            mazeDoorX = x;
          }
        }
      }
      if (bestConnectDist < 3) break; // Close enough
    }

    // Place the door on the dividing wall row
    grid[mazeDoorY][mazeDoorX] = Tile.door;

    // Carve a vertical corridor from the door up into the maze until
    // we hit an open passage cell
    for (int y = mazeDoorY - 1; y >= 1; y--) {
      if (grid[y][mazeDoorX] == Tile.empty) break;
      grid[y][mazeDoorX] = Tile.empty;
    }

    // Carve from door down into the room: open the room's top wall row
    if (mazeDoorY + 1 < totalH) {
      grid[mazeDoorY + 1][mazeDoorX] = Tile.empty;
    }

    // If the door X doesn't match room center, carve a horizontal corridor
    // along the room's top interior row to connect them
    final corridorY = roomTop + 1; // First interior row of room
    final startX = min(mazeDoorX, roomCenterX);
    final endX = max(mazeDoorX, roomCenterX);
    for (int x = startX; x <= endX; x++) {
      if (grid[corridorY][x] == Tile.wall) {
        grid[corridorY][x] = Tile.empty;
      }
      // Also open the wall row above if needed
      if (grid[roomTop][x] == Tile.wall) {
        grid[roomTop][x] = Tile.empty;
      }
    }

    // ── Place the locked exit door (opposite wall of starting room) ─
    final exitDoorX = roomLeft + _startRoomW ~/ 2;
    final exitDoorY = totalH - 1; // Bottom wall of room
    grid[exitDoorY][exitDoorX] = Tile.lockedDoor;

    // Place exit tile just inside the door
    grid[exitDoorY - 1][exitDoorX] = Tile.exit;

    // ── Place player spawn in center-south of starting room ─────
    // Offset toward the exit door so both doors are visible
    final spawnX = roomLeft + _startRoomW ~/ 2;
    final spawnY = roomTop + _startRoomH ~/ 2 + 1;
    grid[spawnY][spawnX] = Tile.spawn;

    // ── Place maze goal at the far end of the maze ──────────────
    // Find open tile furthest from the maze door
    final openTiles = <Point<int>>[];
    for (int y = 1; y < mazeH - 1; y++) {
      for (int x = 1; x < mazeW - 1; x++) {
        if (grid[y][x] == Tile.empty) {
          openTiles.add(Point(x, y));
        }
      }
    }

    // Place goal at the tile furthest from the maze entrance
    Point<int> goalTile = openTiles.first;
    int bestDist = 0;
    for (final p in openTiles) {
      final d = (p.x - mazeDoorX).abs() + (p.y - mazeDoorY).abs();
      if (d > bestDist) {
        bestDist = d;
        goalTile = p;
      }
    }
    grid[goalTile.y][goalTile.x] = Tile.mazeGoal;
    openTiles.remove(goalTile);

    // Remove spawn area tiles from open list
    openTiles.removeWhere((p) =>
        p.x >= roomLeft &&
        p.x < roomLeft + _startRoomW &&
        p.y >= roomTop &&
        p.y < roomTop + _startRoomH);

    // ── Place enemies ───────────────────────────────────────────
    final spawns = <EnemySpawnPoint>[];
    final enemyTypes = [
      EnemyType.grunt,
      EnemyType.grunt,
      EnemyType.imp,
      EnemyType.imp,
      EnemyType.brute,
      EnemyType.sentinel,
      EnemyType.zoomer,
      EnemyType.swarm,
      EnemyType.healer,
      EnemyType.trickster,
    ];

    EnemyAlignment pickAlignment(int index) {
      final roll = _rng.nextDouble();
      if (roll < 0.6) return EnemyAlignment.hostile;
      if (roll < 0.85) return EnemyAlignment.friendly;
      return EnemyAlignment.neutral;
    }

    // Only place enemies in the maze, not the starting room
    final spawnDist = (mazeW + mazeH) * 0.1;
    final enemyCandidates = openTiles.where((p) {
      final dx = (p.x - mazeDoorX).abs();
      final dy = (p.y - mazeDoorY).abs();
      return dx + dy > spawnDist && p.y < mazeH; // Only in maze area
    }).toList();

    for (int i = 0; i < difficulty.enemies && enemyCandidates.isNotEmpty; i++) {
      final idx = _rng.nextInt(enemyCandidates.length);
      final tile = enemyCandidates.removeAt(idx);
      openTiles.remove(tile);
      final type = enemyTypes[i % enemyTypes.length];
      final alignment = pickAlignment(i);
      spawns.add(EnemySpawnPoint(
        Offset(tile.x + 0.5, tile.y + 0.5),
        type,
        alignment,
      ));
    }

    // ── Place pickups in the maze ───────────────────────────────
    final pickupCandidates = openTiles
        .where((p) => p.y < mazeH) // Only in maze
        .toList()
      ..shuffle(_rng);
    final healthCount = (difficulty.pickups * 0.5).ceil();
    final ammoCount = difficulty.pickups - healthCount;

    for (int i = 0; i < healthCount && pickupCandidates.isNotEmpty; i++) {
      final tile = pickupCandidates.removeAt(0);
      grid[tile.y][tile.x] = Tile.healthPickup;
    }
    for (int i = 0; i < ammoCount && pickupCandidates.isNotEmpty; i++) {
      final tile = pickupCandidates.removeAt(0);
      grid[tile.y][tile.x] = Tile.ammoPickup;
    }

    final tileGrid = grid.map((row) => row.toList()).toList();
    final map = GameMap(width: totalW, height: totalH, grid: tileGrid);
    map.enemySpawns.addAll(spawns);
    return map;
  }

  /// Carve the starting room — a clear rectangular space with walls.
  void _carveStartingRoom(
      List<List<Tile>> grid, int left, int top, int gridW) {
    for (int y = top; y < top + _startRoomH; y++) {
      for (int x = left; x < left + _startRoomW; x++) {
        if (x >= 0 && x < gridW && y >= 0 && y < grid.length) {
          // Keep border walls, carve interior
          if (y == top || y == top + _startRoomH - 1 ||
              x == left || x == left + _startRoomW - 1) {
            grid[y][x] = Tile.wall;
          } else {
            grid[y][x] = Tile.empty;
          }
        }
      }
    }
  }

  /// Recursive backtracker maze carving.
  void _carveMaze(List<List<Tile>> grid, int cellW, int cellH) {
    final visited = List.generate(cellH, (_) => List.filled(cellW, false));
    final stack = <Point<int>>[];

    const dirs = [
      Point(0, -1),
      Point(0, 1),
      Point(-1, 0),
      Point(1, 0),
    ];

    int cx = 0, cy = 0;
    visited[cy][cx] = true;
    grid[cy * 2 + 1][cx * 2 + 1] = Tile.empty;
    stack.add(Point(cx, cy));

    while (stack.isNotEmpty) {
      final neighbors = <Point<int>>[];
      for (final d in dirs) {
        final nx = cx + d.x;
        final ny = cy + d.y;
        if (nx >= 0 && nx < cellW && ny >= 0 && ny < cellH && !visited[ny][nx]) {
          neighbors.add(d);
        }
      }

      if (neighbors.isNotEmpty) {
        final dir = neighbors[_rng.nextInt(neighbors.length)];
        final nx = cx + dir.x;
        final ny = cy + dir.y;

        final wallX = cx * 2 + 1 + dir.x;
        final wallY = cy * 2 + 1 + dir.y;
        grid[wallY][wallX] = Tile.empty;

        cx = nx;
        cy = ny;
        visited[cy][cx] = true;
        grid[cy * 2 + 1][cx * 2 + 1] = Tile.empty;
        stack.add(Point(cx, cy));
      } else {
        final prev = stack.removeLast();
        cx = prev.x;
        cy = prev.y;
      }
    }
  }

  /// Carve rectangular rooms for combat arenas.
  List<Point<int>> _carveRooms(
    List<List<Tile>> grid,
    int gridW,
    int gridH,
  ) {
    final centers = <Point<int>>[];

    for (int i = 0; i < difficulty.rooms; i++) {
      final roomW = 3 + _rng.nextInt(3);
      final roomH = 3 + _rng.nextInt(3);

      final rx = 2 + _rng.nextInt(gridW - roomW - 3);
      final ry = 2 + _rng.nextInt(gridH - roomH - 3);

      for (int y = ry; y < ry + roomH && y < gridH - 1; y++) {
        for (int x = rx; x < rx + roomW && x < gridW - 1; x++) {
          grid[y][x] = Tile.empty;
        }
      }

      centers.add(Point(rx + roomW ~/ 2, ry + roomH ~/ 2));
    }

    return centers;
  }

  /// Randomly convert some walls to wallAlt for visual variety.
  void _assignWallTypes(List<List<Tile>> grid, int gridW, int gridH) {
    for (int y = 0; y < gridH; y++) {
      for (int x = 0; x < gridW; x++) {
        if (grid[y][x] == Tile.wall && _rng.nextDouble() < 0.25) {
          grid[y][x] = Tile.wallAlt;
        }
      }
    }
  }
}
