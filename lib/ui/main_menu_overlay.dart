import 'package:flutter/material.dart';

import '../game/fps_game.dart';

class MainMenuOverlay extends StatelessWidget {
  final FpsGame game;

  const MainMenuOverlay({super.key, required this.game});

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
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.redAccent, Colors.orangeAccent],
              ).createShader(bounds),
              child: const Text(
                'RAYCASTER',
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 8,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'F P S',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                color: Colors.grey.shade500,
                letterSpacing: 16,
              ),
            ),
            const SizedBox(height: 60),

            // Start button
            _MenuButton(
              label: 'START GAME',
              onPressed: () => game.startGame(),
              primary: true,
            ),
            const SizedBox(height: 16),

            // Controls info
            Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.only(top: 40),
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
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _controlRow('WASD', 'Move'),
                  _controlRow('Arrow Keys', 'Turn / Move'),
                  _controlRow('Space', 'Shoot'),
                  _controlRow('Shift', 'Sprint'),
                  _controlRow('M', 'Toggle Minimap'),
                  _controlRow('ESC', 'Menu'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlRow(String key, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              key,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.amber,
                fontFamily: 'Courier',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            action,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  const _MenuButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          decoration: BoxDecoration(
            color: _hovering
                ? (widget.primary ? Colors.redAccent : Colors.white.withValues(alpha: 0.15))
                : (widget.primary
                    ? Colors.redAccent.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.primary
                  ? Colors.redAccent
                  : Colors.white.withValues(alpha: 0.2),
              width: _hovering ? 2 : 1,
            ),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }
}
