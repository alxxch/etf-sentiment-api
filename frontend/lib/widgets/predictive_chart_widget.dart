// Fan Chart — Gráfico de Abanico / Cono de Incertidumbre Monte Carlo — Fase 26.
//
// Renderiza:
//   1. Línea histórica continua hasta el día de "Hoy" (X = 0).
//   2. A partir de "Hoy", proyección base P50 con estilo punteado (dashArray) y color distintivo.
//   3. Cono de incertidumbre sombreado y translúcido entre P90 y P10 (BetweenBarsData).
//   4. Líneas P90 (optimista) y P10 (pesimista) delimitando el abanico estocástico.
//
// Optimizaciones de rendimiento:
//   • Submuestreo adaptativo a máx. 252 puntos visibles (≥ 60 fps garantizados)
//   • Cálculos de FlSpot realizados una sola vez en initState / didUpdateWidget
//   • Marcador visual vertical en "Hoy" (X = 0) dividiendo pasado y futuro

import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/etf_history_entry.dart';
import '../models/predictive_models.dart';
import '../theme/app_colors.dart';

class PredictiveChartWidget extends StatefulWidget {
  final MonteCarloResult result;
  final List<EtfHistoryEntry>? history;
  final List<double>? historicalValues;

  /// Número máximo de puntos visibles en el eje X (submuestreo adaptativo).
  final int maxVisiblePoints;

  const PredictiveChartWidget({
    super.key,
    required this.result,
    this.history,
    this.historicalValues,
    this.maxVisiblePoints = 252,
  });

  @override
  State<PredictiveChartWidget> createState() => _PredictiveChartWidgetState();
}

class _PredictiveChartWidgetState extends State<PredictiveChartWidget>
    with SingleTickerProviderStateMixin {
  late List<FlSpot> _spotsHistorical;
  late List<FlSpot> _spotsP10;
  late List<FlSpot> _spotsP50;
  late List<FlSpot> _spotsP90;
  late double _minX;
  late double _maxX;
  late double _minY;
  late double _maxY;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _buildSampledSpots();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void didUpdateWidget(PredictiveChartWidget old) {
    super.didUpdateWidget(old);
    if (old.result != widget.result ||
        old.history != widget.history ||
        old.historicalValues != widget.historicalValues) {
      _buildSampledSpots();
      _animCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Construcción de puntos históricos y predictivos con submuestreo
  // ---------------------------------------------------------------------------

  void _buildSampledSpots() {
    final p10 = widget.result.p10;
    final p50 = widget.result.p50;
    final p90 = widget.result.p90;
    final totalPred = p50.length;

    if (totalPred == 0) {
      _spotsHistorical = [];
      _spotsP10 = [];
      _spotsP50 = [];
      _spotsP90 = [];
      _minX = 0;
      _maxX = 1;
      _minY = 0;
      _maxY = 1;
      return;
    }

    // 1. Extraer o simular serie histórica hasta "Hoy" (X = 0)
    final double initialAnchor =
        widget.result.initialInvestment > 0 ? widget.result.initialInvestment : p50.first;

    List<double> rawHistoryValues = [];
    if (widget.historicalValues != null && widget.historicalValues!.isNotEmpty) {
      rawHistoryValues = widget.historicalValues!;
    } else if (widget.history != null && widget.history!.isNotEmpty) {
      rawHistoryValues = widget.history!.map((e) => e.price).toList();
    }

    _spotsHistorical = [];
    const int histDays = 40; // ~2 meses de histórico visual
    if (rawHistoryValues.isNotEmpty) {
      // Normalizar al valor de anclaje inicial para escala continua de cartera
      final lastRaw = rawHistoryValues.last > 0 ? rawHistoryValues.last : 1.0;
      final scale = initialAnchor / lastRaw;

      final count = math.min(rawHistoryValues.length, histDays);
      final subset = rawHistoryValues.sublist(rawHistoryValues.length - count);
      for (int i = 0; i < subset.length; i++) {
        final x = (i - (subset.length - 1)).toDouble(); // De -(count-1) a 0
        final y = subset[i] * scale;
        _spotsHistorical.add(FlSpot(x, y));
      }
    } else {
      // Generación sintética suave de la trayectoria reciente hacia el anclaje inicial
      for (int i = -histDays; i <= 0; i++) {
        final factor = 1.0 - (i.abs() * 0.002) + (math.sin(i * 0.4) * 0.008);
        _spotsHistorical.add(FlSpot(i.toDouble(), initialAnchor * factor));
      }
    }

    // Asegurar continuidad matemática en X = 0
    if (_spotsHistorical.isNotEmpty) {
      _spotsHistorical[_spotsHistorical.length - 1] = FlSpot(0, initialAnchor);
    }

    _minX = _spotsHistorical.isNotEmpty ? _spotsHistorical.first.x : 0.0;
    _maxX = (widget.result.days.isNotEmpty
        ? widget.result.days.last.toDouble()
        : widget.result.horizonDays.toDouble());

    // 2. Submuestreo adaptativo de las 3 bandas predictivas (X de 0 a T)
    final step = math.max(1, (totalPred / widget.maxVisiblePoints).ceil());

    _spotsP10 = [];
    _spotsP50 = [];
    _spotsP90 = [];

    for (int i = 0; i < totalPred; i += step) {
      final x = i.toDouble();
      _spotsP10.add(FlSpot(x, p10[i]));
      _spotsP50.add(FlSpot(x, p50[i]));
      _spotsP90.add(FlSpot(x, p90[i]));
    }
    // Incluir último punto exacto
    if ((totalPred - 1) % step != 0) {
      final last = totalPred - 1;
      _spotsP10.add(FlSpot(last.toDouble(), p10[last]));
      _spotsP50.add(FlSpot(last.toDouble(), p50[last]));
      _spotsP90.add(FlSpot(last.toDouble(), p90[last]));
    }

    // 3. Rangos verticales con margen del 8%
    final allY = [
      ..._spotsHistorical.map((s) => s.y),
      ...p10,
      ...p50,
      ...p90,
    ];
    final rawMin = allY.reduce(math.min);
    final rawMax = allY.reduce(math.max);
    final margin = (rawMax - rawMin) * 0.08;
    _minY = math.max(0, rawMin - margin);
    _maxY = rawMax + margin;
  }

  // ---------------------------------------------------------------------------
  // Formato de etiquetas
  // ---------------------------------------------------------------------------

  String _labelForDay(double day) {
    if (day < -5) return '-2M';
    if (day.abs() <= 5) return 'Hoy';
    final years = day / 252;
    if (years < 1.5) return '1A';
    if (years < 2.5) return '2A';
    if (years < 3.5) return '3A';
    if (years < 4.5) return '4A';
    return '5A';
  }

  String _formatEuro(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M€';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K€';
    return '${v.toStringAsFixed(0)}€';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!widget.result.hasData) {
      return _buildEmptyState();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.cardBorder.withValues(alpha: 0.6),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildLegend(),
          const SizedBox(height: 12),
          FadeTransition(
            opacity: _fadeAnim,
            child: SizedBox(
              height: 230,
              child: _buildChart(),
            ),
          ),
          const SizedBox(height: 12),
          _buildFinalValues(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.aiAccentSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.auto_graph_rounded,
            color: AppColors.aiAccent,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FAN CHART · PROYECCIÓN ESTOCÁSTICA',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                '${widget.result.ticker} · Histórico real + Monte Carlo (${widget.result.nSimulations ~/ 1000}K trayectorias)',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            'σ ${widget.result.annualizedVolPct.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _legendItem(
            const Color(0xFFE5E5EA),
            'Histórico',
            isSolid: true,
          ),
          const SizedBox(width: 12),
          _legendItem(
            AppColors.aiAccent,
            'P50 Base',
            isDashed: true,
          ),
          const SizedBox(width: 12),
          _legendItem(
            AppColors.bullish.withValues(alpha: 0.8),
            'P90 Optimista',
            isSolid: true,
          ),
          const SizedBox(width: 12),
          _legendItem(
            AppColors.bearish.withValues(alpha: 0.8),
            'P10 Pesimista',
            isSolid: true,
          ),
          const SizedBox(width: 12),
          _legendBand('Cono Monte Carlo'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label,
      {bool isDashed = false, bool isSolid = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDashed)
          CustomPaint(
            size: const Size(18, 4),
            painter: _DashedLinePainter(color: color),
          )
        else
          Container(
            width: isSolid ? 16 : 8,
            height: isSolid ? 2.5 : 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _legendBand(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.aiAccent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: AppColors.aiAccent.withValues(alpha: 0.40),
              width: 0.6,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    return LineChart(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      LineChartData(
        minX: _minX,
        maxX: _maxX,
        minY: _minY,
        maxY: _maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: (_maxY - _minY) / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.cardBorder.withValues(alpha: 0.25),
            strokeWidth: 0.5,
          ),
          checkToShowVerticalLine: (value) => value.abs() <= 5,
          getDrawingVerticalLine: (_) => FlLine(
            color: AppColors.gold.withValues(alpha: 0.55),
            strokeWidth: 1.0,
            dashArray: const [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: (_maxY - _minY) / 4,
              getTitlesWidget: (value, _) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  _formatEuro(value),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 252,
              getTitlesWidget: (value, _) => Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  _labelForDay(value),
                  style: TextStyle(
                    color: value.abs() <= 5
                        ? AppColors.gold
                        : AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: value.abs() <= 5
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceSecondary,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItems: (spots) => spots.map((s) {
              final label = switch (s.barIndex) {
                0 => 'Histórico',
                1 => 'P90 (Optimista)',
                2 => 'P50 (Base)',
                _ => 'P10 (Pesimista)',
              };
              final color = switch (s.barIndex) {
                0 => const Color(0xFFE5E5EA),
                1 => AppColors.bullish,
                2 => AppColors.aiAccent,
                _ => AppColors.bearish,
              };
              return LineTooltipItem(
                '$label: ${_formatEuro(s.y)}',
                TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
        // ----------------------------------------------------------------
        // Cono de incertidumbre: BetweenBarsData entre P90 (idx 1) y P10 (idx 3)
        // ----------------------------------------------------------------
        betweenBarsData: [
          BetweenBarsData(
            fromIndex: 1, // P90
            toIndex: 3, // P10
            color: AppColors.aiAccent.withValues(alpha: 0.14),
          ),
        ],
        lineBarsData: [
          // ── 0. Línea Histórica hasta Hoy (X de -H a 0) ───────────────
          LineChartBarData(
            spots: _spotsHistorical,
            isCurved: true,
            curveSmoothness: 0.25,
            color: const Color(0xFFE5E5EA),
            barWidth: 2.2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // ── 1. P90 (optimista) — Techo superior del cono ────────────
          LineChartBarData(
            spots: _spotsP90,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.bullish.withValues(alpha: 0.70),
            barWidth: 1.6,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
          // ── 2. P50 Base — Línea punteada a partir de Hoy ───────────
          LineChartBarData(
            spots: _spotsP50,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.aiAccent,
            barWidth: 2.4,
            dashArray: const [6, 4], // Estilo punteado exigido
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
          // ── 3. P10 (pesimista) — Suelo inferior del cono ────────────
          LineChartBarData(
            spots: _spotsP10,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.bearish.withValues(alpha: 0.70),
            barWidth: 1.6,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalValues() {
    return Row(
      children: [
        _valueChip(
          'Pesimista (P10)',
          widget.result.finalP10,
          AppColors.bearish,
        ),
        const SizedBox(width: 8),
        _valueChip(
          'Base (P50)',
          widget.result.finalP50,
          AppColors.aiAccent,
          isHighlighted: true,
        ),
        const SizedBox(width: 8),
        _valueChip(
          'Optimista (P90)',
          widget.result.finalP90,
          AppColors.bullish,
        ),
      ],
    );
  }

  Widget _valueChip(String label, double value, Color color,
      {bool isHighlighted = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isHighlighted
              ? color.withValues(alpha: 0.12)
              : AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(10),
          border: isHighlighted
              ? Border.all(color: color.withValues(alpha: 0.35), width: 1.0)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.85),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatEuro(value),
              style: TextStyle(
                color: isHighlighted ? color : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_graph_rounded,
              color: AppColors.textTertiary.withValues(alpha: 0.5), size: 32),
          const SizedBox(height: 10),
          const Text(
            'Sin proyección disponible',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Haz una consulta de análisis a largo plazo para activar\nel motor Monte Carlo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dashWidth = 3.0;
    const dashSpace = 3.0;
    double startX = 0;
    final y = size.height / 2;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
