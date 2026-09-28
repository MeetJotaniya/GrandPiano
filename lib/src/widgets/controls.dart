import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme.dart';

// ─── Small icon button for the header row ────────────────────────────────────
class PianoCtrlBtn extends StatelessWidget {
  final PhosphorIconData icon;
  final Color color;
  final String tooltip;
  final double size;
  final VoidCallback? onTap;
  final bool highlight;

  const PianoCtrlBtn({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.size,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: highlight
                ? PianoTheme.gold.withValues(alpha: 0.12)
                : PianoTheme.woodDark,
            borderRadius: BorderRadius.circular(size * 0.28),
            border: Border.all(
              color: color.withValues(alpha: enabled ? 0.65 : 0.25),
              width: 1.2,
            ),
            boxShadow: enabled
                ? [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 8)]
                : null,
          ),
          child: Center(
            child: PhosphorIcon(icon, color: color, size: size * 0.52),
          ),
        ),
      ),
    );
  }
}

// ─── Blinking REC indicator badge ────────────────────────────────────────────
class RecBadge extends StatefulWidget {
  final double fontSize;
  const RecBadge({super.key, this.fontSize = 11.0});
  @override
  State<RecBadge> createState() => _RecBadgeState();
}

class _RecBadgeState extends State<RecBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() { _blink.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _blink,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: math.max(6.0, widget.fontSize * 0.8),
          vertical:   math.max(2.0, widget.fontSize * 0.35),
        ),
        decoration: BoxDecoration(
          color: PianoTheme.recRed.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PianoTheme.recRed, width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, color: PianoTheme.recRed, size: widget.fontSize * 0.65),
          SizedBox(width: widget.fontSize * 0.45),
          Text('REC', style: GoogleFonts.rajdhani(
            color: PianoTheme.recRed,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          )),
        ]),
      ),
    );
  }
}

