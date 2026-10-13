import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/audio_capture_service.dart';
import '../services/whisper_service.dart';
import '../models/predictive_models.dart';
import 'portfolio_provider.dart';

/// Alias del proveedor para compatibilidad con fases previas
typedef VoiceAssistantProvider = VoiceProvider;

/// Estados del ciclo de vida del asistente conversacional por voz con Edge STT Local (Fase 22).
enum VoiceState {
  idle,
  listening,
  inferringLocal, // Transcribiendo audio en el dispositivo con Whisper AI
  processing,     // Enviando texto reconocido al LLM / Backend FastAPI
  speaking,       // Reproduciendo síntesis de voz (TTS)
  error,
}

class VoiceProvider extends ChangeNotifier {
  final AudioCaptureService _audioCaptureService;
  final WhisperService _whisperService;
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
  String? _lastRecordedWavPath;
  CommitteeDebate? _committeeDebate;
  MonteCarloResult? _monteCarloResult;

  /// Callback opcional invocado al ejecutar una mutación financiera
  void Function(String actionType, Map<String, dynamic> dataPayload)?
      onActionExecuted;

  VoiceProvider({
    AudioCaptureService? audioCaptureService,
    WhisperService? whisperService,
    ApiService? apiService,
    AudioPlayer? audioPlayer,
    PortfolioProvider? portfolioProvider,
    this.onActionExecuted,
  })  : _audioCaptureService = audioCaptureService ?? AudioCaptureService(),
        _whisperService = whisperService ?? WhisperService(),
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

  // Getters de estado
  VoiceState get state => _state;
  String get transcribedText => _transcribedText;
  String get assistantResponse => _assistantResponse;
  String? get actionType => _actionType;
  Map<String, dynamic>? get dataPayload => _dataPayload;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;
  double get soundLevel => _soundLevel;
  String? get lastRecordedWavPath => _lastRecordedWavPath;

  bool get isIdle => _state == VoiceState.idle;
  bool get isListening => _state == VoiceState.listening;
  bool get isInferringLocal => _state == VoiceState.inferringLocal;
  bool get isProcessing => _state == VoiceState.processing;
  bool get isSpeaking => _state == VoiceState.speaking;
  bool get hasError => _state == VoiceState.error;

  // Fase 26: Getters para Comité de IA y Monte Carlo
  CommitteeDebate? get committeeDebate => _committeeDebate;
  MonteCarloResult? get monteCarloResult => _monteCarloResult;
  bool get hasCommitteeDebate =>
      _committeeDebate != null && _committeeDebate!.hasContent;
  bool get hasMonteCarloResult =>
      _monteCarloResult != null && _monteCarloResult!.hasData;

  /// Inicializa el motor de captura y precarga el modelo Whisper
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = true;
      _errorMessage = null;

      // Pre-carga asíncrona del modelo Whisper
      _whisperService.prepareModelFile().catchError((e) {
        debugPrint('[VoiceProvider] Inicialización preliminar del modelo Whisper: $e');
        return '';
      });

      notifyListeners();
      return true;
    } catch (e) {
      _isInitialized = false;
      _errorMessage = 'Error inicializando motor de audio: $e';
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

  /// Inicia la captura de audio crudo en WAV 16kHz mono (Transición a listening)
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
      _lastRecordedWavPath = await _audioCaptureService.startRecording();
    } catch (e) {
      _errorMessage = 'Error al iniciar captura de audio: $e';
      _state = VoiceState.error;
      notifyListeners();
    }
  }

  /// Detiene la grabación WAV, ejecuta Edge STT local con Whisper (inferringLocal)
  /// y envía el texto reconocido al backend FastAPI (processing).
  Future<void> stopListening() async {
    String? wavPath = _lastRecordedWavPath;
    if (_audioCaptureService.isRecording) {
      wavPath = await _audioCaptureService.stopRecording();
      _lastRecordedWavPath = wavPath;
    }

    // 1. Inferencia Local Edge STT con Whisper si hay audio grabado
    if (_transcribedText.trim().isEmpty && wavPath != null && wavPath.isNotEmpty) {
      _state = VoiceState.inferringLocal;
      notifyListeners();

      try {
        debugPrint('🧠 [VoiceProvider] Ejecutando transcripción local con Whisper AI en: $wavPath');
        final recognized = await _whisperService.transcribeAudio(wavPath);
        _transcribedText = recognized.trim();
        debugPrint('🧠 [VoiceProvider] Texto reconocido por Whisper: "$_transcribedText"');
      } catch (e) {
        debugPrint('[VoiceProvider] Excepción durante inferencia Whisper: $e');
        _errorMessage = 'Error en reconocimiento local: $e';
      }
    }

    final capturedText = _transcribedText.trim();
    if (capturedText.isEmpty) {
      _soundLevel = 0.0;
      _state = VoiceState.idle;
      notifyListeners();
      return;
    }

    // 2. Transición a processing y envío de prompt al backend FastAPI
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

      // Fase 26: Capturar CommitteeDebate si está presente en la respuesta
      if (response['committee_debate'] != null &&
          response['committee_debate'] is Map<String, dynamic>) {
        _committeeDebate = CommitteeDebate.fromJson(
            response['committee_debate'] as Map<String, dynamic>);
      }

      // Fase 26: Capturar o disparar proyección Monte Carlo para el Fan Chart
      if (payload['montecarlo'] != null &&
          payload['montecarlo'] is Map<String, dynamic>) {
        final mcMap = payload['montecarlo'] as Map<String, dynamic>;
        if (mcMap['p10'] != null) {
          _monteCarloResult = MonteCarloResult.fromJson(mcMap);
        } else {
          runMonteCarloSimulation(
            ticker: mcMap['ticker'] as String? ?? 'VWCE.DE',
            initialInvestment:
                (mcMap['initial_investment'] as num?)?.toDouble() ?? 10000.0,
            monthlyContribution:
                (mcMap['monthly_contribution'] as num?)?.toDouble() ?? 200.0,
          );
        }
      } else if (_committeeDebate != null || actType == 'INVESTMENT_COMMITTEE') {
        runMonteCarloSimulation();
      }

      debugPrint(
          '⚡ [VoiceProvider] Respuesta recibida: action=$actType, audioLen=${audioBase64?.length ?? 0}');

      // Sincronización reactiva del estado financiero si hay mutación
      if (_portfolioProvider != null) {
        await _portfolioProvider!.applyAssistantPayload(actType, payload);
      }
      if (onActionExecuted != null) {
        onActionExecuted!(actType, payload);
      }

      // Reproducción de audio TTS (ElevenLabs)
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
        // Fallback sin audio: mantener respuesta visible
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

  /// Cancela la captura inmediatamente y descarta el buffer de audio
  Future<void> cancelListening() async {
    await _audioCaptureService.cancelRecording();
    _lastRecordedWavPath = null;
    if (_state == VoiceState.speaking) {
      await stopSpeaking();
    }
    _transcribedText = '';
    _soundLevel = 0.0;
    _state = VoiceState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _audioPlayer?.dispose();
    _audioCaptureService.dispose();
    super.dispose();
  }

  // ==========================================================================
  // Métodos de Analítica Predictiva & Comité (Fase 26)
  // ==========================================================================

  /// Ejecuta una simulación Monte Carlo explícita y almacena el resultado para el Fan Chart.
  Future<void> runMonteCarloSimulation({
    String ticker = 'VWCE.DE',
    int horizonDays = 1260,
    int nSimulations = 5000,
    double initialInvestment = 10000.0,
    double monthlyContribution = 200.0,
  }) async {
    try {
      final res = await _apiService.fetchMonteCarloSimulation(
        ticker: ticker,
        horizonDays: horizonDays,
        nSimulations: nSimulations,
        initialInvestment: initialInvestment,
        monthlyContribution: monthlyContribution,
      );
      _monteCarloResult = res;
      notifyListeners();
    } catch (e) {
      debugPrint('[VoiceProvider] Error ejecutando simulación Monte Carlo: $e');
    }
  }

  /// Limpia el debate del comité activo
  void clearCommitteeDebate() {
    _committeeDebate = null;
    notifyListeners();
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

  @visibleForTesting
  void setCommitteeDebateForTesting(CommitteeDebate? debate) {
    _committeeDebate = debate;
    notifyListeners();
  }

  @visibleForTesting
  void setMonteCarloResultForTesting(MonteCarloResult? result) {
    _monteCarloResult = result;
    notifyListeners();
  }
}
