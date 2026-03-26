import 'dart:math';
import 'dart:ui';

import '../world/game_map.dart';

/// Result of a single ray cast.
class RayHit {
  final double distance;
  final double wallX; // Exact hit position on the wall (0.0 - 1.0) for texturing
  final bool vertical; // Whether hit was on a vertical wall face
  final Tile tile;
  final int mapX;
  final int mapY;

  const RayHit({
    required this.distance,
    required this.wallX,
    required this.vertical,
    required this.tile,
    required this.mapX,
    required this.mapY,
  });
}

/// DDA raycasting engine — casts rays through the 2D grid to find wall hits.
class Raycaster {
  static const double maxRayDistance = 30.0;

  /// Cast a single ray from [origin] at [angle] through the [map].
  /// Returns a [RayHit] with distance, wall face info, and tile type.
  static RayHit castRay(GameMap map, Offset origin, double angle) {
    final dirX = cos(angle);
    final dirY = sin(angle);

    int mapX = origin.dx.floor();
    int mapY = origin.dy.floor();

    // Length of ray from one x/y side to next x/y side
    final deltaDistX = dirX == 0 ? double.infinity : (1.0 / dirX).abs();
    final deltaDistY = dirY == 0 ? double.infinity : (1.0 / dirY).abs();

    int stepX;
    int stepY;
    double sideDistX;
    double sideDistY;

    if (dirX < 0) {
      stepX = -1;
      sideDistX = (origin.dx - mapX) * deltaDistX;
    } else {
      stepX = 1;
      sideDistX = (mapX + 1.0 - origin.dx) * deltaDistX;
    }

    if (dirY < 0) {
      stepY = -1;
      sideDistY = (origin.dy - mapY) * deltaDistY;
    } else {
      stepY = 1;
      sideDistY = (mapY + 1.0 - origin.dy) * deltaDistY;
    }

    // DDA algorithm
    bool hitVertical = false;
    double distance = 0;

    for (int i = 0; i < 200; i++) {
      if (sideDistX < sideDistY) {
        sideDistX += deltaDistX;
        mapX += stepX;
        hitVertical = true;
      } else {
        sideDistY += deltaDistY;
        mapY += stepY;
        hitVertical = false;
      }

      if (map.isSolid(mapX, mapY)) {
        // Calculate perpendicular distance (avoid fisheye)
        if (hitVertical) {
          distance = sideDistX - deltaDistX;
        } else {
          distance = sideDistY - deltaDistY;
        }

        // Calculate exact wall hit position for texturing
        double wallX;
        if (hitVertical) {
          wallX = origin.dy + distance * dirY;
        } else {
          wallX = origin.dx + distance * dirX;
        }
        wallX -= wallX.floor();

        return RayHit(
          distance: distance,
          wallX: wallX,
          vertical: hitVertical,
          tile: map.tileAt(mapX, mapY),
          mapX: mapX,
          mapY: mapY,
        );
      }

      if (sideDistX > maxRayDistance && sideDistY > maxRayDistance) break;
    }

    return RayHit(
      distance: maxRayDistance,
      wallX: 0,
      vertical: false,
      tile: Tile.empty,
      mapX: mapX,
      mapY: mapY,
    );
  }

  /// Cast all rays for a frame — one per screen column.
  static List<RayHit> castAllRays({
    required GameMap map,
    required Offset position,
    required double angle,
    required double fov,
    required int screenWidth,
  }) {
    final rays = <RayHit>[];
    final halfFov = fov / 2;

    for (int x = 0; x < screenWidth; x++) {
      final rayAngle = angle - halfFov + (x / screenWidth) * fov;
      final hit = castRay(map, position, rayAngle);

      // Fix fisheye distortion
      final correctedDistance = hit.distance * cos(rayAngle - angle);

      rays.add(RayHit(
        distance: correctedDistance,
        wallX: hit.wallX,
        vertical: hit.vertical,
        tile: hit.tile,
        mapX: hit.mapX,
        mapY: hit.mapY,
      ));
    }

    return rays;
  }
}
