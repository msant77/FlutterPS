import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../entities/enemy.dart';

/// Procedurally generated retro sound effects.
/// All sounds are synthesized as WAV byte data and played via audioplayers.
class GameAudio {
  static const int _sampleRate = 22050;

  // Dedicated players for concurrent sounds
  final AudioPlayer _shootPlayer = AudioPlayer();
  final AudioPlayer _pickupPlayer = AudioPlayer();
  final AudioPlayer _enemyPlayer = AudioPlayer();
  final AudioPlayer _uiPlayer = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();
  final AudioPlayer _footstepPlayer = AudioPlayer();

  // Pre-generated sound data
  late final Uint8List _shootSound;
  late final Uint8List _healthPickupSound;
  late final Uint8List _ammoPickupSound;
  late final Uint8List _hurtSound;
  late final Uint8List _deathSound;
  late final Uint8List _winSound;
  late final Uint8List _footstepSound;
  late final Uint8List _enemyDeathSound;
  late final Uint8List _enemyHurtSound;
  late final Uint8List _friendlyDeathSound;

  bool _ready = false;
  bool get isReady => _ready;

  double _footstepCooldown = 0;
  static const double _footstepInterval = 0.35;

  /// Generate all sounds. Call once at startup.
  Future<void> generate() async {
    _shootSound = _makeWav(_synthShoot());
    _healthPickupSound = _makeWav(_synthPickup(high: true));
    _ammoPickupSound = _makeWav(_synthPickup(high: false));
    _hurtSound = _makeWav(_synthHurt());
    _deathSound = _makeWav(_synthDeath());
    _winSound = _makeWav(_synthWin());
    _footstepSound = _makeWav(_synthFootstep());
    _enemyDeathSound = _makeWav(_synthEnemyDeath());
    _enemyHurtSound = _makeWav(_synthEnemyHurt());
    _friendlyDeathSound = _makeWav(_synthFriendlyDeath());

    // Set volumes
    await _shootPlayer.setVolume(0.4);
    await _pickupPlayer.setVolume(0.5);
    await _enemyPlayer.setVolume(0.3);
    await _uiPlayer.setVolume(0.6);
    await _footstepPlayer.setVolume(0.15);

    _ready = true;
  }

  void dispose() {
    _shootPlayer.dispose();
    _pickupPlayer.dispose();
    _enemyPlayer.dispose();
    _uiPlayer.dispose();
    _ambientPlayer.dispose();
    _footstepPlayer.dispose();
  }

  // ── Public API ──────────────────────────────────────────────────

  void playShoot() {
    if (!_ready) return;
    _play(_shootPlayer, _shootSound);
  }

  void playHealthPickup() {
    if (!_ready) return;
    _play(_pickupPlayer, _healthPickupSound);
  }

  void playAmmoPickup() {
    if (!_ready) return;
    _play(_pickupPlayer, _ammoPickupSound);
  }

  void playHurt() {
    if (!_ready) return;
    _play(_uiPlayer, _hurtSound);
  }

  void playDeath() {
    if (!_ready) return;
    _play(_uiPlayer, _deathSound);
  }

  void playWin() {
    if (!_ready) return;
    _play(_uiPlayer, _winSound);
  }

  void playEnemyHurt(EnemyType type) {
    if (!_ready) return;
    _play(_enemyPlayer, _enemyHurtSound);
  }

  void playEnemyDeath(EnemyType type, EnemyAlignment alignment) {
    if (!_ready) return;
    if (alignment == EnemyAlignment.friendly) {
      _play(_enemyPlayer, _friendlyDeathSound);
    } else {
      _play(_enemyPlayer, _enemyDeathSound);
    }
  }

  /// Call each frame with dt and whether the player is moving.
  void updateFootsteps(double dt, bool isMoving) {
    if (!_ready) return;
    if (_footstepCooldown > 0) _footstepCooldown -= dt;
    if (isMoving && _footstepCooldown <= 0) {
      _play(_footstepPlayer, _footstepSound);
      _footstepCooldown = _footstepInterval;
    }
  }

  // ── Playback helper ─────────────────────────────────────────────

  void _play(AudioPlayer player, Uint8List wavData) {
    player.play(BytesSource(wavData));
  }

  // ── WAV file builder ────────────────────────────────────────────

  /// Wrap raw PCM samples (mono, 16-bit, _sampleRate) in a WAV container.
  static Uint8List _makeWav(Float64List samples) {
    final numSamples = samples.length;
    final dataSize = numSamples * 2; // 16-bit = 2 bytes per sample
    final fileSize = 44 + dataSize;
    final buffer = ByteData(fileSize);

    // RIFF header
    buffer.setUint8(0, 0x52); // R
    buffer.setUint8(1, 0x49); // I
    buffer.setUint8(2, 0x46); // F
    buffer.setUint8(3, 0x46); // F
    buffer.setUint32(4, fileSize - 8, Endian.little);
    buffer.setUint8(8, 0x57); // W
    buffer.setUint8(9, 0x41); // A
    buffer.setUint8(10, 0x56); // V
    buffer.setUint8(11, 0x45); // E

    // fmt chunk
    buffer.setUint8(12, 0x66); // f
    buffer.setUint8(13, 0x6D); // m
    buffer.setUint8(14, 0x74); // t
    buffer.setUint8(15, 0x20); // (space)
    buffer.setUint32(16, 16, Endian.little); // chunk size
    buffer.setUint16(20, 1, Endian.little); // PCM
    buffer.setUint16(22, 1, Endian.little); // mono
    buffer.setUint32(24, _sampleRate, Endian.little);
    buffer.setUint32(28, _sampleRate * 2, Endian.little); // byte rate
    buffer.setUint16(32, 2, Endian.little); // block align
    buffer.setUint16(34, 16, Endian.little); // bits per sample

    // data chunk
    buffer.setUint8(36, 0x64); // d
    buffer.setUint8(37, 0x61); // a
    buffer.setUint8(38, 0x74); // t
    buffer.setUint8(39, 0x61); // a
    buffer.setUint32(40, dataSize, Endian.little);

    // PCM data
    for (int i = 0; i < numSamples; i++) {
      final sample = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      buffer.setInt16(44 + i * 2, sample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  // ── Sound synthesis ─────────────────────────────────────────────

  /// Gunshot: short white noise burst with pitch drop.
  static Float64List _synthShoot() {
    final rng = Random(42);
    final len = (_sampleRate * 0.12).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / 0.12).clamp(0.0, 1.0);
      // Noise + low tone
      final noise = (rng.nextDouble() * 2 - 1) * env * env;
      final tone = sin(2 * pi * (80 - t * 400) * t) * env;
      samples[i] = (noise * 0.6 + tone * 0.4) * 0.8;
    }
    return samples;
  }

  /// Pickup: ascending arpeggio.
  static Float64List _synthPickup({required bool high}) {
    final baseFreq = high ? 520.0 : 330.0;
    final len = (_sampleRate * 0.2).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / 0.2).clamp(0.0, 1.0);
      // Quick ascending notes
      final noteIdx = (t * 15).floor();
      final freq = baseFreq * pow(2, noteIdx / 12.0);
      samples[i] = sin(2 * pi * freq * t) * env * env * 0.5;
    }
    return samples;
  }

  /// Player hurt: distorted low buzz.
  static Float64List _synthHurt() {
    final len = (_sampleRate * 0.25).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / 0.25).clamp(0.0, 1.0);
      final wave = sin(2 * pi * 120 * t) + sin(2 * pi * 180 * t) * 0.5;
      // Distortion via clipping
      samples[i] = (wave * env * 0.8).clamp(-0.6, 0.6);
    }
    return samples;
  }

  /// Player death: descending tone with rumble.
  static Float64List _synthDeath() {
    final rng = Random(77);
    final len = (_sampleRate * 0.8).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / 0.8).clamp(0.0, 1.0);
      final freq = 300 - t * 300;
      final tone = sin(2 * pi * freq * t) * env;
      final rumble = (rng.nextDouble() * 2 - 1) * env * 0.3;
      samples[i] = (tone * 0.6 + rumble) * 0.7;
    }
    return samples;
  }

  /// Win jingle: major arpeggio.
  static Float64List _synthWin() {
    final len = (_sampleRate * 0.6).round();
    final samples = Float64List(len);
    // C-E-G-C major arpeggio
    final notes = [261.6, 329.6, 392.0, 523.3];
    final noteLen = len ~/ notes.length;
    for (int n = 0; n < notes.length; n++) {
      for (int i = 0; i < noteLen && n * noteLen + i < len; i++) {
        final t = i / _sampleRate;
        final env = (1.0 - t / (noteLen / _sampleRate)) * 0.8;
        final idx = n * noteLen + i;
        samples[idx] = sin(2 * pi * notes[n] * t) * env * 0.5;
      }
    }
    return samples;
  }

  /// Footstep: very short low thud.
  static Float64List _synthFootstep() {
    final rng = Random(33);
    final len = (_sampleRate * 0.06).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / 0.06).clamp(0.0, 1.0);
      final thud = sin(2 * pi * 60 * t) * env * env;
      final click = (rng.nextDouble() * 2 - 1) * env * env * env;
      samples[i] = (thud * 0.7 + click * 0.3) * 0.4;
    }
    return samples;
  }

  /// Enemy hurt: short high yelp.
  static Float64List _synthEnemyHurt() {
    final len = (_sampleRate * 0.1).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / 0.1).clamp(0.0, 1.0);
      samples[i] = sin(2 * pi * (600 + t * 200) * t) * env * 0.5;
    }
    return samples;
  }

  /// Enemy death: descending squeal.
  static Float64List _synthEnemyDeath() {
    final len = (_sampleRate * 0.3).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / 0.3).clamp(0.0, 1.0);
      final freq = 800 - t * 600;
      samples[i] = sin(2 * pi * freq * t) * env * env * 0.5;
    }
    return samples;
  }

  /// Friendly death: sad descending tone (makes you feel bad).
  static Float64List _synthFriendlyDeath() {
    final len = (_sampleRate * 0.5).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / 0.5).clamp(0.0, 1.0);
      // Minor third descent — sad interval
      final freq1 = 440 - t * 200;
      final freq2 = 528 - t * 250;
      samples[i] =
          (sin(2 * pi * freq1 * t) * 0.5 + sin(2 * pi * freq2 * t) * 0.3) *
              env *
              0.5;
    }
    return samples;
  }
}
