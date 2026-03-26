import 'dart:math';
import 'dart:ui';

import '../world/game_map.dart';

class Player {
  Offset position;
  double angle;
  double health;
  int ammo;
  int kills;
  double speed;
  double rotSpeed;
  double bobPhase;
  double bobAmplitude;
  bool isShooting;
  double shootCooldown;
  double shootTimer;

  static const double collisionRadius = 0.25;
  static const double fov = pi / 3; // 60 degrees

  Player({
    required this.position,
    this.angle = 0,
    this.health = 100,
    this.ammo = 50,
    this.kills = 0,
    this.speed = 3.0,
    this.rotSpeed = 2.5,
    this.bobPhase = 0,
    this.bobAmplitude = 4.0,
    this.isShooting = false,
    this.shootCooldown = 0,
    this.shootTimer = 0,
  });

  double get bobOffset => sin(bobPhase) * bobAmplitude;

  void move(double forward, double strafe, double dt, GameMap map) {
    final dx = cos(angle) * forward - sin(angle) * strafe;
    final dy = sin(angle) * forward + cos(angle) * strafe;

    final moveSpeed = speed * dt;
    final newX = position.dx + dx * moveSpeed;
    final newY = position.dy + dy * moveSpeed;

    // Collision: check the bounding box edges in the direction of movement
    // Test X axis
    if (!_collidesX(newX, position.dy, map)) {
      position = Offset(newX, position.dy);
    }
    // Test Y axis (using potentially updated X)
    if (!_collidesY(position.dx, newY, map)) {
      position = Offset(position.dx, newY);
    }

    // Head bob when moving
    if (forward.abs() > 0.1 || strafe.abs() > 0.1) {
      bobPhase += dt * 8.0;
    } else {
      // Dampen bob when standing still
      bobPhase += dt * 0.5;
      bobAmplitude = bobAmplitude * 0.95;
      if (bobAmplitude < 0.1) bobAmplitude = 0;
    }

    if (forward.abs() > 0.1 || strafe.abs() > 0.1) {
      bobAmplitude = 4.0;
    }
  }

  /// Check if position (px, py) collides on the X axis.
  bool _collidesX(double px, double py, GameMap map) {
    // Check both corners on the Y axis at the new X position
    return map.isSolid((px + collisionRadius).floor(), (py + collisionRadius).floor()) ||
        map.isSolid((px + collisionRadius).floor(), (py - collisionRadius).floor()) ||
        map.isSolid((px - collisionRadius).floor(), (py + collisionRadius).floor()) ||
        map.isSolid((px - collisionRadius).floor(), (py - collisionRadius).floor());
  }

  /// Check if position (px, py) collides on the Y axis.
  bool _collidesY(double px, double py, GameMap map) {
    return map.isSolid((px + collisionRadius).floor(), (py + collisionRadius).floor()) ||
        map.isSolid((px + collisionRadius).floor(), (py - collisionRadius).floor()) ||
        map.isSolid((px - collisionRadius).floor(), (py + collisionRadius).floor()) ||
        map.isSolid((px - collisionRadius).floor(), (py - collisionRadius).floor());
  }

  void rotate(double delta) {
    angle += delta;
    // Keep angle in [-pi, pi]
    if (angle > pi) angle -= 2 * pi;
    if (angle < -pi) angle += 2 * pi;
  }

  bool shoot() {
    if (shootCooldown <= 0 && ammo > 0) {
      ammo--;
      isShooting = true;
      shootCooldown = 0.3; // Fire rate
      shootTimer = 1.0;
      return true;
    }
    return false;
  }

  void update(double dt) {
    if (shootCooldown > 0) {
      shootCooldown -= dt;
    }
    if (shootTimer > 0) {
      shootTimer -= dt * 5;
      if (shootTimer <= 0) {
        isShooting = false;
        shootTimer = 0;
      }
    }
  }

  void takeDamage(double amount) {
    health = (health - amount).clamp(0, 100);
  }

  bool get isDead => health <= 0;

  void heal(double amount) {
    health = (health + amount).clamp(0, 100);
  }

  void addAmmo(int amount) {
    ammo += amount;
  }
}
