import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/raycaster.dart';
import '../engine/renderer.dart';
import '../engine/textures.dart';
import '../entities/enemy.dart';
import '../entities/player.dart';
import '../world/game_map.dart';

class FpsGame extends FlameGame with KeyboardEvents {
  late GameMap gameMap;
  late Player player;
  late List<Enemy> enemies;
  final WallTextures textures = WallTextures();

  bool _isRunning = false;
  bool _showMinimap = true;
  final bool _mouseLookEnabled = true;

  // Input state
  final Set<LogicalKeyboardKey> _keysPressed = {};
  bool _mouseDown = false;

  // Screen ray resolution (lower = faster, higher = prettier)
  int rayCount = 320;

  // Cached rays for the current frame
  List<RayHit> _currentRays = [];

  // Damage indicator
  double _damageFlash = 0;
  final List<_DamageIndicator> _damageIndicators = [];

  // Mouse/trackpad look
  double mouseSensitivity = 0.008;
  double _smoothedMouseDelta = 0;
  static const double _mouseSmoothing = 0.4; // 0 = raw, 1 = very smooth

  // Keyboard turn acceleration
  double _turnVelocity = 0;
  static const double _turnAcceleration = 12.0; // rad/s²
  static const double _turnMaxSpeed = 5.0; // rad/s
  static const double _turnDeceleration = 18.0; // rad/s² (stops fast)

  // Score & win state
  int score = 0;
  bool didWin = false;

  bool get isRunning => _isRunning;
  bool get showMinimap => _showMinimap;

  Future<void> startGame() async {
    if (!textures.isReady) {
      await textures.generate();
    }

    gameMap = GameMap.level1();
    player = Player(position: gameMap.playerSpawn);
    enemies = gameMap.enemySpawns
        .map((s) => Enemy.spawn(s.position, s.type))
        .toList();
    score = 0;
    didWin = false;
    _damageIndicators.clear();
    _isRunning = true;

    overlays.remove('mainMenu');
    overlays.remove('endgame');
    overlays.add('hud');
  }

  void _endGame({required bool won}) {
    _isRunning = false;
    didWin = won;
    overlays.remove('hud');
    overlays.add('endgame');
  }

  void returnToMenu() {
    _isRunning = false;
    overlays.remove('hud');
    overlays.remove('endgame');
    overlays.add('mainMenu');
  }

  void toggleMinimap() {
    _showMinimap = !_showMinimap;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isRunning) return;

    _handleInput(dt);
    player.update(dt);

    // Update enemies
    for (final enemy in enemies) {
      enemy.update(dt, player.position, gameMap);
      final damage = enemy.tryAttack();
      if (damage > 0) {
        player.takeDamage(damage);
        _damageFlash = 0.3;

        // Calculate direction damage came from (relative to player facing)
        final toEnemy = enemy.position - player.position;
        final enemyAngle = atan2(toEnemy.dy, toEnemy.dx);
        _damageIndicators.add(_DamageIndicator(
          angle: enemyAngle - player.angle,
          timer: 1.0,
        ));
      }
    }

    // Damage flash decay
    if (_damageFlash > 0) {
      _damageFlash -= dt;
    }

    // Update damage indicators
    _damageIndicators.removeWhere((d) {
      d.timer -= dt;
      return d.timer <= 0;
    });

    // Mouse shooting (hold to fire)
    if (_mouseDown && _isRunning) {
      _tryShoot();
    }

    // Pickup items
    _checkPickups();

    // Check death
    if (player.isDead) {
      _endGame(won: false);
      return;
    }

    // Check win — all enemies dead
    if (enemies.every((e) => e.isDead)) {
      _endGame(won: true);
      return;
    }

    // Cast rays
    _currentRays = Raycaster.castAllRays(
      map: gameMap,
      position: player.position,
      angle: player.angle,
      fov: Player.fov,
      screenWidth: rayCount,
    );
  }

  void _handleInput(double dt) {
    double forward = 0;
    double strafe = 0;

    if (_keysPressed.contains(LogicalKeyboardKey.keyW) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
      forward += 1;
    }
    if (_keysPressed.contains(LogicalKeyboardKey.keyS) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowDown)) {
      forward -= 1;
    }
    if (_keysPressed.contains(LogicalKeyboardKey.keyA)) {
      strafe -= 1;
    }
    if (_keysPressed.contains(LogicalKeyboardKey.keyD)) {
      strafe += 1;
    }

    // Sprint with shift
    if (_keysPressed.contains(LogicalKeyboardKey.shiftLeft)) {
      forward *= 1.6;
      strafe *= 1.6;
    }

    player.move(forward, strafe, dt, gameMap);

    // --- Keyboard turning with acceleration ---
    final wantsLeft = _keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    final wantsRight = _keysPressed.contains(LogicalKeyboardKey.arrowRight);

    if (wantsLeft && !wantsRight) {
      _turnVelocity -= _turnAcceleration * dt;
      if (_turnVelocity < -_turnMaxSpeed) { _turnVelocity = -_turnMaxSpeed; }
    } else if (wantsRight && !wantsLeft) {
      _turnVelocity += _turnAcceleration * dt;
      if (_turnVelocity > _turnMaxSpeed) { _turnVelocity = _turnMaxSpeed; }
    } else {
      // Decelerate to zero
      if (_turnVelocity > 0) {
        _turnVelocity = (_turnVelocity - _turnDeceleration * dt).clamp(0, _turnMaxSpeed);
      } else if (_turnVelocity < 0) {
        _turnVelocity = (_turnVelocity + _turnDeceleration * dt).clamp(-_turnMaxSpeed, 0);
      }
    }

    if (_turnVelocity != 0) {
      player.rotate(_turnVelocity * dt);
    }

    // --- Apply smoothed mouse delta ---
    if (_smoothedMouseDelta.abs() > 0.0001) {
      player.rotate(_smoothedMouseDelta);
      // Decay the smoothed value each frame
      _smoothedMouseDelta *= _mouseSmoothing;
      if (_smoothedMouseDelta.abs() < 0.0001) { _smoothedMouseDelta = 0; }
    }
  }

  void _checkPickups() {
    final px = player.position.dx.floor();
    final py = player.position.dy.floor();
    final tile = gameMap.tileAt(px, py);

    if (tile == Tile.healthPickup) {
      player.heal(25);
      gameMap.grid[py][px] = Tile.empty;
    } else if (tile == Tile.ammoPickup) {
      player.addAmmo(15);
      gameMap.grid[py][px] = Tile.empty;
    }
  }

  void _tryShoot() {
    if (!player.shoot()) return;

    // Simple hitscan — check if any enemy is near the center ray
    final centerRay = Raycaster.castRay(
      gameMap,
      player.position,
      player.angle,
    );

    for (final enemy in enemies) {
      if (enemy.isDead) continue;

      final dist = enemy.distanceTo(player.position);
      if (dist > centerRay.distance) continue; // Enemy behind wall

      // Check if enemy is within crosshair spread
      final toEnemy = enemy.position - player.position;
      final enemyAngle = atan2(toEnemy.dy, toEnemy.dx);
      var angleDiff = (enemyAngle - player.angle);
      // Normalize
      while (angleDiff > pi) { angleDiff -= 2 * pi; }
      while (angleDiff < -pi) { angleDiff += 2 * pi; }

      // Hit detection: wider at closer range
      final hitAngle = atan2(Enemy.hitRadius, dist);
      if (angleDiff.abs() < hitAngle) {
        enemy.takeDamage(25);
        if (enemy.isDead) {
          player.kills++;
          score += 100;
        }
        break; // Hit one enemy per shot
      }
    }
  }

  // --- Mouse/trackpad look ---
  void handlePointerMove(double deltaX) {
    if (!_isRunning || !_mouseLookEnabled) return;
    // Feed delta into smoothing buffer instead of applying directly
    _smoothedMouseDelta += deltaX * mouseSensitivity;
  }

  void handlePointerDown() {
    if (!_isRunning) return;
    _mouseDown = true;
    _tryShoot();
  }

  void handlePointerUp() {
    _mouseDown = false;
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _keysPressed.clear();
    _keysPressed.addAll(keysPressed);

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _tryShoot();
      }
      if (event.logicalKey == LogicalKeyboardKey.keyQ) {
        player.rotate(-pi / 2); // Quick turn left 90°
      }
      if (event.logicalKey == LogicalKeyboardKey.keyE) {
        player.rotate(pi / 2); // Quick turn right 90°
      }
      if (event.logicalKey == LogicalKeyboardKey.keyM) {
        toggleMinimap();
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        returnToMenu();
      }
    }

    return KeyEventResult.handled;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!_isRunning) return;

    Renderer.render(
      canvas: canvas,
      size: size.toSize(),
      rays: _currentRays,
      bobOffset: player.bobOffset,
      textures: textures.isReady ? textures : null,
    );

    // Draw pickups and enemies as sprites (billboard)
    _renderPickups(canvas);
    _renderEnemies(canvas);

    // Weapon
    Renderer.drawWeapon(
      canvas: canvas,
      size: size.toSize(),
      bobOffset: player.bobOffset,
      isShooting: player.isShooting,
      shootTimer: player.shootTimer,
    );

    // Crosshair
    Renderer.drawCrosshair(canvas, size.toSize());

    // Minimap
    if (_showMinimap) {
      Renderer.drawMinimap(
        canvas: canvas,
        size: size.toSize(),
        map: gameMap,
        playerPos: player.position,
        playerAngle: player.angle,
        enemies: enemies,
      );
    }

    // Directional damage indicators
    for (final indicator in _damageIndicators) {
      Renderer.drawDamageIndicator(
        canvas: canvas,
        size: size.toSize(),
        angle: indicator.angle,
        intensity: indicator.timer,
      );
    }

    // Screen-edge damage flash (subtle)
    if (_damageFlash > 0) {
      Renderer.drawDamageVignette(
        canvas: canvas,
        size: size.toSize(),
        intensity: _damageFlash,
      );
    }
  }

  void _renderPickups(Canvas canvas) {
    for (int y = 0; y < gameMap.height; y++) {
      for (int x = 0; x < gameMap.width; x++) {
        final tile = gameMap.grid[y][x];
        if (tile != Tile.healthPickup && tile != Tile.ammoPickup) continue;

        final pickupPos = Offset(x + 0.5, y + 0.5);
        final toPickup = pickupPos - player.position;
        final dist = toPickup.distance;
        if (dist > Raycaster.maxRayDistance || dist < 0.3) continue;

        final pickupAngle = atan2(toPickup.dy, toPickup.dx);
        var relAngle = pickupAngle - player.angle;
        while (relAngle > pi) { relAngle -= 2 * pi; }
        while (relAngle < -pi) { relAngle += 2 * pi; }
        if (relAngle.abs() > Player.fov / 2 + 0.1) continue;

        // Check wall occlusion
        final ray = Raycaster.castRay(gameMap, player.position, pickupAngle);
        if (ray.distance < dist - 0.3) continue;

        final screenX = (0.5 + relAngle / Player.fov) * size.x;
        final spriteHeight = size.y / dist * 0.3; // Small floating item
        final screenY = size.y / 2 + spriteHeight * 0.3 + player.bobOffset; // Sits on floor
        final fogFactor = (1.0 - dist / Raycaster.maxRayDistance).clamp(0.0, 1.0);

        // Bobbing animation
        final bob = sin(size.x * 0.01 + x * 3.0 + y * 7.0) * spriteHeight * 0.15;

        final isHealth = tile == Tile.healthPickup;
        final color = Color.lerp(
          const Color(0xFF0a0a0a),
          isHealth ? Colors.redAccent : Colors.amber,
          fogFactor,
        )!;
        final glowColor = (isHealth ? Colors.red : Colors.amber)
            .withValues(alpha: 0.3 * fogFactor);

        // Glow
        canvas.drawCircle(
          Offset(screenX, screenY + bob),
          spriteHeight * 0.6,
          Paint()
            ..color = glowColor
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );

        if (isHealth) {
          // Health cross
          final s = spriteHeight * 0.4;
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(screenX, screenY + bob),
              width: s,
              height: s * 0.3,
            ),
            Paint()..color = color,
          );
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(screenX, screenY + bob),
              width: s * 0.3,
              height: s,
            ),
            Paint()..color = color,
          );
        } else {
          // Ammo box
          final s = spriteHeight * 0.35;
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(screenX, screenY + bob),
              width: s,
              height: s * 0.7,
            ),
            Paint()..color = color,
          );
          // Bullet tips
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(screenX, screenY + bob - s * 0.25),
              width: s * 0.6,
              height: s * 0.15,
            ),
            Paint()..color = Color.lerp(const Color(0xFF0a0a0a), Colors.amber.shade200, fogFactor)!,
          );
        }
      }
    }
  }

  void _renderEnemies(Canvas canvas) {
    // Sort enemies by distance (far first for painter's algorithm)
    final sortedEnemies = enemies.where((e) => e.isAlive).toList()
      ..sort((a, b) =>
          b.distanceTo(player.position).compareTo(a.distanceTo(player.position)));

    for (final enemy in sortedEnemies) {
      _renderEnemy(canvas, enemy);
    }
  }

  void _renderEnemy(Canvas canvas, Enemy enemy) {
    final toEnemy = enemy.position - player.position;
    final dist = toEnemy.distance;
    if (dist > Raycaster.maxRayDistance || dist < 0.3) return;

    final enemyAngle = atan2(toEnemy.dy, toEnemy.dx);
    var relAngle = enemyAngle - player.angle;
    while (relAngle > pi) { relAngle -= 2 * pi; }
    while (relAngle < -pi) { relAngle += 2 * pi; }

    if (relAngle.abs() > Player.fov / 2 + 0.1) return;

    final screenX = (0.5 + relAngle / Player.fov) * size.x;
    final spriteHeight = size.y / dist;
    final spriteWidth = spriteHeight * 0.6;
    final screenY = size.y / 2 - spriteHeight / 2 + player.bobOffset;

    // Check if behind wall — cast multiple rays across the enemy's visual width
    // to avoid hiding enemies that are partially visible at doorways
    final angularWidth = atan2(Enemy.hitRadius, dist);
    bool visible = false;
    for (final offset in [0.0, -angularWidth, angularWidth]) {
      final ray = Raycaster.castRay(gameMap, player.position, enemyAngle + offset);
      if (ray.distance >= dist - 0.3) {
        visible = true;
        break;
      }
    }
    if (!visible) return;

    final fogFactor = (1.0 - dist / Raycaster.maxRayDistance).clamp(0.0, 1.0);

    Renderer.drawEnemy(
      canvas: canvas,
      enemy: enemy,
      screenX: screenX,
      screenY: screenY,
      spriteHeight: spriteHeight,
      spriteWidth: spriteWidth,
      fogFactor: fogFactor,
      dist: dist,
    );
  }
}

class _DamageIndicator {
  double angle; // Relative angle from player facing direction
  double timer; // Remaining display time

  _DamageIndicator({required this.angle, required this.timer});
}
