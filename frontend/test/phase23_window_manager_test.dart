import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/etf_data.dart';
import 'package:frontend/providers/banking_provider.dart';
import 'package:frontend/providers/etf_provider.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/providers/portfolio_provider.dart';
import 'package:frontend/providers/voice_provider.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/audio_service.dart';
import 'package:frontend/widgets/custom_title_bar.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

Widget createTestApp({required Widget child}) {
  final mockClient = MockClient((request) async {
    return http.Response(json.encode([]), 200, headers: {'content-type': 'application/json'});
  });
  final apiService = ApiService(client: mockClient);

  final testEtfProvider = EtfProvider(apiService: apiService);
  testEtfProvider.setEtfDataForTesting('VWCE.DE', EtfData.mocks[0]);
  testEtfProvider.setEtfDataForTesting('EUNL.DE', EtfData.mocks[1]);
  testEtfProvider.setEtfDataForTesting('8PSG.DE', EtfData.mocks[2]);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<EtfProvider>.value(value: testEtfProvider),
      ChangeNotifierProvider<PortfolioProvider>(create: (_) => PortfolioProvider(apiService: apiService)),
      ChangeNotifierProvider<BankingProvider>(create: (_) => BankingProvider(apiService: apiService)),
      ChangeNotifierProvider<NotificationProvider>(create: (_) => NotificationProvider()),
      ChangeNotifierProvider<AudioService>(create: (_) => AudioService()),
      ChangeNotifierProvider<VoiceProvider>(create: (_) => VoiceProvider()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 23: CustomTitleBar Widget Tests', () {
    testWidgets('Renders Apple Finance design, title, v7.0 badge, and DragToMoveArea',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(
              title: 'Smart Market Sentiment & ETF Dashboard',
            ),
          ),
        ),
      );

      // Verificación de elementos clave
      expect(find.byType(CustomTitleBar), findsOneWidget);
      expect(find.byType(DragToMoveArea), findsOneWidget);
      expect(find.text('Smart Market Sentiment & ETF Dashboard'), findsOneWidget);
      expect(find.text('v7.0'), findsOneWidget);

      // Botones de control de ventana
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.crop_square_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('Triggers minimize, maximize, and close callbacks correctly',
        (tester) async {
      bool minimized = false;
      bool maximized = false;
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(
              onMinimize: () => minimized = true,
              onMaximize: () => maximized = true,
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      // 1. Pulsar minimizar
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(minimized, isTrue);

      // 2. Pulsar maximizar
      await tester.tap(find.byIcon(Icons.crop_square_rounded));
      await tester.pump();
      expect(maximized, isTrue);

      // 3. Pulsar cerrar
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(closed, isTrue);
    });
  });

  group('Phase 23: Desktop Window Manager HomeScreen Layout Integration', () {
    testWidgets('Desktop resolution (>= 800px) injects CustomTitleBar at the top',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(child: const HomeScreen()));
      await tester.pump();

      // CustomTitleBar presente en Desktop
      expect(find.byType(CustomTitleBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('Mobile resolution (< 800px) suppresses CustomTitleBar and shows BottomNavigationBar',
        (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(child: const HomeScreen()));
      await tester.pump();

      // CustomTitleBar ausente en móvil
      expect(find.byType(CustomTitleBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('Zero overflow check at minimum window size (1000x700)',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(child: const HomeScreen()));
      await tester.pump();

      // En tamaño mínimo 1000x700 se renderizan CustomTitleBar y NavigationRail sin overflow
      expect(find.byType(CustomTitleBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
