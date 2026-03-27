import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;


/// Procedurally generated wall textures stored as pixel buffers.
/// Each texture is generated at [_genSize] and upscaled 2x to [size].
class WallTextures {
  /// Output image size (128x128 for crisp rendering).
  static const int size = 128;

  /// Internal generation size.
  static const int _genSize = 64;

  /// Pre-built ui.Image textures ready for canvas rendering.
  late final ui.Image brickTexture;
  late final ui.Image stoneTexture;
  late final ui.Image mossTexture;
  late final ui.Image metalDoorTexture;
  late final ui.Image lockedDoorTexture;

  bool _ready = false;
  bool get isReady => _ready;

  /// Generate all textures. Call once at game start, await completion.
  Future<void> generate() async {
    brickTexture = await _buildImage(_upscale2x(_generateBrick()));
    stoneTexture = await _buildImage(_upscale2x(_generateStone()));
    mossTexture = await _buildImage(_upscale2x(_generateMoss()));
    metalDoorTexture = await _buildImage(_upscale2x(_generateMetalDoor()));
    lockedDoorTexture = await _buildImage(_upscale2x(_generateLockedDoor()));
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

  /// 2x nearest-neighbor upscale.
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

  /// Pack RGBA into a single uint32 (little-endian: ABGR).
  static int _rgba(int r, int g, int b, [int a = 255]) {
    return (a << 24) | (b << 16) | (g << 8) | r;
  }

  /// Brick wall — red/brown bricks with mortar lines.
  static Uint32List _generateBrick() {
    final pixels = Uint32List(_genSize * _genSize);
    final rng = Random(42);

    for (int i = 0; i < pixels.length; i++) {
      final noise = rng.nextInt(15);
      pixels[i] = _rgba(90 + noise, 85 + noise, 75 + noise);
    }

    const brickH = 8;
    const brickW = 16;
    const mortarW = 1;

    for (int row = 0; row < _genSize ~/ brickH; row++) {
      final offset = (row % 2 == 0) ? 0 : brickW ~/ 2;
      for (int col = -1; col < _genSize ~/ brickW + 1; col++) {
        final bx = col * brickW + offset;
        final by = row * brickH;

        final baseR = 130 + rng.nextInt(40);
        final baseG = 50 + rng.nextInt(25);
        final baseB = 30 + rng.nextInt(20);

        for (int py = by + mortarW; py < by + brickH && py < _genSize; py++) {
          for (int px = bx + mortarW; px < bx + brickW && px < _genSize; px++) {
            if (px < 0 || px >= _genSize || py < 0 || py >= _genSize) continue;

            final noise = rng.nextInt(12) - 6;
            final r = (baseR + noise).clamp(0, 255);
            final g = (baseG + noise ~/ 2).clamp(0, 255);
            final b = (baseB + noise ~/ 3).clamp(0, 255);

            pixels[py * _genSize + px] = _rgba(r, g, b);
          }
        }
      }
    }

    return pixels;
  }

  /// Stone wall — irregular grey blocks.
  static Uint32List _generateStone() {
    final pixels = Uint32List(_genSize * _genSize);
    final rng = Random(77);

    for (int y = 0; y < _genSize; y++) {
      for (int x = 0; x < _genSize; x++) {
        final coarse = ((sin(x * 0.3) + cos(y * 0.4)) * 20).round();
        final fine = rng.nextInt(16) - 8;
        final base = 100 + coarse + fine;

        final crack = ((x * 7 + y * 13) % 47 == 0) ? -30 : 0;
        final blockEdge = (x % 16 == 0 || y % 12 == 0) ? -25 : 0;

        final v = (base + crack + blockEdge).clamp(40, 180);
        pixels[y * _genSize + x] = _rgba(v, v - 5, v - 10);
      }
    }

    return pixels;
  }

  /// Mossy green stone.
  static Uint32List _generateMoss() {
    final pixels = Uint32List(_genSize * _genSize);
    final rng = Random(99);

    for (int y = 0; y < _genSize; y++) {
      for (int x = 0; x < _genSize; x++) {
        final noise = rng.nextInt(20) - 10;
        final coarse = ((sin(x * 0.2) + cos(y * 0.3)) * 15).round();

        var r = 60 + coarse + noise;
        var g = 80 + coarse + noise;
        var b = 55 + coarse + noise ~/ 2;

        final mossiness = (sin(x * 0.15 + 1) * cos(y * 0.2 + 2) * 40).round();
        if (mossiness > 10) {
          g += mossiness;
          r -= mossiness ~/ 2;
        }

        if (x % 16 < 1 || y % 16 < 1) {
          r -= 20;
          g -= 20;
          b -= 20;
        }

        pixels[y * _genSize + x] = _rgba(
          r.clamp(20, 200),
          g.clamp(30, 200),
          b.clamp(20, 160),
        );
      }
    }

    return pixels;
  }

  /// Metal door — blue-grey with rivets and a handle.
  static Uint32List _generateMetalDoor() {
    final pixels = Uint32List(_genSize * _genSize);
    final rng = Random(55);

    for (int y = 0; y < _genSize; y++) {
      for (int x = 0; x < _genSize; x++) {
        final noise = rng.nextInt(10) - 5;

        final streak = (sin(y * 1.5) * 8).round();
        var r = 70 + streak + noise;
        var g = 80 + streak + noise;
        var b = 110 + streak + noise;

        if (x < 3 || x >= _genSize - 3 || y < 3 || y >= _genSize - 3) {
          r = 40;
          g = 45;
          b = 60;
        }

        if (x == _genSize ~/ 2 || y == _genSize ~/ 3 || y == (_genSize * 2) ~/ 3) {
          r -= 20;
          g -= 20;
          b -= 20;
        }

        final isRivet = _isNearPoint(x, y, 8, 8, 2) ||
            _isNearPoint(x, y, _genSize - 8, 8, 2) ||
            _isNearPoint(x, y, 8, _genSize - 8, 2) ||
            _isNearPoint(x, y, _genSize - 8, _genSize - 8, 2) ||
            _isNearPoint(x, y, 8, _genSize ~/ 2, 2) ||
            _isNearPoint(x, y, _genSize - 8, _genSize ~/ 2, 2);

        if (isRivet) {
          r = 160;
          g = 170;
          b = 190;
        }

        if (_isNearPoint(x, y, _genSize - 14, _genSize ~/ 2, 3)) {
          r = 180;
          g = 170;
          b = 50;
        }

        pixels[y * _genSize + x] = _rgba(
          r.clamp(20, 255),
          g.clamp(20, 255),
          b.clamp(20, 255),
        );
      }
    }

    return pixels;
  }

  /// Locked door — red-tinted metal with a lock symbol and red indicator.
  static Uint32List _generateLockedDoor() {
    final pixels = Uint32List(_genSize * _genSize);
    final rng = Random(66);

    for (int y = 0; y < _genSize; y++) {
      for (int x = 0; x < _genSize; x++) {
        final noise = rng.nextInt(10) - 5;

        final streak = (sin(y * 1.5) * 6).round();
        var r = 90 + streak + noise;
        var g = 55 + streak + noise;
        var b = 55 + streak + noise;

        // Dark frame
        if (x < 3 || x >= _genSize - 3 || y < 3 || y >= _genSize - 3) {
          r = 50;
          g = 25;
          b = 25;
        }

        // Panel lines
        if (x == _genSize ~/ 2 || y == _genSize ~/ 3 || y == (_genSize * 2) ~/ 3) {
          r -= 15;
          g -= 15;
          b -= 15;
        }

        // Rivets
        final isRivet = _isNearPoint(x, y, 8, 8, 2) ||
            _isNearPoint(x, y, _genSize - 8, 8, 2) ||
            _isNearPoint(x, y, 8, _genSize - 8, 2) ||
            _isNearPoint(x, y, _genSize - 8, _genSize - 8, 2);
        if (isRivet) {
          r = 140;
          g = 100;
          b = 100;
        }

        // Lock icon — padlock shape in center
        final cx = _genSize ~/ 2;
        final cy = _genSize ~/ 2;
        // Lock body (rectangle)
        if (x >= cx - 6 && x <= cx + 6 && y >= cy && y <= cy + 10) {
          r = 60;
          g = 60;
          b = 70;
        }
        // Lock shackle (arch above body)
        if (_isNearPoint(x, y, cx, cy - 2, 6) &&
            !_isNearPoint(x, y, cx, cy - 2, 3) &&
            y < cy) {
          r = 80;
          g = 80;
          b = 90;
        }
        // Keyhole
        if (_isNearPoint(x, y, cx, cy + 4, 2)) {
          r = 30;
          g = 30;
          b = 35;
        }

        // Red warning indicator light (top-right)
        if (_isNearPoint(x, y, _genSize - 10, 10, 3)) {
          r = 220;
          g = 40;
          b = 40;
        }

        pixels[y * _genSize + x] = _rgba(
          r.clamp(20, 255),
          g.clamp(20, 255),
          b.clamp(20, 255),
        );
      }
    }

    return pixels;
  }

  static bool _isNearPoint(int x, int y, int px, int py, int radius) {
    return (x - px) * (x - px) + (y - py) * (y - py) <= radius * radius;
  }
}
