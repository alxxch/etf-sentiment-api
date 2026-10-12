import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/voice_provider.dart';
import '../theme/app_colors.dart';

/// Botón interactivo del asistente de voz con halo reactivo estilo Apple Finance
/// y previsualización de transcripción en tiempo real.
class VoiceAssistantButton extends StatefulWidget {
  const VoiceAssistantButton({super.key});

  @override
  State<VoiceAssistantButton> createState() => _VoiceAssistantButtonState();
}

class _VoiceAssistantButtonState extends State<VoiceAssistantButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onButtonTap(VoiceProvider voice) {
    HapticFeedback.mediumImpact();
    voice.toggleListening();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, voice, child) {
        final isListening = voice.isListening;
        final isProcessing = voice.isProcessing;
        final hasError = voice.hasError;

        if (isListening) {
          if (!_pulseController.isAnimating) {
            _pulseController.repeat(reverse: true);
          }
        } else {
          if (_pulseController.isAnimating) {
            _pulseController.stop();
            _pulseController.reset();
          }
        }

        final showOverlayCard = isListening || isProcessing || hasError;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 1. Tarjeta flotante con transcripción en vivo
            if (showOverlayCard) ...[
              _buildLiveTranscriptionCard(context, voice),
              const SizedBox(height: 12.0),
            ],

            // 2. Botón pulsante con Halo Siri / Apple Intelligence
            _buildMicrophoneFab(voice, isListening, isProcessing, hasError),
          ],
        );
      },
    );
  }

  /// Tarjeta flotante con feedback en tiempo real
  Widget _buildLiveTranscriptionCard(
      BuildContext context, VoiceProvider voice) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = math.min(screenWidth - 40.0, 360.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: cardWidth,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: voice.isListening
              ? AppColors.aiAccent.withValues(alpha: 0.6)
              : (voice.hasError
                  ? AppColors.bearish.withValues(alpha: 0.6)
                  : AppColors.cardBorder),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20.0,
            offset: const Offset(0, 8),
          ),
          if (voice.isListening)
            BoxShadow(
              color: AppColors.aiAccent.withValues(alpha: 0.2),
              blurRadius: 24.0,
              spreadRadius: 2.0,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Estado + Botón cerrar/cancelar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildStatusIndicator(voice),
                  const SizedBox(width: 8.0),
                  Text(
                    _getStatusTitle(voice),
                    style: TextStyle(
                      color: _getStatusColor(voice),
                      fontSize: 11.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  voice.cancelListening();
                },
                child: Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 14.0,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12.0),

          // Texto capturado en vivo o Placeholder guía
          if (voice.hasError) ...[
            Text(
              voice.errorMessage ?? 'Ocurrió un error inesperado de audio.',
              style: const TextStyle(
                color: AppColors.bearish,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ] else if (voice.isProcessing) ...[
            const Row(
              children: [
                SizedBox(
                  width: 14.0,
                  height: 14.0,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.aiAccent),
                  ),
                ),
                SizedBox(width: 10.0),
                Expanded(
                  child: Text(
                    'Analizando tu consulta financiera...',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (voice.transcribedText.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              Text(
                '"${voice.transcribedText}"',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ] else ...[
            Text(
              voice.transcribedText.isEmpty
                  ? 'Di algo como:\n"¿Cómo va mi cartera?" o "Simula 100€ al oro"...'
                  : voice.transcribedText,
              style: TextStyle(
                color: voice.transcribedText.isEmpty
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontSize: 14.5,
                fontWeight: voice.transcribedText.isEmpty
                    ? FontWeight.w400
                    : FontWeight.w600,
                fontStyle: voice.transcribedText.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Botón con halo animado reactivo
  Widget _buildMicrophoneFab(
    VoiceProvider voice,
    bool isListening,
    bool isProcessing,
    bool hasError,
  ) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulseScale = isListening ? 1.0 + (_pulseAnimation.value * 0.18) : 1.0;
        final pulseGlow = isListening ? _pulseAnimation.value : 0.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Halo concéntrico exterior (Siri / Apple Finance pulse)
            if (isListening)
              Container(
                width: 68.0 * pulseScale,
                height: 68.0 * pulseScale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.aiAccent.withValues(alpha: 0.45 * (1.0 - pulseGlow * 0.5)),
                      AppColors.bullish.withValues(alpha: 0.15 * (1.0 - pulseGlow * 0.5)),
                      Colors.transparent,
                    ],
                    stops: const [0.3, 0.7, 1.0],
                  ),
                ),
              ),

            // Botón principal
            GestureDetector(
              onTap: () => _onButtonTap(voice),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56.0,
                height: 56.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isListening
                      ? AppColors.aiAccent
                      : (hasError ? AppColors.bearishSoft : AppColors.cardSurface),
                  border: Border.all(
                    color: isListening
                        ? AppColors.textPrimary
                        : (hasError ? AppColors.bearish : AppColors.cardBorder),
                    width: isListening ? 2.0 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10.0,
                      offset: const Offset(0, 4),
                    ),
                    if (isListening)
                      BoxShadow(
                        color: AppColors.aiAccent.withValues(alpha: 0.6),
                        blurRadius: 16.0,
                        spreadRadius: 2.0,
                      ),
                  ],
                ),
                child: Center(
                  child: isProcessing
                      ? const SizedBox(
                          width: 22.0,
                          height: 22.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.textPrimary),
                          ),
                        )
                      : Icon(
                          isListening
                              ? Icons.mic_rounded
                              : (hasError
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_none_rounded),
                          color: isListening
                              ? AppColors.textPrimary
                              : (hasError
                                  ? AppColors.bearish
                                  : AppColors.aiAccent),
                          size: 26.0,
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusIndicator(VoiceProvider voice) {
    if (voice.isProcessing) {
      return Container(
        width: 8.0,
        height: 8.0,
        decoration: const BoxDecoration(
          color: AppColors.gold,
          shape: BoxShape.circle,
        ),
      );
    }
    if (voice.hasError) {
      return Container(
        width: 8.0,
        height: 8.0,
        decoration: const BoxDecoration(
          color: AppColors.bearish,
          shape: BoxShape.circle,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 8.0,
          height: 8.0,
          decoration: BoxDecoration(
            color: AppColors.bullish,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.bullish
                    .withValues(alpha: 0.4 + (_pulseAnimation.value * 0.4)),
                blurRadius: 6.0,
                spreadRadius: 1.0,
              ),
            ],
          ),
        );
      },
    );
  }

  String _getStatusTitle(VoiceProvider voice) {
    if (voice.isProcessing) return 'PROCESANDO...';
    if (voice.hasError) return 'ERROR DE AUDIO';
    return 'ESCUCHANDO...';
  }

  Color _getStatusColor(VoiceProvider voice) {
    if (voice.isProcessing) return AppColors.gold;
    if (voice.hasError) return AppColors.bearish;
    return AppColors.aiAccent;
  }
}
