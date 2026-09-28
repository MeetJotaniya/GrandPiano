import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';

import 'audio_service.dart';
import 'models.dart';

// ─── Export service ───────────────────────────────────────────────────────────
// Owns the full render pipeline: FFmpeg audio mix, PNG frame generation, and
// final MP4 assembly. Completely stateless — pass recorded notes and all-notes
// list on each call.

/// Render a recording to a local file.
///
/// [format] — one of: 'audio', 'video_1080', 'video_720', 'video_360'
/// [recordedNotes] — the time-stamped recording
/// [allNotes] — full ordered note list (used for frame generation)
/// [onStage] — callback fired at each pipeline stage with a human-readable label
///
/// Returns the absolute path to the output file, or null on failure.
Future<String?> renderRecordingToFile({
  required String format,
  required List<RecordedNote> recordedNotes,
  required List<String> allNotes,
  required void Function(String) onStage,
}) async {
  if (recordedNotes.isEmpty) return null;
  onStage('Preparing…');
  final isVideo = format.startsWith('video');

  // 1. Extract every unique sample this recording needs to a real file
  //    (FFmpeg needs file paths, not Flutter asset-bundle references).
  final tempDir = await getTemporaryDirectory();
  final assetLocalPath = <String, String>{};

  for (final rn in recordedNotes) {
    if (!assetLocalPath.containsKey(rn.note)) {
      final asset = AudioService.assetForNote(rn.note);
      final data = await rootBundle.load(asset);
      final filename = asset.split('/').last;
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      assetLocalPath[rn.note] = file.path;
    }
  }

  final uniqueNotes = assetLocalPath.keys.toList();
  final usageCount = <String, int>{};
  for (final rn in recordedNotes) {
    usageCount[rn.note] = (usageCount[rn.note] ?? 0) + 1;
  }

  // 2. Build FFmpeg filter graph: split inputs, delay, mix
  final filterParts = <String>[];
  final mixLabels = <String>[];
  final noteUseIndex = <String, int>{};

  for (int ai = 0; ai < uniqueNotes.length; ai++) {
    final note = uniqueNotes[ai];
    final n = usageCount[note]!;
    if (n > 1) {
      final outs = List.generate(n, (k) => '[a${ai}_$k]').join();
      filterParts.add('[$ai:a]asplit=$n$outs');
    }
  }

  for (int ni = 0; ni < recordedNotes.length; ni++) {
    final rn = recordedNotes[ni];
    final ai = uniqueNotes.indexOf(rn.note);
    final n = usageCount[rn.note]!;
    final k = noteUseIndex[rn.note] ?? 0;
    noteUseIndex[rn.note] = k + 1;

    final srcLabel = n == 1 ? '[$ai:a]' : '[a${ai}_$k]';
    final delayMs  = rn.time < 0 ? 0 : rn.time;
    final outLabel = '[n$ni]';

    filterParts.add('${srcLabel}adelay=$delayMs:all=1,volume=0.85$outLabel');
    mixLabels.add(outLabel);
  }

  filterParts.add(
    '${mixLabels.join()}amix=inputs=${mixLabels.length}:duration=longest:normalize=0[mixed]',
  );
  filterParts.add('[mixed]alimiter=limit=0.95[out]');

  final filterComplex = filterParts.join(';');
  final outDir = await getApplicationDocumentsDirectory();
  final audioOutputPath =
      '${outDir.path}/piano_recording_temp_${DateTime.now().millisecondsSinceEpoch}.m4a';

  // 3. Render audio via FFmpegKit
  onStage('Rendering audio…');
  final List<String> args = [];
  for (final note in uniqueNotes) {
    args.addAll(['-i', assetLocalPath[note]!]);
  }
  args.addAll([
    '-filter_complex', filterComplex,
    '-map', '[out]',
    '-c:a', 'aac',
    '-b:a', '192k',
    '-y',
    audioOutputPath,
  ]);

  final session = await FFmpegKit.executeWithArguments(args);
  final rc = await session.getReturnCode();
  if (!ReturnCode.isSuccess(rc) || !await File(audioOutputPath).exists()) {
    return null;
  }

  // Audio-only export: rename temp file to final .m4a and return
  if (!isVideo) {
    final finalPath =
        '${outDir.path}/piano_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await File(audioOutputPath).rename(finalPath);
    return finalPath;
  }

  // 4. Animated video: generate PNG keyframes (VFR)
  onStage('Rendering frames…');
  try {
    final framesDir = Directory('${tempDir.path}/piano_frames');
    if (await framesDir.exists()) await framesDir.delete(recursive: true);
    await framesDir.create();

    final whites = allNotes.where((n) => !n.contains('#')).toList();
    const noteDurationMs = 400;

    final events = <int>{};
    events.add(0);
    for (final rn in recordedNotes) {
      events.add(rn.time.clamp(0, 9999999));
      events.add((rn.time + noteDurationMs).clamp(0, 9999999));
    }
    final totalDurationMs = recordedNotes.isEmpty
        ? 1000
        : recordedNotes.last.time + noteDurationMs + 500;
    events.add(totalDurationMs);

    final sortedEvents = events.toList()..sort();
    final framePaths = <String>[];
    final frameDurations = <double>[];

    for (int i = 0; i < sortedEvents.length - 1; i++) {
      final t        = sortedEvents[i];
      final nextT    = sortedEvents[i + 1];
      final durSec   = (nextT - t) / 1000.0;
      if (durSec <= 0) continue;

      final pressed = <String>{};
      for (final rn in recordedNotes) {
        if (t >= rn.time && t < rn.time + noteDurationMs) {
          pressed.add(rn.note);
        }
      }

      double W = 1920.0, H = 1080.0;
      if (format == 'video_720') { W = 1280.0; H = 720.0; }
      else if (format == 'video_360') { W = 640.0; H = 360.0; }

      final frameFile = await _generatePianoFrame(
        pressed, allNotes, whites, i, framesDir.path, W, H,
      );
      framePaths.add(frameFile.path);
      frameDurations.add(durSec);
    }

    if (framePaths.isEmpty) return null;

    // 5. Write concat script
    final concatFile = File('${framesDir.path}/concat.txt');
    final concatBuf = StringBuffer();
    for (int i = 0; i < framePaths.length; i++) {
      final safe = framePaths[i].replaceAll('\\', '/');
      concatBuf.writeln("file '$safe'");
      concatBuf.writeln('duration ${frameDurations[i].toStringAsFixed(6)}');
    }
    if (framePaths.isNotEmpty) {
      concatBuf.writeln("file '${framePaths.last.replaceAll('\\', '/')}'");
    }
    await concatFile.writeAsString(concatBuf.toString());

    final videoOutputPath =
        '${outDir.path}/piano_recording_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // 6. FFmpeg: VFR PNG frames + M4A audio → MP4
    onStage('Encoding video…');
    final List<String> videoArgs = [
      '-f', 'concat', '-safe', '0', '-i', concatFile.path,
      '-i', audioOutputPath,
      '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '18',
      '-pix_fmt', 'yuv420p', '-vsync', 'vfr', '-tune', 'stillimage',
      '-c:a', 'aac', '-b:a', '192k',
      '-shortest', '-movflags', '+faststart', '-y',
      videoOutputPath,
    ];

    var videoSession = await FFmpegKit.executeWithArguments(videoArgs);
    var videoRc = await videoSession.getReturnCode();

    // Fallback: mpeg4 if libx264 unavailable
    if (!ReturnCode.isSuccess(videoRc)) {
      final List<String> fallbackArgs = [
        '-f', 'concat', '-safe', '0', '-i', concatFile.path,
        '-i', audioOutputPath,
        '-c:v', 'mpeg4', '-pix_fmt', 'yuv420p', '-vsync', 'vfr',
        '-c:a', 'aac', '-b:a', '192k',
        '-shortest', '-movflags', '+faststart', '-y',
        videoOutputPath,
      ];
      videoSession = await FFmpegKit.executeWithArguments(fallbackArgs);
      videoRc = await videoSession.getReturnCode();
    }

    // 7. Cleanup
    onStage('Finalizing…');
    try {
      await File(audioOutputPath).delete();
      await framesDir.delete(recursive: true);
    } catch (_) {}

    if (ReturnCode.isSuccess(videoRc) && await File(videoOutputPath).exists()) {
      return videoOutputPath;
    }
  } catch (e) {
    debugPrint('Video generation error: $e');
  }

  return null;
}

// ─── Piano frame generator ────────────────────────────────────────────────────
// Renders a single video frame as a PNG file.
// Self-contained: takes pressed notes + note lists, no widget state.
Future<File> _generatePianoFrame(
  Set<String> pressedNotes,
  List<String> allNotes,
  List<String> whites,
  int frameIndex,
  String tempPath,
  double W,
  double H,
) async {
  final scale   = W / 1920.0;
  final headerH = 130.0 * scale;
  final footerH = 80.0 * scale;
  final keyboardH = H - headerH - footerH;

  final recorder = ui.PictureRecorder();
  final canvas   = Canvas(recorder, Rect.fromLTWH(0, 0, W, H));

  // Background gradient
  canvas.drawRect(
    Rect.fromLTWH(0, 0, W, H),
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0), Offset(W, H),
        [const Color(0xFF1E0D00), const Color(0xFF0A0500)],
      ),
  );

  // Header bar
  canvas.drawRect(
    Rect.fromLTWH(0, 0, W, headerH),
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0), Offset(0, headerH),
        [const Color(0xFF060300), const Color(0xFF140A00)],
      ),
  );
  canvas.drawLine(
    Offset(0, headerH), Offset(W, headerH),
    Paint()..color = const Color(0xFF5C3D1E)..strokeWidth = 2 * scale,
  );

  // Title + subtitle text
  final tp = TextPainter(textDirection: TextDirection.ltr);

  tp.text = TextSpan(
    text: 'GRAND PIANO',
    style: TextStyle(
      color: const Color(0xFFD4A84B),
      fontSize: 56 * scale,
      fontWeight: FontWeight.w900,
      letterSpacing: 5 * scale,
      fontFamily: GoogleFonts.rajdhani().fontFamily,
    ),
  );
  tp.layout();
  tp.paint(canvas, Offset(60 * scale, (headerH - tp.height) / 2));

  tp.text = TextSpan(
    text: pressedNotes.isNotEmpty
        ? '\u266a  ${pressedNotes.join('  ')}'
        : 'STUDIO RECORDING',
    style: TextStyle(
      color: pressedNotes.isNotEmpty
          ? const Color(0xFFFFD980)
          : const Color(0xFF8C6A2A),
      fontSize: 28 * scale,
      fontWeight: FontWeight.w700,
      letterSpacing: 3 * scale,
      fontFamily: GoogleFonts.rajdhani().fontFamily,
    ),
  );
  tp.layout();
  tp.paint(canvas, Offset(W - tp.width - 60 * scale, (headerH - tp.height) / 2));

  // Wood rails
  final railW = 30.0 * scale;
  canvas.drawRect(
    Rect.fromLTWH(0, headerH, railW, keyboardH),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, headerH), Offset(railW, headerH),
        [const Color(0xFF7A3F1E), const Color(0xFF2A1200)],
      ),
  );
  canvas.drawRect(
    Rect.fromLTWH(W - railW, headerH, railW, keyboardH),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(W - railW, headerH), Offset(W, headerH),
        [const Color(0xFF2A1200), const Color(0xFF7A3F1E)],
      ),
  );

  // Keyboard
  final kbX       = railW;
  final kbW       = W - railW * 2;
  final whiteCount = whites.length;
  final whiteW    = kbW / whiteCount;
  final blackW    = whiteW * 0.58;
  final blackH    = keyboardH * 0.60;
  const blackMap  = {'C': 'C#', 'D': 'D#', 'F': 'F#', 'G': 'G#', 'A': 'A#'};

  // White keys
  for (int i = 0; i < whiteCount; i++) {
    final note    = whites[i];
    final pressed = pressedNotes.contains(note);
    final x       = kbX + i * whiteW;
    final rrect   = RRect.fromRectAndCorners(
      Rect.fromLTWH(x + 1, headerH, whiteW - 2, keyboardH - 2),
      bottomLeft: Radius.circular(8 * scale),
      bottomRight: Radius.circular(8 * scale),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = pressed
            ? ui.Gradient.linear(Offset(x, headerH), Offset(x, headerH + keyboardH),
                [const Color(0xFFFFD980), const Color(0xFFD4A84B), const Color(0xFFB88A2E)],
                [0.0, 0.55, 1.0])
            : ui.Gradient.linear(Offset(x, headerH), Offset(x, headerH + keyboardH),
                [Colors.white, const Color(0xFFF8F3EA), const Color(0xFFDDD5C4)],
                [0.0, 0.7, 1.0]),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = pressed ? const Color(0xFF8C6A2A) : const Color(0xFFB0A090)
        ..strokeWidth = pressed ? 2.0 * scale : 1.0 * scale
        ..style = PaintingStyle.stroke,
    );
    if (pressed) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFFD4A84B).withValues(alpha: 0.4)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * scale),
      );
    }

    final letter = note.replaceAll(RegExp(r'\d'), '');
    if (letter == 'C') {
      tp.text = TextSpan(
        text: note,
        style: TextStyle(
          color: note == 'C4'
              ? const Color(0xFFE8543A)
              : (pressed ? const Color(0xFF6A4400) : const Color(0xFFAA9980)),
          fontSize: 18 * scale,
          fontWeight: FontWeight.w700,
          fontFamily: GoogleFonts.rajdhani().fontFamily,
        ),
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(x + (whiteW - tp.width) / 2, headerH + keyboardH - tp.height - 12 * scale),
      );
    }
  }

  // Black keys
  for (int i = 0; i < whiteCount; i++) {
    final w      = whites[i];
    final letter = w.replaceAll(RegExp(r'\d'), '');
    final oct    = w.replaceAll(RegExp(r'[^\d]'), '');
    if (!blackMap.containsKey(letter)) continue;
    final bn = blackMap[letter]! + oct;
    if (!allNotes.contains(bn)) continue;

    final pressed = pressedNotes.contains(bn);
    final x       = kbX + (i + 1) * whiteW - blackW / 2;
    final bRect   = RRect.fromRectAndCorners(
      Rect.fromLTWH(x, headerH, blackW, blackH),
      bottomLeft: Radius.circular(6 * scale),
      bottomRight: Radius.circular(6 * scale),
    );

    canvas.drawRRect(
      bRect,
      Paint()
        ..shader = pressed
            ? ui.Gradient.linear(Offset(x, headerH), Offset(x, headerH + blackH),
                [const Color(0xFFD4A84B), const Color(0xFF7A5500)])
            : ui.Gradient.linear(Offset(x, headerH), Offset(x, headerH + blackH),
                [const Color(0xFF333333), const Color(0xFF1A1A1A)]),
    );
    if (pressed) {
      canvas.drawRRect(
        bRect,
        Paint()
          ..color = const Color(0xFFD4A84B).withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 * scale),
      );
    }
    // Shine strip
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x + 4 * scale, headerH + 4 * scale, blackW - 8 * scale, blackH * 0.2),
        topLeft: Radius.circular(2 * scale),
        topRight: Radius.circular(2 * scale),
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, headerH), Offset(x, headerH + blackH * 0.2),
          [Colors.white.withValues(alpha: pressed ? 0.0 : 0.12), Colors.transparent],
        ),
    );
  }

  // Footer bar
  canvas.drawRect(
    Rect.fromLTWH(0, H - footerH, W, footerH),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, H - footerH), Offset(0, H),
        [const Color(0xFF140A00), const Color(0xFF060300)],
      ),
  );
  canvas.drawLine(
    Offset(0, H - footerH), Offset(W, H - footerH),
    Paint()..color = const Color(0xFF5C3D1E)..strokeWidth = 2 * scale,
  );
  tp.text = TextSpan(
    text: 'GRAND PIANO  •  STUDIO RECORDING  •  88 Keys',
    style: TextStyle(
      color: const Color(0xFF8C6A2A),
      fontSize: 22 * scale,
      fontWeight: FontWeight.w600,
      letterSpacing: 2 * scale,
      fontFamily: GoogleFonts.rajdhani().fontFamily,
    ),
  );
  tp.layout();
  tp.paint(canvas, Offset((W - tp.width) / 2, H - footerH + (footerH - tp.height) / 2));

  // Render to PNG
  final picture  = recorder.endRecording();
  final img      = await picture.toImage(W.toInt(), H.toInt());
  final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();

  final file = File('$tempPath/frame_${frameIndex.toString().padLeft(5, '0')}.png');
  await file.writeAsBytes(pngBytes!.buffer.asUint8List());
  return file;
}
