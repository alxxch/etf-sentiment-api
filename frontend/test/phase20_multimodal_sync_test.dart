import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/portfolio_models.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/providers/portfolio_provider.dart';
import 'package:frontend/providers/voice_provider.dart';
import 'package:frontend/screens/portfolio_screen.dart';
import 'package:frontend/widgets/spatial_portfolio_widget.dart';
import 'package:provider/provider.dart';

void main() {
  group('Phase 20: Sincronización Multimodal (Voz + Cámara 3D)', () {
    testWidgets(
        '1. SpatialPortfolioWidget adapta FOV (28°) y giro (6°/s) en listening y processing',
        (WidgetTester tester) async {
      // Estado Idle inicial: FOV 38deg, Giro 20deg/s
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpatialPortfolioWidget(
              customVoiceState: VoiceState.idle,
            ),
          ),
        ),
      );

      expect(find.byType(SpatialPortfolioWidget), findsOneWidget);
      expect(find.textContaining('FOV: 38deg'), findsOneWidget);
      expect(find.textContaining('Giro: 20deg'), findsOneWidget);
      expect(find.textContaining('Voz: IDLE'), findsOneWidget);

      // Transición a Listening: Zoom-in (FOV 28deg) y rotación ralentizada (6deg)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpatialPortfolioWidget(
              customVoiceState: VoiceState.listening,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('FOV: 28deg'), findsOneWidget);
      expect(find.textContaining('Giro: 6deg'), findsOneWidget);
      expect(find.textContaining('Voz: LISTENING'), findsOneWidget);
      expect(find.text('ATENCIÓN CONVERSACIONAL • ZOOM 28°'), findsOneWidget);

      // Transición a Processing: Mantiene FOV 28deg y rotación atenta
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpatialPortfolioWidget(
              customVoiceState: VoiceState.processing,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('FOV: 28deg'), findsOneWidget);
      expect(find.textContaining('Giro: 6deg'), findsOneWidget);
      expect(find.textContaining('Voz: PROCESSING'), findsOneWidget);
      expect(find.text('PROCESANDO CONSULTA...'), findsOneWidget);
    });

    testWidgets(
        '2. SpatialPortfolioWidget activa animación de pulso TTS en speaking y regresa a defaults en idle',
        (WidgetTester tester) async {
      final voiceProvider = VoiceProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<VoiceProvider>.value(
          value: voiceProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: SpatialPortfolioWidget(),
            ),
          ),
        ),
      );

      expect(find.textContaining('Voz: IDLE'), findsOneWidget);
      expect(find.text('ASISTENTE HABLANDO • PULSO TTS ACTIVO'), findsNothing);

      // El asistente comienza a hablar (TTS ElevenLabs)
      voiceProvider.setStateForTesting(VoiceState.speaking);
      await tester.pump();

      // Comprobar feedback de speaking activo
      expect(find.textContaining('Voz: SPEAKING'), findsOneWidget);
      expect(find.text('ASISTENTE HABLANDO • PULSO TTS ACTIVO'), findsOneWidget);

      // Avanzar frames para verificar oscilación del pulso
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SpatialPortfolioWidget), findsOneWidget);

      // Audio finaliza -> retorno suave a idle
      voiceProvider.setStateForTesting(VoiceState.idle);
      await tester.pumpAndSettle();

      expect(find.textContaining('Voz: IDLE'), findsOneWidget);
      expect(find.textContaining('FOV: 38deg'), findsOneWidget);
      expect(find.textContaining('Giro: 20deg'), findsOneWidget);
      expect(find.text('ASISTENTE HABLANDO • PULSO TTS ACTIVO'), findsNothing);
    });

    testWidgets(
        '3. PortfolioScreen atenúa tarjetas circundantes (opacity: 0.35) manteniendo foco central en el diorama 3D',
        (WidgetTester tester) async {
      final portfolioProvider = PortfolioProvider();
      final portfolioJson = {
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
        'market_sentiment_score': 65,
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
      portfolioProvider.setPortfolioForTesting(PortfolioStatus.fromJson(portfolioJson));

      // Caso A: Asistente en estado Idle (opacidad normal 1.0)
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PortfolioProvider>.value(
              value: portfolioProvider,
            ),
            ChangeNotifierProvider<NotificationProvider>(
              create: (_) => NotificationProvider(),
            ),
          ],
          child: const MaterialApp(
            home: PortfolioScreen(
              customVoiceState: VoiceState.idle,
            ),
          ),
        ),
      );
      await tester.pump();

      // Todas las tarjetas deben tener opacidad 1.0
      final initialOpacities = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .map((w) => w.opacity)
          .toList();

      expect(initialOpacities.isNotEmpty, true);
      for (final opacity in initialOpacities) {
        expect(opacity, 1.0);
      }

      // Caso B: El usuario activa la voz (listening)
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PortfolioProvider>.value(
              value: portfolioProvider,
            ),
            ChangeNotifierProvider<NotificationProvider>(
              create: (_) => NotificationProvider(),
            ),
          ],
          child: const MaterialApp(
            home: PortfolioScreen(
              customVoiceState: VoiceState.listening,
            ),
          ),
        ),
      );
      await tester.pump();

      // Las tarjetas circundantes deben atenuarse a 0.35 para focalizar la atención en el 3D
      final dimmedOpacities = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .map((w) => w.opacity)
          .toList();

      expect(dimmedOpacities.isNotEmpty, true);
      for (final opacity in dimmedOpacities) {
        expect(opacity, 0.35);
      }

      // El visor espacial 3D sigue presente y en foco
      expect(find.byType(SpatialPortfolioWidget), findsOneWidget);
      expect(find.text('ATENCIÓN CONVERSACIONAL • ZOOM 28°'), findsOneWidget);

      // Caso C: Retorno a Idle tras la conversación -> Restauración de opacidad
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PortfolioProvider>.value(
              value: portfolioProvider,
            ),
            ChangeNotifierProvider<NotificationProvider>(
              create: (_) => NotificationProvider(),
            ),
          ],
          child: const MaterialApp(
            home: PortfolioScreen(
              customVoiceState: VoiceState.idle,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final restoredOpacities = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .map((w) => w.opacity)
          .toList();

      for (final opacity in restoredOpacities) {
        expect(opacity, 1.0);
      }
    });
  });
}
