import 'package:flutter/material.dart';

// ─── Wood rail (left/right keyboard border) ───────────────────────────────────
class WoodRail extends StatelessWidget {
  final double width;
  final bool isLeft;
  const WoodRail({super.key, required this.width, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end:   isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: const [Color(0xFF7A3F1E), Color(0xFF2A1200)],
          stops: const [0.0, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 10,
            offset: Offset(isLeft ? 4 : -4, 0),
          ),
        ],
      ),
    );
  }
}

// ─── Glowing dot indicator (used on C keys + middle-C marker) ────────────────
class GlowDot extends StatelessWidget {
  final Color color;
  final double size;
  final bool glow;
  const GlowDot({super.key, required this.color, required this.size, this.glow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glow
            ? [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 8)]
            : null,
      ),
    );
  }
}

// ─── Keyboard constants ───────────────────────────────────────────────────────
const Map<String, String> kBlackKeyMap = {
  'C': 'C#', 'D': 'D#', 'F': 'F#', 'G': 'G#', 'A': 'A#',
};

/// Returns the responsive white key width clamped to be playable on any screen.
double whiteKeyWidth(double screenWidth) =>
    (screenWidth / 10).clamp(32.0, 60.0);

/// Determines if a note name corresponds to a black key.
bool isBlackKey(String note) => note.contains('#');

/// Generates the full 88-key note list ordered C, C#, D, D#… per octave,
/// starting from [start] and ending at [end] (both inclusive).
List<String> generateNoteRange(String start, String end) {
  const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  final startOct = int.parse(start.replaceAll(RegExp(r'[^\d]'), ''));
  final endOct   = int.parse(end.replaceAll(RegExp(r'[^\d]'), ''));
  final notes    = <String>[];
  var started    = false;
  for (var oct = startOct; oct <= endOct; oct++) {
    for (final n in noteNames) {
      final cur = '$n$oct';
      if (!started && cur == start) started = true;
      if (started) notes.add(cur);
      if (cur == end) return notes;
    }
  }
  return notes;
}

/// Builds the interleaved white+black note list (white key, optional black key, ...)
/// used by the keyboard widget.
List<String> buildInterleavedNoteList(List<String> fullRange) {
  final whites = fullRange.where((n) => !n.contains('#')).toList();
  final result = <String>[];
  for (int i = 0; i < whites.length; i++) {
    final w      = whites[i];
    final letter = w.replaceAll(RegExp(r'\d'), '');
    final oct    = w.replaceAll(RegExp(r'[^\d]'), '');
    result.add(w);
    if (i < whites.length - 1 && kBlackKeyMap.containsKey(letter)) {
      final bn = kBlackKeyMap[letter]! + oct;
      if (fullRange.contains(bn)) result.add(bn);
    }
  }
  return result;
}


