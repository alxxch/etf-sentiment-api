import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

/// Servicio de Inferencia Local de Reconocimiento de Voz (Edge STT Local) con Whisper AI (Fase 22).
///
/// Gestiona la carga y ejecución de modelos cuantizados de Whisper (ej. ggml-tiny.bin)
/// desde los assets empaquetados o el sistema de archivos local, eliminando cualquier
/// dependencia de APIs de voz en la nube para garantizar privacidad total y funcionamiento offline.
class WhisperService {
  /// Ruta relativa del modelo en los assets del proyecto Flutter
  static const String defaultModelAssetPath = 'assets/models/ggml-tiny.bin';

  final String modelAssetPath;
  final WhisperController _whisperController;
  final Future<String> Function(String filePath)? customTranscriber;
  String? _resolvedModelPath;

  WhisperService({
    this.modelAssetPath = defaultModelAssetPath,
    WhisperController? whisperController,
    this.customTranscriber,
  })  : _whisperController = whisperController ?? WhisperController();

  /// Retorna la ruta física del archivo del modelo en disco una vez inicializado
  String? get resolvedModelPath => _resolvedModelPath;

  /// Prepara y garantiza que el modelo cuantizado de Whisper esté accesible en el sistema de archivos.
  /// Si el modelo reside en `rootBundle`, lo extrae al directorio de soporte de la aplicación.
  Future<String> prepareModelFile() async {
    if (_resolvedModelPath != null && File(_resolvedModelPath!).existsSync()) {
      return _resolvedModelPath!;
    }

    // 1. Comprobar si existe como archivo directo relativo o absoluto en disco
    final directFile = File(modelAssetPath);
    if (directFile.existsSync() && directFile.lengthSync() > 1024) {
      _resolvedModelPath = directFile.path;
      debugPrint('[WhisperService] Modelo detectado directamente en disco: $_resolvedModelPath');
      return _resolvedModelPath!;
    }

    // 2. Extraer desde el bundle de assets hacia el directorio de la aplicación
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final modelsDir = Directory('${appSupportDir.path}/models');
      if (!modelsDir.existsSync()) {
        await modelsDir.create(recursive: true);
      }

      final fileName = modelAssetPath.split('/').last;
      final targetFile = File('${modelsDir.path}/$fileName');

      if (!targetFile.existsSync() || targetFile.lengthSync() < 1024) {
        debugPrint('[WhisperService] Extrayendo asset $modelAssetPath a ${targetFile.path}...');
        final byteData = await rootBundle.load(modelAssetPath);
        final buffer = byteData.buffer;
        await targetFile.writeAsBytes(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
          flush: true,
        );
      }

      _resolvedModelPath = targetFile.path;
      debugPrint('[WhisperService] Modelo Whisper inicializado en: $_resolvedModelPath');
      return _resolvedModelPath!;
    } catch (e) {
      debugPrint('[WhisperService] Aviso al preparar archivo del modelo desde assets: $e');
      _resolvedModelPath = modelAssetPath;
      return modelAssetPath;
    }
  }

  /// Procesa el archivo de audio WAV temporal y realiza inferencia local con Whisper,
  /// devolviendo el texto puro reconocido.
  Future<String> transcribeAudio(String filePath, {String language = 'es'}) async {
    // 1. Delegado inyectado para testing unitario o entornos simulados
    final custom = customTranscriber;
    if (custom != null) {
      return await custom(filePath);
    }

    final audioFile = File(filePath);
    if (!audioFile.existsSync() || audioFile.lengthSync() == 0) {
      debugPrint('[WhisperService] Archivo de audio no encontrado o vacío: $filePath');
      return '';
    }

    try {
      final localModelPath = await prepareModelFile();
      debugPrint('[WhisperService] Ejecutando inferencia Whisper en $filePath con modelo $localModelPath...');

      // Inferencia nativa utilizando el motor whisper_ggml / whisper.cpp
      final Whisper whisper = const Whisper(model: WhisperModel.tiny);
      final WhisperTranscribeResponse response = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: filePath,
          language: language,
          isTranslate: false,
          isNoTimestamps: true,
          noContext: true,
          suppressNonSpeechTokens: true,
        ),
        modelPath: localModelPath,
      );

      final cleanText = response.text.trim();
      debugPrint('[WhisperService] Inferencia Whisper completada: "$cleanText"');
      return cleanText;
    } catch (e) {
      debugPrint('[WhisperService] Error o limitación en inferencia nativa de Whisper: $e');
      // En entornos donde la librería FFI no está compilada o el modelo es placeholder,
      // retornamos cadena vacía o permitimos continuar sin interrumpir la app
      return '';
    }
  }

  /// Libera memoria nativa asociada al modelo cargado si está estacionado
  Future<void> releaseModel() async {
    try {
      await _whisperController.releaseModel();
    } catch (_) {}
  }
}
