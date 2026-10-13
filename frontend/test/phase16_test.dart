import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/broker_account.dart';
import 'package:frontend/models/notification_item.dart';
import 'package:frontend/models/rebalance_advice.dart';
import 'package:frontend/providers/banking_provider.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/screens/banking_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/widgets/rebalance_card_widget.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  group('Phase 16 - Models Serialization Tests', () {
    test('BrokerAccount.fromJson parses correctly and evaluates status helpers', () {
      final jsonSynced = {
        'id': 1,
        'user_id': 1,
        'broker_name': 'Trade Republic',
        'account_reference': 'TR-DE-882194',
        'sync_status': 'SYNCED',
        'last_synced_at': '2026-10-12T18:00:00Z',
      };
      final account = BrokerAccount.fromJson(jsonSynced);
      expect(account.id, 1);
      expect(account.userId, 1);
      expect(account.brokerName, 'Trade Republic');
      expect(account.accountReference, 'TR-DE-882194');
      expect(account.syncStatus, 'SYNCED');
      expect(account.isSynced, isTrue);
      expect(account.isPending, isFalse);
      expect(account.isError, isFalse);
      expect(account.lastSyncedAt, isNotNull);

      final jsonError = {
        'id': 2,
        'broker_name': 'Scalable Capital',
        'sync_status': 'ERROR',
      };
      final accountError = BrokerAccount.fromJson(jsonError);
      expect(accountError.isError, isTrue);
      expect(accountError.isSynced, isFalse);
    });

    test('RebalanceAdvice.fromJson parses multi-asset allocation drift correctly', () {
      final jsonAdvice = {
        'portfolio_id': 1,
        'user_id': 1,
        'current_portfolio_value': 1200.0,
        'monthly_deposit': 100.0,
        'post_rebalance_portfolio_value': 1300.0,
        'rebalance_status': 'PARTIALLY_REBALANCED',
        'summary_message':
            'Destina 100.00€ a Xetra-Gold para corregir la desviación del -7.50%.',
        'assets': [
          {
            'ticker': 'VWCE.DE',
            'asset_class': 'EQUITY',
            'current_value': 1050.0,
            'current_allocation_pct': 87.5,
            'target_allocation_pct': 80.0,
            'drift_pct': 7.5,
            'drift_amount': 90.0,
            'suggested_deposit': 0.0,
            'suggested_deposit_pct': 0.0,
            'projected_value': 1050.0,
            'projected_allocation_pct': 80.77,
          },
          {
            'ticker': '8PSG.DE',
            'asset_class': 'GOLD',
            'current_value': 150.0,
            'current_allocation_pct': 12.5,
            'target_allocation_pct': 20.0,
            'drift_pct': -7.5,
            'drift_amount': -90.0,
            'suggested_deposit': 100.0,
            'suggested_deposit_pct': 100.0,
            'projected_value': 250.0,
            'projected_allocation_pct': 19.23,
          }
        ],
      };

      final advice = RebalanceAdvice.fromJson(jsonAdvice);
      expect(advice.portfolioId, 1);
      expect(advice.userId, 1);
      expect(advice.monthlyDeposit, 100.0);
      expect(advice.currentPortfolioValue, 1200.0);
      expect(advice.postRebalancePortfolioValue, 1300.0);
      expect(advice.assets.length, 2);
      expect(advice.isFullyRebalanced, isFalse);
      expect(advice.isPartiallyRebalanced, isTrue);
      expect(advice.isBalanced, isFalse);

      final equity = advice.assets.first;
      expect(equity.ticker, 'VWCE.DE');
      expect(equity.currentAllocationPct, 87.5);
      expect(equity.targetAllocationPct, 80.0);
      expect(equity.driftPct, 7.5);
      expect(equity.driftAmount, 90.0);
      expect(equity.suggestedDeposit, 0.0);

      final gold = advice.assets.last;
      expect(gold.ticker, '8PSG.DE');
      expect(gold.currentAllocationPct, 12.5);
      expect(gold.driftPct, -7.5);
      expect(gold.suggestedDeposit, 100.0);
    });

    test('NotificationItem.fromJson and copyWith work as expected', () {
      final jsonNotif = {
        'id': 42,
        'user_id': 1,
        'title': 'Oportunidad de Mercado: VWCE.DE',
        'message': 'VWCE.DE ha caído un 3.5% hoy. Buen momento para aportar.',
        'type': 'OPPORTUNITY',
        'is_read': false,
        'timestamp': '2026-10-12T15:30:00Z',
      };

      final notif = NotificationItem.fromJson(jsonNotif);
      expect(notif.id, 42);
      expect(notif.title, 'Oportunidad de Mercado: VWCE.DE');
      expect(notif.isOpportunity, isTrue);
      expect(notif.isDrift, isFalse);
      expect(notif.isSystem, isFalse);
      expect(notif.isRead, isFalse);

      final updated = notif.copyWith(isRead: true);
      expect(updated.isRead, isTrue);
      expect(updated.id, 42);
      expect(updated.title, notif.title);
    });
  });

  group('Phase 16 - BankingProvider Tests', () {
    test('loadAccounts and syncAccount update state seamlessly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/banking/accounts') {
          return http.Response(
            json.encode([
              {
                'id': 1,
                'user_id': 1,
                'broker_name': 'Trade Republic',
                'account_reference': 'TR-DE-101',
                'sync_status': 'SYNCED',
                'last_synced_at': '2026-10-12T12:00:00Z',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/banking/sync/1') {
          return http.Response(
            json.encode({
              'status': 'SUCCESS',
              'message': 'Sincronización completada exitosamente',
              'transactions_synced': 2,
              'broker_account_id': 1,
              'synced_at': '2026-10-12T12:30:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiService = ApiService(client: mockClient);
      final bankingProvider = BankingProvider(apiService: apiService);

      expect(bankingProvider.accounts, isEmpty);
      expect(bankingProvider.isLoading, isFalse);

      await bankingProvider.loadAccounts(userId: 1);

      expect(bankingProvider.accounts.length, 1);
      expect(bankingProvider.accounts.first.brokerName, 'Trade Republic');

      final result = await bankingProvider.syncAccount(1);
      expect(result != null, isTrue);
      expect(result?['status'], 'SUCCESS');
      expect(bankingProvider.syncSuccessMessage, contains('Sincronización completada'));
    });
  });

  group('Phase 16 - NotificationProvider Tests', () {
    test('loadNotifications and markAsRead update unread counter accurately', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/v1/notifications') {
          return http.Response(
            json.encode([
              {
                'id': 10,
                'user_id': 1,
                'title': 'Desviación en Cartera',
                'message': 'Renta variable descompensada en un 7.5%.',
                'type': 'DRIFT',
                'is_read': false,
                'timestamp': '2026-10-12T10:00:00Z',
              },
              {
                'id': 11,
                'user_id': 1,
                'title': 'Aviso del Sistema',
                'message': 'Sincronización bancaria activa.',
                'type': 'SYSTEM',
                'is_read': true,
                'timestamp': '2026-10-12T09:00:00Z',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'PATCH' && request.url.path == '/api/v1/notifications/10/read') {
          return http.Response(
            json.encode({
              'id': 10,
              'user_id': 1,
              'title': 'Desviación en Cartera',
              'message': 'Renta variable descompensada en un 7.5%.',
              'type': 'DRIFT',
              'is_read': true,
              'timestamp': '2026-10-12T10:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiService = ApiService(client: mockClient);
      final notifProvider = NotificationProvider(apiService: apiService);

      expect(notifProvider.unreadCount, 0);
      expect(notifProvider.hasUnread, isFalse);

      await notifProvider.loadNotifications(userId: 1);

      expect(notifProvider.notifications.length, 2);
      expect(notifProvider.unreadCount, 1);
      expect(notifProvider.hasUnread, isTrue);

      await notifProvider.markAsRead(10);

      expect(notifProvider.unreadCount, 0);
      expect(notifProvider.hasUnread, isFalse);
    });
  });

  group('Phase 16 - Widgets & Navigation Tests', () {
    testWidgets('RebalanceCardWidget renders drift data and suggested deposit amounts',
        (WidgetTester tester) async {
      final advice = RebalanceAdvice(
        portfolioId: 1,
        userId: 1,
        currentPortfolioValue: 1200.0,
        monthlyDeposit: 100.0,
        postRebalancePortfolioValue: 1300.0,
        rebalanceStatus: 'PARTIALLY_REBALANCED',
        summaryMessage:
            'Aporta 100.00€ a Xetra-Gold para compensar el desvío del -7.50%.',
        assets: [
          const AssetRebalanceItem(
            ticker: 'VWCE.DE',
            assetClass: 'EQUITY',
            currentValue: 1050.0,
            currentAllocationPct: 87.5,
            targetAllocationPct: 80.0,
            driftPct: 7.5,
            driftAmount: 90.0,
            suggestedDeposit: 0.0,
            suggestedDepositPct: 0.0,
            projectedValue: 1050.0,
            projectedAllocationPct: 80.77,
          ),
          const AssetRebalanceItem(
            ticker: '8PSG.DE',
            assetClass: 'GOLD',
            currentValue: 150.0,
            currentAllocationPct: 12.5,
            targetAllocationPct: 20.0,
            driftPct: -7.5,
            driftAmount: -90.0,
            suggestedDeposit: 100.0,
            suggestedDepositPct: 100.0,
            projectedValue: 250.0,
            projectedAllocationPct: 19.23,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RebalanceCardWidget(advice: advice),
          ),
        ),
      );

      expect(find.text('DYNAMIC REBALANCING'), findsOneWidget);
      expect(find.text('Consejo de Rebalanceo'), findsOneWidget);
      expect(find.text('Alineación Progresiva'), findsOneWidget);
      expect(find.textContaining('VWCE.DE'), findsOneWidget);
      expect(find.textContaining('8PSG.DE'), findsOneWidget);
      expect(find.textContaining('100.00 €'), findsNWidgets(2)); // En summary o aportar y pie
    });

    testWidgets('BankingScreen renders broker cards and allows sync interaction',
        (WidgetTester tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode([
            {
              'id': 1,
              'user_id': 1,
              'broker_name': 'Trade Republic',
              'account_reference': 'TR-DE-9921',
              'sync_status': 'SYNCED',
              'last_synced_at': '2026-10-12T14:00:00Z',
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiService = ApiService(client: mockClient);
      final bankingProvider = BankingProvider(apiService: apiService);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<BankingProvider>.value(value: bankingProvider),
                ChangeNotifierProvider<NotificationProvider>(create: (_) => NotificationProvider()),
              ],
              child: const BankingScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trade Republic'), findsOneWidget);
      expect(find.text('SINCRONIZADO'), findsOneWidget);
      expect(find.text('Sincronizar Ahora'), findsOneWidget);
    });

    testWidgets('Navigation bar includes Cuentas tab and switches between all 3 tabs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(700, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const EtfSentimentApp());
      await tester.pump();

      // Verificar los 3 tabs en BottomNavigationBar
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Mercado'), findsOneWidget);
      expect(find.text('Mi Cartera'), findsOneWidget);
      expect(find.text('Cuentas'), findsOneWidget);

      // Ir a la pestaña "Cuentas"
      await tester.tap(find.text('Cuentas'));
      await tester.pumpAndSettle();

      expect(find.text('OPEN BANKING & BROKERS'), findsOneWidget);
      expect(find.text('Cuentas'), findsNWidgets(2)); // En nav bar y título

      // Volver a "Mi Cartera"
      await tester.tap(find.text('Mi Cartera'));
      await tester.pumpAndSettle();

      expect(find.text('FINTECH & ASSET ALLOCATION'), findsOneWidget);
    });
  });
}
