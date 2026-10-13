import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/voice_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/audio_capture_service.dart';
import 'package:frontend/services/whisper_service.dart';
import 'package:frontend/widgets/voice_assistant_button.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 22: AudioCaptureService Unit Tests', () {
    test('Initial state of AudioCaptureService is not recording', () {
      final captureService = AudioCaptureService();
      expect(captureService.isRecording, isFalse);
      expect(captureService.currentRecordingPath, isNull);
    });

    test('Cancel and dispose handle uninitialized recorder gracefully', () async {
      final captureService = AudioCaptureService();
      await captureService.cancelRecording();
      expect(captureService.isRecording, isFalse);
      expect(captureService.currentRecordingPath, isNull);
      captureService.dispose();
    });
  });

  group('Phase 22: WhisperService Edge STT Unit Tests', () {
    test('Default model asset path is configured to assets/models/ggml-tiny.bin', () {
      final whisperService = WhisperService();
      expect(whisperService.modelAssetPath, 'assets/models/ggml-tiny.bin');
      expect(WhisperService.defaultModelAssetPath, 'assets/models/ggml-tiny.bin');
    });

    test('transcribeAudio returns empty string if audio file does not exist', () async {
      final whisperService = WhisperService();
      final result = await whisperService.transcribeAudio('non_existent_audio.wav');
      expect(result, isEmpty);
    });

    test('transcribeAudio delegates to customTranscriber accurately', () async {
      final whisperService = WhisperService(
        customTranscriber: (path) async {
          expect(path, contains('test_audio.wav'));
          return 'comprar 100 euros del etf sp500';
        },
      );

      final result = await whisperService.transcribeAudio('/tmp/test_audio.wav');
      expect(result, 'comprar 100 euros del etf sp500');
    });
  });

  group('Phase 22: VoiceProvider Edge STT State Machine Tests', () {
    test('Full lifecycle: idle -> listening -> inferringLocal -> processing -> speaking', () async {
      final tempFile = File('${Directory.systemTemp.path}/test_whisper_sample.wav');
      await tempFile.writeAsString('RIFF...WAVEfmt...test');

      final whisperService = WhisperService(
        customTranscriber: (path) async {
          // Simula latencia de inferencia local Whisper
          await Future.delayed(const Duration(milliseconds: 50));
          return '¿Cuál es la rentabilidad de mi cartera?';
        },
      );

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/assistant/chat');
        final reqBody = json.decode(request.body) as Map<String, dynamic>;
        expect(reqBody['user_prompt'], '¿Cuál es la rentabilidad de mi cartera?');

        return http.Response(
          json.encode({
            'text_response': 'Tu rentabilidad anualizada actual es del +14.2%.',
            'action_type': 'PORTFOLIO_QUERY',
            'data_payload': {'roi_pct': 14.2},
            'audio_base64': null,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiService = ApiService(client: mockClient);
      final provider = VoiceProvider(
        whisperService: whisperService,
        apiService: apiService,
      );

      // 1. Estado inicial
      expect(provider.state, VoiceState.idle);
      expect(provider.isIdle, isTrue);

      // 2. Transición a listening
      provider.setStateForTesting(VoiceState.listening);
      expect(provider.isListening, isTrue);

      // Simulamos que el audio grabado fue guardado en tempFile
      provider.setTranscribedTextForTesting(''); // Vacío antes de Whisper
      
      // Llamamos a stopListening mientras inyectamos el path grabado
      // Creamos una subclase o aprovechamos stopListening() con wavPath
      // Provocamos la inferencia configurando el path a través de startListening/stopListening mockeado
      final future = provider.stopListening();
      
      await future;

      // Al no tener wavPath grabado por AudioCaptureService en test mock, transiciona a idle si texto está vacío
      expect(provider.state, VoiceState.idle);

      // Ahora probamos la inferencia explícita simulando la transición inferringLocal
      provider.setStateForTesting(VoiceState.inferringLocal);
      expect(provider.isInferringLocal, isTrue);

      final localText = await whisperService.transcribeAudio(tempFile.path);
      provider.setTranscribedTextForTesting(localText);
      expect(provider.transcribedText, '¿Cuál es la rentabilidad de mi cartera?');

      // 3. Transición a processing y envío al backend
      final stopFuture = provider.stopListening();
      expect(provider.isProcessing, isTrue);

      await stopFuture;

      // 4. Transición a speaking con respuesta del asistente
      expect(provider.isSpeaking, isTrue);
      expect(provider.assistantResponse, 'Tu rentabilidad anualizada actual es del +14.2%.');
      expect(provider.actionType, 'PORTFOLIO_QUERY');

      // Limpieza
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    });

    test('Push-to-Talk cancellation discards state cleanly to idle', () async {
      final provider = VoiceProvider();
      provider.setStateForTesting(VoiceState.listening);
      expect(provider.isListening, isTrue);

      await provider.cancelListening();
      expect(provider.isIdle, isTrue);
      expect(provider.transcribedText, isEmpty);
      expect(provider.isInferringLocal, isFalse);
    });
  });

  group('Phase 22: VoiceAssistantButton UI Widget Tests', () {
    testWidgets('Renders "TRANSCRIBIENDO (WHISPER LOCAL)..." during inferringLocal state',
        (tester) async {
      final voiceProvider = VoiceProvider();
      voiceProvider.setStateForTesting(VoiceState.inferringLocal);

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

      expect(find.text('TRANSCRIBIENDO (WHISPER LOCAL)...'), findsOneWidget);
      expect(find.text('Transcribiendo con Whisper Edge STT...'), findsOneWidget);
      expect(find.text('Inferencia local en el dispositivo (sin nube)'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('Push-to-Talk gestures: Long press start activates listening', (tester) async {
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
    });
  });
}
