// Panel del Comité de Inversión IA — Glassmorphism — Fase 26.
//
// Muestra las opiniones individuales de los 4 agentes con iconografía
// específica, colores de rol y un veredicto final destacado del Lead Advisor.
//
// Comportamiento responsivo:
//   • Desktop (width ≥ 800): el panel se acopla en la columna derecha
//     sin bloquear el flujo principal (no modal).
//   • Móvil / Tablet: se abre como un BottomSheet con handle draggable.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/predictive_models.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

// ---------------------------------------------------------------------------
// Configuraciones por agente
// ---------------------------------------------------------------------------

class _AgentConfig {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _AgentConfig({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

const _kAgents = [
  _AgentConfig(
    key: 'technical_analyst',
    title: 'Analista Técnico',
    subtitle: 'Volatilidad · Momentum · P50',
    icon: Icons.candlestick_chart_rounded,
    color: AppColors.aiAccent,
  ),
  _AgentConfig(
    key: 'macro_economist',
    title: 'Economista Macro',
    subtitle: 'Ciclos · Inflación · Refugio',
    icon: Icons.public_rounded,
    color: AppColors.gold,
  ),
  _AgentConfig(
    key: 'risk_manager',
    title: 'Gestor de Riesgos',
    subtitle: 'P10 Downside · DCA · Diversificación',
    icon: Icons.shield_rounded,
    color: AppColors.bearish,
  ),
];

// ---------------------------------------------------------------------------
// Widget principal — CommitteePanel
// ---------------------------------------------------------------------------

class CommitteePanel extends StatefulWidget {
  final CommitteeDebate debate;

  /// Si es true, el panel se muestra en formato compacto para columna lateral.
  /// Si es false, se muestra en formato full-width para BottomSheet.
  final bool isDesktopSidebar;

  const CommitteePanel({
    super.key,
    required this.debate,
    this.isDesktopSidebar = false,
  });

  @override
  State<CommitteePanel> createState() => _CommitteePanelState();
}

class _CommitteePanelState extends State<CommitteePanel>
    with SingleTickerProviderStateMixin {
  // Estado de expansión de cada agente (índice → expandido)
  final Map<int, bool> _expanded = {0: false, 1: false, 2: false};

  late AnimationController _entryCtrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  String _agentText(String key) {
    return switch (key) {
      'technical_analyst' => widget.debate.technicalAnalyst,
      'macro_economist' => widget.debate.macroEconomist,
      'risk_manager' => widget.debate.riskManager,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entryCtrl,
      builder: (ctx, child) => Transform.translate(
        offset: Offset(0, _slideAnim.value),
        child: Opacity(opacity: _fadeAnim.value, child: child),
      ),
      child: GlassCard(
        borderColor: AppColors.gold.withValues(alpha: 0.22),
        hoverBorderColor: AppColors.gold.withValues(alpha: 0.45),
        borderRadius: 22,
        padding: const EdgeInsets.all(0),
        enableHover: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const Divider(
              color: AppColors.cardBorder,
              thickness: 0.6,
              height: 1,
            ),
            // Tarjetas de cada agente
            for (int i = 0; i < _kAgents.length; i++) ...[
              _buildAgentTile(i, _kAgents[i]),
              if (i < _kAgents.length - 1)
                const Divider(
                  color: AppColors.cardBorder,
                  thickness: 0.4,
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
            ],
            const Divider(
              color: AppColors.cardBorder,
              thickness: 0.6,
              height: 1,
            ),
            // Veredicto Final — Lead Advisor destacado
            _buildLeadAdvisorSection(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header del panel
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.gold.withValues(alpha: 0.25),
                  AppColors.aiAccent.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.groups_2_rounded,
              color: AppColors.gold,
              size: 18,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COMITÉ DE INVERSIÓN IA',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Debate de 3 expertos + Lead Advisor',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Badge "v8.0"
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.goldSoft,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: const Text(
              'v8.0',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tile expandible de cada agente
  // ---------------------------------------------------------------------------

  Widget _buildAgentTile(int index, _AgentConfig config) {
    final text = _agentText(config.key);
    final isExpanded = _expanded[index] ?? false;
    final isEmpty = text.trim().isEmpty || text.startsWith('[Análisis no disponible');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: isEmpty ? null : () => setState(() => _expanded[index] = !isExpanded),
          borderRadius: BorderRadius.circular(0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                _agentIconBadge(config),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.title,
                        style: TextStyle(
                          color: isEmpty
                              ? AppColors.textTertiary
                              : (isExpanded ? config.color : AppColors.textPrimary),
                          fontSize: 13,
                          fontWeight: isExpanded ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      Text(
                        config.subtitle,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isEmpty)
                  Icon(
                    isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: config.color.withValues(alpha: 0.7),
                    size: 20,
                  )
                else
                  const Icon(
                    Icons.hourglass_disabled_rounded,
                    color: AppColors.textTertiary,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: config.color.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: config.color.withValues(alpha: 0.18),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.55,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _agentIconBadge(_AgentConfig config) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(config.icon, color: config.color, size: 16),
    );
  }

  // ---------------------------------------------------------------------------
  // Lead Advisor — Veredicto Final
  // ---------------------------------------------------------------------------

  Widget _buildLeadAdvisorSection() {
    final verdict = widget.debate.leadAdvisor;
    final hasVerdict = verdict.isNotEmpty &&
        !verdict.startsWith('[Análisis no disponible');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.30),
                      AppColors.bullish.withValues(alpha: 0.20),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: AppColors.gold,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VEREDICTO FINAL',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    'Lead Advisor — Apple Finance Style',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.gold.withValues(alpha: 0.10),
                  AppColors.aiAccent.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.28),
                width: 1.0,
              ),
            ),
            child: hasVerdict
                ? _buildMarkdownVerdict(verdict)
                : const Text(
                    'El comité está procesando el análisis…',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Renderiza el veredicto aplicando negritas básicas a las secciones
  /// marcadas con **Texto** (sin dependencia de markdown_widget).
  Widget _buildMarkdownVerdict(String text) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int lastMatch = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatch) {
        spans.add(TextSpan(
          text: text.substring(lastMatch, match.start),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            height: 1.55,
            fontWeight: FontWeight.w400,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.5,
          height: 1.55,
          fontWeight: FontWeight.w700,
        ),
      ));
      lastMatch = match.end;
    }
    if (lastMatch < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatch),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12.5,
          height: 1.55,
          fontWeight: FontWeight.w400,
        ),
      ));
    }

    return Text.rich(TextSpan(children: spans));
  }
}

// ---------------------------------------------------------------------------
// Helper para abrir el panel como BottomSheet en móvil
// ---------------------------------------------------------------------------

/// Abre el [CommitteePanel] como un [DraggableScrollableSheet] en dispositivos
/// móviles / tablet, o lo devuelve como widget para embeber en desktop.
Future<void> showCommitteePanelSheet(
  BuildContext context,
  CommitteeDebate debate,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: const Color(0xFF1C1C1E).withValues(alpha: 0.92),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Handle visual draggable
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: CommitteePanel(
                      debate: debate,
                      isDesktopSidebar: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
