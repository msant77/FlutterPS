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

/// Generates a solvable maze using recursive backtracker,
/// then carves rooms, places spawn/exit/enemies/pickups.
class MazeGenerator {
  final MazeDifficulty difficulty;
  final Random _rng;

  MazeGenerator({required this.difficulty, int? seed})
      : _rng = Random(seed);

  /// Generate a complete GameMap.
  GameMap generate() {
    final cellW = difficulty.mazeW;
    final cellH = difficulty.mazeH;

    // Grid dimensions: each cell is 2 tiles wide, plus border walls
    final gridW = cellW * 2 + 1;
    final gridH = cellH * 2 + 1;

    // Start with all walls
    final grid = List.generate(
      gridH,
      (_) => List.filled(gridW, Tile.wall),
    );

    // Carve maze using recursive backtracker
    _carveMaze(grid, cellW, cellH);

    // Carve random rooms for combat arenas
    _carveRooms(grid, gridW, gridH);

    // Randomly assign wall types for visual variety
    _assignWallTypes(grid, gridW, gridH);

    // Find all open floor tiles
    final openTiles = <Point<int>>[];
    for (int y = 1; y < gridH - 1; y++) {
      for (int x = 1; x < gridW - 1; x++) {
        if (grid[y][x] == Tile.empty) {
          openTiles.add(Point(x, y));
        }
      }
    }

    // Place player spawn (top-left area)
    final spawnTile = _findOpenNear(openTiles, 2, 2);
    grid[spawnTile.y][spawnTile.x] = Tile.spawn;

    // Place exit (bottom-right area, far from spawn)
    final exitTile = _findOpenNear(openTiles, gridW - 3, gridH - 3);
    grid[exitTile.y][exitTile.x] = Tile.exit;

    // Remove spawn/exit from available tiles
    openTiles.remove(spawnTile);
    openTiles.remove(exitTile);

    // Place enemies in open areas, away from spawn
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

    // Alignment distribution: ~60% hostile, ~25% friendly, ~15% neutral
    EnemyAlignment pickAlignment(int index) {
      final roll = _rng.nextDouble();
      if (roll < 0.6) return EnemyAlignment.hostile;
      if (roll < 0.85) return EnemyAlignment.friendly;
      return EnemyAlignment.neutral;
    }

    // Filter tiles that are far enough from spawn
    final spawnDist = (gridW + gridH) * 0.15;
    final enemyCandidates = openTiles.where((p) {
      final dx = (p.x - spawnTile.x).abs();
      final dy = (p.y - spawnTile.y).abs();
      return dx + dy > spawnDist;
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

    // Place pickups — spread across the map
    final pickupCandidates = List<Point<int>>.from(openTiles)..shuffle(_rng);
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

    // Convert to Tile lists
    final tileGrid = grid.map((row) => row.toList()).toList();

    final map = GameMap(width: gridW, height: gridH, grid: tileGrid);
    map.enemySpawns.addAll(spawns);
    return map;
  }

  /// Recursive backtracker maze carving.
  /// Works on a cell grid where each cell maps to position (cx*2+1, cy*2+1)
  /// in the tile grid, with walls between them.
  void _carveMaze(List<List<Tile>> grid, int cellW, int cellH) {
    final visited = List.generate(cellH, (_) => List.filled(cellW, false));
    final stack = <Point<int>>[];

    // Directions: dx, dy pairs
    const dirs = [
      Point(0, -1), // up
      Point(0, 1), // down
      Point(-1, 0), // left
      Point(1, 0), // right
    ];

    // Start at (0, 0)
    int cx = 0, cy = 0;
    visited[cy][cx] = true;
    grid[cy * 2 + 1][cx * 2 + 1] = Tile.empty;
    stack.add(Point(cx, cy));

    while (stack.isNotEmpty) {
      // Find unvisited neighbors
      final neighbors = <Point<int>>[];
      for (final d in dirs) {
        final nx = cx + d.x;
        final ny = cy + d.y;
        if (nx >= 0 && nx < cellW && ny >= 0 && ny < cellH && !visited[ny][nx]) {
          neighbors.add(d);
        }
      }

      if (neighbors.isNotEmpty) {
        // Pick random neighbor
        final dir = neighbors[_rng.nextInt(neighbors.length)];
        final nx = cx + dir.x;
        final ny = cy + dir.y;

        // Remove wall between current and neighbor
        final wallX = cx * 2 + 1 + dir.x;
        final wallY = cy * 2 + 1 + dir.y;
        grid[wallY][wallX] = Tile.empty;

        // Move to neighbor
        cx = nx;
        cy = ny;
        visited[cy][cx] = true;
        grid[cy * 2 + 1][cx * 2 + 1] = Tile.empty;
        stack.add(Point(cx, cy));
      } else {
        // Backtrack
        final prev = stack.removeLast();
        cx = prev.x;
        cy = prev.y;
      }
    }
  }

  /// Carve rectangular rooms at random positions for combat arenas.
  /// Returns room centers.
  List<Point<int>> _carveRooms(
    List<List<Tile>> grid,
    int gridW,
    int gridH,
  ) {
    final centers = <Point<int>>[];

    for (int i = 0; i < difficulty.rooms; i++) {
      final roomW = 3 + _rng.nextInt(3); // 3-5 tiles wide
      final roomH = 3 + _rng.nextInt(3); // 3-5 tiles tall

      // Random position (keep away from edges)
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

  /// Find the closest open tile to a target position.
  Point<int> _findOpenNear(List<Point<int>> tiles, int tx, int ty) {
    Point<int> best = tiles.first;
    int bestDist = 999999;
    for (final p in tiles) {
      final d = (p.x - tx).abs() + (p.y - ty).abs();
      if (d < bestDist) {
        bestDist = d;
        best = p;
      }
    }
    return best;
  }
}
