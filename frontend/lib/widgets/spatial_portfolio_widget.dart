import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import '../theme/app_colors.dart';

/// Widget Espacial Interactivo v6.0 para la visualización 3D isométrica de la cartera.
///
/// Encapsula [ModelViewer] con renderizado .glb offline, cámara isométrica
/// por defecto (45°, 55°), pan libre deshabilitado, zoom restringido y fondo transparente.
class SpatialPortfolioWidget extends StatefulWidget {
  final String modelPath;
  final double height;
  final bool autoRotate;

  const SpatialPortfolioWidget({
    super.key,
    this.modelPath = 'assets/3d/placeholder.glb',
    this.height = 280.0,
    this.autoRotate = true,
  });

  @override
  State<SpatialPortfolioWidget> createState() => _SpatialPortfolioWidgetState();
}

class _SpatialPortfolioWidgetState extends State<SpatialPortfolioWidget> {
  bool _isAutoRotating = true;

  @override
  void initState() {
    super.initState();
    _isAutoRotating = widget.autoRotate;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Capa de fondo sutil con gradiente radial espacial
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    AppColors.aiAccent.withValues(alpha: 0.08),
                    AppColors.background.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Motor de Renderizado 3D (ModelViewer) o Preview para tests/entornos sin WebView
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.0),
              child: _build3DCanvas(),
            ),
          ),

          // Overlay flotante Glassmorphism: Indicador espacial y controles de cámara
          Positioned(
            top: 10.0,
            left: 12.0,
            right: 12.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Badge 3D Espacial
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.view_in_ar_rounded,
                            color: AppColors.aiAccent,
                            size: 14.0,
                          ),
                          SizedBox(width: 6.0),
                          Text(
                            'DIORAMA 3D • ISOMÉTRICO',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 10.0,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Botón interactivo para alternar auto-rotación
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isAutoRotating = !_isAutoRotating;
                        });
                      },
                      borderRadius: BorderRadius.circular(12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 5.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E).withValues(alpha: 0.50),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isAutoRotating
                                  ? Icons.rotate_right_rounded
                                  : Icons.pan_tool_alt_rounded,
                              color: _isAutoRotating
                                  ? AppColors.bullish
                                  : AppColors.textTertiary,
                              size: 13.0,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              _isAutoRotating ? 'AUTO-GIRO' : 'MANUAL',
                              style: TextStyle(
                                color: _isAutoRotating
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

          // Pistas de interacción gestual en el pie del visor
          Positioned(
            bottom: 8.0,
            child: ClipRRect(
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
          ),
        ],
      ),
    );
  }

  Widget _build3DCanvas() {
    // Si no hay plataforma WebView registrada (ej. entorno headless de flutter_test o desktop sin soporte)
    if (!kIsWeb && WebViewPlatform.instance == null) {
      return _buildFallbackCanvas();
    }

    // Configuración completa del visor 3D según directrices:
    // - Cámara isométrica: 45° azimuth, 55° elevación polar
    // - Pan libre deshabilitado: disablePan = true, disableTap = true
    // - Zoom restringido: disableZoom = false, minFieldOfView = 25deg, maxFieldOfView = 50deg
    // - Fondo transparente para fundirse con AppColors.background (#000000)
    return ModelViewer(
      src: widget.modelPath,
      alt: 'Diorama 3D Isométrico de Cartera Multiactivo',
      backgroundColor: Colors.transparent,
      cameraControls: true,
      disablePan: true,
      disableTap: true,
      disableZoom: false,
      cameraOrbit: '45deg 55deg auto',
      cameraTarget: 'auto auto auto',
      fieldOfView: '38deg',
      minFieldOfView: '25deg',
      maxFieldOfView: '50deg',
      minCameraOrbit: 'auto auto 70%',
      maxCameraOrbit: 'auto auto 140%',
      autoRotate: _isAutoRotating,
      autoRotateDelay: 2500,
      rotationPerSecond: '20deg',
      shadowIntensity: 0.8,
      shadowSoftness: 0.6,
      exposure: 1.1,
      loading: Loading.eager,
      reveal: Reveal.auto,
    );
  }

  Widget _buildFallbackCanvas() {
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
                color: AppColors.aiAccent.withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.view_in_ar_rounded,
              color: AppColors.aiAccent,
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
          const Text(
            'Infraestructura lista para diorama .glb',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
