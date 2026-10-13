import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/portfolio_provider.dart';
import '../providers/voice_provider.dart';
import '../theme/app_colors.dart';

/// Botón interactivo del asistente de voz con halo reactivo estilo Apple Finance
/// y previsualización de transcripción y respuesta multimodal en tiempo real (Fase 12).
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
        // Conexión reactiva con PortfolioProvider si está disponible en el árbol
        try {
          final portfolio = context.read<PortfolioProvider>();
          voice.attachPortfolioProvider(portfolio);
        } catch (_) {}

        final isListening = voice.isListening;
        final isInferringLocal = voice.isInferringLocal;
        final isProcessing = voice.isProcessing;
        final isSpeaking = voice.isSpeaking;
        final hasError = voice.hasError;

        final isAnimatedState = isListening || isInferringLocal || isSpeaking;

        if (isAnimatedState) {
          if (!_pulseController.isAnimating) {
            _pulseController.repeat(reverse: true);
          }
        } else {
          if (_pulseController.isAnimating) {
            _pulseController.stop();
            _pulseController.reset();
          }
        }

        final showOverlayCard =
            isListening || isInferringLocal || isProcessing || isSpeaking || hasError;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 1. Tarjeta flotante con transcripción / respuesta en vivo
            if (showOverlayCard) ...[
              _buildLiveTranscriptionCard(context, voice),
              const SizedBox(height: 12.0),
            ],

            // 2. Botón pulsante con Halo Siri / Apple Intelligence
            _buildMicrophoneFab(
              voice,
              isListening,
              isInferringLocal,
              isProcessing,
              isSpeaking,
              hasError,
            ),
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
              : (voice.isSpeaking
                  ? AppColors.bullish.withValues(alpha: 0.6)
                  : (voice.hasError
                      ? AppColors.bearish.withValues(alpha: 0.6)
                      : AppColors.cardBorder)),
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
          if (voice.isSpeaking)
            BoxShadow(
              color: AppColors.bullish.withValues(alpha: 0.2),
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
              Expanded(
                child: Row(
                  children: [
                    _buildStatusIndicator(voice),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        _getStatusTitle(voice),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _getStatusColor(voice),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  voice.cancelListening();
                },
                child: Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: const BoxDecoration(
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

          // Texto capturado en vivo o respuesta hablada
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
          ] else if (voice.isSpeaking) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.volume_up_rounded,
                  color: AppColors.bullish,
                  size: 20.0,
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text(
                    voice.assistantResponse.isNotEmpty
                        ? voice.assistantResponse
                        : 'Respuesta procesada correctamente.',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            if (voice.transcribedText.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              Text(
                'Tú: "${voice.transcribedText}"',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ] else if (voice.isInferringLocal) ...[
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
                    'Transcribiendo con Whisper Edge STT...',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            const Text(
              'Inferencia local en el dispositivo (sin nube)',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
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
    bool isInferringLocal,
    bool isProcessing,
    bool isSpeaking,
    bool hasError,
  ) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final isPulsing = isListening || isInferringLocal || isSpeaking;
        final pulseScale =
            isPulsing ? 1.0 + (_pulseAnimation.value * 0.18) : 1.0;
        final pulseGlow = isPulsing ? _pulseAnimation.value : 0.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Halo concéntrico exterior (Siri / Apple Finance pulse)
            if (isPulsing)
              Container(
                width: 68.0 * pulseScale,
                height: 68.0 * pulseScale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isSpeaking ? AppColors.bullish : AppColors.aiAccent)
                          .withValues(alpha: 0.45 * (1.0 - pulseGlow * 0.5)),
                      AppColors.bullish
                          .withValues(alpha: 0.15 * (1.0 - pulseGlow * 0.5)),
                      Colors.transparent,
                    ],
                    stops: const [0.3, 0.7, 1.0],
                  ),
                ),
              ),

            // Botón principal con soporte Push-to-Talk y Toggle
            GestureDetector(
              onTap: () => _onButtonTap(voice),
              onLongPressStart: (_) {
                HapticFeedback.heavyImpact();
                voice.startListening();
              },
              onLongPressEnd: (_) {
                HapticFeedback.mediumImpact();
                voice.stopListening();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56.0,
                height: 56.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSpeaking
                      ? AppColors.bullish
                      : (isListening || isInferringLocal
                          ? AppColors.aiAccent
                          : (hasError
                              ? AppColors.bearishSoft
                              : AppColors.cardSurface)),
                  border: Border.all(
                    color: isSpeaking
                        ? AppColors.textPrimary
                        : (isListening || isInferringLocal
                            ? AppColors.textPrimary
                            : (hasError
                                ? AppColors.bearish
                                : AppColors.cardBorder)),
                    width: (isListening || isInferringLocal || isSpeaking) ? 2.0 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10.0,
                      offset: const Offset(0, 4),
                    ),
                    if (isListening || isInferringLocal)
                      BoxShadow(
                        color: AppColors.aiAccent.withValues(alpha: 0.6),
                        blurRadius: 16.0,
                        spreadRadius: 2.0,
                      ),
                    if (isSpeaking)
                      BoxShadow(
                        color: AppColors.bullish.withValues(alpha: 0.6),
                        blurRadius: 16.0,
                        spreadRadius: 2.0,
                      ),
                  ],
                ),
                child: Center(
                  child: (isProcessing || isInferringLocal)
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
                          isSpeaking
                              ? Icons.volume_up_rounded
                              : (isListening
                                  ? Icons.mic_rounded
                                  : (hasError
                                      ? Icons.mic_off_rounded
                                      : Icons.mic_none_rounded)),
                          color: (isListening || isSpeaking)
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
    if (voice.isInferringLocal) {
      return Container(
        width: 8.0,
        height: 8.0,
        decoration: const BoxDecoration(
          color: AppColors.aiAccent,
          shape: BoxShape.circle,
        ),
      );
    }
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
    if (voice.isSpeaking) {
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
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 8.0,
          height: 8.0,
          decoration: BoxDecoration(
            color: AppColors.aiAccent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.aiAccent
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
    if (voice.isSpeaking) return 'ASISTENTE RESPONDIENDO...';
    if (voice.isInferringLocal) return 'TRANSCRIBIENDO (WHISPER LOCAL)...';
    if (voice.isProcessing) return 'PROCESANDO...';
    if (voice.hasError) return 'ERROR DE AUDIO';
    return 'ESCUCHANDO...';
  }

  Color _getStatusColor(VoiceProvider voice) {
    if (voice.isSpeaking) return AppColors.bullish;
    if (voice.isInferringLocal) return AppColors.aiAccent;
    if (voice.isProcessing) return AppColors.gold;
    if (voice.hasError) return AppColors.bearish;
    return AppColors.aiAccent;
  }
}
