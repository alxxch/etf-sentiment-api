import 'dart:convert';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/etf_data.dart';
import 'package:frontend/models/etf_history_entry.dart';
import 'package:frontend/models/portfolio_models.dart';
import 'package:frontend/models/rebalance_advice.dart';
import 'package:frontend/providers/banking_provider.dart';
import 'package:frontend/providers/etf_provider.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/providers/portfolio_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/widgets/etf_card_widget.dart';
import 'package:frontend/widgets/glass_card.dart';
import 'package:frontend/widgets/spatial_portfolio_widget.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Helper de datos mockeados para tests rápidos y reproducibles sin backend real
PortfolioStatus _createMockPortfolio() {
  return PortfolioStatus.fromJson({
    'id': 1,
    'user_id': 1,
    'user_email': 'desktop.tester@example.com',
    'user_name': 'desktop_tester',
    'name': 'Cartera Institucional Desktop',
    'currency': 'EUR',
    'initial_balance': 0.0,
    'total_invested': 12000.0,
    'current_value': 14850.50,
    'pnl': 2850.50,
    'roi_pct': 23.75,
    'market_sentiment_score': 74,
    'asset_allocation': [
      {
        'ticker': 'VWCE.DE',
        'asset_class': 'EQUITY',
        'shares': 70.0,
        'current_price': 173.56,
        'current_value': 12149.20,
        'allocation_pct': 81.8,
        'break_even_price': 150.0,
        'pnl': 1649.20,
        'roi_pct': 15.7,
      },
      {
        'ticker': '8PSG.DE',
        'asset_class': 'GOLD',
        'shares': 7.5,
        'current_price': 359.02,
        'current_value': 2701.30,
        'allocation_pct': 18.2,
        'break_even_price': 300.0,
        'pnl': 451.30,
        'roi_pct': 20.0,
      }
    ],
    'savings_plan': {
      'monthly_deposit': 500.0,
      'frequency': 'monthly',
      'allocation_equity_pct': 80.0,
      'allocation_gold_pct': 20.0,
      'is_active': true,
    },
    'transactions': [
      {
        'id': 1,
        'date': '2026-10-01',
        'amount': 500.0,
        'equity_amount': 400.0,
        'gold_amount': 100.0,
        'note': 'Aportación periódica automatizada',
      }
    ],
  });
}

RebalanceAdvice _createMockRebalanceAdvice() {
  return RebalanceAdvice.fromJson({
    'portfolio_id': 1,
    'user_id': 1,
    'current_portfolio_value': 14850.50,
    'monthly_deposit': 500.0,
    'post_rebalance_portfolio_value': 15350.50,
    'rebalance_status': 'PARTIALLY_REBALANCED',
    'summary_message':
        'Destina 145.00€ a Xetra-Gold para reequilibrar la desviación del -1.8%.',
    'assets': [
      {
        'ticker': 'VWCE.DE',
        'asset_class': 'EQUITY',
        'current_value': 12149.20,
        'current_allocation_pct': 81.8,
        'target_allocation_pct': 80.0,
        'drift_pct': 1.8,
        'drift_amount': 267.31,
        'suggested_deposit': 355.0,
        'suggested_deposit_pct': 71.0,
        'projected_value': 12504.20,
        'projected_allocation_pct': 81.46,
      },
      {
        'ticker': '8PSG.DE',
        'asset_class': 'GOLD',
        'current_value': 2701.30,
        'current_allocation_pct': 18.2,
        'target_allocation_pct': 20.0,
        'drift_pct': -1.8,
        'drift_amount': -267.31,
        'suggested_deposit': 145.0,
        'suggested_deposit_pct': 29.0,
        'projected_value': 2846.30,
        'projected_allocation_pct': 18.54,
      }
    ],
  });
}

EtfData _createMockEtf(String ticker, double price, double change, int score) {
  return EtfData(
    ticker: ticker,
    currentPrice: price,
    changePercent: change,
    sentimentScore: score,
    aiSummary: 'Análisis automatizado para $ticker con sentimiento $score.',
    news: [
      'Titular optimista sobre el crecimiento de $ticker en mercados globales.',
      'Resultados trimestrales alineados con expectativas macroeconómicas.',
    ],
  );
}

List<EtfHistoryEntry> _createMockHistory(String ticker) {
  return [
    EtfHistoryEntry(
      id: 1,
      ticker: ticker,
      price: 170.0,
      changePercent: 1.2,
      sentimentScore: 68,
      aiSummary: 'Resumen histórico 1',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
    ),
    EtfHistoryEntry(
      id: 2,
      ticker: ticker,
      price: 172.5,
      changePercent: 1.5,
      sentimentScore: 72,
      aiSummary: 'Resumen histórico 2',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
}

(EtfProvider, PortfolioProvider, BankingProvider, NotificationProvider)
    _createPopulatedProviders() {
  final mockClient = MockClient((request) async {
    final uri = request.url.path;
    if (uri.contains('/banking/accounts')) {
      return http.Response(
        json.encode([
          {
            'id': 1,
            'user_id': 1,
            'broker_name': 'Trade Republic',
            'account_reference': 'TR-DE-882194',
            'sync_status': 'SYNCED',
            'last_synced_at': '2026-10-13T10:00:00Z',
          }
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (uri.contains('/notifications')) {
      return http.Response(
        json.encode([]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{}', 200, headers: {'content-type': 'application/json'});
  });

  final apiService = ApiService(client: mockClient);

  final etfProvider = EtfProvider(apiService: apiService);
  etfProvider.setEtfDataForTesting(
    'SWDA.L',
    _createMockEtf('SWDA.L', 105.20, 0.85, 75),
    _createMockHistory('SWDA.L'),
  );
  etfProvider.setEtfDataForTesting(
    'CSPX.L',
    _createMockEtf('CSPX.L', 580.40, 1.10, 80),
    _createMockHistory('CSPX.L'),
  );
  etfProvider.setEtfDataForTesting(
    'VWRA.L',
    _createMockEtf('VWRA.L', 132.80, 0.95, 78),
    _createMockHistory('VWRA.L'),
  );
  etfProvider.setEtfDataForTesting(
    'VWCE.DE',
    _createMockEtf('VWCE.DE', 173.56, 1.25, 78),
    _createMockHistory('VWCE.DE'),
  );
  etfProvider.setEtfDataForTesting(
    'EUNL.DE',
    _createMockEtf('EUNL.DE', 98.42, 0.45, 65),
    _createMockHistory('EUNL.DE'),
  );
  etfProvider.setEtfDataForTesting(
    '8PSG.DE',
    _createMockEtf('8PSG.DE', 359.02, -0.62, 52),
    _createMockHistory('8PSG.DE'),
  );

  final portfolioProvider = PortfolioProvider(apiService: apiService);
  portfolioProvider.setPortfolioForTesting(_createMockPortfolio());
  portfolioProvider.setRebalanceAdviceForTesting(_createMockRebalanceAdvice());

  final bankingProvider = BankingProvider(apiService: apiService);
  final notificationProvider = NotificationProvider();

  return (etfProvider, portfolioProvider, bankingProvider, notificationProvider);
}

void main() {
  group('Phase 21: Adaptive Navigation Tests', () {
    testWidgets(
        '1. Desktop Layout (>= 800px) renders NavigationRail and suppresses BottomNavigationBar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final (etf, portfolio, banking, notif) = _createPopulatedProviders();

      await tester.pumpWidget(
        EtfSentimentApp(
          etfProvider: etf,
          portfolioProvider: portfolio,
          bankingProvider: banking,
          notificationProvider: notif,
        ),
      );
      await tester.pumpAndSettle();

      // En resolución de escritorio (1024px) debe haber NavigationRail y no BottomNavigationBar
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);

      // Los 3 destinos deben estar presentes en el NavigationRail
      expect(find.text('Mercado'), findsOneWidget);
      expect(find.text('Mi Cartera'), findsOneWidget);
      expect(find.text('Cuentas'), findsOneWidget);
    });

    testWidgets(
        '2. Desktop NavigationRail allows switching between Mercado, Mi Cartera, and Cuentas tabs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final (etf, portfolio, banking, notif) = _createPopulatedProviders();

      await tester.pumpWidget(
        EtfSentimentApp(
          etfProvider: etf,
          portfolioProvider: portfolio,
          bankingProvider: banking,
          notificationProvider: notif,
        ),
      );
      await tester.pumpAndSettle();

      // Navegar a "Mi Cartera" en el NavigationRail
      await tester.tap(find.text('Mi Cartera'));
      await tester.pumpAndSettle();

      // Comprobar que se muestra la pantalla de Cartera
      expect(find.text('FINTECH & ASSET ALLOCATION'), findsOneWidget);

      // Navegar a "Cuentas" en el NavigationRail
      await tester.tap(find.text('Cuentas'));
      await tester.pumpAndSettle();

      // Comprobar que se muestra la pantalla de Cuentas bancarias
      expect(find.text('OPEN BANKING & BROKERS'), findsOneWidget);

      // Regresar a "Mercado"
      await tester.tap(find.text('Mercado'));
      await tester.pumpAndSettle();

      expect(find.text('MARKET SENTIMENT'), findsOneWidget);
    });

    testWidgets(
        '3. Mobile Layout (< 800px) retains BottomNavigationBar and suppresses NavigationRail',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(700, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final (etf, portfolio, banking, notif) = _createPopulatedProviders();

      await tester.pumpWidget(
        EtfSentimentApp(
          etfProvider: etf,
          portfolioProvider: portfolio,
          bankingProvider: banking,
          notificationProvider: notif,
        ),
      );
      await tester.pumpAndSettle();

      // En < 800px debe renderizarse BottomNavigationBar y omitirse NavigationRail
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  group('Phase 21: Responsive Market Content Tests', () {
    testWidgets(
        '4. Desktop Market Screen displays ETF cards in a responsive GridView with active card badge',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final (etf, portfolio, banking, notif) = _createPopulatedProviders();

      await tester.pumpWidget(
        EtfSentimentApp(
          etfProvider: etf,
          portfolioProvider: portfolio,
          bankingProvider: banking,
          notificationProvider: notif,
        ),
      );
      await tester.pumpAndSettle();

      // Comprobar que el GridView de tarjetas de ETF existe
      expect(find.byType(GridView), findsOneWidget);

      // Debe haber tarjetas de ETF renderizadas
      expect(find.byType(EtfCardWidget), findsNWidgets(3));

      // El badge "ACTIVO" debe estar en el ETF seleccionado (índice 0: VWCE.DE)
      expect(find.text('ACTIVO'), findsOneWidget);

      // Al hacer tap sobre la segunda tarjeta (EUNL.DE), cambia la selección activa
      final secondCard = find.byType(EtfCardWidget).at(1);
      await tester.tap(secondCard);
      await tester.pumpAndSettle();

      // Debe permanecer el badge "ACTIVO" en la tarjeta seleccionada
      expect(find.text('ACTIVO'), findsOneWidget);
      expect(etf.selectedIndex, 1);
    });
  });

  group('Phase 21: Responsive Portfolio 60/40 Split Tests', () {
    testWidgets(
        '5. Desktop Portfolio Screen renders 60% Left Column (3D Diorama) and 40% Right Column (DCA / Rebalancing)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final (etf, portfolio, banking, notif) = _createPopulatedProviders();

      await tester.pumpWidget(
        EtfSentimentApp(
          etfProvider: etf,
          portfolioProvider: portfolio,
          bankingProvider: banking,
          notificationProvider: notif,
        ),
      );
      await tester.pumpAndSettle();

      // Ir al tab de Cartera
      await tester.tap(find.text('Mi Cartera'));
      await tester.pumpAndSettle();

      // Comprobar la presencia del visor 3D
      expect(find.byType(SpatialPortfolioWidget), findsOneWidget);

      // Comprobar que existen widgets Expanded con flex 6 y flex 4 correspondientes al split 60/40
      final expandedWidgets =
          tester.widgetList<Expanded>(find.byType(Expanded)).toList();

      final flex6Widgets = expandedWidgets.where((w) => w.flex == 6).toList();
      final flex4Widgets = expandedWidgets.where((w) => w.flex == 4).toList();

      expect(flex6Widgets.isNotEmpty, isTrue,
          reason: 'Debe existir una columna izquierda con flex: 6 (60%)');
      expect(flex4Widgets.isNotEmpty, isTrue,
          reason: 'Debe existir una columna derecha con flex: 4 (40%)');

      // Comprobar que en la columna derecha se encuentra el simulador DCA
      expect(find.text('SIMULADOR DCA & PLAN DE AHORRO'), findsOneWidget);
      expect(find.text('DYNAMIC REBALANCING'), findsOneWidget);
    });
  });

  group('Phase 21: Desktop Mouse UX & Hover Interactions', () {
    testWidgets(
        '6. GlassCard provides hover elevation and border feedback on mouse enter/exit',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GlassCard(
                borderRadius: 16.0,
                borderColor: Colors.white.withValues(alpha: 0.10),
                hoverBorderColor: Colors.cyanAccent,
                child: const SizedBox(
                  width: 200,
                  height: 100,
                  child: Text('Desktop Hover Test'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Desktop Hover Test'), findsOneWidget);

      // Verificar que el widget incluye MouseRegion
      final mouseRegionFinder = find.descendant(
        of: find.byType(GlassCard),
        matching: find.byType(MouseRegion),
      );
      expect(mouseRegionFinder, findsOneWidget);

      // Simular movimiento del ratón con pointer mouse
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      // Mover el puntero sobre el GlassCard
      await gesture.moveTo(tester.getCenter(find.byType(GlassCard)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // El AnimatedContainer interno debe haber reaccionado con elevación (-3.0)
      final animatedContainers = tester
          .widgetList<AnimatedContainer>(find.descendant(
            of: find.byType(GlassCard),
            matching: find.byType(AnimatedContainer),
          ))
          .toList();
      expect(animatedContainers.isNotEmpty, isTrue);

      final outerContainer = animatedContainers.first;
      expect(outerContainer.transform, isNotNull);

      // Retirar el cursor del GlassCard
      await gesture.moveTo(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      final restoredContainers = tester
          .widgetList<AnimatedContainer>(find.descendant(
            of: find.byType(GlassCard),
            matching: find.byType(AnimatedContainer),
          ))
          .toList();
      expect(restoredContainers.first.transform, Matrix4.identity());
    });

    testWidgets(
        '7. SpatialPortfolioWidget 3D canvas is configured with SystemMouseCursors.grab for drag interaction',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpatialPortfolioWidget(
              height: 360.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Buscar MouseRegion con el cursor de agarre interactivo (grab)
      final grabMouseRegions = tester
          .widgetList<MouseRegion>(find.byType(MouseRegion))
          .where((mr) => mr.cursor == SystemMouseCursors.grab)
          .toList();

      expect(grabMouseRegions.isNotEmpty, isTrue,
          reason:
              'El canvas 3D de SpatialPortfolioWidget debe configurar SystemMouseCursors.grab para desktop UX.');
    });
  });

  group('Phase 21: Multi-Resolution Layout & Zero Overflow Verification', () {
    const resolutions = [
      Size(800, 600), // Desktop lower threshold
      Size(1024, 768), // Standard desktop / iPad landscape
      Size(1440, 900), // Widescreen desktop
      Size(1920, 1080), // Full HD monitor
    ];

    for (final res in resolutions) {
      testWidgets(
          '8. Renders cleanly with zero RenderFlex overflow at ${res.width.toInt()}x${res.height.toInt()}',
          (WidgetTester tester) async {
        tester.view.physicalSize = res;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final (etf, portfolio, banking, notif) = _createPopulatedProviders();

        await tester.pumpWidget(
          EtfSentimentApp(
            etfProvider: etf,
            portfolioProvider: portfolio,
            bankingProvider: banking,
            notificationProvider: notif,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Tab Mercado: sin excepciones
        expect(tester.takeException(), isNull);
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.text('MARKET SENTIMENT'), findsOneWidget);

        // 2. Tab Mi Cartera: sin excepciones
        await tester.tap(find.text('Mi Cartera'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('FINTECH & ASSET ALLOCATION'), findsOneWidget);

        // 3. Tab Cuentas: sin excepciones
        await tester.tap(find.text('Cuentas'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('OPEN BANKING & BROKERS'), findsOneWidget);
      });
    }
  });
}
