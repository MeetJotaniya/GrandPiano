import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'src/theme.dart';
import 'src/models.dart';
import 'src/audio_service.dart';
import 'src/export_service.dart';
import 'src/widgets/piano_key.dart';
import 'src/widgets/header.dart';
import 'src/widgets/export_sheet.dart';

// ─── Backwards-compatible alias so main.dart / other callers don't need edits ─
// ignore: library_private_types_in_public_api
export 'src/theme.dart';
export 'src/models.dart';

// ─── Page ────────────────────────────────────────────────────────────────────
class PianoPage extends StatefulWidget {
  const PianoPage({super.key});
  @override
  State<PianoPage> createState() => _PianoPageState();
}

class _PianoPageState extends State<PianoPage> with TickerProviderStateMixin {
  // ── Note list (full 88-key range) ──────────────────────────────────────────
  List<String> _notes = [];
  final Set<String> _pressedNotes = {};
  final Map<int, String> _activePointers = {};

  // ── Recording / playback ──────────────────────────────────────────────────
  bool _isRecording = false;
  final List<RecordedNote> _recordedNotes = [];
  DateTime? _recordingStart;
  Timer? _playbackTimer;
  int _playbackIndex = 0;
  bool _isPlaying = false;
  bool _isExporting = false;
  String _exportStage = '';

  // ── Animations ───────────────────────────────────────────────────────────
  final Map<String, AnimationController> _animations = {};

  // ── Audio service ────────────────────────────────────────────────────────
  final _audio = AudioService();

  // ── Display ──────────────────────────────────────────────────────────────
  String? _lastNote;
  Timer? _lastNoteTimer;
  Timer? _preloadTimer;

  // ── Horizontal scroll ────────────────────────────────────────────────────
  final ScrollController _hScroll = ScrollController();
  double _scrollRatio = 0.0;

  static const _startNote = 'A0';
  static const _endNote   = 'C8';

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _buildNoteList();
    _initAudio();
    _hScroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMiddleC());
  }

  @override
  void dispose() {
    for (final c in _animations.values) { c.dispose(); }
    _audio.dispose();
    _playbackTimer?.cancel();
    _lastNoteTimer?.cancel();
    _preloadTimer?.cancel();
    _hScroll.dispose();
    super.dispose();
  }

  // ── Audio ─────────────────────────────────────────────────────────────────
  Future<void> _initAudio() async {
    final ok = await _audio.init();
    if (mounted) setState(() {});
    if (!ok) debugPrint('Audio init failed');
  }

  List<String> _getVisibleNotes() {
    if (!_hScroll.hasClients) {
      return [
        'G3','G#3','A3','A#3','B3',
        'C4','C#4','D4','D#4','E4','F4','F#4','G4','G#4','A4','A#4','B4',
        'C5','C#5','D5','D#5','E5','F5','F#5',
      ];
    }
    final whites = _notes.where((n) => !isBlackKey(n)).toList();
    const margin = 1.5;
    final whiteW  = whiteKeyWidth(MediaQuery.of(context).size.width);
    final offset   = _hScroll.offset;
    final viewport = _hScroll.position.viewportDimension;
    final startIdx = (offset / (whiteW + margin)).floor().clamp(0, whites.length - 1);
    final endIdx   = ((offset + viewport) / (whiteW + margin)).ceil().clamp(0, whites.length - 1);

    final visibles = <String>[];
    for (final w in whites.sublist(startIdx, endIdx + 1)) {
      visibles.add(w);
      final letter = w.replaceAll(RegExp(r'\d'), '');
      final oct    = w.replaceAll(RegExp(r'[^\d]'), '');
      if (kBlackKeyMap.containsKey(letter)) {
        final bn = kBlackKeyMap[letter]! + oct;
        if (_notes.contains(bn)) visibles.add(bn);
      }
    }
    return visibles;
  }

  Future<void> _preloadVisibleNotes() async {
    await _audio.preloadNotes(_getVisibleNotes());
  }

  void _onScroll() {
    if (_hScroll.hasClients) {
      final max = _hScroll.position.maxScrollExtent;
      if (max > 0) {
        final ratio = (_hScroll.offset / max).clamp(0.0, 1.0);
        if ((ratio - _scrollRatio).abs() > 0.005) {
          setState(() => _scrollRatio = ratio);
          _preloadTimer?.cancel();
          _preloadTimer = Timer(const Duration(milliseconds: 150), _preloadVisibleNotes);
        }
      }
    }
  }

  // ── Note list builder ─────────────────────────────────────────────────────
  void _buildNoteList() {
    final full = generateNoteRange(_startNote, _endNote);
    final notes = buildInterleavedNoteList(full);
    for (final c in _animations.values) { c.dispose(); }
    _animations.clear();
    for (final n in notes) {
      _animations[n] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 70),
        lowerBound: 0, upperBound: 1,
      );
    }
    setState(() => _notes = notes);
  }

  void _scrollToMiddleC() {
    if (!_hScroll.hasClients || !mounted) return;
    final whites = _notes.where((n) => !isBlackKey(n)).toList();
    final idx    = whites.indexOf('C4');
    if (idx == -1) return;
    const margin = 1.5;
    final whiteW   = whiteKeyWidth(MediaQuery.of(context).size.width);
    final viewport = _hScroll.position.viewportDimension;
    final target   = idx * (whiteW + margin) - viewport / 2 + whiteW / 2;
    _hScroll.jumpTo(target.clamp(0.0, _hScroll.position.maxScrollExtent));
    _preloadVisibleNotes();
  }

  // ── Hit-test ──────────────────────────────────────────────────────────────
  String? _noteAtPosition(
    Offset local, List<String> whites,
    double whiteW, double margin,
    double blackW, double blackH,
  ) {
    final x = local.dx;
    final y = local.dy - 6;
    if (x < 0 || y < 0) return null;

    for (int i = 0; i < whites.length; i++) {
      final w      = whites[i];
      final letter = w.replaceAll(RegExp(r'\d'), '');
      final oct    = w.replaceAll(RegExp(r'[^\d]'), '');
      if (!kBlackKeyMap.containsKey(letter)) continue;
      final bn = kBlackKeyMap[letter]! + oct;
      if (!_animations.containsKey(bn)) continue;
      final left = (i + 1) * (whiteW + margin) - (blackW / 2) - margin / 2;
      if (x >= left && x < left + blackW && y >= 0 && y < blackH) return bn;
    }
    for (int i = 0; i < whites.length; i++) {
      final left = i * (whiteW + margin);
      if (x >= left && x < left + whiteW) return whites[i];
    }
    return null;
  }

  // ── Input ─────────────────────────────────────────────────────────────────
  void _onDown(String note) {
    if (_pressedNotes.contains(note)) return;
    setState(() { _pressedNotes.add(note); _lastNote = note; });
    _animations[note]?.forward();
    _audio.play(note);
    _lastNoteTimer?.cancel();
    _lastNoteTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _lastNote = null);
    });
    if (_isRecording && _recordingStart != null) {
      _recordedNotes.add(RecordedNote(
        note: note,
        time: DateTime.now().difference(_recordingStart!).inMilliseconds,
      ));
    }
  }

  void _onUp(String note) {
    if (!_pressedNotes.contains(note)) return;
    setState(() => _pressedNotes.remove(note));
    _animations[note]?.reverse();
  }

  // ── Recording ─────────────────────────────────────────────────────────────
  void _toggleRec() {
    if (_isRecording) {
      setState(() { _isRecording = false; _recordingStart = null; });
    } else {
      setState(() { _recordedNotes.clear(); _isRecording = true; _recordingStart = DateTime.now(); });
    }
  }

  void _playback() {
    if (_recordedNotes.isEmpty || _isPlaying) return;
    _playbackIndex = 0;
    setState(() { _pressedNotes.clear(); _isPlaying = true; });
    final start = DateTime.now();
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 10), (t) {
      if (_playbackIndex >= _recordedNotes.length) {
        t.cancel();
        if (mounted) setState(() { _pressedNotes.clear(); _isPlaying = false; });
        return;
      }
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      while (_playbackIndex < _recordedNotes.length &&
          _recordedNotes[_playbackIndex].time <= elapsed) {
        final n = _recordedNotes[_playbackIndex].note;
        _onDown(n);
        Future.delayed(const Duration(milliseconds: 220), () => _onUp(n));
        _playbackIndex++;
      }
    });
  }

  // ── Export ────────────────────────────────────────────────────────────────
  Future<void> _handleSave() async {
    if (_recordedNotes.isEmpty || _isExporting || _isRecording || _isPlaying) return;

    final format = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ExportFormatSheet(),
    );
    if (format == null) return;
    final isVideo = format.startsWith('video');

    void setStage(String stage) {
      if (mounted) setState(() { _isExporting = true; _exportStage = stage; });
    }

    setStage('Preparing…');
    try {
      final path = await renderRecordingToFile(
        format: format,
        recordedNotes: List.unmodifiable(_recordedNotes),
        allNotes: List.unmodifiable(_notes),
        onStage: setStage,
      );
      if (!mounted) return;

      if (path != null) {
        setStage('Sharing…');
        String? displayMsg;
        try {
          if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
            final dir = await getDownloadsDirectory();
            if (dir != null) {
              final dest = File('${dir.path}/${path.split('/').last}');
              await File(path).copy(dest.path);
              displayMsg = 'Saved to Downloads';
            }
          }
        } catch (e) { debugPrint('Copy to downloads failed: $e'); }

        await Share.shareXFiles(
          [XFile(path, name: path.split('/').last)],
          text: isVideo ? 'My piano video recording' : 'My piano audio recording',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(displayMsg ?? 'Recording ready — choose where to save it.'),
            duration: const Duration(seconds: 5),
          ));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't export the recording. Please try again."),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't export the recording. Please try again."),
        ));
      }
    } finally {
      if (mounted) setState(() { _isExporting = false; _exportStage = ''; });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    if (_notes.isEmpty) {
      return const Scaffold(
        backgroundColor: PianoTheme.bg,
        body: Center(child: CircularProgressIndicator(color: PianoTheme.gold)),
      );
    }

    final whiteKeyCount = _notes.where((n) => !isBlackKey(n)).length;

    return PopScope(
      canPop: _recordedNotes.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: PianoTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: PianoTheme.border, width: 1.5),
            ),
            title: Row(
              children: [
                PhosphorIcon(PhosphorIconsBold.warning, color: PianoTheme.gold, size: 20),
                const SizedBox(width: 8),
                Text('Unsaved Recording', style: PianoTheme.dialogTitle(ctx)),
              ],
            ),
            content: Text(
              'You have an unsaved recording. Exit anyway?',
              style: PianoTheme.dialogBody(ctx),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: TextButton.styleFrom(
                  foregroundColor: PianoTheme.goldDim,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: PianoTheme.goldDim.withValues(alpha: 0.4)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: PianoTheme.recRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: PianoTheme.recRed.withValues(alpha: 0.4)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        if ((shouldPop ?? false) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: PianoTheme.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              PianoHeader(
                isRecording: _isRecording,
                isPlaying: _isPlaying,
                isExporting: _isExporting,
                exportStage: _exportStage,
                soundEnabled: _audio.soundEnabled,
                lastNote: _lastNote,
                keyCount: _notes.length,
                whiteKeyCount: whiteKeyCount,
                hasNotes: _recordedNotes.isNotEmpty,
                onToggleSound: () => setState(() => _audio.soundEnabled = !_audio.soundEnabled),
                onRecord: _toggleRec,
                onPlay: _playback,
                onClear: () => setState(() => _recordedNotes.clear()),
                onSave: _handleSave,
              ),
              _buildScrollSlider(),
              Expanded(child: _buildKeyboard()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mini-navigator strip ──────────────────────────────────────────────────
  Widget _buildScrollSlider() {
    return LayoutBuilder(builder: (ctx, cst) {
      final h      = MediaQuery.of(ctx).size.height;
      final w      = MediaQuery.of(ctx).size.width;
      final barH   = (h * 0.10).clamp(40.0, 62.0);
      final labelFz = (math.min(w, h) * 0.025).clamp(8.0, 12.0);
      final whites = _notes.where((n) => !isBlackKey(n)).toList();
      final blacks = _notes.where((n) =>  isBlackKey(n)).toSet();
      final count  = whites.length;
      if (count == 0) return const SizedBox.shrink();

      final labelW = math.max(28.0, w * 0.06);

      return GestureDetector(
        onHorizontalDragUpdate: (d) {
          final usableW = cst.maxWidth - labelW * 2;
          final newRatio = (_scrollRatio + d.delta.dx / usableW).clamp(0.0, 1.0);
          setState(() => _scrollRatio = newRatio);
          if (_hScroll.hasClients) {
            _hScroll.jumpTo(newRatio * _hScroll.position.maxScrollExtent);
          }
        },
        onTapDown: (d) {
          final usableW = cst.maxWidth - labelW * 2;
          final newRatio = ((d.localPosition.dx - labelW) / usableW).clamp(0.0, 1.0);
          setState(() => _scrollRatio = newRatio);
          if (_hScroll.hasClients) {
            _hScroll.jumpTo(newRatio * _hScroll.position.maxScrollExtent);
          }
        },
        child: Container(
          height: barH,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF0F0800), PianoTheme.surface],
            ),
            border: Border(
              top:    BorderSide(color: PianoTheme.border, width: 0.5),
              bottom: BorderSide(color: PianoTheme.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: labelW,
                child: Center(child: Text('BASS',
                  style: GoogleFonts.rajdhani(
                    color: PianoTheme.goldDim, fontSize: labelFz,
                    fontWeight: FontWeight.w700, letterSpacing: 1.0,
                  ),
                )),
              ),
              Expanded(
                child: LayoutBuilder(builder: (_, innerCst) {
                  final kbW       = innerCst.maxWidth;
                  final miniKeyH  = barH - 8;
                  final keyW      = kbW / count;
                  final blackKeyH = miniKeyH * 0.58;
                  final blackKeyW = (keyW * 0.65).clamp(1.0, kbW);

                  const windowFrac = 0.22;
                  final windowW = kbW * windowFrac;
                  final windowX = (_scrollRatio * kbW * (1 - windowFrac))
                      .clamp(0.0, kbW - windowW);

                  return ClipRect(
                    child: SizedBox(
                      width: kbW, height: miniKeyH,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Row(
                            children: List.generate(count, (i) {
                              final note    = whites[i];
                              final pressed = _pressedNotes.contains(note);
                              return Flexible(
                                flex: 1,
                                fit: FlexFit.tight,
                                child: Container(
                                  height: miniKeyH,
                                  margin: EdgeInsets.only(right: i < count - 1 ? 0.5 : 0),
                                  decoration: BoxDecoration(
                                    color: pressed ? PianoTheme.goldGlow : PianoTheme.keyIvory,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(2),
                                      bottomRight: Radius.circular(2),
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFFB0A090), width: 0.3,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          ...List.generate(count, (i) {
                            final wn     = whites[i];
                            final letter = wn.replaceAll(RegExp(r'\d'), '');
                            final oct    = wn.replaceAll(RegExp(r'[^\d]'), '');
                            if (!kBlackKeyMap.containsKey(letter)) return const SizedBox.shrink();
                            final bn = kBlackKeyMap[letter]! + oct;
                            if (!blacks.contains(bn)) return const SizedBox.shrink();
                            final pressed = _pressedNotes.contains(bn);
                            final left    = ((i + 1) * keyW - blackKeyW / 2)
                                .clamp(0.0, kbW - blackKeyW);
                            return Positioned(
                              left: left, top: 0,
                              width: blackKeyW, height: blackKeyH,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: pressed ? PianoTheme.gold : PianoTheme.keyEbony,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(2),
                                    bottomRight: Radius.circular(2),
                                  ),
                                ),
                              ),
                            );
                          }),
                          Positioned(
                            left: windowX, top: 0,
                            width: windowW, height: miniKeyH,
                            child: Container(
                              decoration: BoxDecoration(
                                color: PianoTheme.gold.withValues(alpha: 0.18),
                                border: Border.all(
                                  color: PianoTheme.gold.withValues(alpha: 0.7), width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(
                width: labelW,
                child: Center(child: Text('TREBLE',
                  style: GoogleFonts.rajdhani(
                    color: PianoTheme.goldDim, fontSize: labelFz,
                    fontWeight: FontWeight.w700, letterSpacing: 1.0,
                  ),
                )),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ── Keyboard ──────────────────────────────────────────────────────────────
  Widget _buildKeyboard() {
    final whites = _notes.where((n) => !isBlackKey(n)).toList();
    final count  = whites.length;

    return LayoutBuilder(builder: (ctx, constraints) {
      final totalH  = constraints.maxHeight > 0 ? constraints.maxHeight : 260.0;
      final screenW = MediaQuery.of(ctx).size.width;
      const margin  = 1.5;
      final whiteW  = whiteKeyWidth(screenW);
      final frameW  = math.max(8.0, screenW * 0.018);
      final whiteH  = totalH - 4;
      final blackW  = whiteW * 0.62;
      final blackH  = whiteH * 0.62;
      final totalW  = whiteW * count + margin * (count - 1);

      Offset toContent(Offset local) => Offset(
        local.dx - frameW + (_hScroll.hasClients ? _hScroll.offset : 0.0),
        local.dy,
      );

      return Listener(
        onPointerDown: (e) {
          final note = _noteAtPosition(
            toContent(e.localPosition), whites, whiteW, margin, blackW, blackH,
          );
          if (note != null) { _activePointers[e.pointer] = note; _onDown(note); }
        },
        onPointerMove: (e) {
          final newNote  = _noteAtPosition(
            toContent(e.localPosition), whites, whiteW, margin, blackW, blackH,
          );
          final prevNote = _activePointers[e.pointer];
          if (newNote != prevNote) {
            if (prevNote != null) _onUp(prevNote);
            if (newNote != null) {
              _activePointers[e.pointer] = newNote;
              _onDown(newNote);
            } else {
              _activePointers.remove(e.pointer);
            }
          }
        },
        onPointerUp:     (e) { final n = _activePointers.remove(e.pointer); if (n != null) _onUp(n); },
        onPointerCancel: (e) { final n = _activePointers.remove(e.pointer); if (n != null) _onUp(n); },
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.6),
              radius: 1.6,
              colors: [Color(0xFF1E0D00), PianoTheme.bg],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WoodRail(width: frameW, isLeft: true),
              Expanded(
                child: SingleChildScrollView(
                  controller: _hScroll,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: totalW,
                    height: totalH,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 6, left: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(count, (i) {
                              final note = whites[i];
                              return _buildWhiteKey(
                                note, whiteW, whiteH, margin, i == count - 1,
                              );
                            }),
                          ),
                        ),
                        ..._buildBlackKeys(whites, whiteW, margin, blackW, blackH),
                      ],
                    ),
                  ),
                ),
              ),
              WoodRail(width: frameW, isLeft: false),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildWhiteKey(String note, double w, double h, double margin, bool isLast) {
    final anim      = _animations[note]!;
    final pressed   = _pressedNotes.contains(note);
    final letter    = note.replaceAll(RegExp(r'\d'), '');
    final isC       = letter == 'C';
    final isMiddleC = note == 'C4';

    final dotSz     = (w * 0.16).clamp(4.0, 9.0);
    final labelFz   = (w * 0.26).clamp(6.5, 13.0);
    final bottomPad = (h * 0.03).clamp(6.0, 14.0);

    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Container(
        width: w, height: h,
        margin: EdgeInsets.only(right: isLast ? 0 : margin),
        decoration: BoxDecoration(
          gradient: pressed
              ? const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [PianoTheme.goldGlow, PianoTheme.gold, Color(0xFFB88A2E)],
                  stops: [0.0, 0.55, 1.0],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.white, PianoTheme.keyIvory, PianoTheme.keyShade],
                  stops: [0.0, 0.7, 1.0],
                ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(5),
          ),
          border: Border.all(
            color: pressed ? PianoTheme.goldDim : const Color(0xFFB0A090),
            width: pressed ? 1.5 : 0.8,
          ),
          boxShadow: pressed
              ? [
                  BoxShadow(color: PianoTheme.gold.withValues(alpha: 0.55), blurRadius: 18, spreadRadius: 2),
                  const BoxShadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 2)),
                ]
              : [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 5, offset: const Offset(0, 3)),
                ],
        ),
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pressed)
                GlowDot(color: PianoTheme.gold, size: dotSz)
              else if (isMiddleC)
                GlowDot(color: PianoTheme.middleC, size: dotSz * 0.85, glow: false)
              else if (isC)
                GlowDot(color: const Color(0xFFCCB89A), size: dotSz * 0.72, glow: false),
              SizedBox(height: dotSz * 0.5),
              if (isC)
                Text(note,
                  style: GoogleFonts.rajdhani(
                    color: pressed
                        ? const Color(0xFF6A4400)
                        : (isMiddleC ? PianoTheme.middleC : const Color(0xFFAA9980)),
                    fontSize: labelFz,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBlackKeys(
    List<String> whites, double whiteW, double margin,
    double blackW, double blackH,
  ) {
    final result = <Widget>[];
    for (int i = 0; i < whites.length; i++) {
      final w      = whites[i];
      final letter = w.replaceAll(RegExp(r'\d'), '');
      final oct    = w.replaceAll(RegExp(r'[^\d]'), '');
      if (!kBlackKeyMap.containsKey(letter)) continue;
      final bn = kBlackKeyMap[letter]! + oct;
      if (!_animations.containsKey(bn)) continue;

      final anim    = _animations[bn]!;
      final pressed = _pressedNotes.contains(bn);
      final left    = (i + 1) * (whiteW + margin) - (blackW / 2) - margin / 2;

      result.add(Positioned(
        top: 6, left: left,
        width: blackW, height: blackH,
        child: AnimatedBuilder(
          animation: anim,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              gradient: pressed
                  ? const LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [PianoTheme.gold, Color(0xFF7A5500)],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF333333), PianoTheme.keyEbony],
                    ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
              border: Border.all(
                color: pressed ? PianoTheme.goldDim : const Color(0xFF0A0A0A),
                width: 1,
              ),
              boxShadow: pressed
                  ? [BoxShadow(color: PianoTheme.gold.withValues(alpha: 0.65), blurRadius: 16, spreadRadius: 3)]
                  : [
                      const BoxShadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 4)),
                      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 2, offset: const Offset(-1, 0)),
                    ],
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 3, left: 4, right: 4),
                height: blackH * 0.2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: pressed ? 0.0 : 0.14),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ));
    }
    return result;
  }
}
