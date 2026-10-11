import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SentimentGaugeWidget extends StatelessWidget {
  final int score;

  const SentimentGaugeWidget({
    super.key,
    required this.score,
  });

  Color _getScoreColor(double val) {
    if (val >= 60) return AppColors.bullish;
    if (val <= 40) return AppColors.bearish;
    return AppColors.neutral;
  }

  String _getScoreLabel(int val) {
    if (val >= 65) return 'BULLISH';
    if (val <= 40) return 'BEARISH';
    return 'NEUTRAL';
  }

  @override
  Widget build(BuildContext context) {
    final clampedScore = score.clamp(0, 100);
    final activeColor = _getScoreColor(clampedScore.toDouble());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: AppColors.cardBorder.withValues(alpha: 0.6),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SENTIMIENTO DE MERCADO',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: activeColor.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  _getScoreLabel(clampedScore),
                  style: TextStyle(
                    color: activeColor,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24.0),
          // Animación implícita que llena el medidor radial suavemente al cargar el dato
          TweenAnimationBuilder<double>(
            key: ValueKey(clampedScore),
            tween: Tween<double>(begin: 0.0, end: clampedScore.toDouble()),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final dynamicColor = _getScoreColor(value);

              return SizedBox(
                height: 184.0,
                width: 224.0,
                child: CustomPaint(
                  painter: _GaugePainter(
                    score: value,
                    activeColor: dynamicColor,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 18.0),
                        Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 50.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.8,
                          ),
                        ),
                        const Text(
                          'PUNTOS (0 - 100)',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12.0),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0 Bajista',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '50 Neutral',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '100 Alcista',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color activeColor;

  _GaugePainter({
    required this.score,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final radius = math.min(size.width, size.height) / 2 - 12;

    // Arco de 240 grados (de 150° a 390°)
    const startAngle = 150 * (math.pi / 180);
    const sweepAngle = 240 * (math.pi / 180);

    // Track de fondo con estilo Apple Watch / iOS
    final backgroundPaint = Paint()
      ..color = AppColors.surfaceSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    // Arco activo animado
    final progressSweep = (score / 100.0) * sweepAngle;
    if (progressSweep > 0) {
      // Brillo sutil (Glow)
      final glowPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        progressSweep,
        false,
        glowPaint,
      );

      // Trazo principal nítido
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        progressSweep,
        false,
        activePaint,
      );

      // Puntero / Punto terminal al final del arco
      final currentAngle = startAngle + progressSweep;
      final tipX = center.dx + radius * math.cos(currentAngle);
      final tipY = center.dy + radius * math.sin(currentAngle);

      final tipPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(tipX, tipY), 3.5, tipPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.activeColor != activeColor;
  }
}
