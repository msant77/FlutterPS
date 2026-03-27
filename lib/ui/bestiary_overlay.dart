import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/sprites.dart';
import '../entities/enemy.dart';
import '../game/fps_game.dart';
import 'menu_button.dart';

/// Bestiary/instructions screen showing all enemy types with descriptions.
class BestiaryOverlay extends StatefulWidget {
  final FpsGame game;

  const BestiaryOverlay({super.key, required this.game});

  @override
  State<BestiaryOverlay> createState() => _BestiaryOverlayState();
}

class _BestiaryOverlayState extends State<BestiaryOverlay> {
  bool _spritesReady = false;

  @override
  void initState() {
    super.initState();
    _ensureSprites();
  }

  Future<void> _ensureSprites() async {
    if (!widget.game.sprites.isReady) {
      await widget.game.sprites.generate();
    }
    if (mounted) setState(() => _spritesReady = true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0a0a2e),
            Color(0xFF1a0a0a),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Header
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.amber, Colors.orangeAccent, Colors.redAccent],
              ).createShader(bounds),
              child: const Text(
                'BESTIARY',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 6,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Know thy enemy. Know thy friend.',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade500,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),

            // Enemy list
            Expanded(
              child: _spritesReady
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) =>
                          _buildEntry(_entries[index]),
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    ),
            ),

            // Controls section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'CONTROLS',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _controlChip('WASD', 'Move'),
                      _controlChip('Arrows', 'Turn'),
                      _controlChip('Space', 'Shoot'),
                      _controlChip('Shift', 'Sprint'),
                      _controlChip('M', 'Map'),
                      _controlChip('ESC', 'Menu'),
                    ],
                  ),
                ],
              ),
            ),

            // Back button
            Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 8),
              child: MenuButton(
                label: 'BACK',
                onPressed: () => widget.game.showMainMenu(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlChip(String key, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Text(
              key,
              style: const TextStyle(
                color: Colors.amber,
                fontFamily: 'Courier',
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            action,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(_BestiaryEntry entry) {
    final sprite = widget.game.sprites.getSprite(entry.type, SpriteFrame.idle);
    final alignColor = switch (entry.defaultAlignment) {
      EnemyAlignment.hostile => Colors.redAccent,
      EnemyAlignment.friendly => Colors.greenAccent,
      EnemyAlignment.neutral => Colors.amber,
    };
    final alignLabel = switch (entry.defaultAlignment) {
      EnemyAlignment.hostile => 'HOSTILE',
      EnemyAlignment.friendly => 'FRIENDLY',
      EnemyAlignment.neutral => 'NEUTRAL',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alignColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alignColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Sprite
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: alignColor.withValues(alpha: 0.2)),
            ),
            child: sprite != null
                ? _SpriteImage(image: sprite)
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.memeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: alignColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        alignLabel,
                        style: TextStyle(
                          color: alignColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  entry.typeName,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.description,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                // Stat bars
                Row(
                  children: [
                    _statBar('HP', entry.hp, 250, Colors.redAccent),
                    const SizedBox(width: 8),
                    _statBar('SPD', entry.speed, 4.0, Colors.cyanAccent),
                    const SizedBox(width: 8),
                    _statBar('DMG', entry.damage, 30, Colors.orangeAccent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBar(String label, double value, double max, Color color) {
    final fraction = (value / max).clamp(0.0, 1.0);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a dart:ui Image as a widget with pixel-art filtering.
class _SpriteImage extends StatelessWidget {
  final ui.Image image;

  const _SpriteImage({required this.image});

  @override
  Widget build(BuildContext context) {
    return RawImage(
      image: image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
    );
  }
}

class _BestiaryEntry {
  final EnemyType type;
  final String memeName;
  final String typeName;
  final String description;
  final EnemyAlignment defaultAlignment;
  final double hp;
  final double speed;
  final double damage;

  const _BestiaryEntry({
    required this.type,
    required this.memeName,
    required this.typeName,
    required this.description,
    required this.defaultAlignment,
    required this.hp,
    required this.speed,
    required this.damage,
  });
}

const _entries = [
  _BestiaryEntry(
    type: EnemyType.grunt,
    memeName: 'Trollface',
    typeName: 'GRUNT',
    description:
        'The classic troublemaker. Medium speed, medium health. Charges in for melee attacks with that insufferable grin.',
    defaultAlignment: EnemyAlignment.hostile,
    hp: 40,
    speed: 1.8,
    damage: 8,
  ),
  _BestiaryEntry(
    type: EnemyType.imp,
    memeName: 'Doge',
    typeName: 'IMP',
    description:
        'Much speed. Very danger. Wow. Fragile but fast — rushes in before you can react. Easy to kill, hard to ignore.',
    defaultAlignment: EnemyAlignment.hostile,
    hp: 20,
    speed: 3.5,
    damage: 5,
  ),
  _BestiaryEntry(
    type: EnemyType.brute,
    memeName: 'Grumpy Cat',
    typeName: 'BRUTE',
    description:
        'Slow, tanky, and perpetually angry. Hits like a truck. Do not let this cat corner you.',
    defaultAlignment: EnemyAlignment.hostile,
    hp: 100,
    speed: 0.9,
    damage: 20,
  ),
  _BestiaryEntry(
    type: EnemyType.sentinel,
    memeName: 'Stonks Man',
    typeName: 'SENTINEL',
    description:
        'Keeps distance and shoots from range. When neutral, trades ammo for your company. Stonks only go up.',
    defaultAlignment: EnemyAlignment.hostile,
    hp: 30,
    speed: 1.2,
    damage: 6,
  ),
  _BestiaryEntry(
    type: EnemyType.zoomer,
    memeName: 'Distracted BF',
    typeName: 'ZOOMER',
    description:
        'Orbits around you, flanking from unexpected angles. That double-take is the last thing you see.',
    defaultAlignment: EnemyAlignment.hostile,
    hp: 35,
    speed: 2.5,
    damage: 10,
  ),
  _BestiaryEntry(
    type: EnemyType.swarm,
    memeName: 'This Is Fine Dog',
    typeName: 'SWARM',
    description:
        'Suicide rushes and explodes on contact. Everything is fine. Fragile but devastating if it reaches you.',
    defaultAlignment: EnemyAlignment.hostile,
    hp: 10,
    speed: 4.0,
    damage: 30,
  ),
  _BestiaryEntry(
    type: EnemyType.healer,
    memeName: 'Hide the Pain Harold',
    typeName: 'HEALER',
    description:
        'Heals nearby hostiles while hiding behind that forced smile. Kill him first, or the fight never ends.',
    defaultAlignment: EnemyAlignment.hostile,
    hp: 25,
    speed: 1.5,
    damage: 0,
  ),
  _BestiaryEntry(
    type: EnemyType.boss,
    memeName: 'GigaChad',
    typeName: 'BOSS',
    description:
        'Massive HP, heavy damage, and he knows it. A mini-boss that demands respect and a full clip.',
    defaultAlignment: EnemyAlignment.hostile,
    hp: 250,
    speed: 1.4,
    damage: 15,
  ),
  _BestiaryEntry(
    type: EnemyType.trickster,
    memeName: 'Rick Astley',
    typeName: 'TRICKSTER',
    description:
        'Never gonna give you up, never gonna let you aim. Teleports when shot. A frustrating distraction.',
    defaultAlignment: EnemyAlignment.hostile,
    hp: 40,
    speed: 1.0,
    damage: 4,
  ),
  _BestiaryEntry(
    type: EnemyType.sage,
    memeName: 'Rare Pepe',
    typeName: 'SAGE',
    description:
        'A rare and peaceful soul. Approach for free health. Killing him costs you dearly. Protect the Pepe.',
    defaultAlignment: EnemyAlignment.neutral,
    hp: 60,
    speed: 0.0,
    damage: 0,
  ),
];
