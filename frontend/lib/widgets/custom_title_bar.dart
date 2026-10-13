import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_colors.dart';

/// Barra de título personalizada para entorno de escritorio (Fase 23).
///
/// Diseñada con estética "Apple Finance":
/// - Fondo oscuro puro (#000000).
/// - Tipografía sutil en escala de grises con badge de estado.
/// - Área de arrastre fluida mediante [DragToMoveArea] para mover y maximizar con doble click.
/// - Botones de control de ventana (minimizar, maximizar/restaurar, cerrar) conectados a [windowManager].
class CustomTitleBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onMinimize;
  final VoidCallback? onMaximize;
  final VoidCallback? onClose;

  const CustomTitleBar({
    super.key,
    this.title = 'Smart Market Sentiment & ETF Dashboard',
    this.onMinimize,
    this.onMaximize,
    this.onClose,
  });

  @override
  Size get preferredSize => const Size.fromHeight(38.0);

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.addListener(this);
      _checkInitialMaximizedState();
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _checkInitialMaximizedState() async {
    try {
      final isMax = await windowManager.isMaximized();
      if (mounted) {
        setState(() {
          _isMaximized = isMax;
        });
      }
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  void onWindowRestore() {
    if (mounted) setState(() => _isMaximized = false);
  }

  Future<void> _handleMinimize() async {
    if (widget.onMinimize != null) {
      widget.onMinimize!();
      return;
    }
    try {
      await windowManager.minimize();
    } catch (e) {
      debugPrint('[CustomTitleBar] Error al minimizar: $e');
    }
  }

  Future<void> _handleMaximize() async {
    if (widget.onMaximize != null) {
      widget.onMaximize!();
      return;
    }
    try {
      final isMax = await windowManager.isMaximized();
      if (isMax) {
        await windowManager.unmaximize();
        if (mounted) setState(() => _isMaximized = false);
      } else {
        await windowManager.maximize();
        if (mounted) setState(() => _isMaximized = true);
      }
    } catch (e) {
      debugPrint('[CustomTitleBar] Error al alternar maximizado: $e');
    }
  }

  Future<void> _handleClose() async {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    try {
      await windowManager.close();
    } catch (e) {
      debugPrint('[CustomTitleBar] Error al cerrar ventana: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38.0,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF1B1E28),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Área arrastrable (DragToMoveArea) que cubre el logo y título
          Expanded(
            child: DragToMoveArea(
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    // Icono de la aplicación estilo Apple Finance
                    Container(
                      width: 18.0,
                      height: 18.0,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.bullish, AppColors.aiAccent],
                        ),
                        borderRadius: BorderRadius.circular(4.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.bullish.withValues(alpha: 0.25),
                            blurRadius: 6.0,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.candlestick_chart_rounded,
                          size: 11.0,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10.0),

                    // Título de la app en gris sutil
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.35,
                      ),
                    ),
                    const SizedBox(width: 8.0),

                    // Badge de versión / status
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141721),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(
                          color: const Color(0xFF242A38),
                          width: 1.0,
                        ),
                      ),
                      child: const Text(
                        'v7.0',
                        style: TextStyle(
                          color: Color(0xFF757575),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Botones de control de ventana (Minimizar, Maximizar, Cerrar)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WindowControlButton(
                icon: Icons.remove_rounded,
                tooltip: 'Minimizar',
                onPressed: _handleMinimize,
              ),
              _WindowControlButton(
                icon: _isMaximized
                    ? Icons.filter_none_rounded
                    : Icons.crop_square_rounded,
                iconSize: _isMaximized ? 11.5 : 13.0,
                tooltip: _isMaximized ? 'Restaurar' : 'Maximizar',
                onPressed: _handleMaximize,
              ),
              _WindowControlButton(
                icon: Icons.close_rounded,
                tooltip: 'Cerrar',
                isClose: true,
                onPressed: _handleClose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Botón individual de control de ventana con efecto Hover refinado
class _WindowControlButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final String tooltip;
  final bool isClose;
  final VoidCallback onPressed;

  const _WindowControlButton({
    required this.icon,
    this.iconSize = 14.0,
    required this.tooltip,
    this.isClose = false,
    required this.onPressed,
  });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _isHovered
        ? (widget.isClose
            ? const Color(0xFFE81123)
            : Colors.white.withValues(alpha: 0.12))
        : Colors.transparent;

    final iconColor = _isHovered
        ? Colors.white
        : const Color(0xFF8E8E93);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 44.0,
            height: 38.0,
            color: backgroundColor,
            child: Center(
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
