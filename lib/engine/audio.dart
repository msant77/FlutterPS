import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';

import '../entities/enemy.dart';

/// Procedurally generated retro sound effects with 3D spatial audio.
/// All sounds are synthesized as WAV byte data and played via audioplayers.
/// Spatial sounds use stereo panning (setBalance) and distance attenuation.
class GameAudio {
  static const int _sampleRate = 22050;

  /// Maximum distance at which sounds can be heard.
  static const double maxAudioDistance = 15.0;

  // Dedicated players for non-spatial sounds
  final AudioPlayer _shootPlayer = AudioPlayer();
  final AudioPlayer _pickupPlayer = AudioPlayer();
  final AudioPlayer _uiPlayer = AudioPlayer();
  final AudioPlayer _footstepPlayer = AudioPlayer();

  // Spatial audio player pool for concurrent 3D-positioned sounds
  static const int _poolSize = 8;
  final List<AudioPlayer> _spatialPool = [];
  int _nextPoolIndex = 0;

  // Pre-generated sound data (mono)
  late final Uint8List _shootSound;
  late final Uint8List _healthPickupSound;
  late final Uint8List _ammoPickupSound;
  late final Uint8List _hurtSound;
  late final Uint8List _deathSound;
  late final Uint8List _winSound;
  late final Uint8List _footstepSound;

  // Per-enemy-type spatial sounds
  final Map<EnemyType, Uint8List> _enemyHurtSounds = {};
  final Map<EnemyType, Uint8List> _enemyDeathSounds = {};
  late final Uint8List _friendlyDeathSound;
  final Map<EnemyType, Uint8List> _enemyAmbientSounds = {};

  bool _ready = false;
  bool get isReady => _ready;

  double _footstepCooldown = 0;
  static const double _footstepInterval = 0.35;

  // Ambient enemy sound cooldowns
  double _ambientSoundCooldown = 0;
  static const double _ambientSoundInterval = 2.0;

  /// Generate all sounds. Call once at startup.
  Future<void> generate() async {
    // Player sounds (non-spatial, centered)
    _shootSound = _makeWav(_synthShoot());
    _healthPickupSound = _makeWav(_synthPickup(high: true));
    _ammoPickupSound = _makeWav(_synthPickup(high: false));
    _hurtSound = _makeWav(_synthHurt());
    _deathSound = _makeWav(_synthDeath());
    _winSound = _makeWav(_synthWin());
    _footstepSound = _makeWav(_synthFootstep());
    _friendlyDeathSound = _makeWav(_synthFriendlyDeath());

    // Per-enemy-type sounds
    for (final type in EnemyType.values) {
      _enemyHurtSounds[type] = _makeWav(_synthEnemyHurtForType(type));
      _enemyDeathSounds[type] = _makeWav(_synthEnemyDeathForType(type));
      _enemyAmbientSounds[type] = _makeWav(_synthEnemyAmbientForType(type));
    }

    // Initialize spatial player pool
    for (int i = 0; i < _poolSize; i++) {
      _spatialPool.add(AudioPlayer());
    }

    // Set volumes for non-spatial players
    await _shootPlayer.setVolume(0.4);
    await _pickupPlayer.setVolume(0.5);
    await _uiPlayer.setVolume(0.6);
    await _footstepPlayer.setVolume(0.15);

    _ready = true;
  }

  void dispose() {
    _shootPlayer.dispose();
    _pickupPlayer.dispose();
    _uiPlayer.dispose();
    _footstepPlayer.dispose();
    for (final p in _spatialPool) {
      p.dispose();
    }
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

  /// Play enemy hurt sound with 3D spatial positioning.
  void playEnemyHurt(EnemyType type, {required Offset enemyPos,
      required Offset playerPos, required double playerAngle}) {
    if (!_ready) return;
    final sound = _enemyHurtSounds[type];
    if (sound == null) return;
    _playSpatial(sound, enemyPos, playerPos, playerAngle);
  }

  /// Play enemy death sound with 3D spatial positioning.
  void playEnemyDeath(EnemyType type, EnemyAlignment alignment,
      {required Offset enemyPos, required Offset playerPos,
      required double playerAngle}) {
    if (!_ready) return;
    if (alignment == EnemyAlignment.friendly) {
      _playSpatial(_friendlyDeathSound, enemyPos, playerPos, playerAngle);
    } else {
      final sound = _enemyDeathSounds[type];
      if (sound == null) return;
      _playSpatial(sound, enemyPos, playerPos, playerAngle);
    }
  }

  /// Play ambient enemy sounds for nearby enemies each frame.
  /// Creates spatial presence — grunts, growls, hums based on type.
  void updateAmbientEnemySounds(double dt, List<SpatialSource> sources,
      Offset playerPos, double playerAngle) {
    if (!_ready) return;
    _ambientSoundCooldown -= dt;
    if (_ambientSoundCooldown > 0) return;
    _ambientSoundCooldown = _ambientSoundInterval;

    // Pick the closest audible enemy to play an ambient sound
    SpatialSource? closest;
    double closestDist = maxAudioDistance;
    for (final src in sources) {
      final dist = (src.position - playerPos).distance;
      if (dist < closestDist) {
        closestDist = dist;
        closest = src;
      }
    }

    if (closest != null) {
      final sound = _enemyAmbientSounds[closest.type];
      if (sound != null) {
        _playSpatial(sound, closest.position, playerPos, playerAngle,
            baseVolume: 0.15);
      }
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

  // ── Playback helpers ──────────────────────────────────────────

  void _play(AudioPlayer player, Uint8List wavData) {
    player.play(BytesSource(wavData));
  }

  /// Play a sound with 3D spatial positioning using the player pool.
  /// Calculates stereo panning from relative angle and volume from distance.
  void _playSpatial(Uint8List wavData, Offset soundPos, Offset listenerPos,
      double listenerAngle, {double baseVolume = 0.4}) {
    final delta = soundPos - listenerPos;
    final dist = delta.distance;
    if (dist > maxAudioDistance) return;

    // Distance attenuation: inverse-distance with rolloff
    final attenuation = (1.0 - dist / maxAudioDistance).clamp(0.0, 1.0);
    final volume = baseVolume * attenuation * attenuation; // Quadratic falloff

    // Stereo panning: calculate angle relative to listener's facing direction
    final soundAngle = atan2(delta.dy, delta.dx);
    var relAngle = soundAngle - listenerAngle;
    while (relAngle > pi) { relAngle -= 2 * pi; }
    while (relAngle < -pi) { relAngle += 2 * pi; }

    // Balance: -1.0 (left) to 1.0 (right)
    // sin gives natural panning: 0 in front, +1 right, -1 left, 0 behind
    final balance = sin(relAngle).clamp(-1.0, 1.0);

    // Get next player from pool (round-robin)
    final player = _spatialPool[_nextPoolIndex];
    _nextPoolIndex = (_nextPoolIndex + 1) % _poolSize;

    player.setVolume(volume);
    player.setBalance(balance);
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

  // ── Per-enemy-type sound synthesis ─────────────────────────────

  /// Unique hurt sound per enemy type.
  static Float64List _synthEnemyHurtForType(EnemyType type) {
    switch (type) {
      case EnemyType.grunt: // Trollface: mocking "ha" yelp
        return _synthTone(dur: 0.1, freqStart: 600, freqEnd: 800, amp: 0.5);
      case EnemyType.imp: // Doge: high-pitched whimper
        return _synthTone(dur: 0.08, freqStart: 900, freqEnd: 1200, amp: 0.4);
      case EnemyType.brute: // Grumpy Cat: low grunt
        return _synthTone(dur: 0.15, freqStart: 200, freqEnd: 150, amp: 0.6);
      case EnemyType.sentinel: // Stonks: electronic glitch
        return _synthGlitch(dur: 0.1, baseFreq: 400);
      case EnemyType.zoomer: // Distracted BF: surprised yelp
        return _synthTone(dur: 0.12, freqStart: 500, freqEnd: 900, amp: 0.5);
      case EnemyType.swarm: // This Is Fine Dog: sizzle
        return _synthNoiseBurst(dur: 0.08, freq: 300);
      case EnemyType.healer: // Harold: pained sigh
        return _synthTone(dur: 0.2, freqStart: 350, freqEnd: 250, amp: 0.4);
      case EnemyType.boss: // GigaChad: deep impact
        return _synthTone(dur: 0.2, freqStart: 120, freqEnd: 80, amp: 0.7);
      case EnemyType.trickster: // Rick Astley: synth blip
        return _synthGlitch(dur: 0.12, baseFreq: 600);
      case EnemyType.sage: // Rare Pepe: gentle croak
        return _synthTone(dur: 0.15, freqStart: 180, freqEnd: 220, amp: 0.3);
    }
  }

  /// Unique death sound per enemy type.
  static Float64List _synthEnemyDeathForType(EnemyType type) {
    switch (type) {
      case EnemyType.grunt: // Trollface: descending laugh
        return _synthDescend(dur: 0.4, freqStart: 700, freqEnd: 200, amp: 0.5);
      case EnemyType.imp: // Doge: sad descending howl
        return _synthDescend(dur: 0.35, freqStart: 1000, freqEnd: 300, amp: 0.5);
      case EnemyType.brute: // Grumpy Cat: heavy thud + growl
        return _synthThud(dur: 0.5, freq: 100, amp: 0.6);
      case EnemyType.sentinel: // Stonks: digital crash
        return _synthGlitch(dur: 0.4, baseFreq: 300);
      case EnemyType.zoomer: // Distracted BF: dramatic gasp
        return _synthDescend(dur: 0.3, freqStart: 600, freqEnd: 150, amp: 0.5);
      case EnemyType.swarm: // This Is Fine Dog: explosion pop
        return _synthExplosion(dur: 0.3);
      case EnemyType.healer: // Harold: long pained sigh
        return _synthDescend(dur: 0.6, freqStart: 400, freqEnd: 150, amp: 0.4);
      case EnemyType.boss: // GigaChad: epic crash
        return _synthThud(dur: 0.8, freq: 60, amp: 0.8);
      case EnemyType.trickster: // Rick Astley: "never gonna" jingle fragment
        return _synthRickDeath();
      case EnemyType.sage: // Rare Pepe: sad croak descend
        return _synthDescend(dur: 0.4, freqStart: 200, freqEnd: 80, amp: 0.4);
    }
  }

  /// Ambient presence sound per enemy type (growls, hums, etc.).
  static Float64List _synthEnemyAmbientForType(EnemyType type) {
    switch (type) {
      case EnemyType.grunt: // Trollface: chuckling
        return _synthChuckle();
      case EnemyType.imp: // Doge: panting
        return _synthPanting();
      case EnemyType.brute: // Grumpy Cat: low growl
        return _synthTone(dur: 0.4, freqStart: 80, freqEnd: 90, amp: 0.3);
      case EnemyType.sentinel: // Stonks: electronic hum
        return _synthHum(freq: 220, dur: 0.3);
      case EnemyType.zoomer: // Distracted BF: rustling
        return _synthNoiseBurst(dur: 0.2, freq: 600);
      case EnemyType.swarm: // This Is Fine Dog: crackling fire
        return _synthCrackling();
      case EnemyType.healer: // Harold: gentle hum
        return _synthHum(freq: 330, dur: 0.3);
      case EnemyType.boss: // GigaChad: deep breathing
        return _synthDeepBreath();
      case EnemyType.trickster: // Rick Astley: synth warble
        return _synthGlitch(dur: 0.3, baseFreq: 440);
      case EnemyType.sage: // Rare Pepe: calm croak
        return _synthTone(dur: 0.3, freqStart: 140, freqEnd: 160, amp: 0.2);
    }
  }

  /// Friendly death: sad descending tone (makes you feel bad).
  static Float64List _synthFriendlyDeath() {
    final len = (_sampleRate * 0.5).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / 0.5).clamp(0.0, 1.0);
      final freq1 = 440 - t * 200;
      final freq2 = 528 - t * 250;
      samples[i] =
          (sin(2 * pi * freq1 * t) * 0.5 + sin(2 * pi * freq2 * t) * 0.3) *
              env *
              0.5;
    }
    return samples;
  }

  // ── Reusable synth building blocks ────────────────────────────

  /// Simple ascending/descending tone.
  static Float64List _synthTone({
    required double dur,
    required double freqStart,
    required double freqEnd,
    required double amp,
  }) {
    final len = (_sampleRate * dur).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / dur).clamp(0.0, 1.0);
      final freq = freqStart + (freqEnd - freqStart) * (t / dur);
      samples[i] = sin(2 * pi * freq * t) * env * amp;
    }
    return samples;
  }

  /// Descending tone with harmonics.
  static Float64List _synthDescend({
    required double dur,
    required double freqStart,
    required double freqEnd,
    required double amp,
  }) {
    final len = (_sampleRate * dur).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / dur).clamp(0.0, 1.0);
      final freq = freqStart + (freqEnd - freqStart) * (t / dur);
      samples[i] = (sin(2 * pi * freq * t) * 0.6 +
              sin(2 * pi * freq * 1.5 * t) * 0.3) *
          env *
          env *
          amp;
    }
    return samples;
  }

  /// Heavy thud with noise.
  static Float64List _synthThud({
    required double dur,
    required double freq,
    required double amp,
  }) {
    final rng = Random(99);
    final len = (_sampleRate * dur).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / dur).clamp(0.0, 1.0);
      final tone = sin(2 * pi * freq * t) * env * env;
      final rumble = (rng.nextDouble() * 2 - 1) * env * env * env * 0.4;
      samples[i] = (tone + rumble) * amp;
    }
    return samples;
  }

  /// Electronic glitch sound.
  static Float64List _synthGlitch({required double dur, required double baseFreq}) {
    final rng = Random(55);
    final len = (_sampleRate * dur).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / dur).clamp(0.0, 1.0);
      // Rapid frequency modulation for glitchy sound
      final freqMod = baseFreq + sin(t * 80) * 200;
      final square = sin(2 * pi * freqMod * t) > 0 ? 1.0 : -1.0;
      final noise = (rng.nextDouble() * 2 - 1) * 0.2;
      samples[i] = (square * 0.3 + noise) * env * 0.5;
    }
    return samples;
  }

  /// Noise burst with resonance.
  static Float64List _synthNoiseBurst({required double dur, required double freq}) {
    final rng = Random(44);
    final len = (_sampleRate * dur).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / dur).clamp(0.0, 1.0);
      final noise = (rng.nextDouble() * 2 - 1);
      final resonance = sin(2 * pi * freq * t) * 0.3;
      samples[i] = (noise * 0.5 + resonance) * env * env * 0.4;
    }
    return samples;
  }

  /// Explosion pop for swarm death.
  static Float64List _synthExplosion({required double dur}) {
    final rng = Random(88);
    final len = (_sampleRate * dur).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / dur).clamp(0.0, 1.0);
      final boom = sin(2 * pi * (60 - t * 50) * t) * env * env;
      final debris = (rng.nextDouble() * 2 - 1) * env * 0.6;
      samples[i] = (boom * 0.7 + debris * 0.3) * 0.7;
    }
    return samples;
  }

  /// Rick Astley death: descending synth jingle.
  static Float64List _synthRickDeath() {
    final len = (_sampleRate * 0.5).round();
    final samples = Float64List(len);
    // Notes descending: A, F#, D — minor feel
    final notes = [440.0, 370.0, 294.0];
    final noteLen = len ~/ notes.length;
    for (int n = 0; n < notes.length; n++) {
      for (int i = 0; i < noteLen && n * noteLen + i < len; i++) {
        final t = i / _sampleRate;
        final env = (1.0 - t / (noteLen / _sampleRate)) * 0.6;
        final idx = n * noteLen + i;
        // Square-ish wave for synth flavor
        final wave = sin(2 * pi * notes[n] * t);
        samples[idx] = (wave > 0 ? 0.5 : -0.5) * env * 0.5;
      }
    }
    return samples;
  }

  /// Chuckling for trollface ambient.
  static Float64List _synthChuckle() {
    final len = (_sampleRate * 0.3).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = (1.0 - t / 0.3).clamp(0.0, 1.0);
      // Rapid amplitude modulation for "ha ha" effect
      final mod = (sin(t * 25) * 0.5 + 0.5);
      samples[i] = sin(2 * pi * 300 * t) * env * mod * 0.3;
    }
    return samples;
  }

  /// Panting for doge ambient.
  static Float64List _synthPanting() {
    final rng = Random(22);
    final len = (_sampleRate * 0.4).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      // Rhythmic breathing: two quick breaths
      final breathPhase = (t * 8).floor() % 2 == 0;
      final env = breathPhase ? 0.3 : 0.0;
      final noise = (rng.nextDouble() * 2 - 1);
      samples[i] = noise * env * 0.2;
    }
    return samples;
  }

  /// Gentle electronic hum.
  static Float64List _synthHum({required double freq, required double dur}) {
    final len = (_sampleRate * dur).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = sin(pi * t / dur); // Smooth fade in/out
      samples[i] = sin(2 * pi * freq * t) * env * 0.2;
    }
    return samples;
  }

  /// Crackling fire for "This Is Fine" ambient.
  static Float64List _synthCrackling() {
    final rng = Random(66);
    final len = (_sampleRate * 0.3).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      final env = sin(pi * t / 0.3);
      // Random crackles
      final crackle = rng.nextDouble() < 0.1 ? (rng.nextDouble() * 2 - 1) : 0.0;
      final lowRumble = sin(2 * pi * 80 * t) * 0.1;
      samples[i] = (crackle * 0.4 + lowRumble) * env;
    }
    return samples;
  }

  /// Deep breathing for boss ambient.
  static Float64List _synthDeepBreath() {
    final rng = Random(11);
    final len = (_sampleRate * 0.5).round();
    final samples = Float64List(len);
    for (int i = 0; i < len; i++) {
      final t = i / _sampleRate;
      // Slow amplitude modulation for breathing rhythm
      final breathEnv = (sin(2 * pi * 1.5 * t) * 0.5 + 0.5);
      final noise = (rng.nextDouble() * 2 - 1) * 0.15;
      final tone = sin(2 * pi * 60 * t) * 0.1;
      samples[i] = (noise + tone) * breathEnv * 0.3;
    }
    return samples;
  }
}

/// Lightweight struct passed to [GameAudio.updateAmbientEnemySounds].
class SpatialSource {
  final Offset position;
  final EnemyType type;
  const SpatialSource(this.position, this.type);
}
