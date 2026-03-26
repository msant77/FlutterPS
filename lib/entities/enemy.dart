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
  /// Basic grunt — medium speed, medium health, melee.
  grunt,

  /// Fast imp — fast, low health, charges in.
  imp,

  /// Heavy brute — slow, lots of health, hits hard.
  brute,

  /// Ranged sentinel — stays at distance, shoots.
  sentinel,
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

  // Sentinel specific: preferred distance from player
  double preferredRange;

  /// Alignment: hostile, friendly, or neutral.
  EnemyAlignment alignment;

  /// Whether this neutral NPC has already given its item.
  bool hasGivenItem;

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
        state = EnemyState.idle,
        angle = 0,
        hurtTimer = 0,
        _idleWanderAngle = Random().nextDouble() * pi * 2,
        _wanderTimer = 0;

  /// Score value when killed. Positive for hostiles, negative for friendlies.
  int get scoreValue {
    if (alignment == EnemyAlignment.friendly) {
      // Heavy penalty for killing friendlies
      return -200;
    }
    if (alignment == EnemyAlignment.neutral) {
      return -150;
    }
    // Hostile: points scale with difficulty
    switch (type) {
      case EnemyType.grunt:
        return 100;
      case EnemyType.imp:
        return 75;
      case EnemyType.brute:
        return 200;
      case EnemyType.sentinel:
        return 150;
    }
  }

  /// Spawn the right enemy type at a position.
  factory Enemy.spawn(Offset position, EnemyType type,
      {EnemyAlignment alignment = EnemyAlignment.hostile}) {
    switch (type) {
      case EnemyType.grunt:
        return Enemy._(
          position: position,
          type: type,
          health: 40,
          maxHealth: 40,
          speed: 1.8,
          attackRange: 1.5,
          attackDamage: 8,
          attackCooldown: 1.0,
          detectionRange: 10.0,
          preferredRange: 0,
          alignment: alignment,
        );
      case EnemyType.imp:
        return Enemy._(
          position: position,
          type: type,
          health: 20,
          maxHealth: 20,
          speed: 3.5,
          attackRange: 1.2,
          attackDamage: 5,
          attackCooldown: 0.5,
          detectionRange: 12.0,
          preferredRange: 0,
          alignment: alignment,
        );
      case EnemyType.brute:
        return Enemy._(
          position: position,
          type: type,
          health: 100,
          maxHealth: 100,
          speed: 0.9,
          attackRange: 2.0,
          attackDamage: 20,
          attackCooldown: 1.8,
          detectionRange: 8.0,
          preferredRange: 0,
          alignment: alignment,
        );
      case EnemyType.sentinel:
        return Enemy._(
          position: position,
          type: type,
          health: 30,
          maxHealth: 30,
          speed: 1.2,
          attackRange: 8.0,
          attackDamage: 6,
          attackCooldown: 1.5,
          detectionRange: 15.0,
          preferredRange: 5.0,
          alignment: alignment,
        );
    }
  }

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
    }
  }

  void update(double dt, Offset playerPos, GameMap map) {
    if (isDead) return;

    // Hurt state recovery
    if (state == EnemyState.hurt) {
      hurtTimer -= dt;
      if (hurtTimer <= 0) {
        // Friendly/neutral stay idle after being hit, hostile aggro
        state = alignment == EnemyAlignment.hostile
            ? EnemyState.chasing
            : EnemyState.idle;
      }
      return; // Stunned briefly when hurt
    }

    // Neutral NPCs are stationary
    if (alignment == EnemyAlignment.neutral) {
      state = EnemyState.idle;
      return;
    }

    // Friendly NPCs just wander, never attack
    if (alignment == EnemyAlignment.friendly) {
      _wander(dt, map);
      return;
    }

    final toPlayer = playerPos - position;
    final distToPlayer = toPlayer.distance;

    if (_attackTimer > 0) { _attackTimer -= dt; }

    switch (type) {
      case EnemyType.sentinel:
        _updateSentinel(dt, playerPos, distToPlayer, toPlayer, map);
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

  void _updateMelee(
    double dt,
    Offset playerPos,
    double distToPlayer,
    Offset toPlayer,
    GameMap map,
  ) {
    final canSee = _hasLineOfSight(playerPos, distToPlayer, map);

    if (distToPlayer <= attackRange && canSee) {
      state = EnemyState.attacking;
      angle = atan2(toPlayer.dy, toPlayer.dx);
      if (_attackTimer <= 0) {
        _attackTimer = attackCooldown;
      }
    } else if (distToPlayer <= detectionRange && canSee) {
      state = EnemyState.chasing;
      angle = atan2(toPlayer.dy, toPlayer.dx);
      _moveToward(angle, dt, map);
    } else {
      _wander(dt, map);
    }
  }

  void _updateSentinel(
    double dt,
    Offset playerPos,
    double distToPlayer,
    Offset toPlayer,
    GameMap map,
  ) {
    final canSee = _hasLineOfSight(playerPos, distToPlayer, map);
    angle = atan2(toPlayer.dy, toPlayer.dx);

    if (distToPlayer <= detectionRange && canSee) {
      if (distToPlayer <= attackRange && distToPlayer >= preferredRange - 1) {
        state = EnemyState.attacking;
        if (_attackTimer <= 0) {
          _attackTimer = attackCooldown;
        }

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
    // Slow wander movement
    _moveToward(_idleWanderAngle, dt * 0.3, map);
  }

  double tryAttack() {
    if (state == EnemyState.attacking && _attackTimer == attackCooldown) {
      return attackDamage;
    }
    return 0;
  }

  double distanceTo(Offset point) {
    return (position - point).distance;
  }
}
