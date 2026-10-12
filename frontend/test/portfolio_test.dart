import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/portfolio_models.dart';

void main() {
  group('Portfolio Models Test', () {
    test('PortfolioStatus fromJson parses correctly', () {
      final json = {
        'id': 1,
        'user_id': 1,
        'user_email': 'demo@example.com',
        'user_name': 'demo',
        'name': 'Mi Cartera Principal',
        'currency': 'EUR',
        'initial_balance': 0.0,
        'total_invested': 600.0,
        'current_value': 1513.08,
        'pnl': 913.08,
        'roi_pct': 152.18,
        'market_sentiment_score': 58,
        'asset_allocation': [
          {
            'ticker': 'VWCE.DE',
            'asset_class': 'EQUITY',
            'shares': 2.8537,
            'current_price': 173.56,
            'current_value': 495.29,
            'allocation_pct': 32.7,
            'break_even_price': 168.2,
            'pnl': 15.29,
            'roi_pct': 3.19,
          },
          {
            'ticker': '8PSG.DE',
            'asset_class': 'GOLD',
            'shares': 2.8349,
            'current_price': 359.02,
            'current_value': 1017.79,
            'allocation_pct': 67.3,
            'break_even_price': 42.33,
            'pnl': 897.79,
            'roi_pct': 748.16,
          }
        ],
        'savings_plan': {
          'monthly_deposit': 200.0,
          'frequency': 'monthly',
          'allocation_equity_pct': 80.0,
          'allocation_gold_pct': 20.0,
          'is_active': true,
        },
        'transactions': [],
      };

      final status = PortfolioStatus.fromJson(json);
      expect(status.id, 1);
      expect(status.userName, 'demo');
      expect(status.totalInvested, 600.0);
      expect(status.currentValue, 1513.08);
      expect(status.isPnlPositive, true);
      expect(status.assetAllocation.length, 2);
      expect(status.assetAllocation.first.ticker, 'VWCE.DE');
      expect(status.assetAllocation.last.isGold, true);
      expect(status.savingsPlan?.monthlyDeposit, 200.0);
    });

    test('DcaSimulationResult fromJson parses correctly', () {
      final json = {
        'total_invested': 1200.0,
        'current_value': 1246.72,
        'pnl': 46.72,
        'roi_pct': 3.89,
        'equity_shares': 5.5,
        'gold_shares': 0.7,
        'break_even_equity': 174.5,
        'break_even_gold': 342.8,
        'current_equity_price': 173.56,
        'current_gold_price': 359.02,
        'transactions_count': 12,
        'allocation_equity_pct': 80.0,
        'allocation_gold_pct': 20.0,
        'steps': [
          {
            'month_index': 1,
            'date': '2026-05-15',
            'cumulative_invested': 200.0,
            'portfolio_value': 200.0,
            'pnl': 0.0,
            'roi_pct': 0.0,
            'market_sentiment_score': 65,
            'equity_price': 161.0,
            'gold_price': 339.0,
            'equity_shares_bought': 0.99,
            'gold_shares_bought': 0.11,
          }
        ],
      };

      final sim = DcaSimulationResult.fromJson(json);
      expect(sim.totalInvested, 1200.0);
      expect(sim.pnl, 46.72);
      expect(sim.steps.length, 1);
      expect(sim.steps.first.marketSentimentScore, 65);
    });
  });

  group('Navigation & Portfolio Screen Widget Test', () {
    testWidgets('Toggles between Mercado and Mi Cartera tab',
        (WidgetTester tester) async {
      await tester.pumpWidget(const EtfSentimentApp());
      await tester.pump();

      // Verificar que ambos items del BottomNavigationBar existen
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Mercado'), findsOneWidget);
      expect(find.text('Mi Cartera'), findsOneWidget);

      // Tocar en el tab "Mi Cartera"
      await tester.tap(find.text('Mi Cartera'));
      await tester.pumpAndSettle();

      // Verificar que el header de "Mi Cartera" se muestra
      expect(find.text('FINTECH & ASSET ALLOCATION'), findsOneWidget);
      expect(find.text('Mi Cartera'), findsNWidgets(2)); // En nav bar y título

      // Volver a tocar en "Mercado"
      await tester.tap(find.text('Mercado'));
      await tester.pumpAndSettle();

      expect(find.text('MARKET SENTIMENT'), findsOneWidget);
    });
  });
}
