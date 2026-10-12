import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/voice_provider.dart';
import 'package:frontend/widgets/voice_assistant_button.dart';
import 'package:provider/provider.dart';

void main() {
  group('VoiceProvider Unit Tests', () {
    test('Initial state is idle and has empty text', () {
      final provider = VoiceProvider();
      expect(provider.state, VoiceState.idle);
      expect(provider.isIdle, isTrue);
      expect(provider.isListening, isFalse);
      expect(provider.isProcessing, isFalse);
      expect(provider.hasError, isFalse);
      expect(provider.transcribedText, isEmpty);
      expect(provider.errorMessage, isNull);
    });

    test('State changes and transcribed text updates correctly', () {
      final provider = VoiceProvider();

      provider.setStateForTesting(VoiceState.listening);
      expect(provider.isListening, isTrue);

      provider.setTranscribedTextForTesting('Simula una aportación de 100 euros al oro');
      expect(provider.transcribedText, 'Simula una aportación de 100 euros al oro');

      provider.cancelListening();
      expect(provider.isIdle, isTrue);
      expect(provider.transcribedText, isEmpty);
    });

    test('Stop listening with text triggers mock network processing then returns to idle', () async {
      final provider = VoiceProvider();
      provider.setStateForTesting(VoiceState.listening);
      provider.setTranscribedTextForTesting('¿Cómo va mi cartera?');

      final stopFuture = provider.stopListening();
      expect(provider.isProcessing, isTrue);

      await stopFuture;
      expect(provider.isIdle, isTrue);
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

    testWidgets('Shows listening overlay card with live transcribed text', (tester) async {
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

      // Pump single frame
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

    testWidgets('Shows processing state indicator when parsing voice', (tester) async {
      final voiceProvider = VoiceProvider();
      voiceProvider.setStateForTesting(VoiceState.processing);
      voiceProvider.setTranscribedTextForTesting('¿Cuál es el sentimiento del mercado?');

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
      expect(find.text('"¿Cuál es el sentimiento del mercado?"'), findsOneWidget);
    });
  });
}
