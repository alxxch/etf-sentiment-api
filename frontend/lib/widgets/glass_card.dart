import 'dart:ui';
import 'package:flutter/material.dart';

/// Contenedor flotante con efecto Glassmorphism para Spatial UI v6.0 / v7.0.
///
/// Implementa [BackdropFilter] con [ImageFilter.blur] (sigma 10),
/// fondo #1C1C1E al 40% de opacidad y bordes sutiles con sombreado volumétrico.
/// Cuenta con detección de cursor ([MouseRegion]) y efectos interactivos de Hover
/// (elevación volumétrica y aumento de opacidad en el borde) para Desktop UX nativo.
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? hoverBorderColor;
  final double borderWidth;
  final double blurSigma;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool enableHover;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20.0,
    this.borderColor,
    this.hoverBorderColor,
    this.borderWidth = 1.0,
    this.blurSigma = 10.0,
    this.backgroundColor,
    this.onTap,
    this.enableHover = true,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final baseBorderColor =
        widget.borderColor ?? Colors.white.withValues(alpha: 0.10);
    final hoverBorderColor = widget.hoverBorderColor ??
        (widget.borderColor != null
            ? widget.borderColor!.withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.28));

    final currentBorderColor =
        (_isHovered && widget.enableHover) ? hoverBorderColor : baseBorderColor;

    final currentShadow = (_isHovered && widget.enableHover)
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.48),
              blurRadius: 22.0,
              offset: const Offset(0, 9),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              blurRadius: 10.0,
              offset: const Offset(0, 2),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16.0,
              offset: const Offset(0, 6),
            ),
          ];

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        if (widget.enableHover && mounted) {
          setState(() => _isHovered = true);
        }
      },
      onExit: (_) {
        if (widget.enableHover && mounted) {
          setState(() => _isHovered = false);
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: widget.margin ?? EdgeInsets.zero,
          transform: (_isHovered && widget.enableHover)
              ? Matrix4.translationValues(0, -3.0, 0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: currentShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.blurSigma,
                sigmaY: widget.blurSigma,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: widget.padding ?? const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: widget.backgroundColor ??
                      const Color(0xFF1C1C1E).withValues(alpha: 0.40),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: currentBorderColor,
                    width: widget.borderWidth,
                  ),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
