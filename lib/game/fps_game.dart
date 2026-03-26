import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/audio.dart';
import '../engine/raycaster.dart';
import '../engine/renderer.dart';
import '../engine/sprites.dart';
import '../engine/textures.dart';
import '../entities/enemy.dart';
import '../entities/player.dart';
import '../world/game_map.dart';
import '../world/maze_generator.dart';

class FpsGame extends FlameGame with KeyboardEvents {
  late GameMap gameMap;
  late Player player;
  late List<Enemy> enemies;
  final WallTextures textures = WallTextures();
  final MemeSprites sprites = MemeSprites();
  final GameAudio audio = GameAudio();

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
  int hostileKills = 0;
  int friendlyKills = 0;

  // Level progression
  int level = 1;
  int lives = 3;

  bool get isRunning => _isRunning;
  bool get showMinimap => _showMinimap;

  // Animation timer for effects
  double _time = 0;
  double get time => _time;

  /// Get the maze difficulty for the current level.
  MazeDifficulty _difficultyForLevel() {
    if (level <= 2) return MazeDifficulty.small;
    if (level <= 4) return MazeDifficulty.medium;
    return MazeDifficulty.large;
  }

  /// Filter enemy types available at the current level.
  List<EnemyType> _enemyTypesForLevel() {
    switch (level) {
      case 1:
        return [EnemyType.grunt]; // Learn the basics
      case 2:
        return [EnemyType.grunt, EnemyType.imp]; // Add speed
      case 3:
        return [EnemyType.grunt, EnemyType.imp, EnemyType.sentinel]; // Add ranged
      default:
        return EnemyType.values.toList(); // Everything including brutes
    }
  }

  Future<void> _ensureAssetsReady() async {
    if (!textures.isReady) await textures.generate();
    if (!sprites.isReady) await sprites.generate();
    if (!audio.isReady) await audio.generate();
  }

  /// Start a fresh game from level 1.
  Future<void> startGame() async {
    await _ensureAssetsReady();
    level = 1;
    lives = 3;
    score = 0;
    hostileKills = 0;
    friendlyKills = 0;
    await _loadLevel();
  }

  /// Advance to the next level, keeping score and health.
  Future<void> nextLevel() async {
    level++;
    final prevHealth = player.health;
    final prevAmmo = player.ammo;
    await _loadLevel();
    // Carry over health and ammo
    player.health = prevHealth;
    player.ammo = prevAmmo;
  }

  /// Retry the current level (on death with lives remaining).
  Future<void> retryLevel() async {
    await _loadLevel();
  }

  /// Load the current level's map and enemies.
  Future<void> _loadLevel() async {
    final difficulty = _difficultyForLevel();
    final allowedTypes = _enemyTypesForLevel();

    final generator = MazeGenerator(difficulty: difficulty, seed: level * 7);
    gameMap = generator.generate();
    player = Player(position: gameMap.playerSpawn);

    // Filter spawns to only use enemy types available at this level
    enemies = gameMap.enemySpawns.map((s) {
      final type = allowedTypes.contains(s.type)
          ? s.type
          : allowedTypes[s.type.index % allowedTypes.length];
      return Enemy.spawn(s.position, type, alignment: s.alignment);
    }).toList();

    didWin = false;
    _time = 0;
    _damageIndicators.clear();
    _isRunning = true;

    overlays.remove('mainMenu');
    overlays.remove('endgame');
    overlays.remove('levelSplash');
    overlays.add('hud');
  }

  void _endGame({required bool won}) {
    _isRunning = false;
    didWin = won;
    overlays.remove('hud');
    overlays.remove('levelSplash');
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

    _time += dt;
    _handleInput(dt);
    player.update(dt);

    // Update enemies
    for (final enemy in enemies) {
      enemy.update(dt, player.position, gameMap);
      final damage = enemy.tryAttack();
      if (damage > 0) {
        player.takeDamage(damage);
        audio.playHurt();
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

    // Neutral NPC interaction: give items when player is close
    for (final enemy in enemies) {
      if (enemy.isDead || enemy.alignment != EnemyAlignment.neutral) continue;
      if (enemy.hasGivenItem) continue;
      final dist = enemy.distanceTo(player.position);
      if (dist < 1.5) {
        enemy.hasGivenItem = true;
        // Stonks man gives ammo, others give health
        if (enemy.type == EnemyType.sentinel) {
          player.addAmmo(10);
          audio.playAmmoPickup();
        } else {
          player.heal(15);
          audio.playHealthPickup();
        }
        score += 25; // Small bonus for interacting instead of killing
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

    // Footsteps
    final isMoving = _keysPressed.contains(LogicalKeyboardKey.keyW) ||
        _keysPressed.contains(LogicalKeyboardKey.keyS) ||
        _keysPressed.contains(LogicalKeyboardKey.keyA) ||
        _keysPressed.contains(LogicalKeyboardKey.keyD) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowDown);
    audio.updateFootsteps(dt, isMoving);

    // Check death
    if (player.isDead) {
      audio.playDeath();
      lives--;
      _endGame(won: false);
      return;
    }

    // Check win — player reached the exit
    if (gameMap.exitPosition != null) {
      final dx = (player.position.dx - gameMap.exitPosition!.dx).abs();
      final dy = (player.position.dy - gameMap.exitPosition!.dy).abs();
      if (dx < 0.6 && dy < 0.6) {
        // Bonus points for remaining health
        score += player.health.round() * 2;
        // Innocence bonus: no friendly kills
        if (friendlyKills == 0) {
          score += 300;
        }
        audio.playWin();
        // Show level complete splash, then advance
        _isRunning = false;
        didWin = true;
        overlays.remove('hud');
        overlays.add('levelSplash');
        return;
      }
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
      audio.playHealthPickup();
    } else if (tile == Tile.ammoPickup) {
      player.addAmmo(15);
      gameMap.grid[py][px] = Tile.empty;
      audio.playAmmoPickup();
    }
  }

  void _tryShoot() {
    if (!player.shoot()) return;
    audio.playShoot();

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
          score += enemy.scoreValue;
          audio.playEnemyDeath(enemy.type, enemy.alignment);
          if (enemy.alignment == EnemyAlignment.hostile) {
            hostileKills++;
          } else {
            friendlyKills++;
          }
        } else {
          audio.playEnemyHurt(enemy.type);
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

    // Draw world sprites (pickups, exit portal, enemies)
    _renderPickups(canvas);
    _renderExitPortal(canvas);
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

  void _renderExitPortal(Canvas canvas) {
    final exitPos = gameMap.exitPosition;
    if (exitPos == null) return;

    final toExit = exitPos - player.position;
    final dist = toExit.distance;
    if (dist > Raycaster.maxRayDistance || dist < 0.3) return;

    final exitAngle = atan2(toExit.dy, toExit.dx);
    var relAngle = exitAngle - player.angle;
    while (relAngle > pi) { relAngle -= 2 * pi; }
    while (relAngle < -pi) { relAngle += 2 * pi; }
    if (relAngle.abs() > Player.fov / 2 + 0.1) return;

    // Wall occlusion
    final ray = Raycaster.castRay(gameMap, player.position, exitAngle);
    if (ray.distance < dist - 0.3) return;

    final screenX = (0.5 + relAngle / Player.fov) * size.x;
    final spriteHeight = size.y / dist;
    final screenY = size.y / 2 - spriteHeight / 2 + player.bobOffset;
    final fogFactor = (1.0 - dist / Raycaster.maxRayDistance).clamp(0.0, 1.0);

    // Pulsing glow
    final pulse = (sin(_time * 3) * 0.3 + 0.7).clamp(0.4, 1.0);
    final portalColor = Color.lerp(
      const Color(0xFF0a0a0a),
      Colors.cyanAccent,
      fogFactor * pulse,
    )!;

    // Outer glow
    canvas.drawCircle(
      Offset(screenX, screenY + spriteHeight * 0.5),
      spriteHeight * 0.5,
      Paint()
        ..color = portalColor.withValues(alpha: 0.2 * fogFactor)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // Portal ring
    canvas.drawCircle(
      Offset(screenX, screenY + spriteHeight * 0.5),
      spriteHeight * 0.35,
      Paint()
        ..color = portalColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2, spriteHeight * 0.06),
    );

    // Inner swirl (rotating lines)
    for (int i = 0; i < 4; i++) {
      final a = _time * 2 + i * pi / 2;
      final r = spriteHeight * 0.2;
      final cx = screenX;
      final cy = screenY + spriteHeight * 0.5;
      canvas.drawLine(
        Offset(cx + cos(a) * r * 0.3, cy + sin(a) * r * 0.3),
        Offset(cx + cos(a) * r, cy + sin(a) * r),
        Paint()
          ..color = portalColor.withValues(alpha: 0.6 * fogFactor)
          ..strokeWidth = max(1, spriteHeight * 0.03)
          ..strokeCap = StrokeCap.round,
      );
    }

    // Center bright spot
    canvas.drawCircle(
      Offset(screenX, screenY + spriteHeight * 0.5),
      spriteHeight * 0.08,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7 * fogFactor * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // "EXIT" text rendered as a small label above the portal (close range)
    if (dist < 6) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'EXIT',
          style: TextStyle(
            color: portalColor.withValues(alpha: fogFactor),
            fontSize: max(10, spriteHeight * 0.12),
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(screenX - textPainter.width / 2, screenY + spriteHeight * 0.12),
      );
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

    // Alignment glow: green for friendly, red for hostile, gold for neutral
    if (dist < 12) {
      final glowColor = switch (enemy.alignment) {
        EnemyAlignment.friendly => Colors.greenAccent
            .withValues(alpha: 0.15 * fogFactor),
        EnemyAlignment.neutral => Colors.amber
            .withValues(alpha: 0.15 * fogFactor),
        EnemyAlignment.hostile => Colors.redAccent
            .withValues(alpha: 0.1 * fogFactor),
      };
      canvas.drawCircle(
        Offset(screenX, screenY + spriteHeight * 0.5),
        spriteWidth * 0.7,
        Paint()
          ..color = glowColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    Renderer.drawEnemy(
      canvas: canvas,
      enemy: enemy,
      screenX: screenX,
      screenY: screenY,
      spriteHeight: spriteHeight,
      spriteWidth: spriteWidth,
      fogFactor: fogFactor,
      dist: dist,
      sprites: sprites.isReady ? sprites : null,
    );
  }
}

class _DamageIndicator {
  double angle; // Relative angle from player facing direction
  double timer; // Remaining display time

  _DamageIndicator({required this.angle, required this.timer});
}
