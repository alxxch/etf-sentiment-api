import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/predictive_models.dart';
import 'package:frontend/providers/voice_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/widgets/committee_panel.dart';
import 'package:frontend/widgets/predictive_chart_widget.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Phase 26: Predictive Models Serialization Tests', () {
    test('MonteCarloResult.fromJson parses arrays and statistics correctly', () {
      final jsonMap = {
        'ticker': 'VWCE.DE',
        'horizon_days': 1260,
        'n_simulations': 5000,
        'initial_investment': 10000.0,
        'monthly_contribution': 200.0,
        'p10': [10000.0, 9500.0, 9200.0],
        'p50': [10000.0, 10200.0, 10500.0],
        'p90': [10000.0, 11000.0, 12000.0],
        'days': [0, 1, 2],
        'mean_daily_return': 0.0003,
        'std_daily_return': 0.012,
        'annualized_return': 0.0756,
        'annualized_vol': 0.1905,
        'final_p10': 9200.0,
        'final_p50': 10500.0,
        'final_p90': 12000.0,
      };

      final result = MonteCarloResult.fromJson(jsonMap);

      expect(result.ticker, 'VWCE.DE');
      expect(result.horizonDays, 1260);
      expect(result.nSimulations, 5000);
      expect(result.initialInvestment, 10000.0);
      expect(result.monthlyContribution, 200.0);
      expect(result.p10.length, 3);
      expect(result.p50.length, 3);
      expect(result.p90.length, 3);
      expect(result.days.length, 3);
      expect(result.finalP10, 9200.0);
      expect(result.finalP50, 10500.0);
      expect(result.finalP90, 12000.0);
      expect(result.annualizedReturnPct, closeTo(7.56, 0.01));
      expect(result.annualizedVolPct, closeTo(19.05, 0.01));
      expect(result.horizonYears, 5.0);
      expect(result.hasData, isTrue);
    });

    test('CommitteeDebate.fromJson parses all 4 agent personas correctly', () {
      final jsonMap = {
        'technical_analyst': 'Señal MANTENER. Volatilidad contenida en 14%.',
        'macro_economist': 'Entorno MODERADO. Tipos estables y oro como refugio.',
        'risk_manager': 'DIVERSIFICAR. El P10 preserva 82% del capital.',
        'lead_advisor': '**Diagnóstico**: Posición sólida.\n**Recomendación**: Continuar DCA.',
      };

      final debate = CommitteeDebate.fromJson(jsonMap);

      expect(debate.technicalAnalyst, contains('MANTENER'));
      expect(debate.macroEconomist, contains('MODERADO'));
      expect(debate.riskManager, contains('DIVERSIFICAR'));
      expect(debate.leadAdvisor, contains('Diagnóstico'));
      expect(debate.hasContent, isTrue);
    });
  });

  group('Phase 26: ApiService Monte Carlo Tests', () {
    test('fetchMonteCarloSimulation calls endpoint and parses response', () async {
      final mockResponse = {
        'ticker': 'VWCE.DE',
        'horizon_days': 1260,
        'n_simulations': 5000,
        'initial_investment': 10000.0,
        'monthly_contribution': 200.0,
        'p10': [10000.0, 9800.0],
        'p50': [10000.0, 10300.0],
        'p90': [10000.0, 10900.0],
        'days': [0, 1],
        'mean_daily_return': 0.0003,
        'std_daily_return': 0.012,
        'annualized_return': 0.075,
        'annualized_vol': 0.19,
        'final_p10': 9800.0,
        'final_p50': 10300.0,
        'final_p90': 10900.0,
      };

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/analytics/montecarlo');
        expect(request.method, 'POST');
        return http.Response(json.encode(mockResponse), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final api = ApiService(client: mockClient);
      final res = await api.fetchMonteCarloSimulation();

      expect(res.ticker, 'VWCE.DE');
      expect(res.finalP50, 10300.0);
      expect(res.p10.length, 2);
    });
  });

  group('Phase 26: PredictiveChartWidget Tests', () {
    testWidgets('PredictiveChartWidget renders Fan Chart, legend and value chips',
        (tester) async {
      final testResult = MonteCarloResult(
        ticker: 'VWCE.DE',
        horizonDays: 1260,
        nSimulations: 5000,
        initialInvestment: 10000.0,
        monthlyContribution: 200.0,
        p10: [10000.0, 9500.0, 9000.0, 8800.0],
        p50: [10000.0, 10500.0, 11200.0, 12000.0],
        p90: [10000.0, 11500.0, 13000.0, 15000.0],
        days: [0, 420, 840, 1260],
        meanDailyReturn: 0.0003,
        stdDailyReturn: 0.012,
        annualizedReturn: 0.075,
        annualizedVol: 0.19,
        finalP10: 8800.0,
        finalP50: 12000.0,
        finalP90: 15000.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PredictiveChartWidget(result: testResult),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and legend
      expect(find.text('FAN CHART · PROYECCIÓN ESTOCÁSTICA'), findsOneWidget);
      expect(find.text('Histórico'), findsOneWidget);
      expect(find.text('P50 Base'), findsOneWidget);
      expect(find.text('P90 Optimista'), findsOneWidget);
      expect(find.text('P10 Pesimista'), findsOneWidget);
      expect(find.text('Cono Monte Carlo'), findsOneWidget);

      // Check value chips
      expect(find.text('Pesimista (P10)'), findsOneWidget);
      expect(find.text('Base (P50)'), findsOneWidget);
      expect(find.text('Optimista (P90)'), findsOneWidget);
    });
  });

  group('Phase 26: CommitteePanel Tests', () {
    testWidgets('CommitteePanel renders 3 agent tiles and Lead Advisor verdict',
        (tester) async {
      const debate = CommitteeDebate(
        technicalAnalyst: 'Momentum favorable. Volatilidad en rango medio.',
        macroEconomist: 'Tipos de interés estables. Oro protege la cartera.',
        riskManager: 'Percentil P10 seguro. Estrategia DCA recomendada.',
        leadAdvisor:
            '**Diagnóstico**: Cartera equilibrada.\n**Recomendación**: Mantener plan de ahorro mensual.',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommitteePanel(debate: debate),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header
      expect(find.text('COMITÉ DE INVERSIÓN IA'), findsOneWidget);
      expect(find.text('v8.0'), findsOneWidget);

      // 3 Specialists
      expect(find.text('Analista Técnico'), findsOneWidget);
      expect(find.text('Economista Macro'), findsOneWidget);
      expect(find.text('Gestor de Riesgos'), findsOneWidget);

      // Expand Technical Analyst
      await tester.tap(find.text('Analista Técnico'));
      await tester.pumpAndSettle();
      expect(find.text('Momentum favorable. Volatilidad en rango medio.'),
          findsOneWidget);

      // Lead Advisor section
      expect(find.text('VEREDICTO FINAL'), findsOneWidget);
      expect(find.textContaining('Cartera equilibrada'), findsOneWidget);
      expect(find.textContaining('Mantener plan de ahorro mensual'), findsOneWidget);
    });
  });

  group('Phase 26: VoiceProvider Predictive Integration Tests', () {
    test('VoiceProvider parses committee_debate and monte_carlo result', () {
      final voice = VoiceProvider();

      const debate = CommitteeDebate(
        technicalAnalyst: 'Análisis técnico listo',
        macroEconomist: 'Análisis macro listo',
        riskManager: 'Análisis riesgo listo',
        leadAdvisor: 'Veredicto final listo',
      );

      final mcResult = MonteCarloResult(
        ticker: 'VWCE.DE',
        horizonDays: 1260,
        nSimulations: 5000,
        initialInvestment: 10000.0,
        monthlyContribution: 200.0,
        p10: [10000.0, 9500.0],
        p50: [10000.0, 10500.0],
        p90: [10000.0, 11500.0],
        days: [0, 1],
        meanDailyReturn: 0.0003,
        stdDailyReturn: 0.012,
        annualizedReturn: 0.075,
        annualizedVol: 0.19,
        finalP10: 9500.0,
        finalP50: 10500.0,
        finalP90: 11500.0,
      );

      voice.setCommitteeDebateForTesting(debate);
      voice.setMonteCarloResultForTesting(mcResult);

      expect(voice.hasCommitteeDebate, isTrue);
      expect(voice.committeeDebate?.technicalAnalyst, 'Análisis técnico listo');
      expect(voice.hasMonteCarloResult, isTrue);
      expect(voice.monteCarloResult?.finalP50, 10500.0);

      voice.clearCommitteeDebate();
      expect(voice.hasCommitteeDebate, isFalse);
    });
  });
}
