import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'piano.dart';

// ─── Entry point colours (mirror _C so splash has no dependency on private class) ─
const _bg       = Color(0xFF0A0500);
const _goldDim  = Color(0xFF8C6A2A);
const _goldGlow = Color(0xFFFFD980);
const _gold     = Color(0xFFD4A84B);
const _ebony    = Color(0xFF1A1A1A);

// ─────────────────────────────────────────────────────────────────────────────
//  SplashScreen
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── master timeline ──────────────────────────────────────────────────────
  late final AnimationController _master;

  // ── ambient glow ─────────────────────────────────────────────────────────
  late final Animation<double> _ambientOpacity;

  // ── particles ─────────────────────────────────────────────────────────────
  late final Animation<double> _particleProgress;

  // ── piano keys ────────────────────────────────────────────────────────────
  late final Animation<double> _keyReveal;   // staggered reveal
  late final Animation<double> _keyGlow;     // wave sweep 0→1

  // ── wave ──────────────────────────────────────────────────────────────────
  late final Animation<double> _waveSweep;

  // ── logo ──────────────────────────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // ── title ─────────────────────────────────────────────────────────────────
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleSlide;   // 0 → 1  (bottom → centre)
  late final Animation<double> _subtitleOpacity;

  // ── breathing (idle) ──────────────────────────────────────────────────────
  late final AnimationController _breath;

  // ── exit fade ─────────────────────────────────────────────────────────────
  late final AnimationController _exitFade;

  // ── particle data (generated once) ───────────────────────────────────────
  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random(42);

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // 36 particles
    for (int i = 0; i < 36; i++) {
      _particles.add(_Particle(
        x:     _rng.nextDouble(),
        y:     _rng.nextDouble(),
        size:  1.2 + _rng.nextDouble() * 2.4,
        speed: 0.12 + _rng.nextDouble() * 0.22,
        phase: _rng.nextDouble() * math.pi * 2,
        drift: (_rng.nextDouble() - 0.5) * 0.06,
      ));
    }

    // ── master: 3.4 s total ───────────────────────────────────────────────
    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );

    final c = CurvedAnimation(parent: _master, curve: Curves.linear);

    _ambientOpacity  = _interval(c, 0.00, 0.18, Curves.easeOut);
    _particleProgress= _interval(c, 0.09, 1.00, Curves.linear);
    _keyReveal       = _interval(c, 0.18, 0.50, Curves.easeOutCubic);
    _keyGlow         = _interval(c, 0.36, 0.65, Curves.easeInOut);
    _waveSweep       = _interval(c, 0.36, 0.62, Curves.easeInOut);
    _logoScale       = CurvedAnimation(
      parent: _interval(c, 0.53, 0.72, Curves.linear),
      curve: Curves.elasticOut,
    );
    _logoOpacity     = _interval(c, 0.53, 0.68, Curves.easeOut);
    _titleOpacity    = _interval(c, 0.65, 0.82, Curves.easeOut);
    _titleSlide      = _interval(c, 0.65, 0.82, Curves.easeOutCubic);
    _subtitleOpacity = _interval(c, 0.75, 0.90, Curves.easeOut);

    // ── breathing: subtle pulse after master finishes ─────────────────────
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // ── exit fade ─────────────────────────────────────────────────────────
    _exitFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _master.forward().then((_) {
      // small settle pause then fade out
      Future.delayed(const Duration(milliseconds: 300), () async {
        if (!mounted) return;
        await _exitFade.forward();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const PianoPage(),
            transitionDuration: Duration.zero,
          ),
        );
      });
    });
  }

  Animation<double> _interval(
      Animation<double> parent, double begin, double end, Curve curve) {
    return CurvedAnimation(
      parent: parent,
      curve: Interval(begin, end, curve: curve),
    );
  }

  @override
  void dispose() {
    _master.dispose();
    _breath.dispose();
    _exitFade.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    // On landscape phone h is small (~360px). Use shortest side for proportional sizing.
    final shortest = math.min(w, h);
    final longest  = math.max(w, h);

    return AnimatedBuilder(
      animation: Listenable.merge([_master, _breath, _exitFade]),
      builder: (context, _) {
        final exitT = _exitFade.value;

        return Opacity(
          opacity: 1.0 - exitT,
          child: Scaffold(
            backgroundColor: _bg,
            body: Stack(
              children: [
                // ── 1. Deep radial background ──────────────────────────────
                _Background(ambientOpacity: _ambientOpacity.value),

                // ── 2. Floating particles ──────────────────────────────────
                CustomPaint(
                  size: Size(w, h),
                  painter: _ParticlePainter(
                    particles: _particles,
                    progress:  _particleProgress.value,
                    waveSweep: _waveSweep.value,
                    size:      Size(w, h),
                  ),
                ),

                // ── 3. Mini piano keys strip ─────────────────────────────
                // Top offset is 12% of height; height is 16% of height
                // but capped so it doesn't eat too much on short screens
                Positioned(
                  left: 0, right: 0,
                  top: h * 0.10,
                  child: _PianoKeyStrip(
                    reveal:    _keyReveal.value,
                    glow:      _keyGlow.value,
                    waveSweep: _waveSweep.value,
                    width:     w,
                    height:    (h * 0.18).clamp(40.0, 120.0),
                  ),
                ),

                // ── 4. Sound-wave arc ──────────────────────────────────────
                Opacity(
                  opacity: (_waveSweep.value * 2).clamp(0.0, 1.0) *
                      (1 - ((_waveSweep.value - 0.5) * 2).clamp(0.0, 1.0)),
                  child: CustomPaint(
                    size: Size(w, h),
                    painter: _WaveArcPainter(sweep: _waveSweep.value, size: Size(w, h)),
                  ),
                ),

                // ── 5. Logo icon ─────────────────────────────────────────
                // Centre vertically in the lower 60% of screen
                Positioned(
                  left: 0, right: 0,
                  top: h * 0.33,
                  child: Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: 0.6 + _logoScale.value * 0.4,
                      child: _LogoIcon(
                        breath:  _breath.value,
                        sizePct: shortest / longest, // smaller on wider screens
                      ),
                    ),
                  ),
                ),

                // ── 6. App title + subtitle ────────────────────────────────
                Positioned(
                  left: 0, right: 0,
                  bottom: (h * 0.16).clamp(20.0, 80.0),
                  child: _TitleBlock(
                    titleOpacity:    _titleOpacity.value,
                    titleSlide:      _titleSlide.value,
                    subtitleOpacity: _subtitleOpacity.value,
                    breath:          _breath.value,
                  ),
                ),

                // ── 7. Bottom gold line ────────────────────────────────────
                Positioned(
                  bottom: (h * 0.12).clamp(14.0, 60.0),
                  left: w * 0.25 * (1 - _titleOpacity.value),
                  right: w * 0.25 * (1 - _titleOpacity.value),
                  child: Opacity(
                    opacity: _subtitleOpacity.value,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          _gold.withValues(alpha: 0.6),
                          _goldGlow.withValues(alpha: 0.8),
                          _gold.withValues(alpha: 0.6),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Background widget
// ─────────────────────────────────────────────────────────────────────────────
class _Background extends StatelessWidget {
  final double ambientOpacity;
  const _Background({required this.ambientOpacity});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // Base dark background
        Container(
          width: size.width, height: size.height,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.4,
              colors: [Color(0xFF1A0A00), _bg],
            ),
          ),
        ),
        // Ambient gold glow — upper centre
        Opacity(
          opacity: ambientOpacity * 0.55,
          child: Container(
            width: size.width, height: size.height,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.55),
                radius: 0.8,
                colors: [
                  _gold.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Warm lower glow
        Opacity(
          opacity: ambientOpacity * 0.35,
          child: Container(
            width: size.width, height: size.height,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.4, 0.7),
                radius: 0.9,
                colors: [
                  const Color(0xFF3A1800).withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Piano key strip
// ─────────────────────────────────────────────────────────────────────────────
class _PianoKeyStrip extends StatelessWidget {
  final double reveal, glow, waveSweep, width, height;
  const _PianoKeyStrip({
    required this.reveal, required this.glow, required this.waveSweep,
    required this.width,  required this.height,
  });

  @override
  Widget build(BuildContext context) {
    const whiteCount = 14;
    const hasBlack = {0,1,3,4,5,7,8,10,11,12};

    final keyW  = width / whiteCount;
    final keyH  = height;
    final bKeyW = keyW * 0.62;
    final bKeyH = keyH * 0.62;

    // How far along the wave is (0→1 maps left to right across the strip)
    final waveX = waveSweep * width;

    return SizedBox(
      width: width, height: keyH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── White keys ─────────────────────────────────────────────────
          ...List.generate(whiteCount, (i) {
            final progress = ((reveal - i / whiteCount) * whiteCount)
                .clamp(0.0, 1.0);
            final keyX   = i * keyW;
            // Distance from wave centre (0 = at wave, 1 = far)
            final dist   = ((keyX + keyW / 2) - waveX).abs() / (width * 0.3);
            final glowAmt = glow * (1 - dist.clamp(0.0, 1.0));

            return Positioned(
              left: keyX + 1,
              top:  0,
              width: keyW - 2,
              height: keyH * progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(Colors.white, _goldGlow, glowAmt * 0.6)!,
                      Color.lerp(const Color(0xFFF8F3EA), _gold, glowAmt * 0.4)!,
                      Color.lerp(const Color(0xFFDDD5C4), _goldDim, glowAmt * 0.3)!,
                    ],
                    stops: const [0.0, 0.65, 1.0],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft:  Radius.circular(3),
                    bottomRight: Radius.circular(3),
                  ),
                  border: Border.all(
                    color: Color.lerp(
                      const Color(0xFFB0A090), _gold, glowAmt)!,
                    width: 0.8,
                  ),
                  boxShadow: glowAmt > 0.1
                      ? [BoxShadow(
                          color: _gold.withValues(alpha: glowAmt * 0.7),
                          blurRadius: 14,
                          spreadRadius: 1,
                        )]
                      : null,
                ),
              ),
            );
          }),

          // ── Black keys ─────────────────────────────────────────────────
          ...List.generate(whiteCount, (i) {
            if (!hasBlack.contains(i)) return const SizedBox.shrink();
            if (i >= whiteCount - 1) return const SizedBox.shrink();
            final progress = ((reveal - i / whiteCount) * whiteCount)
                .clamp(0.0, 1.0);
            final keyX   = (i + 1) * keyW - bKeyW / 2;
            final dist   = (keyX - waveX).abs() / (width * 0.3);
            final glowAmt = glow * (1 - dist.clamp(0.0, 1.0));

            return Positioned(
              left: keyX, top: 0,
              width: bKeyW,
              height: bKeyH * progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: glowAmt > 0.15
                        ? [_gold.withValues(alpha: 0.85), const Color(0xFF7A5500)]
                        : [const Color(0xFF333333), _ebony],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft:  Radius.circular(3),
                    bottomRight: Radius.circular(3),
                  ),
                  border: Border.all(color: const Color(0xFF0A0A0A), width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: glowAmt > 0.15
                          ? _gold.withValues(alpha: glowAmt * 0.6)
                          : Colors.black.withValues(alpha: 0.6),
                      blurRadius: glowAmt > 0.15 ? 12 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Particle painter
// ─────────────────────────────────────────────────────────────────────────────
class _Particle {
  final double x, y, size, speed, phase, drift;
  const _Particle({
    required this.x, required this.y, required this.size,
    required this.speed, required this.phase, required this.drift,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress, waveSweep;
  final Size size;

  const _ParticlePainter({
    required this.particles, required this.progress,
    required this.waveSweep, required this.size,
  });

  @override
  void paint(Canvas canvas, Size _) {
    for (final p in particles) {
      // Drift upward over time
      final dy = (p.y - progress * p.speed) % 1.0;
      final dx = p.x + math.sin(progress * math.pi * 2 + p.phase) * p.drift;
      final px = dx * size.width;
      final py = dy * size.height;

      // React to wave
      final waveDist = (px - waveSweep * size.width).abs() / size.width;
      final waveReact = (1 - waveDist * 4).clamp(0.0, 1.0);

      final alpha = (0.15 + progress * 0.45 + waveReact * 0.35)
          .clamp(0.0, 0.95);
      final radius = p.size * (1 + waveReact * 1.2);

      // Core dot
      final paint = Paint()
        ..color = Color.lerp(
          _goldDim.withValues(alpha: alpha),
          _goldGlow.withValues(alpha: alpha),
          waveReact,
        )!
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawCircle(Offset(px, py), radius, paint);

      // Sparkle cross on wave-reactive particles
      if (waveReact > 0.5) {
        final sp = Paint()
          ..color = _goldGlow.withValues(alpha: waveReact * 0.6)
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round;
        final arm = radius * 2.5;
        canvas.drawLine(Offset(px - arm, py), Offset(px + arm, py), sp);
        canvas.drawLine(Offset(px, py - arm), Offset(px, py + arm), sp);
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.progress != progress || old.waveSweep != waveSweep;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Wave arc painter
// ─────────────────────────────────────────────────────────────────────────────
class _WaveArcPainter extends CustomPainter {
  final double sweep;
  final Size size;
  const _WaveArcPainter({required this.sweep, required this.size});

  @override
  void paint(Canvas canvas, Size _) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.31;
    final maxR = size.width * 0.72;

    // 3 concentric arcs fading outward
    for (int i = 0; i < 3; i++) {
      final r     = maxR * sweep * (0.55 + i * 0.22);
      final alpha = (0.45 - i * 0.13) * sweep;
      final strokeW = 1.5 - i * 0.4;

      final paint = Paint()
        ..color = _gold.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        math.pi * 1.1,
        math.pi * 0.8,
        false, paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveArcPainter old) => old.sweep != sweep;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Logo icon widget
// ─────────────────────────────────────────────────────────────────────────────
class _LogoIcon extends StatelessWidget {
  final double breath;
  final double sizePct; // 0.0–1.0: shrinks icon on very wide screens
  const _LogoIcon({required this.breath, this.sizePct = 1.0});

  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.of(context).size;
    final shortest = math.min(size.width, size.height);
    // Icon scales with shortest dimension, further clamped so it's never huge
    final iconS = (shortest * 0.22 * (0.7 + sizePct * 0.3)).clamp(40.0, 110.0);
    final glow  = 0.5 + breath * 0.2;

    return Center(
      child: Container(
        width: iconS, height: iconS,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              _goldDim.withValues(alpha: 0.18 * glow),
              Colors.transparent,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: 0.30 * glow),
              blurRadius: iconS * 0.8,
              spreadRadius: iconS * 0.05,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glass ring
            Container(
              width: iconS, height: iconS,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _gold.withValues(alpha: 0.35 * glow),
                  width: 1.5,
                ),
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Inner icon: two small piano keys
            CustomPaint(
              size: Size(iconS * 0.54, iconS * 0.54),
              painter: _PianoIconPainter(glow: glow),
            ),
          ],
        ),
      ),
    );
  }
}

class _PianoIconPainter extends CustomPainter {
  final double glow;
  const _PianoIconPainter({required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final w  = size.width;
    final h  = size.height;
    final kW = w / 5.5;
    final r  = Radius.circular(kW * 0.22);

    // 4 white keys
    for (int i = 0; i < 4; i++) {
      final x = i * (kW + 1.5);
      final rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, 0, kW, h),
        bottomLeft: r, bottomRight: r,
      );
      canvas.drawRRect(rrect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(x, 0), Offset(x, h),
            [
              Color.lerp(Colors.white, _goldGlow, glow * 0.3)!,
              Color.lerp(const Color(0xFFF8F3EA), _gold, glow * 0.2)!,
            ],
          )
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(rrect,
        Paint()
          ..color = _gold.withValues(alpha: 0.25 * glow)
          ..strokeWidth = 0.7
          ..style = PaintingStyle.stroke,
      );
    }

    // 2 black keys
    final bW = kW * 0.65;
    final bH = h * 0.60;
    for (final bi in [0, 2]) {
      final bx = (bi + 1) * (kW + 1.5) - bW / 2;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(bx, 0, bW, bH),
          bottomLeft: r, bottomRight: r,
        ),
        Paint()
          ..color = Color.lerp(_ebony, _gold, glow * 0.25)!,
      );
    }
  }

  @override
  bool shouldRepaint(_PianoIconPainter old) => old.glow != glow;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Title block
// ─────────────────────────────────────────────────────────────────────────────
class _TitleBlock extends StatelessWidget {
  final double titleOpacity, titleSlide, subtitleOpacity, breath;
  const _TitleBlock({
    required this.titleOpacity, required this.titleSlide,
    required this.subtitleOpacity, required this.breath,
  });

  @override
  Widget build(BuildContext context) {
    final w   = MediaQuery.of(context).size.width;
    final h   = MediaQuery.of(context).size.height;
    final shortest = math.min(w, h);
    // Title font: based on shortest side so it doesn't explode on wide screens
    final big = (shortest * 0.085).clamp(18.0, 52.0);
    final breathScale = 1.0 + breath * 0.006;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── "GRAND PIANO" ──────────────────────────────────────────────────
        Transform.translate(
          offset: Offset(0, 18 * (1 - titleSlide)),
          child: Opacity(
            opacity: titleOpacity,
            child: Transform.scale(
              scale: breathScale,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                  colors: [_goldGlow, _gold, _goldDim, _gold],
                  stops: [0.0, 0.35, 0.70, 1.0],
                ).createShader(bounds),
                child: Text(
                  'GRAND PIANO',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rajdhani(
                    fontSize: big,
                    fontWeight: FontWeight.w900,
                    color: Colors.white, // replaced by shader
                    letterSpacing: big * 0.22,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: h * 0.012),

        // ── Subtitle ───────────────────────────────────────────────────────
        Opacity(
          opacity: subtitleOpacity,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - subtitleOpacity)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: w * 0.06, height: 1,
                  color: _goldDim.withValues(alpha: 0.7),
                ),
                SizedBox(width: w * 0.025),
                Text(
                  'Virtual Keyboard',
                  style: GoogleFonts.rajdhani(
                    fontSize: big * 0.36,
                    fontWeight: FontWeight.w500,
                    color: _goldDim,
                    letterSpacing: big * 0.12,
                  ),
                ),
                SizedBox(width: w * 0.025),
                Container(
                  width: w * 0.06, height: 1,
                  color: _goldDim.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
