import 'package:flutter_test/flutter_test.dart';
import 'package:fps_raycaster/world/maze_generator.dart';
import 'package:fps_raycaster/engine/raycaster.dart';

void main() {
  group('MazeGenerator', () {
    test('generates valid map with spawn and exit', () {
      final gen = MazeGenerator(difficulty: MazeDifficulty.small, seed: 42);
      final map = gen.generate();

      expect(map.width, greaterThan(0));
      expect(map.height, greaterThan(0));
      expect(map.playerSpawn.dx, greaterThan(0));
      expect(map.playerSpawn.dy, greaterThan(0));
      expect(map.exitPosition, isNotNull);
      expect(map.enemySpawns, isNotEmpty);
    });

    test('boundaries are walls', () {
      final gen = MazeGenerator(difficulty: MazeDifficulty.small, seed: 42);
      final map = gen.generate();

      expect(map.isWall(0, 0), isTrue);
      expect(map.isWall(-1, 0), isTrue);
      expect(map.isWall(map.width, 0), isTrue);
    });

    test('spawn and exit are in different positions', () {
      final gen = MazeGenerator(difficulty: MazeDifficulty.medium, seed: 99);
      final map = gen.generate();

      expect(map.playerSpawn, isNot(equals(map.exitPosition)));
    });

    test('different seeds produce different mazes', () {
      final map1 = MazeGenerator(difficulty: MazeDifficulty.small, seed: 1).generate();
      final map2 = MazeGenerator(difficulty: MazeDifficulty.small, seed: 2).generate();

      // Grids should differ (extremely unlikely to be identical with different seeds)
      bool differ = false;
      for (int y = 0; y < map1.height && !differ; y++) {
        for (int x = 0; x < map1.width && !differ; x++) {
          if (map1.grid[y][x] != map2.grid[y][x]) differ = true;
        }
      }
      expect(differ, isTrue);
    });
  });

  group('Raycaster', () {
    test('cast ray hits wall in generated maze', () {
      final gen = MazeGenerator(difficulty: MazeDifficulty.small, seed: 42);
      final map = gen.generate();
      final hit = Raycaster.castRay(map, map.playerSpawn, 0);
      expect(hit.distance, greaterThan(0));
      expect(hit.distance, lessThan(Raycaster.maxRayDistance));
    });
  });
}
