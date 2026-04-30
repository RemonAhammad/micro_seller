import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/services/tutorial_service.dart';
import '../../settings/providers/settings_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _master;
  late final AnimationController _pulse;
  late final AnimationController _orbit;
  late final AnimationController _shimmer;
  late final AnimationController _wave;
  late final AnimationController _particleCtrl;

  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Master: 2.5s total
    _master = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _orbit = AnimationController(vsync: this, duration: const Duration(milliseconds: 10000))..repeat();
    _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 6000))..repeat();

    _particles = List.generate(35, (_) => _Particle.random(Random(77)));

    _master.forward();
    _master.addStatusListener((s) {
      if (s == AnimationStatus.completed) _navigateNext();
    });
  }

  double _t(double s, double e, [Curve c = Curves.linear]) =>
      Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _master, curve: Interval(s, e, curve: c))).value;

  Future<void> _navigateNext() async {
    await TutorialService.setSplashShown();
    if (!mounted) return;
    GoRouter.of(context).go('/');
  }

  @override
  void dispose() {
    for (final c in [_master, _pulse, _orbit, _shimmer, _wave, _particleCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final w = sz.width;
    final h = sz.height;

    // Responsive sizes — everything relative to screen
    final logoIcon = (w * 0.22).clamp(80.0, 130.0);
    final orbitR1 = w * 0.32;
    final orbitR2 = w * 0.26;
    final orbitDotSize = (w * 0.11).clamp(36.0, 52.0);
    final orbitIconSize = (w * 0.05).clamp(18.0, 26.0);
    final ringMaxSize = w * 0.85;
    final titleSize = (w * 0.1).clamp(36.0, 56.0);
    final subSize = (w * 0.032).clamp(12.0, 16.0);
    final pillIconSize = (w * 0.04).clamp(15.0, 22.0);
    final pillTextSize = (w * 0.03).clamp(11.0, 16.0);
    final pillH = (w * 0.1).clamp(34.0, 48.0);

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_master, _pulse, _orbit, _shimmer, _wave, _particleCtrl]),
        builder: (context, _) {
          // ── Timeline (compressed to 2.5s) ──
          final logoScale = _t(0.0, 0.25, Curves.elasticOut);
          final logoOp = _t(0.0, 0.1);
          final logoRot = _t(0.0, 0.25, Curves.easeOut);
          final ringFade = _t(0.05, 0.35);
          final ring1 = _t(0.05, 0.3, Curves.easeOutBack);
          final ring2 = _t(0.08, 0.33, Curves.easeOutBack);
          final ring3 = _t(0.12, 0.38, Curves.easeOutBack);
          final titleOp = _t(0.25, 0.4);
          final titleSlide = 1.0 - _t(0.25, 0.4, Curves.easeOutCubic);
          final subOp = _t(0.35, 0.48);
          final pillsOp = _t(0.42, 0.6);
          final bottomOp = _t(0.55, 0.65);
          final progress = _t(0.55, 1.0, Curves.easeInOut);

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(const Color(0xFF00897B), const Color(0xFF26A69A), ringFade * 0.3)!,
                  const Color(0xFF00796B),
                  const Color(0xFF00695C),
                  Color.lerp(const Color(0xFF004D40), const Color(0xFF00201A), _pulse.value * 0.08)!,
                ],
              ),
            ),
            child: Stack(
              children: [
                // ── BG: Particles rising ──
                ..._buildParticles(sz, pillsOp),

                // ── BG: Wave at bottom ──
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: h * 0.18,
                  child: Opacity(
                    opacity: subOp * 0.2,
                    child: CustomPaint(
                      painter: _WavePainter(phase: _wave.value, color: Colors.white),
                      size: Size(w, h * 0.18),
                    ),
                  ),
                ),

                // ── BG: Top radial glow ──
                Positioned(
                  top: -h * 0.12,
                  left: w * 0.5 - w * 0.55,
                  child: Opacity(
                    opacity: ringFade * 0.12,
                    child: Container(
                      width: w * 1.1,
                      height: w * 1.1,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                  ),
                ),

                // ── Content ──
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ═══ Logo area ═══
                          SizedBox(
                            width: ringMaxSize,
                            height: ringMaxSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Ring 3 (outermost)
                                _ring(ring3, ringMaxSize, ringFade * 0.05, 0.8),
                                // Ring 2
                                _ring(ring2, ringMaxSize * 0.75, ringFade * 0.08, 1.0),
                                // Ring 1 glow
                                Transform.scale(
                                  scale: ring1 * (1 + _pulse.value * 0.04),
                                  child: Container(
                                    width: ringMaxSize * 0.5,
                                    height: ringMaxSize * 0.5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(colors: [
                                        Colors.white.withValues(alpha: ringFade * 0.14),
                                        Colors.white.withValues(alpha: 0),
                                      ]),
                                    ),
                                  ),
                                ),

                                // ── Orbit icons (8) ──
                                ..._buildOrbit(
                                  ringFade,
                                  ringMaxSize / 2,
                                  orbitR1,
                                  orbitR2,
                                  orbitDotSize,
                                  orbitIconSize,
                                ),

                                // ── Sparkles (20) ──
                                ..._buildSparkles(ringFade, ringMaxSize / 2, ringMaxSize * 0.2),

                                // ── Logo icon ──
                                Opacity(
                                  opacity: logoOp,
                                  child: Transform.scale(
                                    scale: logoScale,
                                    child: Transform.rotate(
                                      angle: (1 - logoRot) * -0.35,
                                      child: Container(
                                        width: logoIcon,
                                        height: logoIcon,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(logoIcon * 0.24),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF004D40).withValues(alpha: 0.5),
                                              blurRadius: 40,
                                              offset: const Offset(0, 14),
                                            ),
                                            BoxShadow(
                                              color: AppColors.accent.withValues(alpha: 0.3),
                                              blurRadius: 60,
                                              spreadRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(logoIcon * 0.24),
                                              child: Image.asset(
                                                'assets/icons/app_icon.png',
                                                width: logoIcon,
                                                height: logoIcon,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            // Shine sweep
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(logoIcon * 0.24),
                                              child: ShaderMask(
                                                shaderCallback: (b) {
                                                  final x = -1 + _shimmer.value * 3;
                                                  return LinearGradient(
                                                    begin: Alignment(x, -1),
                                                    end: Alignment(x + 1, 1),
                                                    colors: [
                                                      Colors.transparent,
                                                      Colors.white.withValues(alpha: 0.2),
                                                      Colors.transparent,
                                                    ],
                                                  ).createShader(b);
                                                },
                                                blendMode: BlendMode.srcATop,
                                                child: SizedBox(width: logoIcon, height: logoIcon),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ═══ Title ═══
                          Transform.translate(
                            offset: Offset(0, titleSlide * 25),
                            child: Opacity(
                              opacity: titleOp,
                              child: ShaderMask(
                                shaderCallback: (b) {
                                  final x = -1 + _shimmer.value * 3;
                                  return LinearGradient(
                                    begin: Alignment(x, 0),
                                    end: Alignment(x + 1.5, 0),
                                    colors: const [
                                      Colors.white,
                                      Color(0xFFB2DFDB),
                                      Colors.white,
                                    ],
                                  ).createShader(b);
                                },
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    // Watch settings so the title updates
                                    // live if the user changes shop name.
                                    ref.watch(settingsProvider);
                                    final name = ref
                                            .read(settingsProvider.notifier)
                                            .shopName;
                                    return Text(
                                      name.isNotEmpty
                                          ? name
                                          : AppStrings.appName,
                                      style: TextStyle(
                                        fontSize: titleSize,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 3,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          // ═══ Subtitle ═══
                          Opacity(
                            opacity: subOp,
                            child: Transform.translate(
                              offset: Offset(0, (1 - subOp) * 12),
                              child: Text(
                                'INVENTORY  ·  ORDERS  ·  REPORTS',
                                style: TextStyle(
                                  fontSize: subSize,
                                  color: Colors.white54,
                                  letterSpacing: 3.5,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: h * 0.025),

                          // ═══ Divider ═══
                          Opacity(
                            opacity: pillsOp,
                            child: Container(
                              width: w * 0.22,
                              height: 2,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1),
                                gradient: LinearGradient(colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.5),
                                  Colors.white.withValues(alpha: 0),
                                ]),
                              ),
                            ),
                          ),

                          SizedBox(height: h * 0.025),

                          // ═══ Feature pills ═══
                          Opacity(
                            opacity: pillsOp,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: w * 0.06),
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: _featureData
                                    .asMap()
                                    .entries
                                    .map((e) => _pill(e.key, e.value, pillH, pillIconSize, pillTextSize))
                                    .toList(),
                              ),
                            ),
                          ),

                          SizedBox(height: h * 0.04),

                          // ═══ Progress ═══
                          Opacity(
                            opacity: bottomOp,
                            child: Column(
                              children: [
                                SizedBox(
                                  width: w * 0.45,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 4,
                                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                                      valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.4)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _dots(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ═══ Version ═══
                Positioned(
                  bottom: 6,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: subOp * 0.4,
                    child: const Text(
                      'v1.0.0  ·  Black Shadow Software',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9, color: Colors.white30, letterSpacing: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Components
  // ═══════════════════════════════════════════════════════════════════════════

  static const _featureData = [
    (icon: Icons.category_rounded, label: 'Categories'),
    (icon: Icons.inventory_2_rounded, label: 'Products'),
    (icon: Icons.receipt_long_rounded, label: 'Orders'),
    (icon: Icons.people_rounded, label: 'Customers'),
    (icon: Icons.local_shipping_rounded, label: 'Suppliers'),
    (icon: Icons.analytics_rounded, label: 'Reports'),
  ];

  Widget _ring(double scale, double size, double op, double bw) {
    return Transform.scale(
      scale: scale * (1 + _pulse.value * 0.025),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: op),
            width: bw,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOrbit(double fade, double center, double r1, double r2, double dotSize, double iconSize) {
    const icons = [
      Icons.shopping_bag_rounded,
      Icons.payments_rounded,
      Icons.local_shipping_rounded,
      Icons.qr_code_scanner_rounded,
      Icons.warehouse_rounded,
      Icons.point_of_sale_rounded,
      Icons.sell_rounded,
      Icons.bar_chart_rounded,
    ];
    return List.generate(icons.length, (i) {
      final a = (2 * pi * i) / icons.length + _orbit.value * 2 * pi;
      final r = i.isEven ? r1 : r2;
      final x = r * cos(a);
      final y = r * sin(a) * 0.88;
      final op = fade.clamp(0.0, 1.0) * (i.isEven ? 0.6 : 0.45);
      final ds = i.isEven ? dotSize : dotSize * 0.85;
      final is2 = i.isEven ? iconSize : iconSize * 0.85;

      return Positioned(
        left: center + x - ds / 2,
        top: center + y - ds / 2,
        child: Opacity(
          opacity: op,
          child: Transform.rotate(
            angle: -a * 0.25,
            child: Container(
              width: ds,
              height: ds,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(color: Colors.white.withValues(alpha: 0.06), blurRadius: 12),
                ],
              ),
              child: Icon(icons[i], size: is2, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildSparkles(double fade, double center, double baseR) {
    final rng = Random(55);
    return List.generate(20, (i) {
      final a = (2 * pi * i) / 20 + _orbit.value * pi * 0.35;
      final r = baseR + rng.nextDouble() * baseR * 0.8;
      final x = r * cos(a);
      final y = r * sin(a);
      final twinkle = sin(_pulse.value * pi * 2 + i * 1.05) * 0.5 + 0.5;
      final s = 3.0 + rng.nextDouble() * 4;

      return Positioned(
        left: center + x - s / 2,
        top: center + y - s / 2,
        child: Opacity(
          opacity: (fade * twinkle * 0.5).clamp(0.0, 1.0),
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: s * 4),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _pill(int i, ({IconData icon, String label}) f, double h, double iconSz, double textSz) {
    final d = i * 0.018;
    final p = _t(0.4 + d, 0.58 + d, Curves.easeOutBack).clamp(0.0, 1.0);
    return Opacity(
      opacity: p,
      child: Transform.scale(
        scale: 0.3 + p * 0.7,
        child: Transform.translate(
          offset: Offset(0, (1 - p) * 15),
          child: Container(
            height: h,
            padding: EdgeInsets.symmetric(horizontal: h * 0.4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(h / 2),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(color: Colors.white.withValues(alpha: 0.03), blurRadius: 12),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(f.icon, size: iconSz, color: Colors.white60),
                SizedBox(width: iconSz * 0.3),
                Text(f.label, style: TextStyle(fontSize: textSz, color: Colors.white60, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final b = sin((_wave.value * 2 * pi) + i * 1.2) * 0.5 + 0.5;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Opacity(
            opacity: 0.3 + b * 0.5,
            child: Transform.translate(
              offset: Offset(0, -b * 7),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.white.withValues(alpha: 0.25), blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  List<Widget> _buildParticles(Size sz, double fade) {
    return _particles.map((p) {
      final t = (_particleCtrl.value + p.offset) % 1.0;
      final y = sz.height * (1.0 - t);
      final x = p.x * sz.width + sin(t * pi * 3 + p.phase) * 35;
      final op = sin(t * pi) * p.alpha * fade;
      return Positioned(
        left: x,
        top: y,
        child: Opacity(
          opacity: op.clamp(0.0, 1.0),
          child: Container(
            width: p.size,
            height: p.size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: p.size * 3),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _Particle {
  final double x, offset, size, alpha, phase;
  const _Particle(
      {required this.x, required this.offset, required this.size, required this.alpha, required this.phase});
  factory _Particle.random(Random r) => _Particle(
        x: r.nextDouble(),
        offset: r.nextDouble(),
        size: 3 + r.nextDouble() * 5,
        alpha: 0.08 + r.nextDouble() * 0.15,
        phase: r.nextDouble() * pi * 2,
      );
}

class _WavePainter extends CustomPainter {
  final double phase;
  final Color color;
  _WavePainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (int w = 0; w < 4; w++) {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.05 - w * 0.008)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      final path = Path();
      for (double x = 0; x <= size.width; x += 2) {
        final y = size.height * 0.5 +
            sin((x / size.width * pi * 2) + phase * pi * 2 + w * 0.7) * (20 + w * 7) +
            cos((x / size.width * pi * 3) + phase * pi * 1.3 + w * 1.1) * (12 + w * 5);
        if (x == 0)
          path.moveTo(x, y);
        else
          path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.phase != phase;
}
