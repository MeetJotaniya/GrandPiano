import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── App palette ─────────────────────────────────────────────────────────────
class PianoTheme {
  static const bg       = Color(0xFF0A0500);
  static const surface  = Color(0xFF140A00);
  static const woodDark = Color(0xFF2A1200);
  static const woodMid  = Color(0xFF4A2210);
  static const gold     = Color(0xFFD4A84B);
  static const goldDim  = Color(0xFF8C6A2A);
  static const goldGlow = Color(0xFFFFD980);
  static const border   = Color(0xFF5C3D1E);
  static const keyIvory = Color(0xFFF8F3EA);
  static const keyShade = Color(0xFFDDD5C4);
  static const keyEbony = Color(0xFF1A1A1A);
  static const recRed   = Color(0xFFFF3B3B);
  static const middleC  = Color(0xFFE8543A);

  // ── Centralized text styles ──────────────────────────────────────────────
  static TextStyle dialogTitle(BuildContext context) => TextStyle(
    color: gold,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    fontFamily: GoogleFonts.rajdhani().fontFamily,
  );

  static TextStyle dialogBody(BuildContext context) => TextStyle(
    color: goldDim,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontFamily: GoogleFonts.rajdhani().fontFamily,
  );
}
