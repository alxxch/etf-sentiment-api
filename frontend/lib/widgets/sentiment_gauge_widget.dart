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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: _getScoreColor(clampedScore.toDouble()).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  _getScoreLabel(clampedScore),
                  style: TextStyle(
                    color: _getScoreColor(clampedScore.toDouble()),
                    fontSize: 11.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24.0),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: clampedScore.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final activeColor = _getScoreColor(value);
              return SizedBox(
                height: 180.0,
                width: 220.0,
                child: CustomPaint(
                  painter: _GaugePainter(
                    score: value,
                    activeColor: activeColor,
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
                            fontSize: 48.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
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
          const SizedBox(height: 10.0),
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

    // Track de fondo
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

    // Arco activo
    final progressSweep = (score / 100.0) * sweepAngle;
    if (progressSweep > 0) {
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
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.activeColor != activeColor;
  }
}
