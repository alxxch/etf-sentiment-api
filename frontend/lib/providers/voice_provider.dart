import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Estados del ciclo de vida del asistente conversacional por voz
enum VoiceState {
  idle,
  listening,
  processing,
  speaking,
  error,
}

class VoiceProvider extends ChangeNotifier {
  final SpeechToText _speechToText;

  VoiceState _state = VoiceState.idle;
  String _transcribedText = '';
  String? _errorMessage;
  bool _isInitialized = false;
  double _soundLevel = 0.0;

  VoiceProvider({SpeechToText? speechToText})
      : _speechToText = speechToText ?? SpeechToText();

  // Getters
  VoiceState get state => _state;
  String get transcribedText => _transcribedText;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;
  double get soundLevel => _soundLevel;

  bool get isIdle => _state == VoiceState.idle;
  bool get isListening => _state == VoiceState.listening;
  bool get isProcessing => _state == VoiceState.processing;
  bool get isSpeaking => _state == VoiceState.speaking;
  bool get hasError => _state == VoiceState.error;

  /// Inicializa el motor Speech-to-Text y verifica permisos del sistema
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Solicitar permisos de micrófono en plataformas móviles
      if (!kIsWeb) {
        final micStatus = await Permission.microphone.request();
        if (micStatus.isPermanentlyDenied || micStatus.isDenied) {
          _errorMessage =
              'Permiso de micrófono denegado. Habilítalo en los ajustes del sistema.';
          _state = VoiceState.error;
          notifyListeners();
          return false;
        }
      }

      final available = await _speechToText.initialize(
        onError: _handleSpeechError,
        onStatus: _handleSpeechStatus,
        debugLogging: kDebugMode,
      );

      _isInitialized = available;
      if (!available) {
        _errorMessage =
            'El reconocimiento de voz no está disponible en este dispositivo.';
        _state = VoiceState.error;
      } else {
        _errorMessage = null;
      }
      notifyListeners();
      return available;
    } catch (e) {
      _isInitialized = false;
      _errorMessage = 'Error inicializando reconocimiento de voz: $e';
      _state = VoiceState.error;
      notifyListeners();
      return false;
    }
  }

  /// Inicia o detiene la escucha por voz de forma interactiva
  Future<void> toggleListening() async {
    if (_state == VoiceState.listening) {
      await stopListening();
    } else if (_state == VoiceState.idle || _state == VoiceState.error) {
      await startListening();
    }
  }

  /// Comienza a capturar audio del micrófono
  Future<void> startListening() async {
    if (!_isInitialized) {
      final ready = await initialize();
      if (!ready) return;
    }

    _transcribedText = '';
    _errorMessage = null;
    _soundLevel = 0.0;
    _state = VoiceState.listening;
    notifyListeners();

    try {
      // Buscar locale en español preferente si está disponible
      final locales = await _speechToText.locales();
      String? selectedLocaleId;
      for (final loc in locales) {
        if (loc.localeId.startsWith('es')) {
          selectedLocaleId = loc.localeId;
          break;
        }
      }

      final listenOptions = SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
        autoPunctuation: true,
      );

      if (selectedLocaleId != null) {
        // En versiones recientes de speech_to_text el locale se pasa a listen o en options según la plataforma
      }

      await _speechToText.listen(
        onResult: _handleSpeechResult,
        listenOptions: listenOptions,
        onSoundLevelChange: (level) {
          _soundLevel = level;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = 'Error al iniciar captura de audio: $e';
      _state = VoiceState.error;
      notifyListeners();
    }
  }

  /// Detiene la escucha y procesa la transcripción (Mock de red para Fase 10)
  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    final capturedText = _transcribedText.trim();

    if (capturedText.isNotEmpty) {
      // Transición temporal a procesamiento
      _state = VoiceState.processing;
      notifyListeners();

      // Mock de Red para la Fase 10 (impresión en consola del texto transcrito)
      debugPrint('🎙️ [VoiceProvider] Transcripción capturada con éxito: "$capturedText"');
      debugPrint('⚡ [VoiceProvider] Mock de Red: En Fase 11 se enviará al endpoint POST /api/v1/assistant/chat');

      // Simulación sutil de latencia de red antes de volver a reposo
      await Future.delayed(const Duration(milliseconds: 900));
    }

    _soundLevel = 0.0;
    _state = VoiceState.idle;
    notifyListeners();
  }

  /// Cancela la captura inmediatamente y descarta el buffer
  Future<void> cancelListening() async {
    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }
    _transcribedText = '';
    _soundLevel = 0.0;
    _state = VoiceState.idle;
    notifyListeners();
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    _transcribedText = result.recognizedWords;
    notifyListeners();

    // Si la biblioteca detecta fin de locución y es final
    if (result.finalResult) {
      stopListening();
    }
  }

  void _handleSpeechStatus(String status) {
    debugPrint('🎙️ [VoiceProvider] Estado STT: $status');
    if (status == 'notListening' && _state == VoiceState.listening) {
      stopListening();
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    debugPrint('⚠️ [VoiceProvider] Error STT: ${error.errorMsg} (${error.permanent})');
    // Si no reconoció palabras por silencio, volvemos a idle sin mostrar error agresivo
    if (error.errorMsg == 'error_no_match' || error.errorMsg == 'error_speech_timeout') {
      _state = VoiceState.idle;
      _soundLevel = 0.0;
    } else {
      _errorMessage = error.errorMsg;
      _state = VoiceState.error;
    }
    notifyListeners();
  }

  /// Método para setear texto manualmente (útil para testing o mock)
  @visibleForTesting
  void setTranscribedTextForTesting(String text) {
    _transcribedText = text;
    notifyListeners();
  }

  /// Método para setear estado manualmente (útil para testing)
  @visibleForTesting
  void setStateForTesting(VoiceState state) {
    _state = state;
    notifyListeners();
  }
}
