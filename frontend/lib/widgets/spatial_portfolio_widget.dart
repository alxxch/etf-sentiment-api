import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_colors.dart';

/// Widget Espacial Interactivo v6.0 con Reactividad Financiera (Fase 19).
///
/// Conecta el visor 3D al estado de [PortfolioProvider]:
/// 1. Ángulo de cámara reactivo a la asignación de activos (% Renta Variable vs Oro).
/// 2. Resplandor ambiental espacial reactivo al market sentiment score (#FF453A bajista -> #30D158 alcista).
/// 3. Giro acelerado (auto-rotate boost) ante eventos de simulación DCA o rebalanceo.
class SpatialPortfolioWidget extends StatefulWidget {
  final String modelPath;
  final double height;
  final bool autoRotate;
  final double? customEquityPct;
  final int? customSentimentScore;

  const SpatialPortfolioWidget({
    super.key,
    this.modelPath = 'assets/3d/placeholder.glb',
    this.height = 280.0,
    this.autoRotate = true,
    this.customEquityPct,
    this.customSentimentScore,
  });

  @override
  State<SpatialPortfolioWidget> createState() => _SpatialPortfolioWidgetState();
}

class _SpatialPortfolioWidgetState extends State<SpatialPortfolioWidget> {
  bool _userAutoRotate = true;
  bool _isRebalancingBoostActive = false;
  int _lastSeenEventCounter = 0;
  Timer? _rebalanceTimer;
  WebViewController? _webViewController;
  String _currentOrbit = '45deg 55deg auto';

  @override
  void initState() {
    super.initState();
    _userAutoRotate = widget.autoRotate;
  }

  @override
  void dispose() {
    _rebalanceTimer?.cancel();
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
          autoRotate: _userAutoRotate,
          rotationSpeed: '20deg',
        );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sync3DPropertiesToWebView(
        orbit: _currentOrbit,
        autoRotate: true,
        rotationSpeed: '75deg',
      );
    });
  }

  void _sync3DPropertiesToWebView({
    required String orbit,
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

    // 1. Detección reactiva de eventos de simulación/rebalanceo
    if (provider != null) {
      if (provider.rebalanceEventCounter > _lastSeenEventCounter) {
        _lastSeenEventCounter = provider.rebalanceEventCounter;
        _triggerRebalanceSpin();
      }
    }

    // 2. Mapeo reactivo de asignación de activos a la elevación de la cámara 3D
    // A mayor % de Renta Variable, ángulo más vertical (cenital/bird's-eye)
    // 0% RV -> 65° (vista más horizontal); 100% RV -> 38° (vista cenital)
    final equityPct = widget.customEquityPct ??
        provider?.allocationEquityPct ??
        80.0;
    final phi = (65.0 - (equityPct.clamp(0.0, 100.0) / 100.0) * 27.0);
    const theta = 45.0; // Azimuth isométrico base
    final cameraOrbit =
        '${theta.toStringAsFixed(1)}deg ${phi.toStringAsFixed(1)}deg auto';

    if (_currentOrbit != cameraOrbit) {
      _currentOrbit = cameraOrbit;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sync3DPropertiesToWebView(
          orbit: cameraOrbit,
          autoRotate: _isRebalancingBoostActive || _userAutoRotate,
          rotationSpeed: _isRebalancingBoostActive ? '75deg' : '20deg',
        );
      });
    }

    // 3. Mapeo reactivo de Sentimiento de Mercado a la iluminación ambiental
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

    // 4. Parámetros de feedback físico de rotación
    final effectiveAutoRotate = _isRebalancingBoostActive || _userAutoRotate;
    final effectiveRotationSpeed =
        _isRebalancingBoostActive ? '75deg' : '20deg';

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Resplandor ambiental espacial difuso (#FF453A a #30D158)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                    color: ambientGlowColor.withValues(
                      alpha: 0.30 + (sentimentRatio - 0.5).abs() * 0.15,
                    ),
                    blurRadius: 36.0,
                    spreadRadius: 2.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),

          // Gradiente radial interno que baña el volumen 3D
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    ambientGlowColor.withValues(alpha: 0.16),
                    ambientGlowColor.withValues(alpha: 0.03),
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
                autoRotate: effectiveAutoRotate,
                rotationSpeed: effectiveRotationSpeed,
                sentimentColor: ambientGlowColor,
                sentimentScore: sentimentScore,
                equityPct: equityPct,
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
                        color: const Color(0xFF1C1C1E).withValues(alpha: 0.50),
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
                        color: const Color(0xFF1C1C1E).withValues(alpha: 0.50),
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
                                  color: ambientGlowColor.withValues(alpha: 0.8),
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
                        color: const Color(0xFF1C1C1E).withValues(alpha: 0.40),
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
                          autoRotate:
                              _isRebalancingBoostActive || _userAutoRotate,
                          rotationSpeed: _isRebalancingBoostActive
                              ? '75deg'
                              : '20deg',
                        );
                      },
                      borderRadius: BorderRadius.circular(10.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF1C1C1E).withValues(alpha: 0.45),
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
  }

  Widget _build3DCanvas({
    required String cameraOrbit,
    required bool autoRotate,
    required String rotationSpeed,
    required Color sentimentColor,
    required int sentimentScore,
    required double equityPct,
  }) {
    if (!kIsWeb && WebViewPlatform.instance == null) {
      return _buildFallbackCanvas(cameraOrbit, sentimentColor, sentimentScore, equityPct);
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
      fieldOfView: '38deg',
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
      },
    );
  }

  Widget _buildFallbackCanvas(
    String cameraOrbit,
    Color sentimentColor,
    int sentimentScore,
    double equityPct,
  ) {
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
                  color: sentimentColor.withValues(alpha: 0.3),
                  blurRadius: 16.0,
                ),
              ],
            ),
            child: Icon(
              Icons.view_in_ar_rounded,
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
            'Cámara: $cameraOrbit • RV: ${equityPct.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            'Sentimiento: $sentimentScore/100',
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
