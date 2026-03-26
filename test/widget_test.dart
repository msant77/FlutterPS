import 'package:flutter_test/flutter_test.dart';
import 'package:fps_raycaster/world/game_map.dart';
import 'package:fps_raycaster/engine/raycaster.dart';

void main() {
  group('GameMap', () {
    test('level1 creates valid map', () {
      final map = GameMap.level1();
      expect(map.width, greaterThan(0));
      expect(map.height, greaterThan(0));
      expect(map.playerSpawn.dx, greaterThan(0));
      expect(map.playerSpawn.dy, greaterThan(0));
      expect(map.enemySpawns, isNotEmpty);
    });

    test('boundaries are walls', () {
      final map = GameMap.level1();
      expect(map.isWall(0, 0), isTrue);
      expect(map.isWall(-1, 0), isTrue);
      expect(map.isWall(map.width, 0), isTrue);
    });
  });

  group('Raycaster', () {
    test('cast ray hits wall', () {
      final map = GameMap.level1();
      final hit = Raycaster.castRay(map, map.playerSpawn, 0);
      expect(hit.distance, greaterThan(0));
      expect(hit.distance, lessThan(Raycaster.maxRayDistance));
    });
  });
}
