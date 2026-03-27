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
  /// Output image size (128x128 for crisp rendering).
  static const int size = 128;

  /// Internal generation size — art is drawn at 64x64 then upscaled 2x.
  static const int _genSize = 64;

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

  /// Generate sprite at 64x64 then upscale to 128x128 with nearest-neighbor.
  static Uint32List _generateSprite(EnemyType type, SpriteFrame frame) {
    final small = switch (type) {
      EnemyType.grunt => _generateTrollface(frame),
      EnemyType.imp => _generateDoge(frame),
      EnemyType.brute => _generateGrumpyCat(frame),
      EnemyType.sentinel => _generateStonksMan(frame),
      EnemyType.zoomer => _generateDistractedBF(frame),
      EnemyType.swarm => _generateThisIsFine(frame),
      EnemyType.healer => _generateHarold(frame),
      EnemyType.boss => _generateGigaChad(frame),
      EnemyType.trickster => _generateRickAstley(frame),
      EnemyType.sage => _generateRarePepe(frame),
    };
    return _upscale2x(small);
  }

  /// 2x nearest-neighbor upscale from _genSize to size.
  static Uint32List _upscale2x(Uint32List src) {
    final dst = Uint32List(size * size);
    for (int y = 0; y < _genSize; y++) {
      for (int x = 0; x < _genSize; x++) {
        final color = src[y * _genSize + x];
        final dx = x * 2;
        final dy = y * 2;
        dst[dy * size + dx] = color;
        dst[dy * size + dx + 1] = color;
        dst[(dy + 1) * size + dx] = color;
        dst[(dy + 1) * size + dx + 1] = color;
      }
    }
    return dst;
  }

  /// Pack RGBA into uint32 (little-endian: ABGR).
  static int _rgba(int r, int g, int b, [int a = 255]) {
    return (a << 24) | (b << 16) | (g << 8) | r;
  }

  static const int _transparent = 0x00000000;

  static void _setPixel(Uint32List pixels, int x, int y, int color) {
    if (x >= 0 && x < _genSize && y >= 0 && y < _genSize) {
      pixels[y * _genSize + x] = color;
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
    final pixels = Uint32List(_genSize * _genSize);
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
      for (int y = 0; y < _genSize; y++) {
        for (int x = 0; x < _genSize; x++) {
          final c = pixels[y * _genSize + x];
          if (c != _transparent && c != outline && c != eye) {
            pixels[y * _genSize + x] = _rgba(255, 180, 180);
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
      for (int y = 0; y < _genSize; y++) {
        for (int x = 0; x < _genSize; x++) {
          final c = pixels[y * _genSize + x];
          if (c == white) {
            pixels[y * _genSize + x] = _rgba(255, 200, 200);
          }
        }
      }
    }

    return pixels;
  }

  // ── Doge (imp) ─────────────────────────────────────────────────

  static Uint32List _generateDoge(SpriteFrame frame) {
    final pixels = Uint32List(_genSize * _genSize);
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
      for (int y = 0; y < _genSize; y++) {
        for (int x = 0; x < _genSize; x++) {
          final c = pixels[y * _genSize + x];
          if (c == fur || c == lightFur) {
            pixels[y * _genSize + x] = _rgba(240, 160, 100);
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
    final pixels = Uint32List(_genSize * _genSize);
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
      for (int y = 0; y < _genSize; y++) {
        for (int x = 0; x < _genSize; x++) {
          final c = pixels[y * _genSize + x];
          if (c == grey || c == lightGrey) {
            pixels[y * _genSize + x] = _rgba(220, 170, 170);
          }
        }
      }
    }

    return pixels;
  }

  // ── Stonks Man (sentinel) ──────────────────────────────────────

  static Uint32List _generateStonksMan(SpriteFrame frame) {
    final pixels = Uint32List(_genSize * _genSize);
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
      for (int y = 0; y < _genSize; y++) {
        for (int x = 0; x < _genSize; x++) {
          final c = pixels[y * _genSize + x];
          if (c == skin) {
            pixels[y * _genSize + x] = _rgba(240, 170, 150);
          } else if (c == suit) {
            pixels[y * _genSize + x] = _rgba(80, 50, 120);
          }
        }
      }
    }

    return pixels;
  }

  // ── Distracted Boyfriend (zoomer) ──────────────────────────────

  static Uint32List _generateDistractedBF(SpriteFrame frame) {
    final pixels = Uint32List(_genSize * _genSize);
    pixels.fillRange(0, pixels.length, _transparent);

    final skin = _rgba(220, 185, 150);
    final shirt = _rgba(200, 60, 60); // Red shirt
    final hair = _rgba(60, 40, 20);
    final outline = _rgba(30, 25, 20);
    final eye = _rgba(30, 30, 30);

    if (frame == SpriteFrame.dead) {
      _fillOval(pixels, 32, 36, 18, 14, skin);
      _applyXEyes(pixels, eye);
      return pixels;
    }

    // Head — looking sideways (the distracted turn)
    _fillOval(pixels, 34, 22, 14, 14, outline);
    _fillOval(pixels, 34, 22, 12, 12, skin);

    // Hair — swept to one side
    _fillOval(pixels, 30, 14, 14, 6, hair);

    // Eyes — one wide, one squinting (the double-take)
    _fillCircle(pixels, 28, 20, 3, _rgba(255, 255, 255));
    _fillCircle(pixels, 28, 20, 1, eye);
    _fillRect(pixels, 36, 19, 6, 2, eye); // Squinting eye

    // Surprised open mouth
    _fillOval(pixels, 32, 30, 4, 3, _rgba(40, 20, 20));

    // Red shirt body
    _fillRect(pixels, 18, 36, 28, 20, shirt);
    // Neck
    _fillRect(pixels, 28, 32, 8, 5, skin);

    _applyHurtTint(pixels, frame, skin, _rgba(240, 170, 150));
    return pixels;
  }

  // ── This Is Fine Dog (swarm) ───────────────────────────────────

  static Uint32List _generateThisIsFine(SpriteFrame frame) {
    final pixels = Uint32List(_genSize * _genSize);
    pixels.fillRange(0, pixels.length, _transparent);

    final fur = _rgba(220, 190, 100);
    final outline = _rgba(50, 40, 20);
    final eye = _rgba(20, 20, 20);
    final fire = _rgba(255, 120, 20);
    final fireGlow = _rgba(255, 200, 40);

    if (frame == SpriteFrame.dead) {
      // Explosion!
      _fillCircle(pixels, 32, 32, 20, fire);
      _fillCircle(pixels, 32, 32, 14, fireGlow);
      _fillCircle(pixels, 32, 32, 6, _rgba(255, 255, 200));
      return pixels;
    }

    // Flames around the dog
    for (int i = 0; i < 8; i++) {
      final fx = 10 + (i * 7);
      final fy = 10 + (i % 3) * 5;
      _fillOval(pixels, fx, fy, 4, 8, fire);
      _fillOval(pixels, fx, fy + 2, 2, 4, fireGlow);
    }

    // Dog face — simple round
    _fillCircle(pixels, 32, 34, 16, outline);
    _fillCircle(pixels, 32, 34, 14, fur);

    // Floppy ears
    _fillOval(pixels, 14, 30, 6, 10, fur);
    _fillOval(pixels, 50, 30, 6, 10, fur);

    // Calm eyes (this is fine...)
    _fillCircle(pixels, 26, 30, 3, _rgba(255, 255, 255));
    _fillCircle(pixels, 38, 30, 3, _rgba(255, 255, 255));
    _fillCircle(pixels, 26, 30, 1, eye);
    _fillCircle(pixels, 38, 30, 1, eye);

    // Content smile
    for (int x = 26; x < 38; x++) {
      final dx = (x - 32).toDouble();
      final cy = (40 + (dx * dx * 0.03)).round();
      _setPixel(pixels, x, cy, outline);
    }

    // Nose
    _fillOval(pixels, 32, 37, 2, 2, _rgba(40, 30, 25));

    _applyHurtTint(pixels, frame, fur, _rgba(240, 170, 100));
    return pixels;
  }

  // ── Hide the Pain Harold (healer) ──────────────────────────────

  static Uint32List _generateHarold(SpriteFrame frame) {
    final pixels = Uint32List(_genSize * _genSize);
    pixels.fillRange(0, pixels.length, _transparent);

    final skin = _rgba(220, 190, 160);
    final hair = _rgba(180, 180, 180); // Grey hair
    final outline = _rgba(40, 35, 30);
    final eye = _rgba(40, 60, 100); // Blue eyes
    final teeth = _rgba(240, 240, 235);

    if (frame == SpriteFrame.dead) {
      _fillOval(pixels, 32, 36, 18, 14, skin);
      _applyXEyes(pixels, outline);
      // Finally at peace — closed smile
      for (int x = 24; x < 40; x++) {
        _setPixel(pixels, x, 44, outline);
      }
      return pixels;
    }

    // Head
    _fillOval(pixels, 32, 28, 18, 18, outline);
    _fillOval(pixels, 32, 28, 16, 16, skin);

    // Grey hair — receding
    _fillOval(pixels, 32, 16, 16, 8, hair);
    // Forehead wrinkles
    for (int i = 0; i < 3; i++) {
      _fillRect(pixels, 20, 18 + i * 3, 24, 1, _rgba(190, 160, 130));
    }

    // Eyes — the pain behind the smile
    _fillCircle(pixels, 24, 26, 3, _rgba(255, 255, 255));
    _fillCircle(pixels, 40, 26, 3, _rgba(255, 255, 255));
    _fillCircle(pixels, 24, 26, 2, eye);
    _fillCircle(pixels, 40, 26, 2, eye);
    // Slight eyebrow raise (trying to look happy)
    _fillRect(pixels, 19, 21, 12, 2, _rgba(140, 120, 100));
    _fillRect(pixels, 33, 21, 12, 2, _rgba(140, 120, 100));

    // THE SMILE — forced, wide, showing teeth
    _fillRect(pixels, 20, 36, 24, 6, teeth);
    // Lip outline
    for (int x = 20; x < 44; x++) {
      _setPixel(pixels, x, 35, outline);
      _setPixel(pixels, x, 42, outline);
    }
    _setPixel(pixels, 19, 36, outline);
    _setPixel(pixels, 44, 36, outline);

    // Healing cross (green) on chest
    final healGreen = _rgba(60, 200, 100);
    _fillRect(pixels, 28, 48, 8, 3, healGreen);
    _fillRect(pixels, 30, 46, 4, 7, healGreen);

    _applyHurtTint(pixels, frame, skin, _rgba(240, 170, 155));
    return pixels;
  }

  // ── GigaChad (boss) ────────────────────────────────────────────

  static Uint32List _generateGigaChad(SpriteFrame frame) {
    final pixels = Uint32List(_genSize * _genSize);
    pixels.fillRange(0, pixels.length, _transparent);

    final skin = _rgba(180, 150, 120);
    final hair = _rgba(20, 15, 10);
    final outline = _rgba(15, 10, 5);
    final eye = _rgba(30, 30, 30);

    if (frame == SpriteFrame.dead) {
      _fillOval(pixels, 32, 36, 20, 16, skin);
      _applyXEyes(pixels, eye);
      return pixels;
    }

    // Massive square jaw
    _fillRect(pixels, 10, 12, 44, 44, outline);
    _fillRect(pixels, 12, 14, 40, 40, skin);

    // Strong jawline — darker at edges
    _fillRect(pixels, 10, 44, 44, 8, _rgba(140, 110, 80));
    _fillRect(pixels, 12, 44, 40, 6, skin);

    // Hair — short, dark
    _fillRect(pixels, 10, 8, 44, 10, hair);

    // Intense eyes — deep set
    _fillRect(pixels, 18, 24, 10, 5, _rgba(255, 255, 255));
    _fillRect(pixels, 36, 24, 10, 5, _rgba(255, 255, 255));
    _fillCircle(pixels, 23, 26, 2, eye);
    _fillCircle(pixels, 41, 26, 2, eye);

    // Strong brow ridge
    _fillRect(pixels, 16, 20, 14, 3, _rgba(140, 110, 80));
    _fillRect(pixels, 34, 20, 14, 3, _rgba(140, 110, 80));

    // Confident smirk
    for (int x = 22; x < 42; x++) {
      final dx = (x - 32).toDouble();
      final cy = (40 + (dx * dx * 0.01)).round();
      _setPixel(pixels, x, cy, outline);
      _setPixel(pixels, x, cy + 1, outline);
    }

    // Thick neck
    _fillRect(pixels, 20, 52, 24, 10, skin);
    // Shirt collar
    _fillRect(pixels, 14, 56, 36, 8, _rgba(30, 30, 30));

    _applyHurtTint(pixels, frame, skin, _rgba(220, 140, 120));
    return pixels;
  }

  // ── Rick Astley (trickster) ────────────────────────────────────

  static Uint32List _generateRickAstley(SpriteFrame frame) {
    final pixels = Uint32List(_genSize * _genSize);
    pixels.fillRange(0, pixels.length, _transparent);

    final skin = _rgba(230, 195, 165);
    final hair = _rgba(160, 80, 30); // Auburn
    final outline = _rgba(40, 30, 20);
    final eye = _rgba(40, 50, 70);
    final jacket = _rgba(50, 50, 50); // Dark jacket

    if (frame == SpriteFrame.dead) {
      _fillOval(pixels, 32, 36, 18, 14, skin);
      _applyXEyes(pixels, outline);
      // Musical notes fading
      _setPixel(pixels, 14, 20, outline);
      _setPixel(pixels, 16, 18, outline);
      _setPixel(pixels, 50, 22, outline);
      _setPixel(pixels, 48, 20, outline);
      return pixels;
    }

    // Head
    _fillOval(pixels, 32, 24, 14, 16, outline);
    _fillOval(pixels, 32, 24, 12, 14, skin);

    // Signature fluffy hair
    _fillOval(pixels, 32, 12, 14, 8, hair);
    _fillOval(pixels, 22, 16, 6, 6, hair);
    _fillOval(pixels, 42, 16, 6, 6, hair);

    // Eyes
    _fillCircle(pixels, 26, 22, 3, _rgba(255, 255, 255));
    _fillCircle(pixels, 38, 22, 3, _rgba(255, 255, 255));
    _fillCircle(pixels, 26, 22, 1, eye);
    _fillCircle(pixels, 38, 22, 1, eye);

    // Friendly smile
    for (int x = 26; x < 38; x++) {
      final dx = (x - 32).toDouble();
      final cy = (30 + (dx * dx * 0.04)).round();
      _setPixel(pixels, x, cy, outline);
    }

    // Dark jacket body
    _fillRect(pixels, 16, 38, 32, 20, jacket);
    // Neck
    _fillRect(pixels, 26, 34, 12, 5, skin);
    // White shirt collar
    _fillRect(pixels, 24, 38, 16, 3, _rgba(230, 230, 230));

    // Musical notes floating around (the rickroll hint)
    final noteColor = _rgba(255, 200, 50);
    _fillRect(pixels, 8, 16, 2, 6, noteColor);
    _fillCircle(pixels, 8, 22, 2, noteColor);
    _fillRect(pixels, 54, 20, 2, 6, noteColor);
    _fillCircle(pixels, 54, 26, 2, noteColor);

    _applyHurtTint(pixels, frame, skin, _rgba(240, 175, 155));
    return pixels;
  }

  // ── Rare Pepe (sage) ───────────────────────────────────────────

  static Uint32List _generateRarePepe(SpriteFrame frame) {
    final pixels = Uint32List(_genSize * _genSize);
    pixels.fillRange(0, pixels.length, _transparent);

    final green = _rgba(100, 180, 80);
    final darkGreen = _rgba(60, 130, 50);
    final lightGreen = _rgba(140, 210, 120);
    final outline = _rgba(30, 60, 20);
    final eye = _rgba(20, 20, 20);
    final lip = _rgba(180, 50, 50);

    if (frame == SpriteFrame.dead) {
      _fillOval(pixels, 32, 36, 20, 16, green);
      _applyXEyes(pixels, eye);
      // Single tear
      _fillRect(pixels, 24, 38, 2, 6, _rgba(100, 150, 255));
      return pixels;
    }

    // Frog face — wide and round
    _fillOval(pixels, 32, 32, 26, 22, outline);
    _fillOval(pixels, 32, 32, 24, 20, green);

    // Lighter chin/belly
    _fillOval(pixels, 32, 40, 16, 10, lightGreen);

    // Big bulging eyes
    _fillCircle(pixels, 20, 22, 8, _rgba(255, 255, 255));
    _fillCircle(pixels, 44, 22, 8, _rgba(255, 255, 255));
    _fillCircle(pixels, 20, 22, 7, lightGreen);
    _fillCircle(pixels, 44, 22, 7, lightGreen);
    // Eyelids (smugness)
    _fillRect(pixels, 12, 16, 18, 6, darkGreen);
    _fillRect(pixels, 36, 16, 18, 6, darkGreen);
    // Pupils
    _fillCircle(pixels, 22, 24, 2, eye);
    _fillCircle(pixels, 42, 24, 2, eye);

    // Smug smile
    _fillRect(pixels, 18, 40, 28, 3, lip);
    for (int x = 18; x < 46; x++) {
      _setPixel(pixels, x, 39, outline);
      _setPixel(pixels, x, 43, outline);
    }

    // Crown (rare!)
    final gold = _rgba(255, 215, 0);
    _fillRect(pixels, 18, 6, 28, 4, gold);
    for (int i = 0; i < 5; i++) {
      _fillRect(pixels, 20 + i * 6, 2, 3, 4, gold);
    }

    if (frame == SpriteFrame.hurt) {
      // Sad Pepe — add tears
      _fillRect(pixels, 18, 28, 2, 8, _rgba(100, 150, 255));
      _fillRect(pixels, 44, 28, 2, 8, _rgba(100, 150, 255));
      _applyHurtTint(pixels, frame, green, _rgba(160, 200, 140));
    }

    return pixels;
  }

  // ── Shared helpers ─────────────────────────────────────────────

  static void _applyXEyes(Uint32List pixels, int color) {
    for (int i = -3; i <= 3; i++) {
      _setPixel(pixels, 22 + i, 32 + i, color);
      _setPixel(pixels, 22 + i, 38 - i, color);
      _setPixel(pixels, 42 + i, 32 + i, color);
      _setPixel(pixels, 42 + i, 38 - i, color);
    }
  }

  static void _applyHurtTint(
      Uint32List pixels, SpriteFrame frame, int fromColor, int toColor) {
    if (frame != SpriteFrame.hurt) return;
    for (int i = 0; i < pixels.length; i++) {
      if (pixels[i] == fromColor) {
        pixels[i] = toColor;
      }
    }
  }
}
