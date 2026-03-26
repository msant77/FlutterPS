import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../entities/enemy.dart';
import '../world/game_map.dart';
import 'raycaster.dart';
import 'sprites.dart';
import 'textures.dart';

/// Renders the 3D view from raycasting results onto a Canvas.
class Renderer {
  static const double wallHeight = 1.0;

  /// Main render call — draws ceiling, floor, walls, and depth fog.
  static void render({
    required Canvas canvas,
    required Size size,
    required List<RayHit> rays,
    required double bobOffset,
    WallTextures? textures,
  }) {
    _drawSky(canvas, size);
    _drawFloor(canvas, size);
    _drawWalls(canvas, size, rays, bobOffset, textures);
  }

  static void _drawSky(Canvas canvas, Size size) {
    final skyGradient = ui.Gradient.linear(
      Offset(0, 0),
      Offset(0, size.height / 2),
      [
        const Color(0xFF0a0a2e),
        const Color(0xFF1a1a4e),
        const Color(0xFF2a2a5e),
      ],
      [0.0, 0.6, 1.0],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height / 2),
      Paint()..shader = skyGradient,
    );
  }

  static void _drawFloor(Canvas canvas, Size size) {
    final floorGradient = ui.Gradient.linear(
      Offset(0, size.height / 2),
      Offset(0, size.height),
      [
        const Color(0xFF1a1a1a),
        const Color(0xFF2d2d2d),
        const Color(0xFF3a3a3a),
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2),
      Paint()..shader = floorGradient,
    );
  }

  static void _drawWalls(
    Canvas canvas,
    Size size,
    List<RayHit> rays,
    double bobOffset,
    WallTextures? textures,
  ) {
    if (rays.isEmpty) return;

    final stripWidth = size.width / rays.length;
    final useTextures = textures != null && textures.isReady;

    for (int i = 0; i < rays.length; i++) {
      final hit = rays[i];
      if (hit.distance <= 0) continue;

      final lineHeight = (size.height * wallHeight) / hit.distance;
      final drawStart = (size.height / 2 - lineHeight / 2) + bobOffset;
      final drawEnd = drawStart + lineHeight;

      // Distance fog factor
      final fogFactor =
          (1.0 - (hit.distance / Raycaster.maxRayDistance)).clamp(0.0, 1.0);

      // Shade multiplier for vertical faces (depth illusion)
      final shadeMul = hit.vertical ? 0.7 : 1.0;

      if (useTextures) {
        // Textured rendering: draw a column from the texture
        final texture = _textureForTile(hit.tile, textures);
        if (texture != null) {
          // Source: one-pixel-wide column from the texture
          final texX =
              (hit.wallX * WallTextures.size).floor().clamp(0, WallTextures.size - 1);
          final srcRect = Rect.fromLTWH(
            texX.toDouble(),
            0,
            1,
            WallTextures.size.toDouble(),
          );
          // Destination: the wall strip on screen
          final dstRect = Rect.fromLTRB(
            i * stripWidth,
            drawStart,
            (i + 1) * stripWidth + 1,
            drawEnd,
          );

          // Apply fog + shade via color filter
          final brightness = (fogFactor * shadeMul * 255).round().clamp(0, 255);
          final paint = Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = ColorFilter.mode(
              Color.fromARGB(255 - brightness, 10, 10, 10),
              BlendMode.srcATop,
            );

          canvas.drawImageRect(texture, srcRect, dstRect, paint);

          // Re-draw fog on top for distant walls
          if (fogFactor < 0.8) {
            canvas.drawRect(
              dstRect,
              Paint()
                ..color = const Color(0xFF0a0a0a)
                    .withValues(alpha: (1.0 - fogFactor) * 0.7),
            );
          }

          continue;
        }
      }

      // Fallback: flat color rendering
      Color wallColor = _wallColor(hit);
      wallColor = Color.lerp(const Color(0xFF0a0a0a), wallColor, fogFactor)!;

      if (hit.vertical) {
        wallColor = Color.fromARGB(
          wallColor.a ~/ 1,
          (wallColor.r * 0.7).round(),
          (wallColor.g * 0.7).round(),
          (wallColor.b * 0.7).round(),
        );
      }

      canvas.drawRect(
        Rect.fromLTRB(
          i * stripWidth,
          drawStart,
          (i + 1) * stripWidth + 1,
          drawEnd,
        ),
        Paint()
          ..color = wallColor
          ..style = PaintingStyle.fill,
      );
    }
  }

  static ui.Image? _textureForTile(Tile tile, WallTextures textures) {
    switch (tile) {
      case Tile.wall:
        return textures.brickTexture;
      case Tile.wallAlt:
        return textures.mossTexture;
      case Tile.door:
        return textures.metalDoorTexture;
      default:
        return textures.stoneTexture;
    }
  }

  static Color _wallColor(RayHit hit) {
    switch (hit.tile) {
      case Tile.wall:
        return const Color(0xFF8B4513);
      case Tile.wallAlt:
        return const Color(0xFF4a6741);
      case Tile.door:
        return const Color(0xFF4169E1);
      default:
        return const Color(0xFF808080);
    }
  }

  /// Draw weapon at bottom center.
  static void drawWeapon({
    required Canvas canvas,
    required Size size,
    required double bobOffset,
    required bool isShooting,
    required double shootTimer,
  }) {
    final centerX = size.width / 2;
    final baseY = size.height - 120 + bobOffset * 2;

    final gunPaint = Paint()
      ..color = isShooting ? const Color(0xFFCCCCCC) : const Color(0xFF888888)
      ..style = PaintingStyle.fill;

    final gunPath = Path()
      ..moveTo(centerX - 25, baseY + 120)
      ..lineTo(centerX + 25, baseY + 120)
      ..lineTo(centerX + 20, baseY + 40)
      ..lineTo(centerX + 8, baseY)
      ..lineTo(centerX - 8, baseY)
      ..lineTo(centerX - 20, baseY + 40)
      ..close();

    canvas.drawPath(gunPath, gunPaint);

    final detailPaint = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(centerX, baseY + 10),
      Offset(centerX, baseY + 100),
      detailPaint,
    );

    if (isShooting && shootTimer > 0) {
      final flashPaint = Paint()
        ..color = Colors.yellow.withValues(alpha: shootTimer.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawCircle(Offset(centerX, baseY - 5), 20 * shootTimer, flashPaint);

      final flashPaint2 = Paint()
        ..color = Colors.orange.withValues(alpha: (shootTimer * 0.7).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(centerX, baseY - 5), 10 * shootTimer, flashPaint2);
    }
  }

  /// Draw crosshair at screen center.
  static void drawCrosshair(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const gap = 6.0;
    const len = 12.0;

    canvas.drawLine(center - const Offset(0, gap), center - const Offset(0, gap + len), paint);
    canvas.drawLine(center + const Offset(0, gap), center + const Offset(0, gap + len), paint);
    canvas.drawLine(center - const Offset(gap, 0), center - const Offset(gap + len, 0), paint);
    canvas.drawLine(center + const Offset(gap, 0), center + const Offset(gap + len, 0), paint);

    canvas.drawCircle(center, 2, Paint()..color = Colors.greenAccent.withValues(alpha: 0.6));
  }

  /// Draw minimap in corner.
  static void drawMinimap({
    required Canvas canvas,
    required Size size,
    required GameMap map,
    required Offset playerPos,
    required double playerAngle,
    required List<Enemy> enemies,
  }) {
    const minimapSize = 150.0;
    const tileSize = 6.0;
    const padding = 10.0;
    final origin = Offset(size.width - minimapSize - padding, padding);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx, origin.dy, minimapSize, minimapSize),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(origin.dx, origin.dy, minimapSize, minimapSize),
      const Radius.circular(8),
    ));

    final mapCenterX = origin.dx + minimapSize / 2;
    final mapCenterY = origin.dy + minimapSize / 2;

    for (int y = 0; y < map.height; y++) {
      for (int x = 0; x < map.width; x++) {
        final drawX = mapCenterX + (x - playerPos.dx) * tileSize;
        final drawY = mapCenterY + (y - playerPos.dy) * tileSize;

        if (drawX < origin.dx - tileSize ||
            drawX > origin.dx + minimapSize ||
            drawY < origin.dy - tileSize ||
            drawY > origin.dy + minimapSize) {
          continue;
        }

        Color color;
        switch (map.grid[y][x]) {
          case Tile.wall:
            color = const Color(0xFF8B4513);
          case Tile.wallAlt:
            color = const Color(0xFF4a6741);
          case Tile.healthPickup:
            color = Colors.red;
          case Tile.ammoPickup:
            color = Colors.amber;
          case Tile.exit:
            color = Colors.cyanAccent;
          default:
            color = const Color(0xFF222222);
        }

        canvas.drawRect(
          Rect.fromLTWH(drawX, drawY, tileSize, tileSize),
          Paint()..color = color,
        );
      }
    }

    // Enemies on minimap — color-coded by type
    for (final enemy in enemies) {
      if (enemy.isDead) continue;
      final ex = mapCenterX + (enemy.position.dx - playerPos.dx) * tileSize;
      final ey = mapCenterY + (enemy.position.dy - playerPos.dy) * tileSize;

      if (ex >= origin.dx && ex <= origin.dx + minimapSize &&
          ey >= origin.dy && ey <= origin.dy + minimapSize) {
        final enemyColor = _minimapEnemyColor(enemy);
        canvas.drawCircle(Offset(ex, ey), 3, Paint()..color = enemyColor);
      }
    }

    // Player triangle
    final pPath = Path();
    const triSize = 5.0;
    pPath.moveTo(
      mapCenterX + cos(playerAngle) * triSize,
      mapCenterY + sin(playerAngle) * triSize,
    );
    pPath.lineTo(
      mapCenterX + cos(playerAngle + 2.5) * triSize * 0.7,
      mapCenterY + sin(playerAngle + 2.5) * triSize * 0.7,
    );
    pPath.lineTo(
      mapCenterX + cos(playerAngle - 2.5) * triSize * 0.7,
      mapCenterY + sin(playerAngle - 2.5) * triSize * 0.7,
    );
    pPath.close();
    canvas.drawPath(pPath, Paint()..color = Colors.greenAccent);

    canvas.restore();

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx, origin.dy, minimapSize, minimapSize),
        const Radius.circular(8),
      ),
      Paint()
        ..color = Colors.greenAccent.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  static Color _minimapEnemyColor(Enemy enemy) {
    if (enemy.state == EnemyState.attacking) return Colors.red;
    switch (enemy.type) {
      case EnemyType.grunt:
        return const Color(0xFFCC3333);
      case EnemyType.imp:
        return const Color(0xFFFF6600);
      case EnemyType.brute:
        return const Color(0xFF9933CC);
      case EnemyType.sentinel:
        return const Color(0xFF3399FF);
    }
  }

  /// Draw a directional damage indicator arc pointing toward the attacker.
  static void drawDamageIndicator({
    required Canvas canvas,
    required Size size,
    required double angle,
    required double intensity,
  }) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.15;
    final screenAngle = angle - pi / 2;

    final paint = Paint()
      ..color = Colors.red.withValues(alpha: (intensity * 0.8).clamp(0.0, 0.8))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    const arcSweep = 0.6;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      screenAngle - arcSweep / 2,
      arcSweep,
      false,
      paint,
    );

    final tipAngle = screenAngle;
    final tipX = center.dx + cos(tipAngle) * (radius - 10);
    final tipY = center.dy + sin(tipAngle) * (radius - 10);

    final arrowPath = Path();
    const arrowSize = 8.0;
    arrowPath.moveTo(
      tipX + cos(tipAngle) * arrowSize,
      tipY + sin(tipAngle) * arrowSize,
    );
    arrowPath.lineTo(
      tipX + cos(tipAngle + 2.2) * arrowSize * 0.6,
      tipY + sin(tipAngle + 2.2) * arrowSize * 0.6,
    );
    arrowPath.lineTo(
      tipX + cos(tipAngle - 2.2) * arrowSize * 0.6,
      tipY + sin(tipAngle - 2.2) * arrowSize * 0.6,
    );
    arrowPath.close();
    canvas.drawPath(
      arrowPath,
      Paint()..color = Colors.red.withValues(alpha: (intensity * 0.9).clamp(0.0, 0.9)),
    );
  }

  /// Draw a red vignette around screen edges when taking damage.
  static void drawDamageVignette({
    required Canvas canvas,
    required Size size,
    required double intensity,
  }) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.7;

    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        maxRadius,
        [
          Colors.transparent,
          Colors.red.withValues(alpha: (intensity * 0.5).clamp(0.0, 0.5)),
        ],
        [0.5, 1.0],
      );

    canvas.drawRect(rect, paint);
  }

  /// Draw an enemy sprite — uses pixel-art meme sprites when available,
  /// falls back to geometric shapes.
  static void drawEnemy({
    required Canvas canvas,
    required Enemy enemy,
    required double screenX,
    required double screenY,
    required double spriteHeight,
    required double spriteWidth,
    required double fogFactor,
    required double dist,
    MemeSprites? sprites,
  }) {
    // Try sprite-based rendering first
    if (sprites != null && sprites.isReady) {
      final spriteFrame = enemy.state == EnemyState.dead
          ? SpriteFrame.dead
          : enemy.state == EnemyState.hurt
              ? SpriteFrame.hurt
              : SpriteFrame.idle;
      final image = sprites.getSprite(enemy.type, spriteFrame);
      if (image != null) {
        _drawSpriteImage(canvas, image, screenX, screenY, spriteHeight,
            spriteWidth, fogFactor);
        // Draw health bar after sprite, then return
        _drawEnemyHealthBar(canvas, enemy, screenX, screenY, spriteHeight,
            spriteWidth, fogFactor);
        return;
      }
    }

    // Fallback: geometric shapes
    switch (enemy.type) {
      case EnemyType.grunt:
        _drawGrunt(canvas, enemy, screenX, screenY, spriteHeight, spriteWidth, fogFactor, dist);
      case EnemyType.imp:
        _drawImp(canvas, enemy, screenX, screenY, spriteHeight, spriteWidth, fogFactor, dist);
      case EnemyType.brute:
        _drawBrute(canvas, enemy, screenX, screenY, spriteHeight, spriteWidth, fogFactor, dist);
      case EnemyType.sentinel:
        _drawSentinel(canvas, enemy, screenX, screenY, spriteHeight, spriteWidth, fogFactor, dist);
    }

    // Health bar (only when damaged)
    if (enemy.healthPercent < 1.0) {
      final barWidth = spriteWidth * 0.6;
      final barY = screenY + spriteHeight * 0.15;
      // Background
      canvas.drawRect(
        Rect.fromCenter(center: Offset(screenX, barY), width: barWidth, height: 3),
        Paint()..color = Colors.black.withValues(alpha: 0.5 * fogFactor),
      );
      // Fill
      canvas.drawRect(
        Rect.fromLTWH(
          screenX - barWidth / 2,
          barY - 1.5,
          barWidth * enemy.healthPercent,
          3,
        ),
        Paint()
          ..color = Color.lerp(
            Colors.red,
            Colors.greenAccent,
            enemy.healthPercent,
          )!
              .withValues(alpha: fogFactor),
      );
    }
  }

  /// Draw a pixel-art sprite image as a billboard.
  static void _drawSpriteImage(Canvas canvas, ui.Image image, double screenX,
      double screenY, double spriteHeight, double spriteWidth, double fogFactor) {
    final dstRect = Rect.fromCenter(
      center: Offset(screenX, screenY + spriteHeight * 0.5),
      width: spriteWidth * 1.4, // Slightly wider for face visibility
      height: spriteHeight * 0.9,
    );

    final srcRect = Rect.fromLTWH(
      0,
      0,
      MemeSprites.size.toDouble(),
      MemeSprites.size.toDouble(),
    );

    // Apply fog via color filter
    final brightness = (fogFactor * 255).round().clamp(0, 255);
    final paint = Paint()
      ..filterQuality = FilterQuality.none // Pixel-art look
      ..colorFilter = ColorFilter.mode(
        Color.fromARGB(255 - brightness, 10, 10, 10),
        BlendMode.srcATop,
      );

    canvas.drawImageRect(image, srcRect, dstRect, paint);
  }

  /// Draw the health bar for an enemy (extracted for reuse).
  static void _drawEnemyHealthBar(Canvas canvas, Enemy enemy, double screenX,
      double screenY, double spriteHeight, double spriteWidth, double fogFactor) {
    if (enemy.healthPercent >= 1.0) return;
    final barWidth = spriteWidth * 0.6;
    final barY = screenY + spriteHeight * 0.15;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(screenX, barY), width: barWidth, height: 3),
      Paint()..color = Colors.black.withValues(alpha: 0.5 * fogFactor),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        screenX - barWidth / 2,
        barY - 1.5,
        barWidth * enemy.healthPercent,
        3,
      ),
      Paint()
        ..color = Color.lerp(
          Colors.red,
          Colors.greenAccent,
          enemy.healthPercent,
        )!
            .withValues(alpha: fogFactor),
    );
  }

  static void _drawGrunt(Canvas canvas, Enemy enemy, double sx, double sy,
      double sh, double sw, double fog, double dist) {
    final isHurt = enemy.state == EnemyState.hurt;
    final baseColor = isHurt
        ? Colors.white
        : Color.lerp(
            const Color(0xFF0a0a0a),
            enemy.state == EnemyState.attacking ? Colors.red : const Color(0xFFCC3333),
            fog,
          )!;

    // Body
    canvas.drawRect(
      Rect.fromCenter(center: Offset(sx, sy + sh * 0.55), width: sw * 0.5, height: sh * 0.4),
      Paint()..color = baseColor,
    );
    // Head
    canvas.drawCircle(Offset(sx, sy + sh * 0.3), sw * 0.2, Paint()..color = baseColor);
    // Eyes
    if (dist < 10) {
      final eyeColor = Color.lerp(Colors.black, Colors.yellow, fog)!;
      final eyeSize = max(1.0, sw * 0.05);
      canvas.drawCircle(Offset(sx - sw * 0.07, sy + sh * 0.28), eyeSize, Paint()..color = eyeColor);
      canvas.drawCircle(Offset(sx + sw * 0.07, sy + sh * 0.28), eyeSize, Paint()..color = eyeColor);
    }
    // Legs
    canvas.drawRect(
      Rect.fromCenter(center: Offset(sx - sw * 0.12, sy + sh * 0.8), width: sw * 0.15, height: sh * 0.25),
      Paint()..color = baseColor,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(sx + sw * 0.12, sy + sh * 0.8), width: sw * 0.15, height: sh * 0.25),
      Paint()..color = baseColor,
    );
  }

  static void _drawImp(Canvas canvas, Enemy enemy, double sx, double sy,
      double sh, double sw, double fog, double dist) {
    final isHurt = enemy.state == EnemyState.hurt;
    final baseColor = isHurt
        ? Colors.white
        : Color.lerp(
            const Color(0xFF0a0a0a),
            const Color(0xFFFF6600), // Orange
            fog,
          )!;

    // Smaller, hunched body
    canvas.drawOval(
      Rect.fromCenter(center: Offset(sx, sy + sh * 0.5), width: sw * 0.4, height: sh * 0.35),
      Paint()..color = baseColor,
    );
    // Small pointy head
    final headPath = Path()
      ..moveTo(sx, sy + sh * 0.2)
      ..lineTo(sx - sw * 0.12, sy + sh * 0.35)
      ..lineTo(sx + sw * 0.12, sy + sh * 0.35)
      ..close();
    canvas.drawPath(headPath, Paint()..color = baseColor);
    // Glowing red eyes
    if (dist < 12) {
      final eyeSize = max(1.0, sw * 0.04);
      canvas.drawCircle(
        Offset(sx - sw * 0.04, sy + sh * 0.28),
        eyeSize,
        Paint()..color = Color.lerp(Colors.black, Colors.redAccent, fog)!,
      );
      canvas.drawCircle(
        Offset(sx + sw * 0.04, sy + sh * 0.28),
        eyeSize,
        Paint()..color = Color.lerp(Colors.black, Colors.redAccent, fog)!,
      );
    }
    // Thin legs (fast runner)
    canvas.drawLine(
      Offset(sx - sw * 0.08, sy + sh * 0.65),
      Offset(sx - sw * 0.15, sy + sh * 0.95),
      Paint()
        ..color = baseColor
        ..strokeWidth = max(1, sw * 0.06),
    );
    canvas.drawLine(
      Offset(sx + sw * 0.08, sy + sh * 0.65),
      Offset(sx + sw * 0.15, sy + sh * 0.95),
      Paint()
        ..color = baseColor
        ..strokeWidth = max(1, sw * 0.06),
    );
  }

  static void _drawBrute(Canvas canvas, Enemy enemy, double sx, double sy,
      double sh, double sw, double fog, double dist) {
    final isHurt = enemy.state == EnemyState.hurt;
    final baseColor = isHurt
        ? Colors.white
        : Color.lerp(
            const Color(0xFF0a0a0a),
            const Color(0xFF6633AA), // Purple
            fog,
          )!;
    final darkColor = Color.lerp(const Color(0xFF0a0a0a), const Color(0xFF442277), fog)!;

    // Massive body
    canvas.drawRect(
      Rect.fromCenter(center: Offset(sx, sy + sh * 0.5), width: sw * 0.7, height: sh * 0.5),
      Paint()..color = baseColor,
    );
    // Shoulder armor
    canvas.drawRect(
      Rect.fromCenter(center: Offset(sx, sy + sh * 0.32), width: sw * 0.8, height: sh * 0.08),
      Paint()..color = darkColor,
    );
    // Small head on big body
    canvas.drawCircle(Offset(sx, sy + sh * 0.22), sw * 0.15, Paint()..color = baseColor);
    // Angry red eyes
    if (dist < 10) {
      final eyeSize = max(1.5, sw * 0.06);
      canvas.drawCircle(
        Offset(sx - sw * 0.06, sy + sh * 0.21),
        eyeSize,
        Paint()..color = Color.lerp(Colors.black, Colors.red, fog)!,
      );
      canvas.drawCircle(
        Offset(sx + sw * 0.06, sy + sh * 0.21),
        eyeSize,
        Paint()..color = Color.lerp(Colors.black, Colors.red, fog)!,
      );
    }
    // Thick legs
    canvas.drawRect(
      Rect.fromCenter(center: Offset(sx - sw * 0.15, sy + sh * 0.82), width: sw * 0.2, height: sh * 0.22),
      Paint()..color = baseColor,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(sx + sw * 0.15, sy + sh * 0.82), width: sw * 0.2, height: sh * 0.22),
      Paint()..color = baseColor,
    );
  }

  static void _drawSentinel(Canvas canvas, Enemy enemy, double sx, double sy,
      double sh, double sw, double fog, double dist) {
    final isHurt = enemy.state == EnemyState.hurt;
    final baseColor = isHurt
        ? Colors.white
        : Color.lerp(
            const Color(0xFF0a0a0a),
            const Color(0xFF3399FF), // Blue
            fog,
          )!;
    final accentColor = Color.lerp(const Color(0xFF0a0a0a), const Color(0xFF66CCFF), fog)!;

    // Floating body (no legs visible — hovering sentinel)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(sx, sy + sh * 0.5), width: sw * 0.5, height: sh * 0.45),
      Paint()..color = baseColor,
    );
    // Visor/eye stripe
    canvas.drawRect(
      Rect.fromCenter(center: Offset(sx, sy + sh * 0.42), width: sw * 0.45, height: sh * 0.05),
      Paint()..color = accentColor,
    );
    // Central eye (glowing)
    if (dist < 15) {
      canvas.drawCircle(
        Offset(sx, sy + sh * 0.42),
        max(2, sw * 0.06),
        Paint()
          ..color = Color.lerp(Colors.black, Colors.cyanAccent, fog)!
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    // Hover glow underneath
    canvas.drawOval(
      Rect.fromCenter(center: Offset(sx, sy + sh * 0.8), width: sw * 0.3, height: sh * 0.05),
      Paint()
        ..color = accentColor.withValues(alpha: 0.4 * fog)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }
}
