import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/etf_data.dart';
import 'package:frontend/models/etf_history_entry.dart';
import 'package:frontend/models/portfolio_models.dart';
import 'package:frontend/providers/banking_provider.dart';
import 'package:frontend/providers/etf_provider.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/providers/portfolio_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/widgets/category_selector.dart';
import 'package:frontend/widgets/etf_card_widget.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

PortfolioStatus _createMockPortfolio() {
  return PortfolioStatus.fromJson({
    'id': 1,
    'user_id': 1,
    'user_email': 'test@example.com',
    'user_name': 'tester',
    'name': 'Cartera Test',
    'currency': 'EUR',
    'initial_balance': 0.0,
    'total_invested': 10000.0,
    'current_value': 12000.0,
    'pnl': 2000.0,
    'roi_pct': 20.0,
    'market_sentiment_score': 70,
    'asset_allocation': [],
    'savings_plan': {
      'monthly_deposit': 500.0,
      'frequency': 'monthly',
      'allocation_equity_pct': 80.0,
      'allocation_gold_pct': 20.0,
      'is_active': true,
    },
    'transactions': [],
  });
}

EtfData _createMockEtf(String ticker, double price, double change, int score, {String currency = 'EUR'}) {
  return EtfData(
    ticker: ticker,
    currentPrice: price,
    changePercent: change,
    currency: currency,
    sentimentScore: score,
    aiSummary: 'Análisis automatizado para $ticker.',
    news: ['Titular para $ticker.'],
  );
}

void main() {
  group('1. EtfProvider Category State Management Tests', () {
    test('Categories map defines correct tickers and default category is ETFs', () {
      expect(EtfProvider.categories['Trending'], ['NVDA', 'TSLA', 'PLTR']);
      expect(EtfProvider.categories['ETFs'], ['SWDA.L', 'CSPX.L', 'VWRA.L']);
      expect(EtfProvider.categories['Stocks'], ['AAPL', 'MSFT', 'AMZN']);
      expect(EtfProvider.categories['Crypto'], ['BTC-USD', 'ETH-USD', 'SOL-USD']);

      final provider = EtfProvider();
      expect(provider.selectedCategory, 'ETFs');
      expect(provider.tickers, ['SWDA.L', 'CSPX.L', 'VWRA.L']);
      expect(provider.selectedIndex, 0);
      expect(provider.selectedTicker, 'SWDA.L');
    });

    test('selectCategory updates selectedCategory, tickers, and triggers data loading', () async {
      final fetchedTickers = <String>[];
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        for (final t in ['NVDA', 'TSLA', 'PLTR']) {
          if (path.contains('/sentiment/$t')) {
            fetchedTickers.add(t);
            return http.Response(
              json.encode({
                'ticker': t,
                'current_price': 135.50,
                'change_percent': 2.30,
                'currency': 'USD',
                'sentiment_score': 82,
                'ai_summary': 'Análisis de $t',
                'news': [],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.contains('/history/$t')) {
            return http.Response('[]', 200, headers: {'content-type': 'application/json'});
          }
        }
        return http.Response('{}', 404);
      });

      final apiService = ApiService(client: mockClient);
      final provider = EtfProvider(apiService: apiService);

      expect(provider.selectedCategory, 'ETFs');

      // Cambiar a Trending
      await provider.selectCategory('Trending');

      expect(provider.selectedCategory, 'Trending');
      expect(provider.tickers, ['NVDA', 'TSLA', 'PLTR']);
      expect(provider.selectedIndex, 0);
      expect(provider.selectedTicker, 'NVDA');
      expect(fetchedTickers, containsAll(['NVDA', 'TSLA', 'PLTR']));
      expect(provider.currentEtf, isNotNull);
      expect(provider.currentEtf!.ticker, 'NVDA');
      expect(provider.currentEtf!.currentPrice, 135.50);
      expect(provider.currentEtf!.currency, 'USD');
    });

    test('isTickerLoading accurately reports loading state per ticker', () {
      final provider = EtfProvider();
      provider.setEtfDataForTesting('SWDA.L', _createMockEtf('SWDA.L', 105.0, 1.0, 60));

      expect(provider.isTickerLoading('SWDA.L'), isFalse);
      expect(provider.isTickerLoading('NVDA'), isTrue); // Not in map yet
    });
  });

  group('2. CategorySelector Widget UI Tests', () {
    testWidgets('Renders horizontal list of category pill chips with proper styling',
        (WidgetTester tester) async {
      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategorySelector(
              categories: const ['Trending', 'ETFs', 'Stocks', 'Crypto'],
              selectedCategory: 'ETFs',
              onCategorySelected: (cat) => selected = cat,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que todas las categorías están presentes
      expect(find.text('Trending'), findsOneWidget);
      expect(find.text('ETFs'), findsOneWidget);
      expect(find.text('Stocks'), findsOneWidget);
      expect(find.text('Crypto'), findsOneWidget);

      // Verificar que el widget tiene SingleChildScrollView horizontal
      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);
      final scrollWidget = tester.widget<SingleChildScrollView>(scrollFinder);
      expect(scrollWidget.scrollDirection, Axis.horizontal);

      // Tocar en 'Crypto' y confirmar callback
      await tester.tap(find.text('Crypto'));
      await tester.pumpAndSettle();

      expect(selected, 'Crypto');
    });

    testWidgets('Active category is highlighted with blue border while inactive have dark surface',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategorySelector(
              categories: const ['Trending', 'ETFs'],
              selectedCategory: 'ETFs',
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Encontrar AnimatedContainer de los chips
      final containers = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
      expect(containers.length, 2);

      // Primer chip: Trending (inactivo)
      final trendingDec = containers[0].decoration as BoxDecoration;
      expect(trendingDec.color, AppColors.surfaceSecondary);

      // Segundo chip: ETFs (activo)
      final etfsDec = containers[1].decoration as BoxDecoration;
      expect(etfsDec.border!.top.color, AppColors.aiAccent);
    });
  });

  group('3. HomeScreen Reactive Integration & Category Switching', () {
    testWidgets(
        'HomeScreen displays CategorySelector under Market Dashboard and updates cards dynamically',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/sentiment/NVDA')) {
          return http.Response(
            json.encode({
              'ticker': 'NVDA',
              'current_price': 140.0,
              'change_percent': 3.5,
              'currency': 'USD',
              'sentiment_score': 85,
              'ai_summary': 'Nvidia AI chips demand surging.',
              'news': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.contains('/sentiment/TSLA')) {
          return http.Response(
            json.encode({
              'ticker': 'TSLA',
              'current_price': 220.0,
              'change_percent': -1.2,
              'currency': 'USD',
              'sentiment_score': 55,
              'ai_summary': 'Tesla deliveries quarterly update.',
              'news': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.contains('/sentiment/PLTR')) {
          return http.Response(
            json.encode({
              'ticker': 'PLTR',
              'current_price': 42.0,
              'change_percent': 5.0,
              'currency': 'USD',
              'sentiment_score': 90,
              'ai_summary': 'Palantir AIP enterprise growth.',
              'news': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.contains('/history/')) {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }
        if (path.contains('/banking/accounts')) {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }
        if (path.contains('/notifications')) {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      final apiService = ApiService(client: mockClient);
      final etfProvider = EtfProvider(apiService: apiService);

      // Pre-cargar datos para ETFs iniciales
      etfProvider.setEtfDataForTesting(
        'SWDA.L',
        _createMockEtf('SWDA.L', 105.20, 0.85, 75, currency: 'USD'),
        [
          EtfHistoryEntry(
            id: 1,
            ticker: 'SWDA.L',
            price: 102.0,
            changePercent: 0.8,
            sentimentScore: 70,
            aiSummary: 'Historial',
            timestamp: DateTime.now(),
          ),
        ],
      );
      etfProvider.setEtfDataForTesting('CSPX.L', _createMockEtf('CSPX.L', 580.40, 1.10, 80, currency: 'USD'));
      etfProvider.setEtfDataForTesting('VWRA.L', _createMockEtf('VWRA.L', 132.80, 0.95, 78, currency: 'USD'));

      final portfolioProvider = PortfolioProvider(apiService: apiService);
      portfolioProvider.setPortfolioForTesting(_createMockPortfolio());
      final bankingProvider = BankingProvider(apiService: apiService);
      final notificationProvider = NotificationProvider();

      await tester.pumpWidget(
        EtfSentimentApp(
          etfProvider: etfProvider,
          portfolioProvider: portfolioProvider,
          bankingProvider: bankingProvider,
          notificationProvider: notificationProvider,
        ),
      );
      await tester.pumpAndSettle();

      // Verificar título dinámico inicial 'ETFs Dashboard'
      expect(find.text('ETFs Dashboard'), findsOneWidget);

      // CategorySelector debe estar presente con las 4 categorías
      expect(find.byType(CategorySelector), findsOneWidget);
      expect(find.text('Trending'), findsOneWidget);
      expect(find.text('ETFs'), findsOneWidget);
      expect(find.text('Stocks'), findsOneWidget);
      expect(find.text('Crypto'), findsOneWidget);

      // Inicialmente en ETFs, se ven SWDA.L, CSPX.L, VWRA.L
      expect(find.text('SWDA.L'), findsWidgets);
      expect(find.text('CSPX.L'), findsWidgets);
      expect(find.text('VWRA.L'), findsWidgets);

      // Tocar en 'Trending'
      await tester.tap(find.text('Trending'));
      await tester.pump(); // Inicia petición asíncrona y cambia estado

      // Verificar que el título dinámico cambia inmediatamente a 'Trending Dashboard'
      expect(find.text('Trending Dashboard'), findsOneWidget);

      // Verificar que los tickers cambian a NVDA, TSLA, PLTR
      expect(find.text('NVDA'), findsWidgets);
      expect(find.text('TSLA'), findsWidgets);
      expect(find.text('PLTR'), findsWidgets);

      // Completar la carga asíncrona
      await tester.pumpAndSettle();

      // Confirmar que se han actualizado los precios de Trending
      expect(find.text('140.00'), findsOneWidget);
      expect(find.text('220.00'), findsOneWidget);
      expect(find.text('42.00'), findsOneWidget);
      expect(etfProvider.selectedCategory, 'Trending');
    });

    testWidgets('Cards display loading indicator when fetching new category prices',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EtfCardWidget(
              data: const EtfData(
                ticker: 'NVDA',
                currentPrice: 0.0,
                changePercent: 0.0,
                currency: 'USD',
                sentimentScore: 50,
                aiSummary: 'Cargando...',
              ),
              isLoading: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verificar presencia de indicador de carga y etiqueta CARGANDO
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('CARGANDO'), findsOneWidget);
      expect(find.text('Cargando cotización...'), findsOneWidget);
      expect(find.text('NVIDIA Corporation'), findsOneWidget);
    });
  });
}
