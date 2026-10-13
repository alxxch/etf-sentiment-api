import 'package:flutter/material.dart';
import '../models/etf_data.dart';
import '../theme/app_colors.dart';

class EtfCardWidget extends StatelessWidget {
  final EtfData data;
  final bool isLoading;

  const EtfCardWidget({
    super.key,
    required this.data,
    this.isLoading = false,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.ticker,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 3.0),
                    Text(
                      _getSubtitle(data.ticker),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              // Badge de variación porcentual o indicador de carga
              if (isLoading && data.currentPrice == 0.0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: AppColors.cardBorder.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12.0,
                        height: 12.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.aiAccent),
                        ),
                      ),
                      SizedBox(width: 6.0),
                      Text(
                        'CARGANDO',
                        style: TextStyle(
                          color: AppColors.aiAccent,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: changeBgColor,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: changeColor.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
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
          const SizedBox(height: 22.0),
          if (isLoading && data.currentPrice == 0.0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 22.0,
                    height: 22.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.aiAccent),
                    ),
                  ),
                  SizedBox(width: 10.0),
                  Flexible(
                    child: Text(
                      'Cargando cotización...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // Contador numérico suave con TweenAnimationBuilder
                Flexible(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('${data.ticker}_${data.currentPrice}'),
                    tween: Tween<double>(begin: 0.0, end: data.currentPrice),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, child) {
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          val.toStringAsFixed(2),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 40.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8.0),
                Text(
                  data.currency,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(width: 10.0),
                  const SizedBox(
                    width: 14.0,
                    height: 14.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.aiAccent),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  String _getSubtitle(String ticker) {
    switch (ticker.trim().toUpperCase()) {
      case 'SWDA.L':
        return 'iShares Core MSCI World UCITS (USD)';
      case 'CSPX.L':
        return 'iShares Core S&P 500 UCITS (USD)';
      case 'VWRA.L':
        return 'Vanguard FTSE All-World UCITS (USD)';
      case 'VWCE.DE':
        return 'Vanguard FTSE All-World UCITS';
      case 'EUNL.DE':
        return 'iShares Core MSCI World UCITS';
      case '8PSG.DE':
        return 'Invesco Physical Gold ETC';
      case 'NVDA':
        return 'NVIDIA Corporation';
      case 'TSLA':
        return 'Tesla, Inc.';
      case 'PLTR':
        return 'Palantir Technologies Inc.';
      case 'AAPL':
        return 'Apple Inc.';
      case 'MSFT':
        return 'Microsoft Corporation';
      case 'AMZN':
        return 'Amazon.com, Inc.';
      case 'BTC-USD':
        return 'Bitcoin / USD';
      case 'ETH-USD':
        return 'Ethereum / USD';
      case 'SOL-USD':
        return 'Solana / USD';
      default:
        return 'Activo de Mercado';
    }
  }
}
