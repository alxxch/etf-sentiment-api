import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/portfolio_provider.dart';
import '../providers/voice_provider.dart';
import '../theme/app_colors.dart';

/// Widget Espacial Interactivo v6.0 con Reactividad Financiera y Sincronización Multimodal (Fases 18-20).
///
/// Conecta el visor 3D al estado de [PortfolioProvider] y [VoiceProvider]:
/// 1. Ángulo de cámara reactivo a la asignación de activos (% Renta Variable vs Oro).
/// 2. Resplandor ambiental espacial reactivo al market sentiment score (#FF453A bajista -> #30D158 alcista).
/// 3. Giro acelerado (auto-rotate boost) ante eventos de simulación DCA o rebalanceo.
/// 4. Cinemáticas de Cámara Conversacional (Fase 20):
///    - Estado listening / processing: Zoom in automático (FOV 28° vs 38°) y rotación ralentizada (6°/s).
///    - Estado speaking: Animación de "latido" (pulso de opacidad y resplandor) mientras ElevenLabs reproduce audio.
///    - Retorno a idle: Retorno suave a la posición isométrica base calculada y velocidad normal (20°/s).
class SpatialPortfolioWidget extends StatefulWidget {
  final String modelPath;
  final double height;
  final bool autoRotate;
  final double? customEquityPct;
  final int? customSentimentScore;
  final VoiceState? customVoiceState;
  final VoiceProvider? customVoiceProvider;

  const SpatialPortfolioWidget({
    super.key,
    this.modelPath = 'assets/3d/placeholder.glb',
    this.height = 280.0,
    this.autoRotate = true,
    this.customEquityPct,
    this.customSentimentScore,
    this.customVoiceState,
    this.customVoiceProvider,
  });

  @override
  State<SpatialPortfolioWidget> createState() => _SpatialPortfolioWidgetState();
}

class _SpatialPortfolioWidgetState extends State<SpatialPortfolioWidget>
    with SingleTickerProviderStateMixin {
  bool _userAutoRotate = true;
  bool _isRebalancingBoostActive = false;
  int _lastSeenEventCounter = 0;
  Timer? _rebalanceTimer;
  WebViewController? _webViewController;
  String _currentOrbit = '45deg 55deg auto';
  String _currentFov = '38deg';
  String _currentSpeed = '20deg';

  late final AnimationController _heartbeatController;
  late final Animation<double> _heartbeatAnimation;

  @override
  void initState() {
    super.initState();
    _userAutoRotate = widget.autoRotate;

    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _heartbeatAnimation = CurvedAnimation(
      parent: _heartbeatController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _rebalanceTimer?.cancel();
    _heartbeatController.dispose();
    super.dispose();
  }

  void _triggerRebalanceSpin() {
    _rebalanceTimer?.cancel();
    _isRebalancingBoostActive = true;
    _rebalanceTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isRebalancingBoostActive = false;
        });
        _sync3DPropertiesToWebView(
          orbit: _currentOrbit,
          fov: _currentFov,
          autoRotate: _userAutoRotate,
          rotationSpeed: _currentSpeed,
        );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sync3DPropertiesToWebView(
        orbit: _currentOrbit,
        fov: _currentFov,
        autoRotate: true,
        rotationSpeed: '75deg',
      );
    });
  }

  void _sync3DPropertiesToWebView({
    required String orbit,
    required String fov,
    required bool autoRotate,
    required String rotationSpeed,
  }) {
    if (_webViewController == null) return;
    try {
      _webViewController?.runJavaScript('''
        (function() {
          const mv = document.querySelector('model-viewer');
          if (mv) {
            mv.cameraOrbit = '$orbit';
            mv.fieldOfView = '$fov';
            mv.autoRotate = $autoRotate;
            mv.rotationPerSecond = '$rotationSpeed';
          }
        })();
      ''');
    } catch (e) {
      debugPrint('[SpatialPortfolioWidget] Error syncing 3D properties: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    PortfolioProvider? provider;
    try {
      provider = Provider.of<PortfolioProvider?>(context);
    } catch (_) {
      provider = null;
    }

    VoiceProvider? voiceProvider;
    try {
      voiceProvider =
          widget.customVoiceProvider ?? Provider.of<VoiceProvider?>(context);
    } catch (_) {
      voiceProvider = null;
    }

    // 1. Sincronización Multimodal de Voz (Fase 20)
    final voiceState =
        widget.customVoiceState ?? voiceProvider?.state ?? VoiceState.idle;
    final isVoiceListening = voiceState == VoiceState.listening;
    final isVoiceProcessing = voiceState == VoiceState.processing;
    final isVoiceSpeaking = voiceState == VoiceState.speaking;
    final isVoiceAttentive = isVoiceListening || isVoiceProcessing;

    // Control de la animación de latido/pulso durante síntesis de voz (TTS)
    if (isVoiceSpeaking) {
      if (!_heartbeatController.isAnimating) {
        _heartbeatController.repeat(reverse: true);
      }
    } else {
      if (_heartbeatController.isAnimating) {
        _heartbeatController.stop();
        _heartbeatController.reset();
      }
    }

    // 2. Detección reactiva de eventos de simulación/rebalanceo
    if (provider != null) {
      if (provider.rebalanceEventCounter > _lastSeenEventCounter) {
        _lastSeenEventCounter = provider.rebalanceEventCounter;
        _triggerRebalanceSpin();
      }
    }

    // 3. Mapeo reactivo de asignación de activos a la elevación de la cámara 3D
    // A mayor % de Renta Variable, ángulo más vertical (cenital/bird's-eye)
    // 0% RV -> 65° (vista más horizontal); 100% RV -> 38° (vista cenital)
    final equityPct = widget.customEquityPct ??
        provider?.allocationEquityPct ??
        80.0;
    final phi = (65.0 - (equityPct.clamp(0.0, 100.0) / 100.0) * 27.0);
    const theta = 45.0; // Azimuth isométrico base
    final cameraOrbit =
        '${theta.toStringAsFixed(1)}deg ${phi.toStringAsFixed(1)}deg auto';

    // 4. Cinemáticas de Cámara Conversacional (Fase 20)
    // - En listening/processing: Zoom in (FOV 28° vs 38°) y ralentización a 6°/s
    // - En idle/speaking: FOV 38° e isometría estándar, velocidad 20°/s
    final targetFov = isVoiceAttentive ? '28deg' : '38deg';
    final targetSpeed = _isRebalancingBoostActive
        ? '75deg'
        : (isVoiceAttentive ? '6deg' : '20deg');
    final effectiveAutoRotate =
        _isRebalancingBoostActive || isVoiceAttentive || _userAutoRotate;

    if (_currentOrbit != cameraOrbit ||
        _currentFov != targetFov ||
        _currentSpeed != targetSpeed) {
      _currentOrbit = cameraOrbit;
      _currentFov = targetFov;
      _currentSpeed = targetSpeed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sync3DPropertiesToWebView(
          orbit: cameraOrbit,
          fov: targetFov,
          autoRotate: effectiveAutoRotate,
          rotationSpeed: targetSpeed,
        );
      });
    }

    // 5. Mapeo reactivo de Sentimiento de Mercado a la iluminación ambiental
    // Score 0 -> #FF453A (Bearish Rojo)
    // Score 100 -> #30D158 (Bullish Verde)
    final sentimentScore = widget.customSentimentScore ??
        provider?.portfolio?.marketSentimentScore ??
        50;
    final sentimentRatio = (sentimentScore.clamp(0, 100)) / 100.0;
    final ambientGlowColor = Color.lerp(
      AppColors.bearish, // #FF453A
      AppColors.bullish, // #30D158
      sentimentRatio,
    )!;

    return AnimatedBuilder(
      animation: _heartbeatAnimation,
      builder: (context, _) {
        final pulse = isVoiceSpeaking ? _heartbeatAnimation.value : 0.0;
        final glowAlpha = ((0.30 + (sentimentRatio - 0.5).abs() * 0.15) +
                (pulse * 0.35))
            .clamp(0.0, 1.0);
        final glowBlur = 36.0 + (pulse * 24.0);
        final glowSpread = 2.0 + (pulse * 6.0);

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Resplandor ambiental espacial difuso (#FF453A a #30D158 con pulso TTS)
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: ambientGlowColor.withValues(alpha: glowAlpha),
                        blurRadius: glowBlur,
                        spreadRadius: glowSpread,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),

              // Gradiente radial interno que baña el volumen 3D con animación TTS
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.0),
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.85,
                      colors: [
                        ambientGlowColor.withValues(
                          alpha: (0.16 + pulse * 0.20).clamp(0.0, 1.0),
                        ),
                        ambientGlowColor.withValues(
                          alpha: (0.03 + pulse * 0.08).clamp(0.0, 1.0),
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),

              // Motor de Renderizado 3D (ModelViewer) o Canvas fallback en tests
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20.0),
                  child: _build3DCanvas(
                    cameraOrbit: cameraOrbit,
                    fov: targetFov,
                    autoRotate: effectiveAutoRotate,
                    rotationSpeed: targetSpeed,
                    sentimentColor: ambientGlowColor,
                    sentimentScore: sentimentScore,
                    equityPct: equityPct,
                    voiceState: voiceState,
                    pulse: pulse,
                  ),
                ),
              ),

              // Overlay flotante Glassmorphism superior: Badges espaciales y telemetría
              Positioned(
                top: 10.0,
                left: 12.0,
                right: 12.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Badge 3D Espacial con ángulo dinámico
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 5.0,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1C1C1E).withValues(alpha: 0.50),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: AppColors.aiAccent.withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.view_in_ar_rounded,
                                color: AppColors.aiAccent,
                                size: 14.0,
                              ),
                              const SizedBox(width: 6.0),
                              const Text(
                                'DIORAMA 3D • ISOMÉTRICO',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(width: 4.0),
                              Text(
                                '• ${equityPct.toStringAsFixed(0)}% RV (${phi.toStringAsFixed(0)}°)',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Badge reactivo de Sentimiento con color ambiental
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9.0,
                            vertical: 5.0,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1C1C1E).withValues(alpha: 0.50),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: ambientGlowColor.withValues(alpha: 0.45),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6.5,
                                height: 6.5,
                                decoration: BoxDecoration(
                                  color: ambientGlowColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: ambientGlowColor
                                          .withValues(alpha: 0.8),
                                      blurRadius: 5.0,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 5.0),
                              Text(
                                'SENTIMIENTO $sentimentScore',
                                style: TextStyle(
                                  color: ambientGlowColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Banner flotante superior de estado Multimodal Conversacional (Fase 20)
              if (isVoiceAttentive || isVoiceSpeaking)
                Positioned(
                  top: 44.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 5.0,
                        ),
                        decoration: BoxDecoration(
                          color: (isVoiceSpeaking
                                  ? AppColors.bullish
                                  : (isVoiceListening
                                      ? AppColors.aiAccent
                                      : AppColors.gold))
                              .withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: isVoiceSpeaking
                                ? AppColors.bullish
                                : (isVoiceListening
                                    ? AppColors.aiAccent
                                    : AppColors.gold),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isVoiceSpeaking
                                  ? Icons.volume_up_rounded
                                  : (isVoiceListening
                                      ? Icons.mic_rounded
                                      : Icons.hourglass_top_rounded),
                              color: isVoiceSpeaking
                                  ? AppColors.bullish
                                  : (isVoiceListening
                                      ? AppColors.aiAccent
                                      : AppColors.gold),
                              size: 13.0,
                            ),
                            const SizedBox(width: 6.0),
                            Text(
                              isVoiceSpeaking
                                  ? 'ASISTENTE HABLANDO • PULSO TTS ACTIVO'
                                  : (isVoiceListening
                                      ? 'ATENCIÓN CONVERSACIONAL • ZOOM 28°'
                                      : 'PROCESANDO CONSULTA...'),
                              style: TextStyle(
                                color: isVoiceSpeaking
                                    ? AppColors.bullish
                                    : (isVoiceListening
                                        ? AppColors.aiAccent
                                        : AppColors.gold),
                                fontSize: 10.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Banner flotante de feedback ante evento de rebalanceo activo
              if (_isRebalancingBoostActive)
                Positioned(
                  top: 48.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 6.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.aiAccent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: AppColors.aiAccent,
                            width: 1.2,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12.0,
                              height: 12.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.aiAccent,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.0),
                            Text(
                              'RECALCULANDO ACTIVOS...',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Controles inferiores: Auto-giro toggle y asistencia de gestos
              Positioned(
                bottom: 8.0,
                left: 12.0,
                right: 12.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Gestos
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1C1C1E).withValues(alpha: 0.40),
                            borderRadius: BorderRadius.circular(10.0),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                color: AppColors.textTertiary,
                                size: 12.0,
                              ),
                              SizedBox(width: 5.0),
                              Text(
                                'Arrastra para rotar • Pellizca para zoom',
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Botón interactivo para alternar auto-rotación
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _userAutoRotate = !_userAutoRotate;
                            });
                            _sync3DPropertiesToWebView(
                              orbit: _currentOrbit,
                              fov: _currentFov,
                              autoRotate: _isRebalancingBoostActive ||
                                  isVoiceAttentive ||
                                  _userAutoRotate,
                              rotationSpeed: targetSpeed,
                            );
                          },
                          borderRadius: BorderRadius.circular(10.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E)
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _userAutoRotate
                                      ? Icons.rotate_right_rounded
                                      : Icons.pan_tool_alt_rounded,
                                  color: _userAutoRotate
                                      ? AppColors.bullish
                                      : AppColors.textTertiary,
                                  size: 13.0,
                                ),
                                const SizedBox(width: 4.0),
                                Text(
                                  _userAutoRotate ? 'AUTO-GIRO' : 'MANUAL',
                                  style: TextStyle(
                                    color: _userAutoRotate
                                        ? AppColors.bullish
                                        : AppColors.textTertiary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _build3DCanvas({
    required String cameraOrbit,
    required String fov,
    required bool autoRotate,
    required String rotationSpeed,
    required Color sentimentColor,
    required int sentimentScore,
    required double equityPct,
    required VoiceState voiceState,
    required double pulse,
  }) {
    if (!kIsWeb && WebViewPlatform.instance == null) {
      return _buildFallbackCanvas(
        cameraOrbit: cameraOrbit,
        fov: fov,
        rotationSpeed: rotationSpeed,
        sentimentColor: sentimentColor,
        sentimentScore: sentimentScore,
        equityPct: equityPct,
        voiceState: voiceState,
        pulse: pulse,
      );
    }

    return ModelViewer(
      src: widget.modelPath,
      alt: 'Diorama 3D Isométrico de Cartera Multiactivo',
      backgroundColor: Colors.transparent,
      cameraControls: true,
      disablePan: true,
      disableTap: true,
      disableZoom: false,
      cameraOrbit: cameraOrbit,
      cameraTarget: 'auto auto auto',
      fieldOfView: fov,
      minFieldOfView: '25deg',
      maxFieldOfView: '50deg',
      minCameraOrbit: 'auto auto 70%',
      maxCameraOrbit: 'auto auto 140%',
      autoRotate: autoRotate,
      autoRotateDelay: 1500,
      rotationPerSecond: rotationSpeed,
      shadowIntensity: 0.8,
      shadowSoftness: 0.6,
      exposure: 1.1,
      loading: Loading.eager,
      reveal: Reveal.auto,
      onWebViewCreated: (controller) {
        _webViewController = controller;
        _sync3DPropertiesToWebView(
          orbit: cameraOrbit,
          fov: fov,
          autoRotate: autoRotate,
          rotationSpeed: rotationSpeed,
        );
      },
    );
  }

  Widget _buildFallbackCanvas({
    required String cameraOrbit,
    required String fov,
    required String rotationSpeed,
    required Color sentimentColor,
    required int sentimentScore,
    required double equityPct,
    required VoiceState voiceState,
    required double pulse,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(
                color: sentimentColor.withValues(alpha: 0.6),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: sentimentColor.withValues(alpha: 0.3 + (pulse * 0.4)),
                  blurRadius: 16.0 + (pulse * 12.0),
                  spreadRadius: pulse * 4.0,
                ),
              ],
            ),
            child: Icon(
              voiceState == VoiceState.speaking
                  ? Icons.volume_up_rounded
                  : (voiceState == VoiceState.listening
                      ? Icons.mic_rounded
                      : Icons.view_in_ar_rounded),
              color: sentimentColor,
              size: 40.0,
            ),
          ),
          const SizedBox(height: 12.0),
          const Text(
            'Vista Espacial 3D Isométrica',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            'Cámara: $cameraOrbit • FOV: $fov • RV: ${equityPct.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            'Sentimiento: $sentimentScore/100 • Giro: $rotationSpeed • Voz: ${voiceState.name.toUpperCase()}',
            style: TextStyle(
              color: sentimentColor,
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

