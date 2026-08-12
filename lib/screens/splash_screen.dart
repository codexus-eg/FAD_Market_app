import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();

    Timer(const Duration(milliseconds: 3400), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, animation, __) {
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: slideAnimation,
                child: const HomeScreen(),
              ),
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double easeOut(double value) {
    return Curves.easeOutCubic.transform(value.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = screenWidth > 600 ? 280.0 : 230.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;

          final logoOpacity = easeOut(progress / 0.55);
          final logoScale = 0.65 + (easeOut(progress / 0.65) * 0.35);

          final textOpacity = easeOut((progress - 0.45) / 0.35);
          final textMove = 20 * (1 - textOpacity);

          final laserProgress = ((progress - 0.35) / 0.45).clamp(0.0, 1.0);
          final laserX = -logoSize + (laserProgress * logoSize * 2.2);

          final glowValue = math.sin(progress * math.pi);
          final glowOpacity = (0.18 + glowValue * 0.18).clamp(0.0, 0.36);

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: BackgroundLinesPainter(progress: progress),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: logoSize + 20,
                          height: logoSize + 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: goldColor.withOpacity(glowOpacity),
                                blurRadius: 55,
                                spreadRadius: 7,
                              ),
                            ],
                          ),
                        ),
                        Opacity(
                          opacity: logoOpacity,
                          child: Transform.scale(
                            scale: logoScale,
                            child: Container(
                              width: logoSize,
                              height: logoSize,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: goldColor.withOpacity(0.16),
                                  width: 1.4,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/fce_logo.jpeg',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (laserProgress > 0 && laserProgress < 1)
                          Positioned(
                            left: laserX,
                            child: Transform.rotate(
                              angle: -0.18,
                              child: Container(
                                width: 38,
                                height: logoSize + 20,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      goldColor.withOpacity(0.0),
                                      goldColor.withOpacity(0.95),
                                      Colors.white.withOpacity(0.95),
                                      goldColor.withOpacity(0.95),
                                      goldColor.withOpacity(0.0),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: goldColor.withOpacity(0.45),
                                      blurRadius: 25,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Opacity(
                      opacity: textOpacity,
                      child: Transform.translate(
                        offset: Offset(0, textMove),
                        child: const Column(
                          children: [
                            Text(
                              'FAD CNC COMPANY',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: darkColor,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Machines • Spare Parts • Maintenance',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: goldColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 30),
                            SizedBox(
                              width: 130,
                              height: 4,
                              child: LinearProgressIndicator(
                                color: goldColor,
                                backgroundColor: Color(0x33D4A02A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 18,
                child: Opacity(
                  opacity: 0.72,
                  child: Text(
                    'تطوير eivo.ai 2026 -971557685561',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: darkColor.withOpacity(0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class BackgroundLinesPainter extends CustomPainter {
  final double progress;

  BackgroundLinesPainter({required this.progress});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color greyColor = Color(0xFF8B8B8B);

  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..color = goldColor.withOpacity(0.07)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final greyPaint = Paint()
      ..color = greyColor.withOpacity(0.06)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 8; i++) {
      final y = size.height * (0.18 + i * 0.09);
      final path = Path();

      path.moveTo(0, y);

      for (double x = 0; x <= size.width; x += 8) {
        final wave = math.sin(
          (x / size.width * math.pi * 2) + progress * math.pi * 2 + i,
        );
        path.lineTo(x, y + wave * 8);
      }

      canvas.drawPath(path, i.isEven ? goldPaint : greyPaint);
    }

    final bottomPaint = Paint()
      ..color = goldColor.withOpacity(0.09)
      ..style = PaintingStyle.fill;

    final bottomPath = Path();
    bottomPath.moveTo(0, size.height * 0.82);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.82 +
          math.sin((x / size.width * math.pi * 2) + progress * math.pi * 2) *
              18;
      bottomPath.lineTo(x, y);
    }

    bottomPath.lineTo(size.width, size.height);
    bottomPath.lineTo(0, size.height);
    bottomPath.close();

    canvas.drawPath(bottomPath, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant BackgroundLinesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
