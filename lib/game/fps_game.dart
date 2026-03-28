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
import '../data/save_service.dart';
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
        return [EnemyType.grunt];
      case 2:
        return [EnemyType.grunt, EnemyType.imp];
      case 3:
        return [EnemyType.grunt, EnemyType.imp, EnemyType.sentinel, EnemyType.sage];
      case 4:
        return [EnemyType.grunt, EnemyType.imp, EnemyType.sentinel, EnemyType.zoomer, EnemyType.sage];
      case 5:
        return [EnemyType.grunt, EnemyType.imp, EnemyType.sentinel, EnemyType.zoomer,
                EnemyType.brute, EnemyType.swarm, EnemyType.healer, EnemyType.sage];
      default:
        return EnemyType.values.toList(); // Everything including boss and trickster
    }
  }

  Future<void> _ensureAssetsReady() async {
    if (!textures.isReady) await textures.generate();
    if (!sprites.isReady) await sprites.generate();
    if (!audio.isReady) await audio.generate();
  }

  /// Start a fresh game from level 1.
  Future<void> startGame() async {
    await SaveService.deleteSave();
    await _ensureAssetsReady();
    level = 1;
    lives = 3;
    score = 0;
    hostileKills = 0;
    friendlyKills = 0;
    await _loadLevel();
  }

  /// Continue from a saved game.
  Future<void> continueGame() async {
    final data = await SaveService.loadGame();
    if (data == null) return;

    await _ensureAssetsReady();

    score = data.score;
    level = data.level;
    lives = data.lives;
    hostileKills = data.hostileKills;
    friendlyKills = data.friendlyKills;

    final grid = data.grid
        .map((row) => row.map(GameMap.tileFromName).toList())
        .toList();
    gameMap = GameMap.fromSaveData(
      width: data.mapWidth,
      height: data.mapHeight,
      grid: grid,
      exitUnlocked: data.exitUnlocked,
    );

    player = Player(
      position: Offset(data.playerX, data.playerY),
      angle: data.playerAngle,
      health: data.playerHealth,
      ammo: data.playerAmmo,
      kills: data.playerKills,
    );

    enemies = data.enemies
        .map((e) => Enemy.fromSaveData(
              position: Offset(e.x, e.y),
              type: Enemy.typeFromName(e.type),
              alignment: Enemy.alignmentFromName(e.alignment),
              health: e.health,
              maxHealth: e.maxHealth,
              state: Enemy.stateFromName(e.state),
              angle: e.angle,
              hasGivenItem: e.hasGivenItem,
              hasExploded: e.hasExploded,
            ))
        .toList();

    didWin = false;
    _time = 0;
    _damageIndicators.clear();
    _isRunning = true;

    overlays.remove('mainMenu');
    overlays.remove('endgame');
    overlays.remove('levelSplash');
    overlays.add('hud');
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
    player = Player(position: gameMap.playerSpawn, angle: -pi / 2);

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

    if (!won && lives <= 0) {
      recordHighScore();
      SaveService.deleteSave();
    }
  }

  void returnToMenu() {
    _isRunning = false;
    overlays.remove('hud');
    overlays.remove('endgame');
    overlays.add('mainMenu');
  }

  void showBestiary() {
    overlays.remove('mainMenu');
    overlays.add('bestiary');
  }

  void showMainMenu() {
    overlays.remove('bestiary');
    overlays.remove('highScores');
    overlays.add('mainMenu');
  }

  void showHighScores() {
    overlays.remove('mainMenu');
    overlays.add('highScores');
  }

  /// Auto-save current state (called at level transitions).
  Future<void> autoSave() async {
    await SaveService.saveGame(_buildSaveData());
  }

  /// Record current run as a high score entry.
  Future<void> recordHighScore() async {
    await SaveService.addHighScore(HighScoreEntry(
      score: score,
      levelReached: level,
      totalKills: hostileKills + friendlyKills,
      date: DateTime.now().toIso8601String(),
      innocenceBonus: friendlyKills == 0,
    ));
  }

  SaveData _buildSaveData() {
    return SaveData(
      score: score,
      level: level,
      lives: lives,
      hostileKills: hostileKills,
      friendlyKills: friendlyKills,
      playerX: player.position.dx,
      playerY: player.position.dy,
      playerAngle: player.angle,
      playerHealth: player.health,
      playerAmmo: player.ammo,
      playerKills: player.kills,
      mapWidth: gameMap.width,
      mapHeight: gameMap.height,
      grid: gameMap.grid
          .map((row) => row.map((t) => t.name).toList())
          .toList(),
      exitUnlocked: gameMap.exitUnlocked,
      enemies: enemies
          .where((e) => e.isAlive)
          .map((e) => EnemySaveData(
                x: e.position.dx,
                y: e.position.dy,
                health: e.health,
                maxHealth: e.maxHealth,
                state: e.state.name,
                angle: e.angle,
                type: e.type.name,
                alignment: e.alignment.name,
                hasGivenItem: e.hasGivenItem,
                hasExploded: e.hasExploded,
              ))
          .toList(),
    );
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

    // Healer enemies heal nearby hostiles
    for (final healer in enemies) {
      if (healer.type != EnemyType.healer || healer.isDead) continue;
      if (healer.alignment != EnemyAlignment.hostile) continue;
      if (!healer.canHeal()) continue;
      for (final ally in enemies) {
        if (ally == healer || ally.isDead) continue;
        if (ally.alignment != EnemyAlignment.hostile) continue;
        if (ally.healthPercent >= 1.0) continue;
        if (healer.distanceTo(ally.position) < 5.0) {
          ally.receiveHeal(15);
          break; // Heal one ally per cooldown
        }
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

    // Ambient enemy sounds (spatial)
    final ambientSources = enemies
        .where((e) => e.isAlive && e.alignment == EnemyAlignment.hostile)
        .map((e) => SpatialSource(e.position, e.type))
        .toList();
    audio.updateAmbientEnemySounds(
        dt, ambientSources, player.position, player.angle);

    // Check death
    if (player.isDead) {
      audio.playDeath();
      lives--;
      _endGame(won: false);
      return;
    }

    // Check maze goal — unlock exit door when reached
    if (!gameMap.exitUnlocked && gameMap.mazeGoalPosition != null) {
      final gx = (player.position.dx - gameMap.mazeGoalPosition!.dx).abs();
      final gy = (player.position.dy - gameMap.mazeGoalPosition!.dy).abs();
      if (gx < 0.6 && gy < 0.6) {
        gameMap.unlockExit();
        audio.playWin(); // Door unlock sound
      }
    }

    // Check win — player reached the exit
    if (gameMap.exitUnlocked && gameMap.exitPosition != null) {
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
          audio.playEnemyDeath(enemy.type, enemy.alignment,
              enemyPos: enemy.position,
              playerPos: player.position,
              playerAngle: player.angle);
          if (enemy.alignment == EnemyAlignment.hostile) {
            hostileKills++;
          } else {
            friendlyKills++;
          }
        } else {
          audio.playEnemyHurt(enemy.type,
              enemyPos: enemy.position,
              playerPos: player.position,
              playerAngle: player.angle);
          // Trickster teleports when hit
          if (enemy.type == EnemyType.trickster) {
            enemy.tryTeleport(gameMap);
          }
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

    // Draw world sprites (pickups, goal beacon, exit portal, enemies)
    _renderPickups(canvas);
    _renderMazeGoal(canvas);
    _renderMazeEntrance(canvas);
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

        final center = Offset(screenX, screenY + bob);

        if (isHealth) {
          // Medkit — white box with red cross
          final s = spriteHeight * 0.45;
          final boxColor = Color.lerp(
            const Color(0xFF0a0a0a), Colors.white, fogFactor)!;
          final crossColor = Color.lerp(
            const Color(0xFF0a0a0a), Colors.redAccent, fogFactor)!;
          final shadowColor = Color.lerp(
            const Color(0xFF0a0a0a), const Color(0xFFCCCCCC), fogFactor)!;
          // Box body
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: center, width: s, height: s * 0.7),
              Radius.circular(s * 0.08),
            ),
            Paint()..color = boxColor,
          );
          // Box shadow/depth
          canvas.drawRect(
            Rect.fromLTWH(
              center.dx - s * 0.5, center.dy + s * 0.25,
              s, s * 0.1,
            ),
            Paint()..color = shadowColor,
          );
          // Red cross
          canvas.drawRect(
            Rect.fromCenter(
              center: center,
              width: s * 0.55, height: s * 0.18,
            ),
            Paint()..color = crossColor,
          );
          canvas.drawRect(
            Rect.fromCenter(
              center: center,
              width: s * 0.18, height: s * 0.55,
            ),
            Paint()..color = crossColor,
          );
          // Latch/clasp
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(center.dx, center.dy - s * 0.32),
              width: s * 0.2, height: s * 0.06,
            ),
            Paint()..color = Color.lerp(
              const Color(0xFF0a0a0a), Colors.grey.shade600, fogFactor)!,
          );
        } else {
          // Ammo crate — olive/green box with "AMMO" stripe
          final s = spriteHeight * 0.45;
          final crateColor = Color.lerp(
            const Color(0xFF0a0a0a), const Color(0xFF6B7C3E), fogFactor)!;
          final crateLight = Color.lerp(
            const Color(0xFF0a0a0a), const Color(0xFF8B9C4E), fogFactor)!;
          final stripeColor = Color.lerp(
            const Color(0xFF0a0a0a), Colors.amber, fogFactor)!;
          final metalColor = Color.lerp(
            const Color(0xFF0a0a0a), const Color(0xFFAAAA88), fogFactor)!;
          // Crate body
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: center, width: s, height: s * 0.65),
              Radius.circular(s * 0.05),
            ),
            Paint()..color = crateColor,
          );
          // Top highlight
          canvas.drawRect(
            Rect.fromLTWH(
              center.dx - s * 0.45, center.dy - s * 0.3,
              s * 0.9, s * 0.12,
            ),
            Paint()..color = crateLight,
          );
          // Amber stripe across middle
          canvas.drawRect(
            Rect.fromCenter(
              center: center,
              width: s * 0.85, height: s * 0.12,
            ),
            Paint()..color = stripeColor,
          );
          // Metal clasp corners
          for (final dx in [-1.0, 1.0]) {
            canvas.drawRect(
              Rect.fromCenter(
                center: Offset(center.dx + dx * s * 0.38, center.dy),
                width: s * 0.08, height: s * 0.5,
              ),
              Paint()..color = metalColor,
            );
          }
          // Bullet tips peeking out top
          for (int i = -2; i <= 2; i++) {
            final bulletX = center.dx + i * s * 0.12;
            final bulletY = center.dy - s * 0.38;
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset(bulletX, bulletY),
                  width: s * 0.07, height: s * 0.15,
                ),
                Radius.circular(s * 0.03),
              ),
              Paint()..color = Color.lerp(
                const Color(0xFF0a0a0a), const Color(0xFFD4AA44), fogFactor)!,
            );
          }
        }
      }
    }
  }

  void _renderMazeGoal(Canvas canvas) {
    if (gameMap.exitUnlocked) return; // Already reached, no need to show
    final goalPos = gameMap.mazeGoalPosition;
    if (goalPos == null) return;

    final toGoal = goalPos - player.position;
    final dist = toGoal.distance;
    if (dist > Raycaster.maxRayDistance || dist < 0.3) return;

    final goalAngle = atan2(toGoal.dy, toGoal.dx);
    var relAngle = goalAngle - player.angle;
    while (relAngle > pi) { relAngle -= 2 * pi; }
    while (relAngle < -pi) { relAngle += 2 * pi; }
    if (relAngle.abs() > Player.fov / 2 + 0.1) return;

    final ray = Raycaster.castRay(gameMap, player.position, goalAngle);
    if (ray.distance < dist - 0.3) return;

    final screenX = (0.5 + relAngle / Player.fov) * size.x;
    final spriteHeight = size.y / dist;
    final screenY = size.y / 2 - spriteHeight / 2 + player.bobOffset;
    final fogFactor = (1.0 - dist / Raycaster.maxRayDistance).clamp(0.0, 1.0);

    // Pulsing purple beacon
    final pulse = (sin(_time * 4) * 0.3 + 0.7).clamp(0.4, 1.0);
    final beaconColor = Color.lerp(
      const Color(0xFF0a0a0a),
      Colors.purpleAccent,
      fogFactor * pulse,
    )!;

    // Vertical beam
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(screenX, screenY + spriteHeight * 0.3),
        width: spriteHeight * 0.06,
        height: spriteHeight * 0.8,
      ),
      Paint()
        ..color = beaconColor.withValues(alpha: 0.4 * fogFactor)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Base diamond
    final diamondPath = Path()
      ..moveTo(screenX, screenY + spriteHeight * 0.3 - spriteHeight * 0.15)
      ..lineTo(screenX + spriteHeight * 0.1, screenY + spriteHeight * 0.3)
      ..lineTo(screenX, screenY + spriteHeight * 0.3 + spriteHeight * 0.15)
      ..lineTo(screenX - spriteHeight * 0.1, screenY + spriteHeight * 0.3)
      ..close();
    canvas.drawPath(diamondPath, Paint()..color = beaconColor);

    // Glow
    canvas.drawCircle(
      Offset(screenX, screenY + spriteHeight * 0.3),
      spriteHeight * 0.2,
      Paint()
        ..color = beaconColor.withValues(alpha: 0.2 * fogFactor)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // "KEY" label when close
    if (dist < 6) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'UNLOCK',
          style: TextStyle(
            color: beaconColor.withValues(alpha: fogFactor),
            fontSize: max(8, spriteHeight * 0.1),
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(screenX - textPainter.width / 2, screenY + spriteHeight * 0.05),
      );
    }
  }

  /// Renders a glowing "ENTER MAZE" label above the maze entrance door.
  void _renderMazeEntrance(Canvas canvas) {
    final entrancePos = gameMap.mazeEntrancePosition;
    if (entrancePos == null) return;

    final toEntrance = entrancePos - player.position;
    final dist = toEntrance.distance;
    if (dist > 10 || dist < 0.3) return;

    final entranceAngle = atan2(toEntrance.dy, toEntrance.dx);
    var relAngle = entranceAngle - player.angle;
    while (relAngle > pi) { relAngle -= 2 * pi; }
    while (relAngle < -pi) { relAngle += 2 * pi; }
    if (relAngle.abs() > Player.fov / 2 + 0.1) return;

    final ray = Raycaster.castRay(gameMap, player.position, entranceAngle);
    if (ray.distance < dist - 0.5) return;

    final screenX = (0.5 + relAngle / Player.fov) * size.x;
    final spriteHeight = size.y / dist;
    final screenY = size.y / 2 - spriteHeight / 2 + player.bobOffset;
    final fogFactor = (1.0 - dist / 12).clamp(0.0, 1.0);

    // Glowing green arrow/label
    final pulse = (sin(_time * 2) * 0.2 + 0.8).clamp(0.5, 1.0);
    final color = Colors.greenAccent.withValues(alpha: fogFactor * pulse);

    // "ENTER MAZE" label
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'ENTER MAZE',
        style: TextStyle(
          color: color,
          fontSize: max(10, spriteHeight * 0.12),
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(screenX - textPainter.width / 2, screenY + spriteHeight * 0.15),
    );

    // Small downward arrow
    final arrowY = screenY + spriteHeight * 0.15 + textPainter.height + 4;
    final arrowPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(screenX, arrowY),
      Offset(screenX, arrowY + spriteHeight * 0.1),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(screenX - 4, arrowY + spriteHeight * 0.06),
      Offset(screenX, arrowY + spriteHeight * 0.1),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(screenX + 4, arrowY + spriteHeight * 0.06),
      Offset(screenX, arrowY + spriteHeight * 0.1),
      arrowPaint,
    );
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

    // Pulsing glow — red when locked, cyan when unlocked
    final pulse = (sin(_time * 3) * 0.3 + 0.7).clamp(0.4, 1.0);
    final baseColor = gameMap.exitUnlocked ? Colors.cyanAccent : Colors.redAccent;
    final portalColor = Color.lerp(
      const Color(0xFF0a0a0a),
      baseColor,
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

    // Label above portal — shows lock status and hint
    if (dist < 8) {
      final label = gameMap.exitUnlocked ? 'EXIT' : 'LOCKED';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
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

      // Show hint when locked and close
      if (!gameMap.exitUnlocked && dist < 4) {
        final hintPainter = TextPainter(
          text: TextSpan(
            text: 'Find the beacon in the maze',
            style: TextStyle(
              color: Colors.grey.withValues(alpha: 0.7 * fogFactor),
              fontSize: max(8, spriteHeight * 0.08),
              fontStyle: FontStyle.italic,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        hintPainter.paint(
          canvas,
          Offset(screenX - hintPainter.width / 2,
              screenY + spriteHeight * 0.12 + textPainter.height + 2),
        );
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
