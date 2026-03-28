import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/save_service.dart';
import '../engine/sprites.dart';
import '../entities/enemy.dart';
import '../game/fps_game.dart';
import 'menu_button.dart';

class MainMenuOverlay extends StatefulWidget {
  final FpsGame game;

  const MainMenuOverlay({super.key, required this.game});

  @override
  State<MainMenuOverlay> createState() => _MainMenuOverlayState();
}

class _MainMenuOverlayState extends State<MainMenuOverlay>
    with SingleTickerProviderStateMixin {
  bool _spritesReady = false;
  bool _hasSave = false;
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _ensureSprites();
    _checkSave();
  }

  Future<void> _checkSave() async {
    final exists = await SaveService.hasSaveGame();
    if (mounted) setState(() => _hasSave = exists);
  }

  Future<void> _ensureSprites() async {
    if (!widget.game.sprites.isReady) {
      await widget.game.sprites.generate();
    }
    if (mounted) setState(() => _spritesReady = true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
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
            Color(0xFF12081a),
            Color(0xFF1a0a0a),
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 40),

              // Title
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Colors.redAccent,
                    Colors.amber,
                    Colors.orangeAccent,
                  ],
                ).createShader(bounds),
                child: const Text(
                  'MEMESLAYER',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 6,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Not everything in the maze deserves to die',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade400,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 40),

              // Sprite showcase
              if (_spritesReady) _buildSpriteShowcase(),

              const SizedBox(height: 40),

              // Buttons
              if (_hasSave) ...[
                MenuButton(
                  label: 'CONTINUE',
                  onPressed: () => widget.game.continueGame(),
                  primary: true,
                ),
                const SizedBox(height: 12),
              ],
              MenuButton(
                label: 'NEW GAME',
                onPressed: () => widget.game.startGame(),
                primary: !_hasSave,
              ),
              const SizedBox(height: 12),
              MenuButton(
                label: 'BESTIARY',
                onPressed: () => widget.game.showBestiary(),
              ),
              const SizedBox(height: 12),
              MenuButton(
                label: 'HIGH SCORES',
                onPressed: () => widget.game.showHighScores(),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpriteShowcase() {
    // Featured enemies for the main menu
    const featured = [
      (EnemyType.grunt, 'Trollface', Colors.redAccent),
      (EnemyType.imp, 'Doge', Colors.amber),
      (EnemyType.brute, 'Grumpy Cat', Colors.blueGrey),
      (EnemyType.boss, 'GigaChad', Colors.deepPurple),
      (EnemyType.trickster, 'Rick Astley', Colors.teal),
      (EnemyType.sage, 'Rare Pepe', Colors.green),
    ];

    return SizedBox(
      height: 130,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            itemCount: featured.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final (type, name, color) = featured[index];
              final sprite =
                  widget.game.sprites.getSprite(type, SpriteFrame.idle);
              // Staggered floating animation
              final bobOffset =
                  sin(_anim.value * 2 * pi + index * 0.8) * 4.0;

              return Transform.translate(
                offset: Offset(0, bobOffset),
                child: _SpriteCard(
                  sprite: sprite,
                  name: name,
                  color: color,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SpriteCard extends StatelessWidget {
  final ui.Image? sprite;
  final String name;
  final Color color;

  const _SpriteCard({
    required this.sprite,
    required this.name,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: sprite != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: RawImage(
                    image: sprite,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
