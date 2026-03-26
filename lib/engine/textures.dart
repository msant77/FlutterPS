import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;


/// Procedurally generated wall textures stored as pixel buffers.
/// Each texture is [size] x [size] pixels in RGBA format.
class WallTextures {
  static const int size = 64;

  /// Pre-built ui.Image textures ready for canvas rendering.
  late final ui.Image brickTexture;
  late final ui.Image stoneTexture;
  late final ui.Image mossTexture;
  late final ui.Image metalDoorTexture;

  bool _ready = false;
  bool get isReady => _ready;

  /// Generate all textures. Call once at game start, await completion.
  Future<void> generate() async {
    brickTexture = await _buildImage(_generateBrick());
    stoneTexture = await _buildImage(_generateStone());
    mossTexture = await _buildImage(_generateMoss());
    metalDoorTexture = await _buildImage(_generateMetalDoor());
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

  /// Pack RGBA into a single uint32 (little-endian: ABGR).
  static int _rgba(int r, int g, int b, [int a = 255]) {
    return (a << 24) | (b << 16) | (g << 8) | r;
  }

  /// Brick wall — red/brown bricks with mortar lines.
  static Uint32List _generateBrick() {
    final pixels = Uint32List(size * size);
    final rng = Random(42);

    // Fill with mortar color
    for (int i = 0; i < pixels.length; i++) {
      final noise = rng.nextInt(15);
      pixels[i] = _rgba(90 + noise, 85 + noise, 75 + noise);
    }

    // Draw bricks
    const brickH = 8;
    const brickW = 16;
    const mortarW = 1;

    for (int row = 0; row < size ~/ brickH; row++) {
      final offset = (row % 2 == 0) ? 0 : brickW ~/ 2;
      for (int col = -1; col < size ~/ brickW + 1; col++) {
        final bx = col * brickW + offset;
        final by = row * brickH;

        // Random brick color variation
        final baseR = 130 + rng.nextInt(40);
        final baseG = 50 + rng.nextInt(25);
        final baseB = 30 + rng.nextInt(20);

        for (int py = by + mortarW; py < by + brickH && py < size; py++) {
          for (int px = bx + mortarW; px < bx + brickW && px < size; px++) {
            if (px < 0 || px >= size || py < 0 || py >= size) continue;

            // Per-pixel noise for texture
            final noise = rng.nextInt(12) - 6;
            final r = (baseR + noise).clamp(0, 255);
            final g = (baseG + noise ~/ 2).clamp(0, 255);
            final b = (baseB + noise ~/ 3).clamp(0, 255);

            pixels[py * size + px] = _rgba(r, g, b);
          }
        }
      }
    }

    return pixels;
  }

  /// Stone wall — irregular grey blocks.
  static Uint32List _generateStone() {
    final pixels = Uint32List(size * size);
    final rng = Random(77);

    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        // Create stone-like pattern using multiple noise layers
        final coarse = ((sin(x * 0.3) + cos(y * 0.4)) * 20).round();
        final fine = rng.nextInt(16) - 8;
        final base = 100 + coarse + fine;

        // Add cracks (dark lines at certain positions)
        final crack = ((x * 7 + y * 13) % 47 == 0) ? -30 : 0;

        // Block edges
        final blockEdge =
            (x % 16 == 0 || y % 12 == 0) ? -25 : 0;

        final v = (base + crack + blockEdge).clamp(40, 180);
        pixels[y * size + x] = _rgba(v, v - 5, v - 10);
      }
    }

    return pixels;
  }

  /// Mossy green stone.
  static Uint32List _generateMoss() {
    final pixels = Uint32List(size * size);
    final rng = Random(99);

    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final noise = rng.nextInt(20) - 10;
        final coarse = ((sin(x * 0.2) + cos(y * 0.3)) * 15).round();

        // Base grey stone
        var r = 60 + coarse + noise;
        var g = 80 + coarse + noise;
        var b = 55 + coarse + noise ~/ 2;

        // Moss patches (more green in certain areas)
        final mossiness = (sin(x * 0.15 + 1) * cos(y * 0.2 + 2) * 40).round();
        if (mossiness > 10) {
          g += mossiness;
          r -= mossiness ~/ 2;
        }

        // Block edges
        if (x % 16 < 1 || y % 16 < 1) {
          r -= 20;
          g -= 20;
          b -= 20;
        }

        pixels[y * size + x] = _rgba(
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
    final pixels = Uint32List(size * size);
    final rng = Random(55);

    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final noise = rng.nextInt(10) - 5;

        // Brushed metal: horizontal streaks
        final streak = (sin(y * 1.5) * 8).round();
        var r = 70 + streak + noise;
        var g = 80 + streak + noise;
        var b = 110 + streak + noise;

        // Door frame (darker edges)
        if (x < 3 || x >= size - 3 || y < 3 || y >= size - 3) {
          r = 40;
          g = 45;
          b = 60;
        }

        // Center panel lines
        if (x == size ~/ 2 || y == size ~/ 3 || y == (size * 2) ~/ 3) {
          r -= 20;
          g -= 20;
          b -= 20;
        }

        // Rivets (small bright dots at corners of panels)
        final isRivet = _isNearPoint(x, y, 8, 8, 2) ||
            _isNearPoint(x, y, size - 8, 8, 2) ||
            _isNearPoint(x, y, 8, size - 8, 2) ||
            _isNearPoint(x, y, size - 8, size - 8, 2) ||
            _isNearPoint(x, y, 8, size ~/ 2, 2) ||
            _isNearPoint(x, y, size - 8, size ~/ 2, 2);

        if (isRivet) {
          r = 160;
          g = 170;
          b = 190;
        }

        // Door handle
        if (_isNearPoint(x, y, size - 14, size ~/ 2, 3)) {
          r = 180;
          g = 170;
          b = 50;
        }

        pixels[y * size + x] = _rgba(
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
