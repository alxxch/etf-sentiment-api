import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Servicio de captura cruda de audio en búfer para Edge STT Local (Fase 22).
///
/// Configura el encoder a formato WAV estándar requerido por Whisper:
/// - Frecuencia de muestreo: 16 kHz (16000 Hz)
/// - Canales: 1 (Mono)
/// - Codificación: 16-bit PCM lineal
///
/// El archivo resultante se almacena temporalmente en el directorio de caché del sistema
/// ([getTemporaryDirectory]) y su ruta se transfiere al motor de inferencia Whisper.
class AudioCaptureService {
  AudioRecorder? _recorder;
  bool _isRecording = false;
  String? _currentRecordingPath;

  AudioCaptureService({AudioRecorder? recorder}) {
    _recorder = recorder;
  }

  AudioRecorder get recorder => _recorder ??= AudioRecorder();

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  /// Comprueba y solicita permisos para capturar audio desde el micrófono
  Future<bool> hasPermission() async {
    try {
      return await recorder.hasPermission();
    } catch (e) {
      debugPrint('[AudioCaptureService] Error verificando permisos de micrófono: $e');
      return false;
    }
  }

  /// Inicia la grabación del flujo de audio crudo en un archivo temporal .wav
  Future<String> startRecording({String? customPath}) async {
    if (_isRecording) {
      debugPrint('[AudioCaptureService] Grabación ya activa en: $_currentRecordingPath');
      return _currentRecordingPath!;
    }

    final hasPerm = await hasPermission();
    if (!hasPerm) {
      throw Exception('Permiso de grabación de micrófono no concedido.');
    }

    String targetPath = customPath ?? '';
    if (targetPath.isEmpty) {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      targetPath = '${tempDir.path}/whisper_record_$timestamp.wav';
    }

    // Configuración estricta WAV 16kHz mono 16-bit PCM requerida por Whisper AI
    const config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 256000,
    );

    debugPrint('[AudioCaptureService] Iniciando grabación WAV (16kHz Mono) en: $targetPath');
    await recorder.start(config, path: targetPath);
    _isRecording = true;
    _currentRecordingPath = targetPath;
    return targetPath;
  }

  /// Detiene la grabación y retorna la ruta del archivo WAV generado
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      return _currentRecordingPath;
    }

    debugPrint('[AudioCaptureService] Deteniendo grabación de audio...');
    final recordedPath = await _recorder?.stop();
    _isRecording = false;
    _currentRecordingPath = recordedPath ?? _currentRecordingPath;
    debugPrint('[AudioCaptureService] Audio WAV capturado en: $_currentRecordingPath');
    return _currentRecordingPath;
  }

  /// Cancela la captura actual y purga el archivo temporal si existe
  Future<void> cancelRecording() async {
    if (_isRecording) {
      try {
        await _recorder?.cancel();
      } catch (e) {
        debugPrint('[AudioCaptureService] Error al cancelar grabación: $e');
      }
      _isRecording = false;
    }

    if (_currentRecordingPath != null) {
      try {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      _currentRecordingPath = null;
    }
  }

  void dispose() {
    _recorder?.dispose();
  }
}
