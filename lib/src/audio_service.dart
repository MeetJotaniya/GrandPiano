import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

// ─── Audio service ────────────────────────────────────────────────────────────
// Owns the player pool, asset resolution, preloading, and polyphonic playback.
// Completely decoupled from Flutter widgets — safe to instantiate in state.
class AudioService {
  static const int _maxPlayers = 16;
  final List<AudioPlayer> _players = [];
  final List<String?> _playerNotes = [];
  int _nextPlayerIndex = 0;
  bool _initialized = false;
  bool soundEnabled = true;

  bool get isInitialized => _initialized;

  // Sharp-spelled internal note names (e.g. 'C#4') map to the flat-spelled
  // filenames actually present in assets/music/ (e.g. 'Db4.mp3').
  static const _flatFileName = {
    'C#': 'Db', 'D#': 'Eb', 'F#': 'Gb', 'G#': 'Ab', 'A#': 'Bb',
  };

  static String assetForNote(String note) {
    if (note == 'A0') return 'assets/music/piano-mp3_A0.mp3';
    final letter = note.replaceAll(RegExp(r'\d'), '');
    final oct    = note.replaceAll(RegExp(r'[^\d]'), '');
    final fileLetter = _flatFileName[letter] ?? letter;
    return 'assets/music/$fileLetter$oct.mp3';
  }

  // ── Initialise player pool and preload default middle-C area notes ──────────
  Future<bool> init() async {
    try {
      for (int i = 0; i < _maxPlayers; i++) {
        _players.add(AudioPlayer());
        _playerNotes.add(null);
      }
      _initialized = true;

      // Preload default set of middle notes in the background immediately
      const defaultNotes = [
        'C4', 'C#4', 'D4', 'D#4', 'E4', 'F4', 'F#4', 'G4', 'G#4', 'A4', 'A#4', 'B4',
        'C5', 'C#5', 'D5', 'D#5',
      ];
      for (int i = 0; i < defaultNotes.length && i < _players.length; i++) {
        final note = defaultNotes[i];
        _playerNotes[i] = note;
        unawaited(_players[i].setAsset(assetForNote(note)).catchError((e) {
          _playerNotes[i] = null;
          debugPrint('Init preload failed for $note: $e');
          return null; // setAsset returns Duration? — satisfy type checker
        }));
      }
      return true;
    } catch (e) {
      debugPrint('Audio init failed: $e');
      _initialized = false;
      return false;
    }
  }

  // ── Preload a given list of visible notes into idle players ─────────────────
  Future<void> preloadNotes(List<String> visible) async {
    if (!_initialized) return;

    // Find notes not yet loaded in any player
    final notesToLoad = visible.where((n) => !_playerNotes.contains(n)).toList();
    if (notesToLoad.isEmpty) return;

    // Find idle players that don't currently hold a visible note
    final idleIndexes = <int>[];
    for (int i = 0; i < _maxPlayers; i++) {
      if (_isIdle(_players[i])) {
        final cur = _playerNotes[i];
        if (cur == null || !visible.contains(cur)) {
          idleIndexes.add(i);
        }
      }
    }

    final loadCount = math.min(notesToLoad.length, idleIndexes.length);
    for (int i = 0; i < loadCount; i++) {
      final note = notesToLoad[i];
      final idx  = idleIndexes[i];
      _playerNotes[idx] = note;
      try {
        await _players[idx].setAsset(assetForNote(note));
      } catch (e) {
        _playerNotes[idx] = null;
        debugPrint('Background preload failed for $note: $e');
      }
    }
  }

  // ── Play a note — uses preloaded player when available ─────────────────────
  Future<void> play(String note) async {
    if (!soundEnabled || !_initialized) return;
    try {
      final asset = assetForNote(note);
      int targetIdx = -1;

      // 1. Idle player already holding this note
      for (int i = 0; i < _maxPlayers; i++) {
        if (_playerNotes[i] == note && _isIdle(_players[i])) {
          targetIdx = i;
          break;
        }
      }
      // 2. Any player holding this note (will seek to zero)
      if (targetIdx == -1) {
        for (int i = 0; i < _maxPlayers; i++) {
          if (_playerNotes[i] == note) { targetIdx = i; break; }
        }
      }
      // 3. Any idle player
      if (targetIdx == -1) {
        for (int i = 0; i < _maxPlayers; i++) {
          if (_isIdle(_players[i])) { targetIdx = i; break; }
        }
      }
      // 4. Round-robin fallback
      if (targetIdx == -1) {
        targetIdx = _nextPlayerIndex;
        _nextPlayerIndex = (_nextPlayerIndex + 1) % _maxPlayers;
      }

      final player = _players[targetIdx];
      if (_playerNotes[targetIdx] == note) {
        await player.seek(Duration.zero);
        unawaited(player.play());
      } else {
        _playerNotes[targetIdx] = note;
        await player.setAsset(asset);
        await player.seek(Duration.zero);
        unawaited(player.play());
      }
    } catch (e) {
      debugPrint('Play sound failed for $note: $e');
    }
  }

  bool _isIdle(AudioPlayer p) =>
      !p.playing || p.processingState == ProcessingState.completed;

  void dispose() {
    for (final p in _players) { p.dispose(); }
    _players.clear();
    _playerNotes.clear();
  }
}
