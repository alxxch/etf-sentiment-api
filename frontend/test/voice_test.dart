import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/portfolio_provider.dart';
import 'package:frontend/providers/voice_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/widgets/voice_assistant_button.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  group('VoiceProvider Unit Tests', () {
    test('Initial state is idle and has empty text', () {
      final provider = VoiceProvider();
      expect(provider.state, VoiceState.idle);
      expect(provider.isIdle, isTrue);
      expect(provider.isListening, isFalse);
      expect(provider.isProcessing, isFalse);
      expect(provider.isSpeaking, isFalse);
      expect(provider.hasError, isFalse);
      expect(provider.transcribedText, isEmpty);
      expect(provider.assistantResponse, isEmpty);
      expect(provider.errorMessage, isNull);
    });

    test('State changes and transcribed text updates correctly', () {
      final provider = VoiceProvider();

      provider.setStateForTesting(VoiceState.listening);
      expect(provider.isListening, isTrue);

      provider.setTranscribedTextForTesting(
          'Simula una aportación de 100 euros al oro');
      expect(
          provider.transcribedText, 'Simula una aportación de 100 euros al oro');

      provider.cancelListening();
      expect(provider.isIdle, isTrue);
      expect(provider.transcribedText, isEmpty);
    });

    test(
        'Stop listening sends prompt to backend, parses response, and transitions to speaking',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/assistant/chat');
        final reqBody = json.decode(request.body) as Map<String, dynamic>;
        expect(reqBody['user_prompt'], '¿Cómo va mi cartera?');

        return http.Response(
          json.encode({
            'text_response':
                'Tu cartera está valorada en 1500€ con un 15% de ROI.',
            'action_type': 'PORTFOLIO_QUERY',
            'action_executed': 'get_portfolio_summary',
            'tool_args': {},
            'data_payload': {
              'current_value': 1500.0,
              'total_invested': 1300.0,
              'roi_pct': 15.38,
            },
            'audio_base64': null,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiService = ApiService(client: mockClient);
      final provider = VoiceProvider(apiService: apiService);

      provider.setStateForTesting(VoiceState.listening);
      provider.setTranscribedTextForTesting('¿Cómo va mi cartera?');

      final stopFuture = provider.stopListening();
      expect(provider.isProcessing, isTrue);

      await stopFuture;
      expect(provider.isSpeaking, isTrue);
      expect(provider.assistantResponse,
          'Tu cartera está valorada en 1500€ con un 15% de ROI.');
      expect(provider.actionType, 'PORTFOLIO_QUERY');
    });

    test('VoiceProvider mutates PortfolioProvider on DCA_SIMULATED', () async {
      final portfolioProvider = PortfolioProvider();

      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'text_response': 'Simulación de 100€ al oro calculada.',
            'action_type': 'DCA_SIMULATED',
            'action_executed': 'simulate_dca_plan',
            'tool_args': {
              'monthly_deposit': 100.0,
              'allocation_gold_pct': 100.0,
              'allocation_equity_pct': 0.0,
            },
            'data_payload': {
              'status': 'success',
              'simulation_parameters': {
                'monthly_deposit': 100.0,
                'allocation_gold_pct': 100.0,
                'allocation_equity_pct': 0.0,
                'months': 6,
              },
            },
            'audio_base64': null,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiService = ApiService(client: mockClient);
      final voiceProvider = VoiceProvider(
        apiService: apiService,
        portfolioProvider: portfolioProvider,
      );

      voiceProvider.setStateForTesting(VoiceState.listening);
      voiceProvider.setTranscribedTextForTesting('aporta 100 euros al oro');

      await voiceProvider.stopListening();

      // Sliders en PortfolioProvider deben actualizarse de forma reactiva
      expect(portfolioProvider.monthlyDeposit, 100.0);
      expect(portfolioProvider.allocationGoldPct, 100.0);
      expect(portfolioProvider.allocationEquityPct, 0.0);
    });
  });

  group('VoiceAssistantButton Widget Tests', () {
    testWidgets('Renders microphone button in idle state', (tester) async {
      final voiceProvider = VoiceProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<VoiceProvider>.value(
              value: voiceProvider,
              child: const Center(
                child: VoiceAssistantButton(),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VoiceAssistantButton), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.text('ESCUCHANDO...'), findsNothing);
    });

    testWidgets('Shows listening overlay card with live transcribed text',
        (tester) async {
      final voiceProvider = VoiceProvider();
      voiceProvider.setStateForTesting(VoiceState.listening);
      voiceProvider.setTranscribedTextForTesting('Aporta 50€ al mundo');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<VoiceProvider>.value(
              value: voiceProvider,
              child: const Center(
                child: VoiceAssistantButton(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('ESCUCHANDO...'), findsOneWidget);
      expect(find.text('Aporta 50€ al mundo'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tapping cancel button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(voiceProvider.isIdle, isTrue);
      expect(voiceProvider.transcribedText, isEmpty);
    });

    testWidgets('Shows processing state indicator when parsing voice',
        (tester) async {
      final voiceProvider = VoiceProvider();
      voiceProvider.setStateForTesting(VoiceState.processing);
      voiceProvider
          .setTranscribedTextForTesting('¿Cuál es el sentimiento del mercado?');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<VoiceProvider>.value(
              value: voiceProvider,
              child: const Center(
                child: VoiceAssistantButton(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('PROCESANDO...'), findsOneWidget);
      expect(find.text('Analizando tu consulta financiera...'), findsOneWidget);
      expect(
          find.text('"¿Cuál es el sentimiento del mercado?"'), findsOneWidget);
    });

    testWidgets('Shows speaking state with assistant response and volume icon',
        (tester) async {
      final voiceProvider = VoiceProvider();
      voiceProvider.setStateForTesting(VoiceState.speaking);
      voiceProvider.setTranscribedTextForTesting('¿Cómo va mi cartera?');
      voiceProvider.setAssistantResponseForTesting(
          'Tu cartera acumula 1512€ con una rentabilidad del +152%.');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<VoiceProvider>.value(
              value: voiceProvider,
              child: const Center(
                child: VoiceAssistantButton(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('ASISTENTE RESPONDIENDO...'), findsOneWidget);
      expect(
        find.text('Tu cartera acumula 1512€ con una rentabilidad del +152%.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.volume_up_rounded), findsAtLeastNWidgets(1));

      // Tapping the button stops speaking
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pump();

      expect(voiceProvider.isIdle, isTrue);
    });
  });
}
