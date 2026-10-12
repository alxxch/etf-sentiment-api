import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/portfolio_provider.dart';
import 'package:frontend/widgets/spatial_portfolio_widget.dart';
import 'package:provider/provider.dart';

void main() {
  group('Phase 19: Spatial Reactivity & Financial 3D Mapping Tests', () {
    testWidgets(
        '1. Camera orbit interpolates dynamically based on Equity allocation',
        (WidgetTester tester) async {
      // Caso 1: 80% RV -> ángulo phi ≈ 43.4° (enfoque más zenital)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpatialPortfolioWidget(
              customEquityPct: 80.0,
              customSentimentScore: 50,
            ),
          ),
        ),
      );

      expect(find.byType(SpatialPortfolioWidget), findsOneWidget);
      expect(find.textContaining('80% RV (43°)'), findsOneWidget);
      expect(find.textContaining('RV: 80%'), findsOneWidget);

      // Caso 2: 20% RV -> ángulo phi ≈ 60° (enfoque más frontal/horizontal)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpatialPortfolioWidget(
              customEquityPct: 20.0,
              customSentimentScore: 50,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('20% RV (60°)'), findsOneWidget);
      expect(find.textContaining('RV: 20%'), findsOneWidget);
    });

    testWidgets(
        '2. Ambient glow and sentiment badge react to market sentiment score',
        (WidgetTester tester) async {
      // Sentimiento bajista (Score = 15)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpatialPortfolioWidget(
              customEquityPct: 80.0,
              customSentimentScore: 15,
            ),
          ),
        ),
      );

      expect(find.text('SENTIMIENTO 15'), findsOneWidget);
      expect(find.textContaining('Sentimiento: 15/100'), findsOneWidget);

      // Sentimiento alcista (Score = 85)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpatialPortfolioWidget(
              customEquityPct: 80.0,
              customSentimentScore: 85,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('SENTIMIENTO 85'), findsOneWidget);
      expect(find.textContaining('Sentimiento: 85/100'), findsOneWidget);
    });

    testWidgets(
        '3. Provider state mutations trigger camera adaptation and rebalance spin animation',
        (WidgetTester tester) async {
      final provider = PortfolioProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<PortfolioProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(
              body: SpatialPortfolioWidget(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Por defecto provider tiene 80% RV
      expect(find.textContaining('80% RV'), findsOneWidget);
      expect(find.text('RECALCULANDO ACTIVOS...'), findsNothing);

      // Modificamos asignación de RV a 40% en el provider
      provider.setEquityAllocation(40.0);
      await tester.pump();

      expect(find.textContaining('40% RV (54°)'), findsOneWidget);

      // Disparamos evento de rebalanceo/recalculo en el provider
      provider.triggerRebalanceAnimation();
      await tester.pump();

      // Debe aparecer el feedback físico de rebalanceo activo
      expect(find.text('RECALCULANDO ACTIVOS...'), findsOneWidget);

      // Tras avanzar el temporizador de 4 segundos, el feedback temporal desaparece
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('RECALCULANDO ACTIVOS...'), findsNothing);
    });
  });
}
