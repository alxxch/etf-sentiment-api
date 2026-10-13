import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../theme/app_colors.dart';

class AiSummaryWidget extends StatelessWidget {
  final String summary;
  final String? audioBase64;
  final String? ticker;

  const AiSummaryWidget({
    super.key,
    required this.summary,
    this.audioBase64,
    this.ticker,
  });

  @override
  Widget build(BuildContext context) {
    final audioService = context.watch<AudioService>();
    final isPlaying = audioService.isPlayingKey(ticker ?? audioBase64.hashCode.toString());
    final hasAudio = audioBase64 != null && audioBase64!.trim().isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: isPlaying
              ? AppColors.aiAccent.withValues(alpha: 0.8)
              : AppColors.cardBorder.withValues(alpha: 0.6),
          width: isPlaying ? 1.5 : 1.0,
        ),
        boxShadow: isPlaying
            ? [
                BoxShadow(
                  color: AppColors.aiAccent.withValues(alpha: 0.18),
                  blurRadius: 18.0,
                  spreadRadius: 1.0,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: isPlaying ? AppColors.bullishSoft : AppColors.aiAccentSoft,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: isPlaying ? AppColors.bullish : AppColors.aiAccent,
                        size: 18.0,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    const Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RESUMEN INTELIGENTE (IA)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.0,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            'Google Gemini & ElevenLabs',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Botón minimalista de Play/Pause con indicador de onda animada
              if (hasAudio)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPlaying) ...[
                      const _SoundWaveBars(),
                      const SizedBox(width: 8.0),
                    ],
                    GestureDetector(
                      onTap: () {
                        audioService.togglePlayPause(
                          audioBase64!,
                          audioKey: ticker ?? audioBase64.hashCode.toString(),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 6.0,
                        ),
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? AppColors.bullishSoft
                              : AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(
                            color: isPlaying
                                ? AppColors.bullish.withValues(alpha: 0.6)
                                : AppColors.cardBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: isPlaying
                                  ? AppColors.bullish
                                  : AppColors.textPrimary,
                              size: 18.0,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              isPlaying ? 'PAUSAR' : 'BRIEFING',
                              style: TextStyle(
                                color: isPlaying
                                    ? AppColors.bullish
                                    : AppColors.textPrimary,
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16.0),
          Text(
            summary.isNotEmpty
                ? summary
                : 'Sin análisis generado para este activo en este momento.',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15.0,
              height: 1.55,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador visual animado de ondas de sonido estilo iOS
class _SoundWaveBars extends StatefulWidget {
  const _SoundWaveBars();

  @override
  State<_SoundWaveBars> createState() => _SoundWaveBarsState();
}

class _SoundWaveBarsState extends State<_SoundWaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildBar(6.0 + 10.0 * val),
            const SizedBox(width: 2.5),
            _buildBar(16.0 - 10.0 * val),
            const SizedBox(width: 2.5),
            _buildBar(8.0 + 8.0 * (1.0 - val)),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.8,
      height: height.clamp(4.0, 18.0),
      decoration: BoxDecoration(
        color: AppColors.bullish,
        borderRadius: BorderRadius.circular(2.0),
      ),
    );
  }
}
