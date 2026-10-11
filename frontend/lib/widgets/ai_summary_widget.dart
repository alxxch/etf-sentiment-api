import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AiSummaryWidget extends StatelessWidget {
  final String summary;

  const AiSummaryWidget({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: AppColors.aiAccentSoft,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.aiAccent,
                  size: 18.0,
                ),
              ),
              const SizedBox(width: 12.0),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESUMEN INTELIGENTE (IA)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'Google Gemini Engine',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Text(
            summary.isNotEmpty
                ? summary
                : 'Sin análisis generado para este activo en este momento.',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15.0,
              height: 1.55,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
