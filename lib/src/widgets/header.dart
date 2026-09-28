import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme.dart';
import 'controls.dart';

// ─── Piano page header bar ────────────────────────────────────────────────────
class PianoHeader extends StatelessWidget {
  final bool isRecording, isPlaying, isExporting, soundEnabled, hasNotes;
  final String? lastNote;
  final String exportStage;
  final int keyCount;
  final int whiteKeyCount;
  final VoidCallback onToggleSound, onRecord, onPlay, onClear, onSave;

  const PianoHeader({
    super.key,
    required this.isRecording,
    required this.isPlaying,
    required this.isExporting,
    required this.exportStage,
    required this.soundEnabled,
    required this.lastNote,
    required this.keyCount,
    required this.whiteKeyCount,
    required this.hasNotes,
    required this.onToggleSound,
    required this.onRecord,
    required this.onPlay,
    required this.onClear,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final mq       = MediaQuery.of(context);
    final h        = mq.size.height;
    final w        = mq.size.width;
    final shortest = math.min(w, h);

    final btnSz = (shortest * 0.105).clamp(26.0, 50.0);
    final gap   = (w * 0.010).clamp(3.0, 10.0);
    final vPad  = (h * 0.012).clamp(4.0, 12.0);
    final hPad  = math.max(8.0, w * 0.020);

    final playEnabled  = !isPlaying && !isRecording && !isExporting && hasNotes;
    final clearEnabled = hasNotes && !isRecording && !isPlaying && !isExporting;
    final saveEnabled  = hasNotes && !isRecording && !isPlaying && !isExporting;

    final recBtn = PianoCtrlBtn(
      icon: isRecording ? PhosphorIconsBold.stop : PhosphorIconsBold.record,
      color: isRecording ? PianoTheme.recRed : PianoTheme.gold,
      tooltip: isRecording ? 'Stop' : 'Record',
      size: btnSz, onTap: onRecord,
    );
    final playBtn = PianoCtrlBtn(
      icon: PhosphorIconsBold.play,
      color: playEnabled ? PianoTheme.gold : PianoTheme.goldDim,
      tooltip: 'Play',
      size: btnSz, onTap: playEnabled ? onPlay : null,
    );
    final saveBtn = isExporting
        ? SizedBox(
            width: btnSz,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: btnSz, height: btnSz,
                  child: Padding(
                    padding: EdgeInsets.all(btnSz * 0.15),
                    child: const CircularProgressIndicator(
                        strokeWidth: 2.5, color: PianoTheme.gold),
                  ),
                ),
                if (exportStage.isNotEmpty) ...[
                  SizedBox(height: btnSz * 0.10),
                  Text(
                    exportStage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.rajdhani(
                      color: PianoTheme.gold,
                      fontSize: (btnSz * 0.24).clamp(7.0, 11.0),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          )
        : PianoCtrlBtn(
            icon: PhosphorIconsBold.export,
            color: saveEnabled ? PianoTheme.gold : PianoTheme.goldDim,
            tooltip: 'Save',
            size: btnSz, onTap: saveEnabled ? onSave : null,
          );
    final clearBtn = PianoCtrlBtn(
      icon: PhosphorIconsBold.trash,
      color: clearEnabled ? PianoTheme.gold : PianoTheme.goldDim,
      tooltip: 'Clear',
      size: btnSz, onTap: clearEnabled ? onClear : null,
    );
    final soundBtn = PianoCtrlBtn(
      icon: soundEnabled ? PhosphorIconsBold.speakerHigh : PhosphorIconsBold.speakerSlash,
      color: soundEnabled ? PianoTheme.gold : PianoTheme.goldDim,
      tooltip: soundEnabled ? 'Mute' : 'Unmute',
      size: btnSz, onTap: onToggleSound,
      highlight: soundEnabled,
    );

    final titleFz    = (btnSz * 0.56).clamp(11.0, 24.0);
    final subtitleFz = (btnSz * 0.28).clamp(7.0, 12.0);

    final titleBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GRAND PIANO',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: GoogleFonts.rajdhani(
            color: PianoTheme.gold,
            fontSize: titleFz,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        Text(
          '$keyCount Keys\u2022 A0\u2013C8',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: GoogleFonts.rajdhani(
            color: PianoTheme.goldDim,
            fontSize: subtitleFz,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );

    Widget? badge;
    if (isRecording) {
      badge = RecBadge(fontSize: (btnSz * 0.28).clamp(8.0, 12.0));
    } else if (lastNote != null) {
      badge = Container(
        padding: EdgeInsets.symmetric(
          horizontal: math.max(4.0, w * 0.009),
          vertical:   math.max(2.0, h * 0.005),
        ),
        decoration: BoxDecoration(
          color: PianoTheme.gold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PianoTheme.gold.withValues(alpha: 0.5), width: 1),
        ),
        child: Text(
          lastNote!,
          style: GoogleFonts.rajdhani(
            color: PianoTheme.goldGlow,
            fontSize: (btnSz * 0.32).clamp(9.0, 15.0),
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF060300), PianoTheme.surface],
        ),
        border: const Border(bottom: BorderSide(color: PianoTheme.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(builder: (ctx, cst) {
        final availW = cst.maxWidth;
        final btnsW    = btnSz * 5 + gap * 4;
        final badgeW   = badge != null ? (btnSz * 0.9 + gap) : 0.0;
        const minTitleW = 72.0;
        final totalNeeded = minTitleW + btnsW + badgeW + gap * 3;

        if (availW >= totalNeeded) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: titleBlock),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (badge != null) ...[badge, SizedBox(width: gap)],
                  recBtn,
                  SizedBox(width: gap),
                  playBtn,
                  SizedBox(width: gap),
                  saveBtn,
                  SizedBox(width: gap),
                  clearBtn,
                  SizedBox(width: gap),
                  soundBtn,
                ],
              ),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: titleBlock),
                if (badge != null) ...[SizedBox(width: gap), badge],
              ],
            ),
            SizedBox(height: (vPad * 0.55).clamp(2.0, 7.0)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                recBtn, SizedBox(width: gap),
                playBtn, SizedBox(width: gap),
                saveBtn, SizedBox(width: gap),
                clearBtn, SizedBox(width: gap),
                soundBtn,
              ],
            ),
          ],
        );
      }),
    );
  }
}
