import 'package:flutter/material.dart';

import '../game/fps_game.dart';

class EndgameOverlay extends StatelessWidget {
  final FpsGame game;

  const EndgameOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final won = game.didWin;
    final title = won ? 'LEVEL CLEAR' : 'YOU DIED';
    final titleColor = won ? Colors.greenAccent : Colors.redAccent;
    final subtitle = won ? 'All hostiles eliminated' : 'Better luck next time';

    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: titleColor,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 40),

            // Stats
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  _statRow('SCORE', '${game.score}'),
                  _statRow('KILLS', '${game.player.kills}'),
                  _statRow('HEALTH', '${game.player.health.round()}%'),
                  _statRow('AMMO LEFT', '${game.player.ammo}'),
                ],
              ),
            ),

            const SizedBox(height: 40),
            _EndgameButton(
              label: won ? 'PLAY AGAIN' : 'RETRY',
              onPressed: () => game.startGame(),
            ),
            const SizedBox(height: 12),
            _EndgameButton(
              label: 'MAIN MENU',
              onPressed: () => game.returnToMenu(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EndgameButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _EndgameButton({required this.label, required this.onPressed});

  @override
  State<_EndgameButton> createState() => _EndgameButtonState();
}

class _EndgameButtonState extends State<_EndgameButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          decoration: BoxDecoration(
            color: _hovering
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: _hovering ? 0.4 : 0.2),
            ),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }
}
