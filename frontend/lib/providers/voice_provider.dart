import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/api_service.dart';
import 'portfolio_provider.dart';

/// Alias del proveedor para la Fase 12
typedef VoiceAssistantProvider = VoiceProvider;

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
  final ApiService _apiService;
  AudioPlayer? _audioPlayer;
  PortfolioProvider? _portfolioProvider;

  StreamSubscription<void>? _playerCompleteSubscription;

  VoiceState _state = VoiceState.idle;
  String _transcribedText = '';
  String _assistantResponse = '';
  String? _actionType;
  Map<String, dynamic>? _dataPayload;
  String? _errorMessage;
  bool _isInitialized = false;
  double _soundLevel = 0.0;

  /// Callback opcional invocado al ejecutar una mutación financiera
  void Function(String actionType, Map<String, dynamic> dataPayload)?
      onActionExecuted;

  VoiceProvider({
    SpeechToText? speechToText,
    ApiService? apiService,
    AudioPlayer? audioPlayer,
    PortfolioProvider? portfolioProvider,
    this.onActionExecuted,
  })  : _speechToText = speechToText ?? SpeechToText(),
        _apiService = apiService ?? ApiService() {
    _audioPlayer = audioPlayer;
    _portfolioProvider = portfolioProvider;
    if (_audioPlayer != null) {
      _initAudioListeners();
    }
  }

  AudioPlayer get audioPlayer {
    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      _initAudioListeners();
    }
    return _audioPlayer!;
  }

  void _initAudioListeners() {
    _playerCompleteSubscription?.cancel();
    _playerCompleteSubscription = _audioPlayer?.onPlayerComplete.listen((_) {
      if (_state == VoiceState.speaking) {
        _state = VoiceState.idle;
        notifyListeners();
      }
    });
  }

  /// Vincula reactivamente el proveedor de cartera para mutaciones
  void attachPortfolioProvider(PortfolioProvider provider) {
    _portfolioProvider = provider;
  }

  // Getters
  VoiceState get state => _state;
  String get transcribedText => _transcribedText;
  String get assistantResponse => _assistantResponse;
  String? get actionType => _actionType;
  Map<String, dynamic>? get dataPayload => _dataPayload;
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

  /// Inicia o detiene la interacción según el estado actual
  Future<void> toggleListening() async {
    if (_state == VoiceState.listening) {
      await stopListening();
    } else if (_state == VoiceState.speaking) {
      await stopSpeaking();
    } else if (_state == VoiceState.idle || _state == VoiceState.error) {
      await startListening();
    }
  }

  /// Comienza a capturar audio del micrófono
  Future<void> startListening() async {
    // Si estaba hablando, detener audio previo
    if (_state == VoiceState.speaking) {
      await stopSpeaking();
    }

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
      final listenOptions = SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
        autoPunctuation: true,
      );

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

  /// Detiene la escucha y envía la consulta al backend (Fase 12: Bucle Multimodal)
  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    final capturedText = _transcribedText.trim();
    if (capturedText.isEmpty) {
      _soundLevel = 0.0;
      _state = VoiceState.idle;
      notifyListeners();
      return;
    }

    _soundLevel = 0.0;
    _state = VoiceState.processing;
    notifyListeners();

    try {
      debugPrint('🎙️ [VoiceProvider] Enviando prompt al backend: "$capturedText"');
      final response = await _apiService.sendAssistantChat(capturedText);

      final textResp = response['text_response'] as String? ?? '';
      final actType = response['action_type'] as String? ?? 'GENERAL_QUERY';
      final payload =
          (response['data_payload'] as Map<String, dynamic>?) ?? {};
      final audioBase64 = response['audio_base64'] as String?;

      _assistantResponse = textResp;
      _actionType = actType;
      _dataPayload = payload;

      debugPrint(
          '⚡ [VoiceProvider] Respuesta recibida: action=$actType, audioLen=${audioBase64?.length ?? 0}');

      // 1. Sincronización reactiva del estado financiero si hay mutación
      if (_portfolioProvider != null) {
        await _portfolioProvider!.applyAssistantPayload(actType, payload);
      }
      if (onActionExecuted != null) {
        onActionExecuted!(actType, payload);
      }

      // 2. Reproducción de audio con ElevenLabs (t9LRTh3y1ioN00e9wsNh)
      if (audioBase64 != null && audioBase64.isNotEmpty) {
        _state = VoiceState.speaking;
        notifyListeners();

        try {
          final cleanB64 = audioBase64.replaceAll(RegExp(r'\s+'), '');
          final Uint8List bytes = base64Decode(cleanB64);
          await audioPlayer.stop();
          await audioPlayer.play(BytesSource(bytes, mimeType: 'audio/mp3'));
        } catch (audioErr) {
          debugPrint(
              '[VoiceProvider] Error reproduciendo audio ElevenLabs: $audioErr');
          _state = VoiceState.idle;
          notifyListeners();
        }
      } else {
        // Fallback sin audio (ElevenLabs cuota o offline): mantener texto visible
        _state = VoiceState.speaking;
        notifyListeners();
        Future.delayed(const Duration(seconds: 4), () {
          if (_state == VoiceState.speaking) {
            _state = VoiceState.idle;
            notifyListeners();
          }
        });
      }
    } catch (e) {
      debugPrint('[VoiceProvider] Error comunicando con el asistente: $e');
      _errorMessage = 'Error en el asistente: $e';
      _state = VoiceState.error;
      notifyListeners();
    }
  }

  /// Detiene la reproducción de voz del asistente
  Future<void> stopSpeaking() async {
    try {
      await _audioPlayer?.stop();
    } catch (_) {}
    _state = VoiceState.idle;
    notifyListeners();
  }

  /// Cancela la captura inmediatamente y descarta el buffer
  Future<void> cancelListening() async {
    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }
    if (_state == VoiceState.speaking) {
      await stopSpeaking();
    }
    _transcribedText = '';
    _soundLevel = 0.0;
    _state = VoiceState.idle;
    notifyListeners();
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    _transcribedText = result.recognizedWords;
    notifyListeners();

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
    if (error.errorMsg == 'error_no_match' ||
        error.errorMsg == 'error_speech_timeout') {
      _state = VoiceState.idle;
      _soundLevel = 0.0;
    } else {
      _errorMessage = error.errorMsg;
      _state = VoiceState.error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  // ==========================================================================
  // Métodos de ayuda para Testing Unitario
  // ==========================================================================
  @visibleForTesting
  void setTranscribedTextForTesting(String text) {
    _transcribedText = text;
    notifyListeners();
  }

  @visibleForTesting
  void setAssistantResponseForTesting(String response) {
    _assistantResponse = response;
    notifyListeners();
  }

  @visibleForTesting
  void setStateForTesting(VoiceState state) {
    _state = state;
    notifyListeners();
  }

  @visibleForTesting
  void setActionTypeForTesting(String actionType) {
    _actionType = actionType;
    notifyListeners();
  }

  @visibleForTesting
  void setDataPayloadForTesting(Map<String, dynamic> payload) {
    _dataPayload = payload;
    notifyListeners();
  }
}
