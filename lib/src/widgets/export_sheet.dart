import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme.dart';

// ─── Export format picker sheet ───────────────────────────────────────────────
class ExportFormatSheet extends StatelessWidget {
  const ExportFormatSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final size      = MediaQuery.of(context).size;
    final insets    = MediaQuery.of(context).viewInsets;
    final landscape = size.width > size.height;
    final availH    = size.height - insets.bottom;

    final double vertPad      = landscape ? 8 : 20;
    final double horzPad      = landscape ? 32 : 24;
    final double titleGap     = landscape ? 8 : 24;
    final double subtitleGap  = landscape ? 4 : 6;
    final double optionGap    = landscape ? 8 : 24;
    final double titleFontSz  = landscape ? 18.0 : 22.0;
    final double subFontSz    = landscape ? 12.0 : 14.0;
    final double betweenOpts  = landscape ? 8 : 12;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: PianoTheme.woodMid,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        SizedBox(height: titleGap),
        Text(
          'EXPORT RECORDING',
          style: GoogleFonts.rajdhani(
            color: PianoTheme.gold,
            fontSize: titleFontSz,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: subtitleGap),
        Text(
          'Choose your preferred export format',
          style: GoogleFonts.rajdhani(
            color: PianoTheme.goldDim,
            fontSize: subFontSz,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: optionGap),
        if (landscape)
          Row(children: [
            Expanded(child: ExportOption(
              icon: PhosphorIconsBold.musicNote,
              title: 'Audio (M4A)',
              description: 'Lightweight audio.',
              compact: true,
              onTap: () => Navigator.pop(context, 'audio'),
            )),
            const SizedBox(width: 8),
            Expanded(child: ExportOption(
              icon: PhosphorIconsBold.filmStrip,
              title: 'Video 1080p',
              description: 'Crisp HD, slower.',
              compact: true,
              onTap: () => Navigator.pop(context, 'video_1080'),
            )),
            const SizedBox(width: 8),
            Expanded(child: ExportOption(
              icon: PhosphorIconsBold.video,
              title: 'Video 720p',
              description: 'Balanced speed.',
              compact: true,
              onTap: () => Navigator.pop(context, 'video_720'),
            )),
            const SizedBox(width: 8),
            Expanded(child: ExportOption(
              icon: PhosphorIconsBold.lightning,
              title: 'Video 360p',
              description: 'Extremely fast.',
              compact: true,
              onTap: () => Navigator.pop(context, 'video_360'),
            )),
          ])
        else
          Column(children: [
            ExportOption(
              icon: PhosphorIconsBold.musicNote,
              title: 'Audio File (M4A)',
              description: 'Studio-quality, lightweight audio file.',
              onTap: () => Navigator.pop(context, 'audio'),
            ),
            SizedBox(height: betweenOpts),
            ExportOption(
              icon: PhosphorIconsBold.filmStrip,
              title: 'Video File - 1080p (High Quality)',
              description: 'Crisp HD video. Best visuals, slower export.',
              onTap: () => Navigator.pop(context, 'video_1080'),
            ),
            SizedBox(height: betweenOpts),
            ExportOption(
              icon: PhosphorIconsBold.video,
              title: 'Video File - 720p (Medium Quality)',
              description: 'Standard HD video. Balanced speed & quality.',
              onTap: () => Navigator.pop(context, 'video_720'),
            ),
            SizedBox(height: betweenOpts),
            ExportOption(
              icon: PhosphorIconsBold.lightning,
              title: 'Video File - 360p (Low Quality - Fast)',
              description: 'Extremely fast export. Ideal for quick sharing.',
              onTap: () => Navigator.pop(context, 'video_360'),
            ),
          ]),
        SizedBox(height: vertPad),
      ],
    );

    return Container(
      constraints: BoxConstraints(maxHeight: availH * 0.95),
      decoration: const BoxDecoration(
        color: PianoTheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(top: BorderSide(color: PianoTheme.border, width: 1.5)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(horzPad, vertPad, horzPad, insets.bottom + vertPad),
        child: content,
      ),
    );
  }
}

// ─── Single export format option tile ────────────────────────────────────────
class ExportOption extends StatelessWidget {
  final PhosphorIconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool compact;

  const ExportOption({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: PianoTheme.woodDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PianoTheme.border, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(compact ? 10 : 16),
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: PianoTheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: PianoTheme.goldDim, width: 1.0),
                    ),
                    child: Center(child: PhosphorIcon(icon, color: PianoTheme.gold, size: 18)),
                  ),
                  const SizedBox(height: 6),
                  Text(title,
                    style: GoogleFonts.rajdhani(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(description,
                    style: GoogleFonts.rajdhani(
                      color: const Color(0xFFAA9980), fontSize: 10, fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: PianoTheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: PianoTheme.goldDim, width: 1.0),
                    ),
                    child: Center(child: PhosphorIcon(icon, color: PianoTheme.gold, size: 24)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                          style: GoogleFonts.rajdhani(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(description,
                          style: GoogleFonts.rajdhani(
                            color: const Color(0xFFAA9980),
                            fontSize: 12, fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PhosphorIcon(PhosphorIconsBold.caretRight, color: PianoTheme.goldDim, size: 20),
                ],
              ),
      ),
    );
  }
}
