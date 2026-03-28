import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

const _dirName = 'memeslayer';
const _saveFile = 'save.json';
const _scoresFile = 'highscores.json';
const _maxHighScores = 10;

// ──────────────────────────────────────────────────────────────
// Save Service
// ──────────────────────────────────────────────────────────────

class SaveService {
  static Future<Directory> _dataDir() async {
    final appSupport = await getApplicationSupportDirectory();
    final dir = Directory('${appSupport.path}/$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Save Game ───────────────────────────────────────────────

  static Future<void> saveGame(SaveData data) async {
    final dir = await _dataDir();
    final file = File('${dir.path}/$_saveFile');
    await file.writeAsString(jsonEncode(data.toJson()));
  }

  static Future<SaveData?> loadGame() async {
    try {
      final dir = await _dataDir();
      final file = File('${dir.path}/$_saveFile');
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return SaveData.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasSaveGame() async {
    return await loadGame() != null;
  }

  static Future<void> deleteSave() async {
    try {
      final dir = await _dataDir();
      final file = File('${dir.path}/$_saveFile');
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Silently ignore
    }
  }

  // ── High Scores ─────────────────────────────────────────────

  static Future<void> addHighScore(HighScoreEntry entry) async {
    final scores = await loadHighScores();
    scores.add(entry);
    scores.sort((a, b) => b.score.compareTo(a.score));
    if (scores.length > _maxHighScores) {
      scores.removeRange(_maxHighScores, scores.length);
    }
    final dir = await _dataDir();
    final file = File('${dir.path}/$_scoresFile');
    await file.writeAsString(
        jsonEncode(scores.map((s) => s.toJson()).toList()));
  }

  static Future<List<HighScoreEntry>> loadHighScores() async {
    try {
      final dir = await _dataDir();
      final file = File('${dir.path}/$_scoresFile');
      if (!await file.exists()) return [];
      final json = jsonDecode(await file.readAsString());
      return (json as List)
          .map((e) => HighScoreEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

// ──────────────────────────────────────────────────────────────
// Save Data
// ──────────────────────────────────────────────────────────────

class SaveData {
  final int score;
  final int level;
  final int lives;
  final int hostileKills;
  final int friendlyKills;

  final double playerX;
  final double playerY;
  final double playerAngle;
  final double playerHealth;
  final int playerAmmo;
  final int playerKills;

  final int mapWidth;
  final int mapHeight;
  final List<List<String>> grid; // Tile.name strings
  final bool exitUnlocked;

  final List<EnemySaveData> enemies;

  const SaveData({
    required this.score,
    required this.level,
    required this.lives,
    required this.hostileKills,
    required this.friendlyKills,
    required this.playerX,
    required this.playerY,
    required this.playerAngle,
    required this.playerHealth,
    required this.playerAmmo,
    required this.playerKills,
    required this.mapWidth,
    required this.mapHeight,
    required this.grid,
    required this.exitUnlocked,
    required this.enemies,
  });

  Map<String, dynamic> toJson() => {
        'score': score,
        'level': level,
        'lives': lives,
        'hostileKills': hostileKills,
        'friendlyKills': friendlyKills,
        'playerX': playerX,
        'playerY': playerY,
        'playerAngle': playerAngle,
        'playerHealth': playerHealth,
        'playerAmmo': playerAmmo,
        'playerKills': playerKills,
        'mapWidth': mapWidth,
        'mapHeight': mapHeight,
        'grid': grid,
        'exitUnlocked': exitUnlocked,
        'enemies': enemies.map((e) => e.toJson()).toList(),
      };

  factory SaveData.fromJson(Map<String, dynamic> j) => SaveData(
        score: j['score'] as int,
        level: j['level'] as int,
        lives: j['lives'] as int,
        hostileKills: j['hostileKills'] as int,
        friendlyKills: j['friendlyKills'] as int,
        playerX: (j['playerX'] as num).toDouble(),
        playerY: (j['playerY'] as num).toDouble(),
        playerAngle: (j['playerAngle'] as num).toDouble(),
        playerHealth: (j['playerHealth'] as num).toDouble(),
        playerAmmo: j['playerAmmo'] as int,
        playerKills: j['playerKills'] as int,
        mapWidth: j['mapWidth'] as int,
        mapHeight: j['mapHeight'] as int,
        grid: (j['grid'] as List)
            .map((row) => (row as List).cast<String>().toList())
            .toList(),
        exitUnlocked: j['exitUnlocked'] as bool,
        enemies: (j['enemies'] as List)
            .map((e) => EnemySaveData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ──────────────────────────────────────────────────────────────
// Enemy Save Data
// ──────────────────────────────────────────────────────────────

class EnemySaveData {
  final double x;
  final double y;
  final double health;
  final double maxHealth;
  final String state;
  final double angle;
  final String type;
  final String alignment;
  final bool hasGivenItem;
  final bool hasExploded;

  const EnemySaveData({
    required this.x,
    required this.y,
    required this.health,
    required this.maxHealth,
    required this.state,
    required this.angle,
    required this.type,
    required this.alignment,
    required this.hasGivenItem,
    required this.hasExploded,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'health': health,
        'maxHealth': maxHealth,
        'state': state,
        'angle': angle,
        'type': type,
        'alignment': alignment,
        'hasGivenItem': hasGivenItem,
        'hasExploded': hasExploded,
      };

  factory EnemySaveData.fromJson(Map<String, dynamic> j) => EnemySaveData(
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        health: (j['health'] as num).toDouble(),
        maxHealth: (j['maxHealth'] as num).toDouble(),
        state: j['state'] as String,
        angle: (j['angle'] as num).toDouble(),
        type: j['type'] as String,
        alignment: j['alignment'] as String,
        hasGivenItem: j['hasGivenItem'] as bool,
        hasExploded: j['hasExploded'] as bool,
      );
}

// ──────────────────────────────────────────────────────────────
// High Score Entry
// ──────────────────────────────────────────────────────────────

class HighScoreEntry {
  final int score;
  final int levelReached;
  final int totalKills;
  final String date;
  final bool innocenceBonus;

  const HighScoreEntry({
    required this.score,
    required this.levelReached,
    required this.totalKills,
    required this.date,
    required this.innocenceBonus,
  });

  Map<String, dynamic> toJson() => {
        'score': score,
        'level': levelReached,
        'kills': totalKills,
        'date': date,
        'innocence': innocenceBonus,
      };

  factory HighScoreEntry.fromJson(Map<String, dynamic> j) => HighScoreEntry(
        score: j['score'] as int,
        levelReached: j['level'] as int,
        totalKills: j['kills'] as int,
        date: j['date'] as String,
        innocenceBonus: j['innocence'] as bool,
      );
}
