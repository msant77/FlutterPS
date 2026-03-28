import 'package:flutter/material.dart';

import '../data/save_service.dart';
import '../game/fps_game.dart';
import 'menu_button.dart';

class HighScoresOverlay extends StatefulWidget {
  final FpsGame game;

  const HighScoresOverlay({super.key, required this.game});

  @override
  State<HighScoresOverlay> createState() => _HighScoresOverlayState();
}

class _HighScoresOverlayState extends State<HighScoresOverlay> {
  List<HighScoreEntry> _scores = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    final scores = await SaveService.loadHighScores();
    if (mounted) {
      setState(() {
        _scores = scores;
        _loaded = true;
      });
    }
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
                  colors: [Colors.amber, Colors.orangeAccent],
                ).createShader(bounds),
                child: const Text(
                  'HIGH SCORES',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 6,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              if (!_loaded)
                const CircularProgressIndicator(color: Colors.amber)
              else if (_scores.isEmpty)
                Text(
                  'No scores yet — go slay some memes!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                _buildScoreTable(),

              const SizedBox(height: 40),

              MenuButton(
                label: 'BACK',
                onPressed: () => widget.game.showMainMenu(),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreTable() {
    return Container(
      width: 500,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                _headerCell('#', 30),
                _headerCell('SCORE', 80),
                _headerCell('LVL', 40),
                _headerCell('KILLS', 50),
                const Spacer(),
                _headerCell('DATE', 90),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Colors.amber.withValues(alpha: 0.2),
          ),
          // Rows
          for (int i = 0; i < _scores.length; i++) ...[
            const SizedBox(height: 8),
            _buildRow(i, _scores[i]),
          ],
        ],
      ),
    );
  }

  Widget _headerCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.amber.withValues(alpha: 0.6),
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildRow(int index, HighScoreEntry entry) {
    final rank = index + 1;
    final rankColor = switch (rank) {
      1 => Colors.amber,
      2 => Colors.grey.shade300,
      3 => const Color(0xFFCD7F32), // Bronze
      _ => Colors.grey.shade500,
    };

    final dateStr = _formatDate(entry.date);

    return Row(
      children: [
        // Rank
        SizedBox(
          width: 30,
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: rankColor,
              fontFamily: 'Courier',
            ),
          ),
        ),
        // Score
        SizedBox(
          width: 80,
          child: Text(
            '${entry.score}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Courier',
            ),
          ),
        ),
        // Level
        SizedBox(
          width: 40,
          child: Text(
            '${entry.levelReached}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade300,
              fontFamily: 'Courier',
            ),
          ),
        ),
        // Kills
        SizedBox(
          width: 50,
          child: Text(
            '${entry.totalKills}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade300,
              fontFamily: 'Courier',
            ),
          ),
        ),
        const Spacer(),
        // Innocence badge
        if (entry.innocenceBonus)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'INNOCENT',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.greenAccent,
                letterSpacing: 1,
              ),
            ),
          ),
        // Date
        SizedBox(
          width: 90,
          child: Text(
            dateStr,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontFamily: 'Courier',
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}
