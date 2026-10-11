import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService extends ChangeNotifier {
  final AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  String? _currentAudioKey;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<void>? _completeSubscription;

  AudioService({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _initListeners();
  }

  void _initListeners() {
    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      _playerState = state;
      notifyListeners();
    });

    _completeSubscription = _player.onPlayerComplete.listen((_) {
      _playerState = PlayerState.stopped;
      _currentAudioKey = null;
      notifyListeners();
    });
  }

  PlayerState get playerState => _playerState;
  bool get isPlaying => _playerState == PlayerState.playing;
  String? get currentAudioKey => _currentAudioKey;

  bool isPlayingKey(String? key) => isPlaying && _currentAudioKey == key;

  /// Alterna reproducción/pausa de un audio en base64 identificado por una clave (ej. ticker)
  Future<void> togglePlayPause(String base64String, {String? audioKey}) async {
    final key = audioKey ?? base64String.hashCode.toString();

    if (_currentAudioKey == key && isPlaying) {
      await pause();
    } else if (_currentAudioKey == key && _playerState == PlayerState.paused) {
      await resume();
    } else {
      await playBase64(base64String, audioKey: key);
    }
  }

  /// Decodifica la cadena base64 y la reproduce desde memoria mediante BytesSource
  Future<void> playBase64(String base64String, {String? audioKey}) async {
    try {
      final cleanBase64 = base64String.replaceAll(RegExp(r'\s+'), '');
      final Uint8List bytes = base64Decode(cleanBase64);

      _currentAudioKey = audioKey ?? base64String.hashCode.toString();
      await _player.stop();
      await _player.play(BytesSource(bytes, mimeType: 'audio/mp3'));
    } catch (e) {
      debugPrint('[AudioService] Error al reproducir audio base64: $e');
      _playerState = PlayerState.stopped;
      _currentAudioKey = null;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('[AudioService] Error al pausar: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _player.resume();
    } catch (e) {
      debugPrint('[AudioService] Error al reanudar: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _playerState = PlayerState.stopped;
      _currentAudioKey = null;
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioService] Error al detener: $e');
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _completeSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
