import 'package:flutter/material.dart';
import '../models/rebalance_advice.dart';
import '../theme/app_colors.dart';

class RebalanceCardWidget extends StatelessWidget {
  final RebalanceAdvice advice;
  final EdgeInsetsGeometry? margin;

  const RebalanceCardWidget({
    super.key,
    required this.advice,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Color statusBg;
    String statusLabel;

    if (advice.isFullyRebalanced) {
      statusColor = AppColors.bullish;
      statusBg = AppColors.bullishSoft;
      statusLabel = 'Rebalanceo 100% Viable';
    } else if (advice.isPartiallyRebalanced) {
      statusColor = AppColors.gold;
      statusBg = AppColors.goldSoft;
      statusLabel = 'Alineación Progresiva';
    } else {
      statusColor = AppColors.aiAccent;
      statusBg = AppColors.aiAccentSoft;
      statusLabel = 'Cartera Equilibrada';
    }

    return Container(
      margin: margin ?? EdgeInsets.zero,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7.0),
                    decoration: BoxDecoration(
                      color: statusBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_graph_rounded,
                      color: statusColor,
                      size: 18.0,
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DYNAMIC REBALANCING',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      Text(
                        'Consejo de Rebalanceo',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14.0),

          // Caja de texto explicativo (Directriz Matemática)
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: AppColors.cardBorder.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: statusColor,
                  size: 18.0,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    advice.summaryMessage,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16.0),

          // Barras de progreso de Activos: Actual vs Objetivo vs Sugerencia
          ...advice.assets.map((asset) => _buildAssetDriftBar(context, asset)),

          const SizedBox(height: 6.0),

          // Nota al pie con la cuota considerada
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cuota evaluada: ${advice.monthlyDeposit.toStringAsFixed(2)} €/mes',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Post-rebalanceo: ${advice.postRebalancePortfolioValue.toStringAsFixed(2)} €',
                style: const TextStyle(
                  color: AppColors.textSecondary,
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

  Widget _buildAssetDriftBar(BuildContext context, AssetRebalanceItem asset) {
    final isGold = asset.isGold;
    final assetColor = isGold ? AppColors.gold : AppColors.equity;
    final driftIsPositive = asset.driftPct > 0;
    final driftSign = driftIsPositive ? '+' : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila de encabezado del activo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8.0,
                    height: 8.0,
                    decoration: BoxDecoration(
                      color: assetColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    '${asset.ticker} (${isGold ? 'Oro Físico' : 'Renta Variable'})',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              // Badge de Desviación (Drift)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: (driftIsPositive ? AppColors.bearish : AppColors.bullish)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  'Drift: $driftSign${asset.driftPct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: driftIsPositive ? AppColors.bearish : AppColors.bullish,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6.0),

          // Barras de progreso comparativas (Actual vs Objetivo)
          Stack(
            children: [
              // Fondo de barra
              Container(
                height: 8.0,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
              // Barra actual
              FractionallySizedBox(
                widthFactor: (asset.currentAllocationPct / 100.0).clamp(0.0, 1.0),
                child: Container(
                  height: 8.0,
                  decoration: BoxDecoration(
                    color: assetColor.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                ),
              ),
              // Marcador objetivo
              Positioned(
                left: null,
                right: null,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Container();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 4.0),

          // Fila descriptiva numérica
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Actual: ${asset.currentAllocationPct.toStringAsFixed(1)}% | Objetivo: ${asset.targetAllocationPct.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.0,
                ),
              ),
              Text(
                'Aportar: ${asset.suggestedDeposit.toStringAsFixed(2)} € (${asset.suggestedDepositPct.toStringAsFixed(0)}%)',
                style: TextStyle(
                  color: assetColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
