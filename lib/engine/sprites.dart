import 'dart:typed_data';
import 'dart:ui' as ui;

import '../entities/enemy.dart';

/// Animation states for meme sprites.
enum SpriteFrame { idle, hurt, dead }

/// Procedurally generated pixel-art meme sprites.
/// Each enemy type maps to a meme character with idle/hurt/dead frames.
///
/// Mappings:
///   grunt    → Trollface (white face, wide grin)
///   imp      → Doge (yellow shiba, much speed)
///   brute    → Grumpy Cat (grey cat, big frown)
///   sentinel → Stonks Man (blue suit, arrow up)
class MemeSprites {
  static const int size = 64;

  final Map<EnemyType, Map<SpriteFrame, ui.Image>> _sprites = {};

  bool _ready = false;
  bool get isReady => _ready;

  /// Get the sprite image for an enemy type and animation frame.
  ui.Image? getSprite(EnemyType type, SpriteFrame frame) {
    return _sprites[type]?[frame];
  }

  /// Generate all sprite images. Call once at startup.
  Future<void> generate() async {
    for (final type in EnemyType.values) {
      _sprites[type] = {};
      for (final frame in SpriteFrame.values) {
        final pixels = _generateSprite(type, frame);
        _sprites[type]![frame] = await _buildImage(pixels);
      }
    }
    _ready = true;
  }

  static Future<ui.Image> _buildImage(Uint32List pixels) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      pixels.buffer.asUint8List(),
    );
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: size,
      height: size,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static Uint32List _generateSprite(EnemyType type, SpriteFrame frame) {
    switch (type) {
      case EnemyType.grunt:
        return _generateTrollface(frame);
      case EnemyType.imp:
        return _generateDoge(frame);
      case EnemyType.brute:
        return _generateGrumpyCat(frame);
      case EnemyType.sentinel:
        return _generateStonksMan(frame);
    }
  }

  /// Pack RGBA into uint32 (little-endian: ABGR).
  static int _rgba(int r, int g, int b, [int a = 255]) {
    return (a << 24) | (b << 16) | (g << 8) | r;
  }

  static const int _transparent = 0x00000000;

  static void _setPixel(Uint32List pixels, int x, int y, int color) {
    if (x >= 0 && x < size && y >= 0 && y < size) {
      pixels[y * size + x] = color;
    }
  }

  static void _fillRect(
      Uint32List pixels, int x, int y, int w, int h, int color) {
    for (int py = y; py < y + h; py++) {
      for (int px = x; px < x + w; px++) {
        _setPixel(pixels, px, py, color);
      }
    }
  }

  static void _fillCircle(
      Uint32List pixels, int cx, int cy, int radius, int color) {
    for (int y = cy - radius; y <= cy + radius; y++) {
      for (int x = cx - radius; x <= cx + radius; x++) {
        if ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= radius * radius) {
          _setPixel(pixels, x, y, color);
        }
      }
    }
  }

  static void _fillOval(
      Uint32List pixels, int cx, int cy, int rx, int ry, int color) {
    for (int y = cy - ry; y <= cy + ry; y++) {
      for (int x = cx - rx; x <= cx + rx; x++) {
        final dx = (x - cx) / rx;
        final dy = (y - cy) / ry;
        if (dx * dx + dy * dy <= 1.0) {
          _setPixel(pixels, x, y, color);
        }
      }
    }
  }

  // ── Trollface (grunt) ──────────────────────────────────────────

  static Uint32List _generateTrollface(SpriteFrame frame) {
    final pixels = Uint32List(size * size);
    pixels.fillRange(0, pixels.length, _transparent);

    final white = _rgba(240, 240, 240);
    final outline = _rgba(40, 40, 40);
    final eye = _rgba(20, 20, 20);
    final mouth = _rgba(200, 50, 50);

    if (frame == SpriteFrame.dead) {
      // Dead: face sideways/fallen, X eyes
      _fillOval(pixels, 32, 38, 22, 16, white);
      _fillOval(pixels, 32, 38, 23, 17, outline);
      _fillOval(pixels, 32, 38, 21, 15, white);
      // X eyes
      for (int i = -3; i <= 3; i++) {
        _setPixel(pixels, 22 + i, 34 + i, eye);
        _setPixel(pixels, 22 + i, 40 - i, eye);
        _setPixel(pixels, 40 + i, 34 + i, eye);
        _setPixel(pixels, 40 + i, 40 - i, eye);
      }
      // Flat line mouth
      _fillRect(pixels, 22, 46, 20, 2, outline);
      return pixels;
    }

    // Face shape — wide, slightly deformed oval
    _fillOval(pixels, 32, 30, 24, 22, outline);
    _fillOval(pixels, 32, 30, 22, 20, white);

    if (frame == SpriteFrame.hurt) {
      // Hurt tint: reddish overlay
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          final c = pixels[y * size + x];
          if (c != _transparent && c != outline && c != eye) {
            pixels[y * size + x] = _rgba(255, 180, 180);
          }
        }
      }
    }

    // Squinted eyes — thin horizontal lines
    _fillRect(pixels, 18, 24, 10, 3, eye);
    _fillRect(pixels, 36, 24, 10, 3, eye);
    // Raised eyebrow on left
    _fillRect(pixels, 17, 20, 12, 2, outline);

    // Wide troll grin — curved upward
    for (int x = 14; x < 50; x++) {
      final dx = (x - 32).toDouble();
      final curveY = (30 + (dx * dx * 0.02)).round();
      _setPixel(pixels, x, curveY, outline);
      _setPixel(pixels, x, curveY + 1, outline);
    }
    // Teeth
    _fillRect(pixels, 18, 31, 28, 6, white);
    // Tooth lines
    for (int tx = 20; tx < 46; tx += 4) {
      _fillRect(pixels, tx, 31, 1, 6, outline);
    }
    // Lower lip
    _fillRect(pixels, 16, 37, 32, 3, mouth);

    // Chin
    _fillOval(pixels, 32, 44, 16, 8, outline);
    _fillOval(pixels, 32, 44, 14, 6, white);

    if (frame == SpriteFrame.hurt) {
      // Re-apply hurt tint
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          final c = pixels[y * size + x];
          if (c == white) {
            pixels[y * size + x] = _rgba(255, 200, 200);
          }
        }
      }
    }

    return pixels;
  }

  // ── Doge (imp) ─────────────────────────────────────────────────

  static Uint32List _generateDoge(SpriteFrame frame) {
    final pixels = Uint32List(size * size);
    pixels.fillRange(0, pixels.length, _transparent);

    final fur = _rgba(220, 180, 80);
    final lightFur = _rgba(245, 225, 170);
    final darkFur = _rgba(180, 140, 50);
    final outline = _rgba(60, 40, 10);
    final eye = _rgba(30, 20, 10);
    final nose = _rgba(40, 30, 25);
    final tongue = _rgba(230, 100, 120);

    if (frame == SpriteFrame.dead) {
      // Dead doge: lying flat, X eyes
      _fillOval(pixels, 32, 36, 20, 14, fur);
      _fillOval(pixels, 32, 36, 18, 12, lightFur);
      // X eyes
      for (int i = -2; i <= 2; i++) {
        _setPixel(pixels, 24 + i, 32 + i, eye);
        _setPixel(pixels, 24 + i, 36 - i, eye);
        _setPixel(pixels, 40 + i, 32 + i, eye);
        _setPixel(pixels, 40 + i, 36 - i, eye);
      }
      _fillCircle(pixels, 32, 42, 2, nose);
      return pixels;
    }

    // Head shape — round shiba face
    _fillCircle(pixels, 32, 32, 24, outline);
    _fillCircle(pixels, 32, 32, 22, fur);

    // Light face center
    _fillOval(pixels, 32, 36, 14, 12, lightFur);

    // Ears (triangular, pointy)
    // Left ear
    for (int i = 0; i < 14; i++) {
      final w = 14 - i;
      _fillRect(pixels, 10 - w ~/ 2 + 4, 4 + i, w, 1, darkFur);
    }
    // Right ear
    for (int i = 0; i < 14; i++) {
      final w = 14 - i;
      _fillRect(pixels, 50 - w ~/ 2 - 4, 4 + i, w, 1, darkFur);
    }

    // Eyes — round with raised eyebrow look
    _fillCircle(pixels, 22, 28, 4, _rgba(255, 255, 255));
    _fillCircle(pixels, 22, 28, 2, eye);
    _fillCircle(pixels, 42, 28, 4, _rgba(255, 255, 255));
    _fillCircle(pixels, 42, 28, 2, eye);

    // Raised eyebrows (the classic doge look)
    _fillRect(pixels, 17, 22, 12, 2, darkFur);
    _fillRect(pixels, 37, 22, 12, 2, darkFur);

    // Nose
    _fillOval(pixels, 32, 38, 4, 3, nose);

    // Mouth — slight open-mouth smile
    for (int x = 26; x < 38; x++) {
      final dx = (x - 32).toDouble();
      final curveY = (42 + (dx * dx * 0.04)).round();
      _setPixel(pixels, x, curveY, outline);
    }

    // Tongue sticking out (classic doge)
    if (frame == SpriteFrame.idle) {
      _fillOval(pixels, 34, 47, 4, 5, tongue);
    }

    if (frame == SpriteFrame.hurt) {
      // Hurt: reddish tint, squished eyes
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          final c = pixels[y * size + x];
          if (c == fur || c == lightFur) {
            pixels[y * size + x] = _rgba(240, 160, 100);
          }
        }
      }
      // Replace round eyes with squint lines
      _fillCircle(pixels, 22, 28, 4, _rgba(240, 160, 100));
      _fillCircle(pixels, 42, 28, 4, _rgba(240, 160, 100));
      _fillRect(pixels, 18, 27, 10, 2, eye);
      _fillRect(pixels, 38, 27, 10, 2, eye);
    }

    return pixels;
  }

  // ── Grumpy Cat (brute) ─────────────────────────────────────────

  static Uint32List _generateGrumpyCat(SpriteFrame frame) {
    final pixels = Uint32List(size * size);
    pixels.fillRange(0, pixels.length, _transparent);

    final grey = _rgba(140, 140, 150);
    final lightGrey = _rgba(190, 190, 195);
    final darkGrey = _rgba(80, 80, 90);
    final outline = _rgba(40, 40, 50);
    final eye = _rgba(30, 30, 30);
    final eyeColor = _rgba(160, 180, 50); // Greenish cat eyes

    if (frame == SpriteFrame.dead) {
      // Dead: flat cat, X eyes
      _fillOval(pixels, 32, 36, 22, 16, grey);
      _fillOval(pixels, 32, 36, 20, 14, lightGrey);
      for (int i = -3; i <= 3; i++) {
        _setPixel(pixels, 22 + i, 32 + i, eye);
        _setPixel(pixels, 22 + i, 38 - i, eye);
        _setPixel(pixels, 42 + i, 32 + i, eye);
        _setPixel(pixels, 42 + i, 38 - i, eye);
      }
      // Flat mouth
      _fillRect(pixels, 24, 44, 16, 2, outline);
      return pixels;
    }

    // Wide, flat cat head
    _fillOval(pixels, 32, 34, 26, 22, outline);
    _fillOval(pixels, 32, 34, 24, 20, grey);

    // Light face patches
    _fillOval(pixels, 32, 38, 16, 12, lightGrey);

    // Pointy ears
    for (int i = 0; i < 16; i++) {
      final w = 16 - i;
      _fillRect(pixels, 6 - w ~/ 2 + 6, 6 + i, w, 1, darkGrey);
      // Inner ear
      if (i > 4 && i < 14) {
        _fillRect(pixels, 6 - (w - 4) ~/ 2 + 6, 6 + i, w - 4, 1,
            _rgba(180, 140, 140));
      }
    }
    for (int i = 0; i < 16; i++) {
      final w = 16 - i;
      _fillRect(pixels, 52 - w ~/ 2 - 2, 6 + i, w, 1, darkGrey);
      if (i > 4 && i < 14) {
        _fillRect(pixels, 52 - (w - 4) ~/ 2 - 2, 6 + i, w - 4, 1,
            _rgba(180, 140, 140));
      }
    }

    // Angry cat eyes — slit pupils
    _fillOval(pixels, 20, 30, 6, 5, _rgba(255, 255, 240));
    _fillOval(pixels, 44, 30, 6, 5, _rgba(255, 255, 240));
    _fillOval(pixels, 20, 30, 5, 4, eyeColor);
    _fillOval(pixels, 44, 30, 5, 4, eyeColor);
    // Vertical slit pupils
    _fillRect(pixels, 19, 27, 2, 7, eye);
    _fillRect(pixels, 43, 27, 2, 7, eye);

    // Angry brow — angled downward toward center
    for (int i = 0; i < 8; i++) {
      _setPixel(pixels, 14 + i, 24 + i ~/ 2, outline);
      _setPixel(pixels, 14 + i, 25 + i ~/ 2, outline);
      _setPixel(pixels, 50 - i, 24 + i ~/ 2, outline);
      _setPixel(pixels, 50 - i, 25 + i ~/ 2, outline);
    }

    // Nose
    _fillOval(pixels, 32, 38, 3, 2, _rgba(180, 130, 130));

    // THE FROWN — iconic grumpy cat downturned mouth
    for (int x = 18; x < 46; x++) {
      final dx = (x - 32).toDouble();
      final curveY = (42 - (dx * dx * 0.03)).round();
      _setPixel(pixels, x, curveY, outline);
      _setPixel(pixels, x, curveY + 1, outline);
    }

    // Whiskers
    for (int i = 0; i < 12; i++) {
      _setPixel(pixels, 6 + i, 36, outline);
      _setPixel(pixels, 6 + i, 39, outline);
      _setPixel(pixels, 52 - i, 36, outline);
      _setPixel(pixels, 52 - i, 39, outline);
    }

    // Dark markings around the mouth area (grumpy cat pattern)
    _fillOval(pixels, 32, 44, 10, 5, darkGrey);
    _fillOval(pixels, 32, 44, 8, 3, lightGrey);

    if (frame == SpriteFrame.hurt) {
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          final c = pixels[y * size + x];
          if (c == grey || c == lightGrey) {
            pixels[y * size + x] = _rgba(220, 170, 170);
          }
        }
      }
    }

    return pixels;
  }

  // ── Stonks Man (sentinel) ──────────────────────────────────────

  static Uint32List _generateStonksMan(SpriteFrame frame) {
    final pixels = Uint32List(size * size);
    pixels.fillRange(0, pixels.length, _transparent);

    final suit = _rgba(30, 50, 120);
    final suitLight = _rgba(50, 70, 160);
    final skin = _rgba(220, 190, 150);
    final outline = _rgba(20, 20, 40);
    final arrowGreen = _rgba(40, 220, 80);

    if (frame == SpriteFrame.dead) {
      // Dead stonks: NOT stonks (red arrow down)
      _fillOval(pixels, 32, 24, 12, 12, skin);
      // X eyes
      final eye = _rgba(20, 20, 20);
      for (int i = -2; i <= 2; i++) {
        _setPixel(pixels, 26 + i, 22 + i, eye);
        _setPixel(pixels, 26 + i, 26 - i, eye);
        _setPixel(pixels, 38 + i, 22 + i, eye);
        _setPixel(pixels, 38 + i, 26 - i, eye);
      }
      // Red arrow pointing down
      final red = _rgba(220, 40, 40);
      _fillRect(pixels, 28, 38, 8, 16, red);
      // Arrow head
      for (int i = 0; i < 8; i++) {
        _fillRect(pixels, 24 + i, 50 + i, 16 - i * 2, 2, red);
      }
      return pixels;
    }

    // Head — smooth, slightly elongated (the mannequin look)
    _fillOval(pixels, 32, 16, 12, 14, outline);
    _fillOval(pixels, 32, 16, 10, 12, skin);

    // Eyes — hollow/featureless (stonks man aesthetic)
    _fillCircle(pixels, 27, 14, 2, outline);
    _fillCircle(pixels, 37, 14, 2, outline);
    // Confident smirk
    for (int x = 28; x < 38; x++) {
      final dx = (x - 33).toDouble();
      final cy = (20 + (dx * dx * 0.05)).round();
      _setPixel(pixels, x, cy, outline);
    }

    // Suit body — broad shoulders, tapered
    // Shoulders
    _fillRect(pixels, 10, 30, 44, 4, suit);
    // Torso
    for (int y = 34; y < 56; y++) {
      final taper = ((y - 34) * 0.15).round();
      _fillRect(pixels, 14 + taper, y, 36 - taper * 2, 1, suit);
    }
    // Lapels
    _fillRect(pixels, 28, 30, 2, 20, suitLight);
    _fillRect(pixels, 34, 30, 2, 20, suitLight);
    // Tie
    _fillRect(pixels, 31, 30, 2, 22, _rgba(180, 30, 30));

    // Neck
    _fillRect(pixels, 28, 26, 8, 5, skin);

    // Rising arrow — the STONKS indicator
    final arrowColor = frame == SpriteFrame.hurt
        ? _rgba(220, 180, 40) // Yellow-ish when hurt
        : arrowGreen;

    // Arrow shaft going up-right
    for (int i = 0; i < 20; i++) {
      final ax = 42 + i ~/ 2;
      final ay = 50 - i;
      _fillRect(pixels, ax, ay, 3, 2, arrowColor);
    }
    // Arrow head
    for (int i = 0; i < 6; i++) {
      _setPixel(pixels, 52 + i, 30 + i, arrowColor);
      _setPixel(pixels, 52 + i, 31 + i, arrowColor);
      _setPixel(pixels, 52 - i, 30 + i, arrowColor);
      _setPixel(pixels, 52 - i, 31 + i, arrowColor);
    }

    if (frame == SpriteFrame.hurt) {
      // Hurt tint — reddish overlay on skin/suit
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          final c = pixels[y * size + x];
          if (c == skin) {
            pixels[y * size + x] = _rgba(240, 170, 150);
          } else if (c == suit) {
            pixels[y * size + x] = _rgba(80, 50, 120);
          }
        }
      }
    }

    return pixels;
  }
}
