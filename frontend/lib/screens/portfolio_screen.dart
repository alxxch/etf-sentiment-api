import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/portfolio_models.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/notifications_panel.dart';
import '../widgets/rebalance_card_widget.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PortfolioProvider>().fetchInitialData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PortfolioProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(provider),
                Expanded(
                  child: _buildBody(provider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(PortfolioProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FINTECH & ASSET ALLOCATION',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 2.0),
              Text(
                'Mi Cartera',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Badge de estado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: AppColors.cardBorder.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (provider.isLoading) ...[
                      const SizedBox(
                        width: 8.0,
                        height: 8.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.aiAccent),
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      const Text(
                        'CARGANDO',
                        style: TextStyle(
                          color: AppColors.aiAccent,
                          fontSize: 10.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.circle,
                        color: AppColors.bullish,
                        size: 7.0,
                      ),
                      const SizedBox(width: 6.0),
                      const Text(
                        'DCA ACTIVO',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4.0),
              const NotificationBellButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(PortfolioProvider provider) {
    if (provider.isLoading && !provider.hasData) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 38.0,
              height: 38.0,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.bullish),
              ),
            ),
            SizedBox(height: 20.0),
            Text(
              'Cargando valoración de cartera...',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (provider.errorMessage != null && !provider.hasData) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.bearishSoft,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.bearish,
                  size: 40.0,
                ),
              ),
              const SizedBox(height: 20.0),
              const Text(
                'No se pudo cargar la cartera',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.0,
                ),
              ),
              const SizedBox(height: 20.0),
              ElevatedButton.icon(
                onPressed: () => provider.loadPortfolio(force: true),
                icon: const Icon(Icons.refresh_rounded, size: 18.0),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceSecondary,
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final portfolio = provider.portfolio;
    if (portfolio == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      color: AppColors.bullish,
      backgroundColor: AppColors.cardSurface,
      onRefresh: () => provider.loadPortfolio(force: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Tarjeta principal de Rendimiento y Valoración
            _buildPerformancePanel(portfolio),

            // Tarjeta destacada de Consejo de Rebalanceo Inteligente (Fase 14 & 16)
            if (provider.rebalanceAdvice != null) ...[
              const SizedBox(height: 18.0),
              RebalanceCardWidget(advice: provider.rebalanceAdvice!),
            ],

            const SizedBox(height: 18.0),

            // 2. Gráfico de Alocación Multiactivo (PieChart con fl_chart)
            _buildAssetAllocationSection(portfolio),

            const SizedBox(height: 18.0),

            // 3. Simulador y Configuración interactiva DCA
            _buildDcaSimulatorForm(provider),

            const SizedBox(height: 18.0),

            // 4. Historial de Transacciones DCA
            _buildTransactionsSection(portfolio),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // 1. PANEL DE RENDIMIENTO
  // ==========================================================================
  Widget _buildPerformancePanel(PortfolioStatus portfolio) {
    final isPositive = portfolio.isPnlPositive;
    final pnlColor = isPositive ? AppColors.bullish : AppColors.bearish;
    final pnlBg = isPositive ? AppColors.bullishSoft : AppColors.bearishSoft;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'VALOR TOTAL DE LA CARTERA',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8.0, vertical: 3.5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  'Score Sentimiento: ${portfolio.marketSentimentScore}',
                  style: const TextStyle(
                    color: AppColors.aiAccent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            portfolio.formattedCurrentValue,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32.0,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 12.0),
          // Badge P&L y ROI
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10.0, vertical: 5.0),
                decoration: BoxDecoration(
                  color: pnlBg,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: pnlColor,
                      size: 14.0,
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      '${portfolio.formattedPnl} (${portfolio.formattedRoi})',
                      style: TextStyle(
                        color: pnlColor,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10.0),
              const Text(
                'P&L acumulado',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18.0),
          const Divider(color: AppColors.cardBorder, height: 1.0),
          const SizedBox(height: 14.0),
          // Sub-métricas
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Capital Invertido',
                  value: portfolio.formattedTotalInvested,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  title: 'Plan Recurrente',
                  value:
                      '${portfolio.savingsPlan?.monthlyDeposit.toStringAsFixed(0) ?? "200"} € / mes',
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  title: 'Transacciones',
                  value: '${portfolio.transactions.length}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({required String title, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // 2. GRÁFICO DE ALOCACIÓN MULTIACTIVO (fl_chart PieChart)
  // ==========================================================================
  Widget _buildAssetAllocationSection(PortfolioStatus portfolio) {
    final allocation = portfolio.assetAllocation;

    double equityPct = 80.0;
    double goldPct = 20.0;

    for (final item in allocation) {
      if (item.isGold) {
        goldPct = item.allocationPct;
      } else {
        equityPct = item.allocationPct;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ASSET ALLOCATION',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Renta Variable vs Oro',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20.0),

          // Gráfico PieChart
          SizedBox(
            height: 180.0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedPieIndex = -1;
                            return;
                          }
                          _touchedPieIndex = pieTouchResponse
                              .touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 3,
                    centerSpaceRadius: 46,
                    sections: [
                      PieChartSectionData(
                        value: equityPct > 0 ? equityPct : 80.0,
                        title: '${equityPct.toStringAsFixed(0)}%',
                        color: AppColors.equity,
                        radius: _touchedPieIndex == 0 ? 30.0 : 25.0,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      PieChartSectionData(
                        value: goldPct > 0 ? goldPct : 20.0,
                        title: '${goldPct.toStringAsFixed(0)}%',
                        color: AppColors.gold,
                        radius: _touchedPieIndex == 1 ? 30.0 : 25.0,
                        titleStyle: const TextStyle(
                          color: Colors.black,
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.pie_chart_outline_rounded,
                      color: AppColors.textSecondary,
                      size: 20.0,
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${allocation.length} ACTIVOS',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 9.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16.0),
          const Divider(color: AppColors.cardBorder, height: 1.0),
          const SizedBox(height: 12.0),

          // Desglose detallado de los activos
          ...allocation.map((item) => _buildAssetRow(item)),
        ],
      ),
    );
  }

  Widget _buildAssetRow(AssetAllocationItem item) {
    final isGold = item.isGold;
    final color = isGold ? AppColors.gold : AppColors.equity;
    final label = isGold
        ? 'Oro Físico (Cobertura)'
        : 'Renta Variable Global';

    final isPos = item.isPnlPositive;
    final pnlColor = isPos ? AppColors.bullish : AppColors.bearish;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 10.0,
            height: 10.0,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.ticker,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1.0),
                Text(
                  '$label • ${item.shares.toStringAsFixed(3)} accs',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.currentValue.toStringAsFixed(2)} € (${item.allocationPct.toStringAsFixed(1)}%)',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1.0),
              Text(
                '${isPos ? "+" : ""}${item.pnl.toStringAsFixed(2)} € (${isPos ? "+" : ""}${item.roiPct.toStringAsFixed(2)}%)',
                style: TextStyle(
                  color: pnlColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 3. FORMULARIO INTERACTIVO DCA & SIMULACIÓN
  // ==========================================================================
  Widget _buildDcaSimulatorForm(PortfolioProvider provider) {
    final simulation = provider.simulation;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SIMULADOR DCA & PLAN DE AHORRO',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              if (provider.isSimulating)
                const SizedBox(
                  width: 14.0,
                  height: 14.0,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.aiAccent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6.0),
          const Text(
            'Modifica tu aportación y visualiza la rentabilidad proyectada cruzada con sentimiento.',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12.0,
            ),
          ),
          const SizedBox(height: 20.0),

          // Control: Aportación Mensual
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Aportación Mensual',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text(
                  '${provider.monthlyDeposit.toStringAsFixed(0)} €',
                  style: const TextStyle(
                    color: AppColors.bullish,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.bullish,
              inactiveTrackColor: AppColors.surfaceSecondary,
              thumbColor: AppColors.bullish,
              overlayColor: AppColors.bullishSoft,
              trackHeight: 3.5,
            ),
            child: Slider(
              value: provider.monthlyDeposit,
              min: 25.0,
              max: 1000.0,
              divisions: 39,
              onChanged: (val) {
                provider.setMonthlyDeposit(val);
              },
              onChangeEnd: (_) {
                provider.runSimulation();
              },
            ),
          ),

          const SizedBox(height: 10.0),

          // Control: Distribución (% RV vs % Oro)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Distribución de Activos',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${provider.allocationEquityPct.toStringAsFixed(0)}% RV  /  ${provider.allocationGoldPct.toStringAsFixed(0)}% Oro',
                style: const TextStyle(
                  color: AppColors.aiAccent,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.equity,
              inactiveTrackColor: AppColors.gold,
              thumbColor: Colors.white,
              overlayColor: AppColors.aiAccentSoft,
              trackHeight: 5.0,
            ),
            child: Slider(
              value: provider.allocationEquityPct,
              min: 0.0,
              max: 100.0,
              divisions: 20,
              onChanged: (val) {
                provider.setEquityAllocation(val);
              },
              onChangeEnd: (_) {
                provider.runSimulation();
              },
            ),
          ),

          const SizedBox(height: 10.0),

          // Control: Horizonte temporal (Meses)
          const Text(
            'Horizonte Temporal a Simular',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            children: [3, 6, 12, 24].map((m) {
              final isSel = provider.simulationMonths == m;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: GestureDetector(
                    onTap: () {
                      provider.setSimulationMonths(m);
                      provider.runSimulation();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.surfaceSecondary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: isSel
                              ? AppColors.cardBorder
                              : AppColors.cardBorder.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$m meses',
                          style: TextStyle(
                            color: isSel
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 12.0,
                            fontWeight:
                                isSel ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18.0),

          // Panel de Resultado de la Simulación
          if (simulation != null) ...[
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(
                  color: AppColors.cardBorder.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RESULTADO DE LA SIMULACIÓN DCA',
                        style: TextStyle(
                          color: AppColors.aiAccent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Icon(Icons.auto_graph_rounded,
                          color: AppColors.aiAccent, size: 16.0),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Capital Aportado',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11.0,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            '${simulation.totalInvested.toStringAsFixed(0)} €',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Valor Estimado',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11.0,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            '${simulation.currentValue.toStringAsFixed(2)} €',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Rentabilidad',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11.0,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            '${simulation.isPnlPositive ? "+" : ""}${simulation.roiPct.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: simulation.isPnlPositive
                                  ? AppColors.bullish
                                  : AppColors.bearish,
                              fontSize: 16.0,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14.0),
          ],

          // Botón para Persistir el Plan en Backend
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final success = await provider.saveSavingsPlan();
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: success
                            ? AppColors.surfaceSecondary
                            : AppColors.bearishSoft,
                        content: Text(
                          success
                              ? 'Plan de ahorro guardado con éxito (${provider.monthlyDeposit.toStringAsFixed(0)} €/mes).'
                              : 'Error al guardar el plan de ahorro.',
                          style: TextStyle(
                            color: success
                                ? AppColors.textPrimary
                                : AppColors.bearish,
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bookmark_add_rounded, size: 16.0),
                  label: const Text('Guardar Configuración'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceSecondary,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      side: const BorderSide(color: AppColors.cardBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10.0),
              IconButton(
                onPressed: () => provider.runSimulation(),
                tooltip: 'Recalcular simulación',
                icon: const Icon(Icons.refresh_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceSecondary,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 4. HISTORIAL DE TRANSACCIONES DCA
  // ==========================================================================
  Widget _buildTransactionsSection(PortfolioStatus portfolio) {
    final transactions = portfolio.transactions;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'HISTORIAL DE APORTACIONES',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${transactions.length} operaciones',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  'No hay aportaciones registradas.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: AppColors.cardBorder, height: 16.0),
              itemBuilder: (context, index) {
                final tx = transactions[index];
                final isGold = tx.ticker.contains('8PSG');
                final badgeColor = isGold ? AppColors.gold : AppColors.equity;

                final dateStr = tx.timestamp != null
                    ? '${tx.timestamp!.day.toString().padLeft(2, '0')}/${tx.timestamp!.month.toString().padLeft(2, '0')}/${tx.timestamp!.year}'
                    : 'Aportación DCA';

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                            color: badgeColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        tx.ticker.replaceAll('.DE', ''),
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compra DCA • $dateStr',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 1.0),
                          Text(
                            '${tx.shares.toStringAsFixed(4)} accs @ ${tx.pricePerShare.toStringAsFixed(2)} €',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${tx.amountInvested.toStringAsFixed(2)} €',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
