import 'package:flutter/material.dart';
import '../models/etf_data.dart';
import '../theme/app_colors.dart';

class EtfCardWidget extends StatelessWidget {
  final EtfData data;

  const EtfCardWidget({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = data.isPositive;
    final changeColor = isPositive ? AppColors.bullish : AppColors.bearish;
    final changeBgColor = isPositive ? AppColors.bullishSoft : AppColors.bearishSoft;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.ticker,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    _getSubtitle(data.ticker),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // Badge de variación porcentual estilo Apple Finance
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: changeBgColor,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                      color: changeColor,
                      size: 20.0,
                    ),
                    const SizedBox(width: 2.0),
                    Text(
                      data.formattedChange,
                      style: TextStyle(
                        color: changeColor,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                data.currentPrice.toStringAsFixed(2),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 38.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(width: 6.0),
              Text(
                data.currency,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getSubtitle(String ticker) {
    switch (ticker) {
      case 'VWCE.DE':
        return 'Vanguard FTSE All-World UCITS';
      case 'EUNL.DE':
        return 'iShares Core MSCI World UCITS';
      case '8PSG.DE':
        return 'Invesco Physical Gold ETC';
      default:
        return 'ETF Instrument';
    }
  }
}
