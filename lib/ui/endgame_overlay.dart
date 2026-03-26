import 'package:flutter/material.dart';

import '../game/fps_game.dart';

class EndgameOverlay extends StatelessWidget {
  final FpsGame game;

  const EndgameOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final won = game.didWin;
    final gameOver = !won && game.lives <= 0;
    final title = gameOver ? 'GAME OVER' : (won ? 'LEVEL CLEAR' : 'YOU DIED');
    final titleColor = won ? Colors.greenAccent : Colors.redAccent;
    final subtitle = gameOver
        ? 'Reached Level ${game.level} — Final Score: ${game.score}'
        : won
            ? (game.friendlyKills == 0
                ? 'Escaped with clean hands!'
                : 'Escaped... but at what cost?')
            : 'Lives remaining: ${game.lives}';

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
                  _statRow('HOSTILES', '${game.hostileKills}',
                      color: Colors.redAccent),
                  if (game.friendlyKills > 0)
                    _statRow('INNOCENTS KILLED', '${game.friendlyKills}',
                        color: Colors.red),
                  if (game.friendlyKills == 0 && won)
                    _statRow('INNOCENCE', 'PERFECT',
                        color: Colors.greenAccent),
                  _statRow('HEALTH', '${game.player.health.round()}%'),
                  _statRow('AMMO LEFT', '${game.player.ammo}'),
                ],
              ),
            ),

            // Show level info
            if (!gameOver)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Level ${game.level}',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
              ),

            const SizedBox(height: 40),
            if (!gameOver && !won && game.lives > 0)
              _EndgameButton(
                label: 'RETRY LEVEL',
                onPressed: () => game.retryLevel(),
              ),
            if (gameOver || won)
              _EndgameButton(
                label: gameOver ? 'NEW GAME' : 'PLAY AGAIN',
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

  Widget _statRow(String labelText, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              labelText,
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
              style: TextStyle(
                color: color ?? Colors.white,
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
