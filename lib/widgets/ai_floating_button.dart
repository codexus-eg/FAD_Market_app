import 'dart:math' as math;

import 'package:flutter/material.dart';

class AiFloatingButton extends StatefulWidget {
  final VoidCallback onTap;
  final List<String> messages;
  final int animationCycleMs;
  final int teaserIntervalMs;

  const AiFloatingButton({
    super.key,
    required this.onTap,
    required this.messages,
    this.animationCycleMs = 2400,
    this.teaserIntervalMs = 2200,
  });

  @override
  State<AiFloatingButton> createState() => _AiFloatingButtonState();
}

class _AiFloatingButtonState extends State<AiFloatingButton>
    with TickerProviderStateMixin {
  static const _frames = <String>[
    'assets/ai_assistant/fce_ai_frame_1.png',
    'assets/ai_assistant/fce_ai_frame_2.png',
    'assets/ai_assistant/fce_ai_frame_3.png',
    'assets/ai_assistant/fce_ai_frame_4.png',
    'assets/ai_assistant/fce_ai_frame_5.png',
    'assets/ai_assistant/fce_ai_frame_6.png',
  ];

  late AnimationController _iconController;
  late AnimationController _messageController;

  @override
  void initState() {
    super.initState();
    _buildControllers();
  }

  void _buildControllers() {
    _iconController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.animationCycleMs.clamp(1400, 6000).toInt()),
    )..repeat();

    final messageCount = widget.messages.isEmpty ? 1 : widget.messages.length;
    _messageController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (widget.teaserIntervalMs.clamp(1200, 8000).toInt() * messageCount),
      ),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant AiFloatingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationCycleMs != widget.animationCycleMs ||
        oldWidget.teaserIntervalMs != widget.teaserIntervalMs ||
        oldWidget.messages.join('|') != widget.messages.join('|')) {
      _iconController.dispose();
      _messageController.dispose();
      _buildControllers();
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages.where((e) => e.trim().isNotEmpty).toList();
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return AnimatedBuilder(
      animation: Listenable.merge([_iconController, _messageController]),
      builder: (context, child) {
        final rawFrame = (_iconController.value * _frames.length).floor();
        final frameIndex = rawFrame.clamp(0, _frames.length - 1).toInt();
        final pulse = 1.0 + math.sin(_iconController.value * math.pi * 2) * .022;
        final floatY = math.sin(_iconController.value * math.pi * 2) * 2.2;

        var messageIndex = 0;
        var messageOpacity = 0.0;
        if (messages.isNotEmpty) {
          final scaled = _messageController.value * messages.length;
          messageIndex = scaled.floor().clamp(0, messages.length - 1).toInt();
          final local = scaled - scaled.floor();
          if (local < .16) {
            messageOpacity = local / .16;
          } else if (local > .82) {
            messageOpacity = (1 - local) / .18;
          } else {
            messageOpacity = 1;
          }
        }

        return SizedBox(
          width: 292,
          height: 116,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: rtl ? Alignment.bottomLeft : Alignment.bottomRight,
            children: [
              if (messages.isNotEmpty)
                Positioned(
                  right: rtl ? 96 : null,
                  left: rtl ? null : 96,
                  bottom: 30,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: messageOpacity.clamp(0, 1).toDouble(),
                      child: Transform.translate(
                        offset: Offset(rtl ? -2 : 2, 0),
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 112,
                            maxWidth: 174,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF07192D).withOpacity(.96),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF16B9FF).withOpacity(.78),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x4416B9FF),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Text(
                            messages[messageIndex],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(0, floatY),
                child: Transform.scale(
                  scale: pulse,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: widget.onTap,
                      child: CustomPaint(
                        foregroundPainter: _AiRingPainter(progress: _iconController.value),
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x5516B9FF),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: Color(0x44FFC928),
                                blurRadius: 20,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 110),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              child: Image.asset(
                                _frames[frameIndex],
                                key: ValueKey<int>(frameIndex),
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _AiRingPainter extends CustomPainter {
  final double progress;

  const _AiRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2.5;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final start = -math.pi / 2 + progress * math.pi * 2;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x55FFD32A);
    canvas.drawArc(rect, start, math.pi * .46, false, glow);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          Color(0x00FFD32A),
          Color(0xFFFFD32A),
          Color(0xFFFFFFFF),
          Color(0xFFFFB800),
          Color(0x00FFD32A),
        ],
        stops: [0, .18, .46, .72, 1],
      ).createShader(rect);
    canvas.drawArc(rect, start, math.pi * .56, false, paint);
  }

  @override
  bool shouldRepaint(covariant _AiRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
