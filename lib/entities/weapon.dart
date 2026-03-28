/// Weapon types available to the player.
enum WeaponType {
  /// Standard sidearm. Balanced damage, rate, and ammo cost.
  pistol,

  /// Spread shot — fires 5 rays in a cone. High damage up close, burns ammo.
  shotgun,

  /// Fast fire rate, low damage per shot, 1 ammo each.
  rapidFire,

  /// Close-range claw swipe. No ammo cost, high damage, short range.
  melee,
}

/// Stats for a weapon type.
class Weapon {
  final WeaponType type;
  final String name;
  final double damage;
  final double cooldown;
  final int ammoCost;
  final int spreadRays; // 1 for single, 5 for shotgun
  final double spreadAngle; // Cone half-angle in radians
  final double range; // Max hit distance

  const Weapon._({
    required this.type,
    required this.name,
    required this.damage,
    required this.cooldown,
    required this.ammoCost,
    this.spreadRays = 1,
    this.spreadAngle = 0,
    this.range = 30,
  });

  static const pistol = Weapon._(
    type: WeaponType.pistol,
    name: 'PISTOL',
    damage: 25,
    cooldown: 0.3,
    ammoCost: 1,
  );

  static const shotgun = Weapon._(
    type: WeaponType.shotgun,
    name: 'SHOTGUN',
    damage: 15,
    cooldown: 0.8,
    ammoCost: 2,
    spreadRays: 5,
    spreadAngle: 0.12,
  );

  static const rapidFire = Weapon._(
    type: WeaponType.rapidFire,
    name: 'SMG',
    damage: 12,
    cooldown: 0.1,
    ammoCost: 1,
  );

  static const melee = Weapon._(
    type: WeaponType.melee,
    name: 'CLAWS',
    damage: 35,
    cooldown: 0.4,
    ammoCost: 0,
    range: 2.5,
  );

  static Weapon forType(WeaponType type) => switch (type) {
        WeaponType.pistol => pistol,
        WeaponType.shotgun => shotgun,
        WeaponType.rapidFire => rapidFire,
        WeaponType.melee => melee,
      };
}
