import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NewsListWidget extends StatelessWidget {
  final List<String> news;

  const NewsListWidget({
    super.key,
    required this.news,
  });

  @override
  Widget build(BuildContext context) {
    if (news.isEmpty) return const SizedBox.shrink();

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
          const Row(
            children: [
              Icon(
                Icons.newspaper_rounded,
                color: AppColors.textSecondary,
                size: 16.0,
              ),
              SizedBox(width: 8.0),
              Text(
                'TITULARES RECIENTES (YFINANCE)',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          ...news.asMap().entries.map((entry) {
            final index = entry.key;
            final headline = entry.value;
            final isLast = index == news.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0.0 : 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4.0),
                    width: 5.0,
                    height: 5.0,
                    decoration: const BoxDecoration(
                      color: AppColors.aiAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      headline,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
