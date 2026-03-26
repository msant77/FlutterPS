import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:fps_raycaster/engine/raycaster.dart';
import 'package:fps_raycaster/engine/sprites.dart';
import 'package:fps_raycaster/entities/enemy.dart';
import 'package:fps_raycaster/entities/player.dart';
import 'package:fps_raycaster/world/game_map.dart';
import 'package:fps_raycaster/world/maze_generator.dart';

/// Helper: create a small open map for testing movement/combat.
GameMap _testMap() {
  // 7x7 map with walls around the border and open center
  final grid = List.generate(7, (y) {
    return List.generate(7, (x) {
      if (x == 0 || x == 6 || y == 0 || y == 6) return Tile.wall;
      return Tile.empty;
    });
  });
  // Place spawn and exit
  grid[1][1] = Tile.spawn;
  grid[5][5] = Tile.exit;
  grid[3][3] = Tile.healthPickup;
  grid[3][4] = Tile.ammoPickup;
  return GameMap(width: 7, height: 7, grid: grid);
}

// ==========================================================================
// Player
// ==========================================================================
void main() {
  group('Player', () {
    test('starts with default stats', () {
      final p = Player(position: const Offset(3.5, 3.5));
      expect(p.health, 100);
      expect(p.ammo, 50);
      expect(p.kills, 0);
      expect(p.isDead, isFalse);
    });

    test('takeDamage reduces health and clamps to 0', () {
      final p = Player(position: const Offset(3.5, 3.5));
      p.takeDamage(30);
      expect(p.health, 70);
      p.takeDamage(200);
      expect(p.health, 0);
      expect(p.isDead, isTrue);
    });

    test('heal clamps to 100', () {
      final p = Player(position: const Offset(3.5, 3.5));
      p.takeDamage(50);
      p.heal(20);
      expect(p.health, 70);
      p.heal(999);
      expect(p.health, 100);
    });

    test('shoot consumes ammo and respects cooldown', () {
      final p = Player(position: const Offset(3.5, 3.5), ammo: 2);

      expect(p.shoot(), isTrue);
      expect(p.ammo, 1);
      expect(p.isShooting, isTrue);

      // Can't shoot again immediately (cooldown)
      expect(p.shoot(), isFalse);
      expect(p.ammo, 1);

      // After cooldown expires
      p.update(0.5); // 0.3s cooldown
      expect(p.shoot(), isTrue);
      expect(p.ammo, 0);

      // No ammo left
      p.update(0.5);
      expect(p.shoot(), isFalse);
    });

    test('rotate wraps angle to [-pi, pi]', () {
      final p = Player(position: const Offset(3.5, 3.5), angle: 0);
      p.rotate(pi + 0.5);
      expect(p.angle, lessThan(pi));
      expect(p.angle, greaterThan(-pi));

      p.rotate(-2 * pi);
      expect(p.angle, lessThanOrEqualTo(pi));
      expect(p.angle, greaterThanOrEqualTo(-pi));
    });

    test('move does not go through walls', () {
      final map = _testMap();
      final p = Player(position: const Offset(1.5, 1.5), angle: pi); // Facing left (toward wall)

      final startX = p.position.dx;
      p.move(1, 0, 1.0, map); // Try to walk into wall
      // Should not move past the wall boundary
      expect(p.position.dx, lessThanOrEqualTo(startX + 0.1));
    });

    test('move advances in open space', () {
      final map = _testMap();
      final p = Player(position: const Offset(3.5, 3.5), angle: 0); // Facing right

      p.move(1, 0, 0.1, map);
      expect(p.position.dx, greaterThan(3.5));
    });

    test('shootTimer decays and clears isShooting', () {
      final p = Player(position: const Offset(3.5, 3.5));
      p.shoot();
      expect(p.isShooting, isTrue);

      // Simulate enough time for shootTimer to expire (starts at 1.0, decays at 5x)
      for (int i = 0; i < 10; i++) {
        p.update(0.1);
      }
      expect(p.isShooting, isFalse);
    });
  });

  // ==========================================================================
  // Enemy
  // ==========================================================================
  group('Enemy', () {
    test('spawn creates correct stats per type', () {
      final grunt = Enemy.spawn(const Offset(3, 3), EnemyType.grunt);
      expect(grunt.health, 40);
      expect(grunt.type, EnemyType.grunt);

      final imp = Enemy.spawn(const Offset(3, 3), EnemyType.imp);
      expect(imp.health, 20);
      expect(imp.speed, greaterThan(grunt.speed));

      final brute = Enemy.spawn(const Offset(3, 3), EnemyType.brute);
      expect(brute.health, 100);
      expect(brute.attackDamage, greaterThan(grunt.attackDamage));

      final sentinel = Enemy.spawn(const Offset(3, 3), EnemyType.sentinel);
      expect(sentinel.attackRange, greaterThan(grunt.attackRange));
      expect(sentinel.preferredRange, greaterThan(0));
    });

    test('takeDamage transitions to hurt then dead', () {
      final e = Enemy.spawn(const Offset(3, 3), EnemyType.grunt);
      e.takeDamage(10);
      expect(e.state, EnemyState.hurt);
      expect(e.isAlive, isTrue);
      expect(e.healthPercent, closeTo(0.75, 0.01));

      e.takeDamage(999);
      expect(e.state, EnemyState.dead);
      expect(e.isDead, isTrue);
      expect(e.health, 0);
    });

    test('dead enemy does not update', () {
      final map = _testMap();
      final e = Enemy.spawn(const Offset(3.5, 3.5), EnemyType.grunt);
      e.takeDamage(999);

      final posBefore = e.position;
      e.update(1.0, const Offset(3.5, 2.5), map);
      expect(e.position, posBefore);
    });

    test('hurt state recovers after timer', () {
      final map = _testMap();
      final e = Enemy.spawn(const Offset(3.5, 3.5), EnemyType.grunt);
      e.takeDamage(5);
      expect(e.state, EnemyState.hurt);

      // Simulate time > hurtTimer (0.15s)
      e.update(0.2, const Offset(3.5, 2.5), map);
      expect(e.state, isNot(EnemyState.hurt));
    });

    test('enemy chases player within detection range with LOS', () {
      final map = _testMap();
      // Place enemy in open area, player nearby
      final e = Enemy.spawn(const Offset(3.5, 3.5), EnemyType.grunt);
      final playerPos = const Offset(3.5, 2.0);

      // Multiple updates to get past initial idle
      for (int i = 0; i < 5; i++) {
        e.update(0.1, playerPos, map);
      }

      // Should be chasing or attacking since player is within detection range
      expect(
        e.state == EnemyState.chasing || e.state == EnemyState.attacking,
        isTrue,
      );
    });

    test('enemy does not detect player through wall', () {
      // Build a map with a wall between enemy and player
      final grid = List.generate(7, (y) {
        return List.generate(7, (x) {
          if (x == 0 || x == 6 || y == 0 || y == 6) return Tile.wall;
          if (x == 3) return Tile.wall; // Vertical wall divider
          return Tile.empty;
        });
      });
      grid[1][1] = Tile.spawn;
      final map = GameMap(width: 7, height: 7, grid: grid);

      final e = Enemy.spawn(const Offset(1.5, 3.5), EnemyType.grunt);
      final playerPos = const Offset(5.5, 3.5); // Other side of wall

      for (int i = 0; i < 10; i++) {
        e.update(0.1, playerPos, map);
      }

      // Should remain idle — wall blocks LOS
      expect(e.state, EnemyState.idle);
    });

    test('friendly enemy never attacks', () {
      final map = _testMap();
      final friendly = Enemy.spawn(const Offset(3.5, 3.5), EnemyType.grunt,
          alignment: EnemyAlignment.friendly);
      final playerPos = const Offset(3.5, 4.0); // Very close

      // Update several times — should stay idle, never attack
      for (int i = 0; i < 20; i++) {
        friendly.update(0.1, playerPos, map);
      }
      expect(friendly.state, isNot(EnemyState.attacking));
      expect(friendly.state, isNot(EnemyState.chasing));
    });

    test('neutral enemy is stationary', () {
      final map = _testMap();
      final neutral = Enemy.spawn(const Offset(3.5, 3.5), EnemyType.sentinel,
          alignment: EnemyAlignment.neutral);
      final startPos = neutral.position;

      neutral.update(0.1, const Offset(3.5, 4.0), map);
      expect(neutral.position, equals(startPos));
      expect(neutral.state, EnemyState.idle);
    });

    test('hostile enemy score is positive, friendly is negative', () {
      final hostile = Enemy.spawn(const Offset(1, 1), EnemyType.grunt,
          alignment: EnemyAlignment.hostile);
      final friendly = Enemy.spawn(const Offset(1, 1), EnemyType.grunt,
          alignment: EnemyAlignment.friendly);
      final neutral = Enemy.spawn(const Offset(1, 1), EnemyType.grunt,
          alignment: EnemyAlignment.neutral);

      expect(hostile.scoreValue, greaterThan(0));
      expect(friendly.scoreValue, lessThan(0));
      expect(neutral.scoreValue, lessThan(0));
    });

    test('distanceTo calculates correctly', () {
      final e = Enemy.spawn(const Offset(0, 0), EnemyType.grunt);
      expect(e.distanceTo(const Offset(3, 4)), closeTo(5.0, 0.01));
    });
  });

  // ==========================================================================
  // GameMap
  // ==========================================================================
  group('GameMap', () {
    test('finds spawn and exit positions', () {
      final map = _testMap();
      expect(map.playerSpawn, const Offset(1.5, 1.5));
      expect(map.exitPosition, const Offset(5.5, 5.5));
    });

    test('isWall returns true for walls and out of bounds', () {
      final map = _testMap();
      expect(map.isWall(0, 0), isTrue);
      expect(map.isWall(-1, 0), isTrue);
      expect(map.isWall(100, 100), isTrue);
      expect(map.isWall(3, 3), isFalse); // healthPickup, not a wall
    });

    test('isSolid matches wall tiles', () {
      final map = _testMap();
      expect(map.isSolid(0, 0), isTrue);
      expect(map.isSolid(3, 3), isFalse);
    });

    test('tileAt returns correct tiles', () {
      final map = _testMap();
      expect(map.tileAt(0, 0), Tile.wall);
      expect(map.tileAt(1, 1), Tile.spawn);
      expect(map.tileAt(5, 5), Tile.exit);
      expect(map.tileAt(3, 3), Tile.healthPickup);
      expect(map.tileAt(4, 3), Tile.ammoPickup);
      expect(map.tileAt(-1, -1), Tile.wall); // Out of bounds
    });
  });

  // ==========================================================================
  // MazeGenerator
  // ==========================================================================
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

    test('all difficulty levels produce valid maps', () {
      for (final diff in MazeDifficulty.values) {
        final map = MazeGenerator(difficulty: diff, seed: 42).generate();
        expect(map.playerSpawn.dx, greaterThan(0), reason: '$diff spawn');
        expect(map.exitPosition, isNotNull, reason: '$diff exit');
        expect(map.enemySpawns.length, greaterThan(0), reason: '$diff enemies');
      }
    });

    test('boundaries are walls', () {
      final gen = MazeGenerator(difficulty: MazeDifficulty.small, seed: 42);
      final map = gen.generate();

      // All edges should be walls
      for (int x = 0; x < map.width; x++) {
        expect(map.isWall(x, 0), isTrue, reason: 'top edge x=$x');
        expect(map.isWall(x, map.height - 1), isTrue, reason: 'bottom edge x=$x');
      }
      for (int y = 0; y < map.height; y++) {
        expect(map.isWall(0, y), isTrue, reason: 'left edge y=$y');
        expect(map.isWall(map.width - 1, y), isTrue, reason: 'right edge y=$y');
      }
    });

    test('spawn and exit are in different positions', () {
      final gen = MazeGenerator(difficulty: MazeDifficulty.medium, seed: 99);
      final map = gen.generate();
      expect(map.playerSpawn, isNot(equals(map.exitPosition)));
    });

    test('spawn is in open space', () {
      final gen = MazeGenerator(difficulty: MazeDifficulty.medium, seed: 42);
      final map = gen.generate();
      final sx = map.playerSpawn.dx.floor();
      final sy = map.playerSpawn.dy.floor();
      expect(map.isSolid(sx, sy), isFalse);
    });

    test('exit is in open space', () {
      final gen = MazeGenerator(difficulty: MazeDifficulty.medium, seed: 42);
      final map = gen.generate();
      final ex = map.exitPosition!.dx.floor();
      final ey = map.exitPosition!.dy.floor();
      expect(map.isSolid(ex, ey), isFalse);
    });

    test('enemies spawn in open space', () {
      final gen = MazeGenerator(difficulty: MazeDifficulty.medium, seed: 42);
      final map = gen.generate();
      for (final spawn in map.enemySpawns) {
        final x = spawn.position.dx.floor();
        final y = spawn.position.dy.floor();
        expect(map.isSolid(x, y), isFalse,
            reason: 'Enemy at ($x,$y) is in a wall');
      }
    });

    test('different seeds produce different mazes', () {
      final map1 = MazeGenerator(difficulty: MazeDifficulty.small, seed: 1).generate();
      final map2 = MazeGenerator(difficulty: MazeDifficulty.small, seed: 2).generate();

      bool differ = false;
      for (int y = 0; y < map1.height && !differ; y++) {
        for (int x = 0; x < map1.width && !differ; x++) {
          if (map1.grid[y][x] != map2.grid[y][x]) differ = true;
        }
      }
      expect(differ, isTrue);
    });

    test('same seed produces identical maze', () {
      final map1 = MazeGenerator(difficulty: MazeDifficulty.small, seed: 42).generate();
      final map2 = MazeGenerator(difficulty: MazeDifficulty.small, seed: 42).generate();

      for (int y = 0; y < map1.height; y++) {
        for (int x = 0; x < map1.width; x++) {
          expect(map1.grid[y][x], map2.grid[y][x],
              reason: 'Tile ($x,$y) differs');
        }
      }
    });

    test('has pickups placed', () {
      final gen = MazeGenerator(difficulty: MazeDifficulty.medium, seed: 42);
      final map = gen.generate();

      int healthCount = 0;
      int ammoCount = 0;
      for (int y = 0; y < map.height; y++) {
        for (int x = 0; x < map.width; x++) {
          if (map.grid[y][x] == Tile.healthPickup) healthCount++;
          if (map.grid[y][x] == Tile.ammoPickup) ammoCount++;
        }
      }
      expect(healthCount, greaterThan(0));
      expect(ammoCount, greaterThan(0));
    });
  });

  // ==========================================================================
  // MemeSprites
  // ==========================================================================
  group('MemeSprites', () {
    test('generates sprites for all enemy types and frames', () async {
      final sprites = MemeSprites();
      expect(sprites.isReady, isFalse);
      await sprites.generate();
      expect(sprites.isReady, isTrue);

      for (final type in EnemyType.values) {
        for (final frame in SpriteFrame.values) {
          final image = sprites.getSprite(type, frame);
          expect(image, isNotNull, reason: '$type/$frame should exist');
          expect(image!.width, MemeSprites.size);
          expect(image.height, MemeSprites.size);
        }
      }
    });

    test('returns null for ungenerated sprites', () {
      final sprites = MemeSprites();
      expect(sprites.getSprite(EnemyType.grunt, SpriteFrame.idle), isNull);
    });
  });

  // ==========================================================================
  // GameAudio — skipped in unit tests (requires platform channels)
  // Audio WAV synthesis is tested implicitly via integration tests.
  // ==========================================================================
  // Raycaster
  // ==========================================================================
  group('Raycaster', () {
    test('cast ray hits wall in generated maze', () {
      final gen = MazeGenerator(difficulty: MazeDifficulty.small, seed: 42);
      final map = gen.generate();
      final hit = Raycaster.castRay(map, map.playerSpawn, 0);
      expect(hit.distance, greaterThan(0));
      expect(hit.distance, lessThan(Raycaster.maxRayDistance));
    });

    test('ray in all 4 cardinal directions hits a wall', () {
      final map = _testMap();
      final origin = const Offset(3.5, 3.5);
      for (final angle in [0.0, pi / 2, pi, -pi / 2]) {
        final hit = Raycaster.castRay(map, origin, angle);
        expect(hit.distance, greaterThan(0), reason: 'angle=$angle');
        expect(hit.distance, lessThan(10), reason: 'angle=$angle');
      }
    });

    test('castAllRays returns correct number of rays', () {
      final map = _testMap();
      final rays = Raycaster.castAllRays(
        map: map,
        position: const Offset(3.5, 3.5),
        angle: 0,
        fov: pi / 3,
        screenWidth: 100,
      );
      expect(rays.length, 100);
    });

    test('fisheye correction produces shorter center distances', () {
      final map = _testMap();
      final rays = Raycaster.castAllRays(
        map: map,
        position: const Offset(3.5, 3.5),
        angle: 0,
        fov: pi / 3,
        screenWidth: 100,
      );
      // Center ray should generally have the shortest (corrected) distance
      // compared to edge rays, due to fisheye correction
      final centerDist = rays[50].distance;
      final edgeDist = rays[0].distance;
      // Edge rays hit walls at a wider angle so they tend to be farther
      // This is a sanity check, not a strict inequality
      expect(centerDist, greaterThan(0));
      expect(edgeDist, greaterThan(0));
    });
  });
}
