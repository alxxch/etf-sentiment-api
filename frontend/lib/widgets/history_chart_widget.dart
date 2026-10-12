import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/etf_history_entry.dart';
import '../theme/app_colors.dart';

class HistoryChartWidget extends StatelessWidget {
  final List<EtfHistoryEntry> history;
  final String ticker;

  const HistoryChartWidget({
    super.key,
    required this.history,
    required this.ticker,
  });

  Color _getScoreColor(double score) {
    if (score >= 60) return AppColors.bullish;
    if (score <= 40) return AppColors.bearish;
    return AppColors.aiAccent;
  }

  @override
  Widget build(BuildContext context) {
    // Ordenar cronológicamente ascendente para el eje X (tiempo)
    final sorted = [...history]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

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
          // Encabezado del gráfico
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7.0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(9.0),
                    ),
                    child: const Icon(
                      Icons.show_chart_rounded,
                      color: AppColors.aiAccent,
                      size: 17.0,
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EVOLUCIÓN DE SENTIMIENTO',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        'Histórico en PostgreSQL',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (sorted.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: AppColors.cardBorder.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '${sorted.length} ${sorted.length == 1 ? "registro" : "registros"}',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20.0),

          // Renderizado del LineChart o estado vacío
          if (sorted.isEmpty)
            _buildEmptyState()
          else
            _buildChart(sorted),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 16.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.query_builder_rounded,
            color: AppColors.textTertiary.withValues(alpha: 0.7),
            size: 32.0,
          ),
          const SizedBox(height: 10.0),
          const Text(
            'Sin registros históricos acumulados',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4.0),
          const Text(
            'Se guardarán automáticamente con Celery o al consultar el activo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12.0,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<EtfHistoryEntry> sorted) {
    final latestScore = sorted.last.sentimentScore.toDouble();
    final lineColor = _getScoreColor(latestScore);

    // Mapear puntos del gráfico
    List<FlSpot> spots;
    if (sorted.length == 1) {
      // Para un único registro, graficar una línea horizontal corta
      spots = [
        FlSpot(0, sorted.first.sentimentScore.toDouble()),
        FlSpot(1, sorted.first.sentimentScore.toDouble()),
      ];
    } else {
      spots = sorted
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), e.value.sentimentScore.toDouble()))
          .toList();
    }

    final maxX = (spots.length - 1).toDouble();

    return SizedBox(
      height: 170.0,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          minX: 0,
          maxX: maxX > 0 ? maxX : 1,
          // Minimalismo Apple Finance: sin cuadrículas internas
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            // Eje Y (Sentimiento 0 - 100)
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28.0,
                interval: 50.0,
                getTitlesWidget: (value, meta) {
                  if (value == 0 || value == 50 || value == 100) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10.0,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            // Eje X (Tiempo)
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22.0,
                interval: sorted.length > 3 ? (sorted.length / 3).floorToDouble() : 1.0,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < sorted.length) {
                    final item = sorted[index];
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        sorted.length <= 4 ? item.formattedTime : item.formattedShortDate,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          // Tooltips interactivos al tocar
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceSecondary,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.x.toInt().clamp(0, sorted.length - 1);
                  final item = sorted[idx];
                  return LineTooltipItem(
                    '${item.sentimentScore} pts\n',
                    TextStyle(
                      color: _getScoreColor(item.sentimentScore.toDouble()),
                      fontWeight: FontWeight.w800,
                      fontSize: 13.0,
                    ),
                    children: [
                      TextSpan(
                        text: '${item.formattedShortDate} ${item.formattedTime}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10.0,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: lineColor,
              barWidth: 2.8,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: sorted.length <= 10,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 3.5,
                    color: lineColor,
                    strokeWidth: 1.5,
                    strokeColor: Colors.black,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    lineColor.withValues(alpha: 0.28),
                    lineColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
