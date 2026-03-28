import 'dart:math';
import 'dart:ui';

import '../engine/raycaster.dart';
import '../world/game_map.dart';

enum EnemyState { idle, chasing, attacking, hurt, dead }

/// Alignment determines AI behavior and scoring.
enum EnemyAlignment {
  /// Chases and attacks the player.
  hostile,

  /// Wanders peacefully, never attacks. Killing penalizes score.
  friendly,

  /// Stationary, gives items on approach.
  neutral,
}

enum EnemyType {
  /// Trollface — medium speed, medium health, melee.
  grunt,

  /// Doge — fast, low health, charges in.
  imp,

  /// Grumpy Cat — slow, lots of health, hits hard.
  brute,

  /// Stonks Man — stays at distance, shoots.
  sentinel,

  /// Distracted Boyfriend — circles around the player, flanks.
  zoomer,

  /// This Is Fine Dog — suicide rushes, explodes on contact.
  swarm,

  /// Hide the Pain Harold — heals nearby hostile enemies.
  healer,

  /// GigaChad — mini-boss, high HP, mixed attacks.
  boss,

  /// Rick Astley — teleports when shot, distracting.
  trickster,

  /// Rare Pepe — neutral vendor, gives rare items.
  sage,
}

class Enemy {
  Offset position;
  double health;
  double maxHealth;
  double speed;
  double attackRange;
  double attackDamage;
  double attackCooldown;
  double _attackTimer;
  EnemyState state;
  double detectionRange;
  double angle;
  EnemyType type;

  // Visual feedback
  double hurtTimer;
  double _idleWanderAngle;
  double _wanderTimer;

  // Sentinel/boss: preferred distance from player
  double preferredRange;

  /// Alignment: hostile, friendly, or neutral.
  EnemyAlignment alignment;

  /// Whether this neutral NPC has already given its item.
  bool hasGivenItem;

  /// Swarm: whether explosion has triggered.
  bool hasExploded;

  /// Trickster: teleport cooldown.
  double _teleportCooldown;

  /// Healer: heal cooldown.
  double _healCooldown;

  /// Flanker (zoomer): orbit angle offset.
  double _orbitAngle;

  static const double collisionRadius = 0.3;
  static const double hitRadius = 0.4;

  Enemy._({
    required this.position,
    required this.type,
    required this.health,
    required this.maxHealth,
    required this.speed,
    required this.attackRange,
    required this.attackDamage,
    required this.attackCooldown,
    required this.detectionRange,
    required this.preferredRange,
    this.alignment = EnemyAlignment.hostile,
  })  : _attackTimer = 0,
        hasGivenItem = false,
        hasExploded = false,
        _teleportCooldown = 0,
        _healCooldown = 0,
        _orbitAngle = Random().nextDouble() * pi * 2,
        state = EnemyState.idle,
        angle = 0,
        hurtTimer = 0,
        _idleWanderAngle = Random().nextDouble() * pi * 2,
        _wanderTimer = 0;

  /// Score value when killed. Positive for hostiles, negative for friendlies.
  int get scoreValue {
    if (alignment == EnemyAlignment.friendly) return -200;
    if (alignment == EnemyAlignment.neutral) return -150;
    switch (type) {
      case EnemyType.grunt:
        return 100;
      case EnemyType.imp:
        return 75;
      case EnemyType.brute:
        return 200;
      case EnemyType.sentinel:
        return 150;
      case EnemyType.zoomer:
        return 125;
      case EnemyType.swarm:
        return 50; // Easy to kill but dangerous
      case EnemyType.healer:
        return 175; // High priority target
      case EnemyType.boss:
        return 500;
      case EnemyType.trickster:
        return 100;
      case EnemyType.sage:
        return -150; // Should never be hostile, but just in case
    }
  }

  /// Spawn the right enemy type at a position.
  factory Enemy.spawn(Offset position, EnemyType type,
      {EnemyAlignment alignment = EnemyAlignment.hostile}) {
    switch (type) {
      case EnemyType.grunt:
        return Enemy._(
          position: position, type: type, alignment: alignment,
          health: 40, maxHealth: 40, speed: 1.8,
          attackRange: 1.5, attackDamage: 8, attackCooldown: 1.0,
          detectionRange: 10.0, preferredRange: 0,
        );
      case EnemyType.imp:
        return Enemy._(
          position: position, type: type, alignment: alignment,
          health: 20, maxHealth: 20, speed: 3.5,
          attackRange: 1.2, attackDamage: 5, attackCooldown: 0.5,
          detectionRange: 12.0, preferredRange: 0,
        );
      case EnemyType.brute:
        return Enemy._(
          position: position, type: type, alignment: alignment,
          health: 100, maxHealth: 100, speed: 0.9,
          attackRange: 2.0, attackDamage: 20, attackCooldown: 1.8,
          detectionRange: 8.0, preferredRange: 0,
        );
      case EnemyType.sentinel:
        return Enemy._(
          position: position, type: type, alignment: alignment,
          health: 30, maxHealth: 30, speed: 1.2,
          attackRange: 8.0, attackDamage: 6, attackCooldown: 1.5,
          detectionRange: 15.0, preferredRange: 5.0,
        );
      case EnemyType.zoomer:
        return Enemy._(
          position: position, type: type, alignment: alignment,
          health: 35, maxHealth: 35, speed: 2.5,
          attackRange: 1.5, attackDamage: 10, attackCooldown: 0.8,
          detectionRange: 12.0, preferredRange: 3.0,
        );
      case EnemyType.swarm:
        return Enemy._(
          position: position, type: type, alignment: alignment,
          health: 10, maxHealth: 10, speed: 4.0,
          attackRange: 0.8, attackDamage: 30, attackCooldown: 0.1,
          detectionRange: 10.0, preferredRange: 0,
        );
      case EnemyType.healer:
        return Enemy._(
          position: position, type: type, alignment: alignment,
          health: 25, maxHealth: 25, speed: 1.5,
          attackRange: 6.0, attackDamage: 0, attackCooldown: 2.0,
          detectionRange: 12.0, preferredRange: 4.0,
        );
      case EnemyType.boss:
        return Enemy._(
          position: position, type: type, alignment: alignment,
          health: 250, maxHealth: 250, speed: 1.4,
          attackRange: 3.0, attackDamage: 15, attackCooldown: 1.2,
          detectionRange: 18.0, preferredRange: 0,
        );
      case EnemyType.trickster:
        return Enemy._(
          position: position, type: type, alignment: alignment,
          health: 40, maxHealth: 40, speed: 1.0,
          attackRange: 6.0, attackDamage: 4, attackCooldown: 2.0,
          detectionRange: 14.0, preferredRange: 4.0,
        );
      case EnemyType.sage:
        return Enemy._(
          position: position, type: type,
          alignment: EnemyAlignment.neutral, // Always neutral
          health: 50, maxHealth: 50, speed: 0,
          attackRange: 0, attackDamage: 0, attackCooldown: 999,
          detectionRange: 3.0, preferredRange: 0,
        );
    }
  }

  /// Reconstruct an enemy from saved data.
  /// Uses spawn() for stat defaults, then overwrites mutable fields.
  factory Enemy.fromSaveData({
    required Offset position,
    required EnemyType type,
    required EnemyAlignment alignment,
    required double health,
    required double maxHealth,
    required EnemyState state,
    required double angle,
    required bool hasGivenItem,
    required bool hasExploded,
  }) {
    final e = Enemy.spawn(position, type, alignment: alignment);
    e.health = health;
    e.maxHealth = maxHealth;
    e.state = state;
    e.angle = angle;
    e.hasGivenItem = hasGivenItem;
    e.hasExploded = hasExploded;
    return e;
  }

  static EnemyType typeFromName(String name) =>
      EnemyType.values.firstWhere((t) => t.name == name,
          orElse: () => EnemyType.grunt);

  static EnemyAlignment alignmentFromName(String name) =>
      EnemyAlignment.values.firstWhere((a) => a.name == name,
          orElse: () => EnemyAlignment.hostile);

  static EnemyState stateFromName(String name) =>
      EnemyState.values.firstWhere((s) => s.name == name,
          orElse: () => EnemyState.idle);

  bool get isDead => state == EnemyState.dead;
  bool get isAlive => !isDead;
  double get healthPercent => health / maxHealth;

  void takeDamage(double amount) {
    health -= amount;
    if (health <= 0) {
      health = 0;
      state = EnemyState.dead;
    } else {
      state = EnemyState.hurt;
      hurtTimer = 0.15;
      // Trickster teleports when hit
      if (type == EnemyType.trickster && _teleportCooldown <= 0) {
        _teleportCooldown = 3.0;
      }
    }
  }

  void update(double dt, Offset playerPos, GameMap map) {
    if (isDead) return;

    // Decay cooldowns
    if (_teleportCooldown > 0) _teleportCooldown -= dt;
    if (_healCooldown > 0) _healCooldown -= dt;

    // Hurt state recovery
    if (state == EnemyState.hurt) {
      hurtTimer -= dt;
      if (hurtTimer <= 0) {
        state = alignment == EnemyAlignment.hostile
            ? EnemyState.chasing
            : EnemyState.idle;
      }
      return;
    }

    // Neutral NPCs are stationary
    if (alignment == EnemyAlignment.neutral) {
      state = EnemyState.idle;
      return;
    }

    // Friendly NPCs just wander
    if (alignment == EnemyAlignment.friendly) {
      _wander(dt, map);
      return;
    }

    final toPlayer = playerPos - position;
    final distToPlayer = toPlayer.distance;

    if (_attackTimer > 0) _attackTimer -= dt;

    switch (type) {
      case EnemyType.sentinel:
      case EnemyType.trickster:
        _updateSentinel(dt, playerPos, distToPlayer, toPlayer, map);
      case EnemyType.zoomer:
        _updateFlanker(dt, playerPos, distToPlayer, toPlayer, map);
      case EnemyType.swarm:
        _updateSuicideRusher(dt, playerPos, distToPlayer, toPlayer, map);
      case EnemyType.healer:
        _updateHealer(dt, playerPos, distToPlayer, map);
      case EnemyType.boss:
        _updateBoss(dt, playerPos, distToPlayer, toPlayer, map);
      case EnemyType.sage:
        // Sage is always neutral, handled above
        state = EnemyState.idle;
      default:
        _updateMelee(dt, playerPos, distToPlayer, toPlayer, map);
    }
  }

  /// Check if enemy has clear line of sight to the player.
  bool _hasLineOfSight(Offset playerPos, double distToPlayer, GameMap map) {
    final angleToPlayer = atan2(
      playerPos.dy - position.dy,
      playerPos.dx - position.dx,
    );
    final hit = Raycaster.castRay(map, position, angleToPlayer);
    return hit.distance >= distToPlayer - 0.5;
  }

  void _updateMelee(double dt, Offset playerPos, double distToPlayer,
      Offset toPlayer, GameMap map) {
    final canSee = _hasLineOfSight(playerPos, distToPlayer, map);

    if (distToPlayer <= attackRange && canSee) {
      state = EnemyState.attacking;
      angle = atan2(toPlayer.dy, toPlayer.dx);
      if (_attackTimer <= 0) _attackTimer = attackCooldown;
    } else if (distToPlayer <= detectionRange && canSee) {
      state = EnemyState.chasing;
      angle = atan2(toPlayer.dy, toPlayer.dx);
      _moveToward(angle, dt, map);
    } else {
      _wander(dt, map);
    }
  }

  void _updateSentinel(double dt, Offset playerPos, double distToPlayer,
      Offset toPlayer, GameMap map) {
    final canSee = _hasLineOfSight(playerPos, distToPlayer, map);
    angle = atan2(toPlayer.dy, toPlayer.dx);

    if (distToPlayer <= detectionRange && canSee) {
      if (distToPlayer <= attackRange && distToPlayer >= preferredRange - 1) {
        state = EnemyState.attacking;
        if (_attackTimer <= 0) _attackTimer = attackCooldown;
        if (distToPlayer < preferredRange - 1) {
          _moveToward(angle + pi, dt, map);
        }
      } else if (distToPlayer < preferredRange - 1) {
        state = EnemyState.chasing;
        _moveToward(angle + pi, dt, map);
      } else {
        state = EnemyState.chasing;
        _moveToward(angle, dt, map);
      }
    } else {
      _wander(dt, map);
    }
  }

  /// Flanker: orbits the player at preferredRange, attacking from the side.
  void _updateFlanker(double dt, Offset playerPos, double distToPlayer,
      Offset toPlayer, GameMap map) {
    final canSee = _hasLineOfSight(playerPos, distToPlayer, map);
    angle = atan2(toPlayer.dy, toPlayer.dx);

    if (!canSee || distToPlayer > detectionRange) {
      _wander(dt, map);
      return;
    }

    state = EnemyState.chasing;
    _orbitAngle += dt * 1.8; // Orbit speed

    if (distToPlayer <= attackRange) {
      state = EnemyState.attacking;
      if (_attackTimer <= 0) _attackTimer = attackCooldown;
    }

    // Move toward orbit position around the player
    final targetX = playerPos.dx + cos(_orbitAngle) * preferredRange;
    final targetY = playerPos.dy + sin(_orbitAngle) * preferredRange;
    final toTarget = Offset(targetX, targetY) - position;
    final moveAngle = atan2(toTarget.dy, toTarget.dx);
    _moveToward(moveAngle, dt, map);
  }

  /// Suicide rusher: beelines toward player, dies on contact dealing explosion damage.
  void _updateSuicideRusher(double dt, Offset playerPos, double distToPlayer,
      Offset toPlayer, GameMap map) {
    final canSee = _hasLineOfSight(playerPos, distToPlayer, map);

    if (!canSee || distToPlayer > detectionRange) {
      _wander(dt, map);
      return;
    }

    state = EnemyState.chasing;
    angle = atan2(toPlayer.dy, toPlayer.dx);
    _moveToward(angle, dt, map);

    // Explode on contact
    if (distToPlayer <= attackRange) {
      state = EnemyState.attacking;
      if (_attackTimer <= 0) {
        _attackTimer = attackCooldown;
        hasExploded = true;
      }
    }
  }

  /// Healer: stays near hostiles and heals them, avoids the player.
  void _updateHealer(double dt, Offset playerPos, double distToPlayer,
      GameMap map) {
    final canSee = _hasLineOfSight(playerPos, distToPlayer, map);
    final toPlayer = playerPos - position;
    angle = atan2(toPlayer.dy, toPlayer.dx);

    if (canSee && distToPlayer < preferredRange) {
      // Too close to player, run away
      state = EnemyState.chasing;
      _moveToward(angle + pi, dt, map);
    } else {
      // Wander but stay in the area
      _wander(dt, map);
    }

    // Healing is handled externally in fps_game.dart via healNearby()
  }

  /// Heal a nearby enemy.
  bool canHeal() {
    if (type != EnemyType.healer || isDead || _healCooldown > 0) return false;
    _healCooldown = 2.5;
    return true;
  }

  void receiveHeal(double amount) {
    if (isDead) return;
    health = (health + amount).clamp(0, maxHealth);
  }

  /// Boss: alternates between rushing and ranged attacks.
  void _updateBoss(double dt, Offset playerPos, double distToPlayer,
      Offset toPlayer, GameMap map) {
    final canSee = _hasLineOfSight(playerPos, distToPlayer, map);
    angle = atan2(toPlayer.dy, toPlayer.dx);

    if (!canSee || distToPlayer > detectionRange) {
      _wander(dt, map);
      return;
    }

    if (distToPlayer <= attackRange) {
      state = EnemyState.attacking;
      if (_attackTimer <= 0) _attackTimer = attackCooldown;
    } else {
      state = EnemyState.chasing;
      _moveToward(angle, dt, map);
    }
  }

  /// Attempt teleport (trickster). Returns true if teleported.
  bool tryTeleport(GameMap map) {
    if (type != EnemyType.trickster || _teleportCooldown > 0) return false;

    // Find a random open tile nearby
    final rng = Random();
    for (int attempt = 0; attempt < 20; attempt++) {
      final nx = position.dx.floor() + rng.nextInt(7) - 3;
      final ny = position.dy.floor() + rng.nextInt(7) - 3;
      if (!map.isSolid(nx, ny)) {
        position = Offset(nx + 0.5, ny + 0.5);
        _teleportCooldown = 3.0;
        return true;
      }
    }
    return false;
  }

  void _moveToward(double moveAngle, double dt, GameMap map) {
    final dirX = cos(moveAngle) * speed * dt;
    final dirY = sin(moveAngle) * speed * dt;

    final newX = position.dx + dirX;
    final newY = position.dy + dirY;

    if (!map.isSolid(newX.floor(), position.dy.floor())) {
      position = Offset(newX, position.dy);
    }
    if (!map.isSolid(position.dx.floor(), newY.floor())) {
      position = Offset(position.dx, newY);
    }
  }

  void _wander(double dt, GameMap map) {
    state = EnemyState.idle;
    _wanderTimer -= dt;
    if (_wanderTimer <= 0) {
      _wanderTimer = 2.0 + Random().nextDouble() * 3.0;
      _idleWanderAngle += (Random().nextDouble() - 0.5) * pi;
    }
    _moveToward(_idleWanderAngle, dt * 0.3, map);
  }

  double tryAttack() {
    if (state == EnemyState.attacking && _attackTimer == attackCooldown) {
      // Swarm dies on attack (explosion)
      if (type == EnemyType.swarm) {
        health = 0;
        state = EnemyState.dead;
      }
      return attackDamage;
    }
    return 0;
  }

  double distanceTo(Offset point) {
    return (position - point).distance;
  }
}
