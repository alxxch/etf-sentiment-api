import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/etf_data.dart';
import '../providers/etf_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/voice_provider.dart';
import '../services/audio_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ai_summary_widget.dart';
import '../widgets/category_selector.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/etf_card_widget.dart';
import '../widgets/glass_card.dart';
import '../widgets/history_chart_widget.dart';
import '../widgets/news_list_widget.dart';
import '../widgets/notifications_panel.dart';
import '../widgets/sentiment_gauge_widget.dart';
import '../widgets/predictive_chart_widget.dart';
import '../widgets/committee_panel.dart';
import '../widgets/voice_assistant_button.dart';
import 'banking_screen.dart';
import 'portfolio_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _pageController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    final initialIndex = context.read<EtfProvider>().selectedIndex;
    _pageController = PageController(initialPage: initialIndex);

    // Inicialización segura post-frame si la lista de datos está vacía
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<EtfProvider>().fetchInitialData();
        context.read<NotificationProvider>().loadNotifications();

        try {
          final voice = context.read<VoiceProvider>();
          voice.onActionExecuted = (actionType, payload) {
            if (!mounted) return;
            if (actionType == 'REBALANCE_ADVICE_QUERIED' ||
                actionType == 'PORTFOLIO_REBALANCE' ||
                actionType == 'PORTFOLIO_QUERY') {
              setState(() {
                _currentTabIndex = 1;
              });
            } else if (actionType == 'NOTIFICATIONS_QUERIED') {
              showNotificationsPanel(context);
            } else if (actionType == 'INVESTMENT_COMMITTEE' ||
                voice.hasCommitteeDebate) {
              final isDesktop = MediaQuery.of(context).size.width >= 800;
              if (!isDesktop && voice.committeeDebate != null) {
                showCommitteePanelSheet(context, voice.committeeDebate!);
              }
            }
          };
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onSelectTab(int index, EtfProvider provider) {
    if (provider.selectedIndex != index) {
      context.read<AudioService>().stop();
      provider.selectTickerIndex(index);
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EtfProvider>(
      builder: (context, provider, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 800;

            final content = IndexedStack(
              index: _currentTabIndex,
              children: [
                _buildMarketTab(provider, isDesktop: isDesktop),
                const PortfolioScreen(),
                const BankingScreen(),
              ],
            );

            return Scaffold(
              backgroundColor: AppColors.background,
              body: isDesktop
                  ? Column(
                      children: [
                        const CustomTitleBar(),
                        Expanded(
                          child: Row(
                            children: [
                              _buildNavigationRail(),
                              const VerticalDivider(
                                thickness: 1.0,
                                width: 1.0,
                                color: AppColors.cardBorder,
                              ),
                              Expanded(child: content),
                            ],
                          ),
                        ),
                      ],
                    )
                  : content,
              bottomNavigationBar:
                  isDesktop ? null : _buildBottomNavigationBar(),
              floatingActionButton: const VoiceAssistantButton(),
              floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            );
          },
        );
      },
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _currentTabIndex,
      onDestinationSelected: (index) {
        setState(() {
          _currentTabIndex = index;
        });
      },
      backgroundColor: AppColors.cardSurface,
      indicatorColor: AppColors.surfaceSecondary,
      labelType: NavigationRailLabelType.all,
      minWidth: 78.0,
      leading: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16.0, 0, 16.0),
        child: Container(
          width: 44.0,
          height: 44.0,
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.8),
              width: 1.0,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.query_stats_rounded,
              color: AppColors.aiAccent,
              size: 22.0,
            ),
          ),
        ),
      ),
      selectedIconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 22.0,
      ),
      unselectedIconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 20.0,
      ),
      selectedLabelTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11.0,
        fontWeight: FontWeight.w500,
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.trending_up_rounded),
          selectedIcon:
              Icon(Icons.trending_up_rounded, color: AppColors.aiAccent),
          label: Text('Mercado'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.pie_chart_outline_rounded),
          selectedIcon: Icon(Icons.pie_chart_rounded, color: AppColors.bullish),
          label: Text('Mi Cartera'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.account_balance_outlined),
          selectedIcon:
              Icon(Icons.account_balance_rounded, color: AppColors.gold),
          label: Text('Cuentas'),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(
          top: BorderSide(
            color: AppColors.cardBorder,
            width: 0.8,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        backgroundColor: AppColors.cardSurface,
        elevation: 0,
        selectedItemColor: AppColors.textPrimary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 11.5,
        unselectedFontSize: 11.5,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up_rounded),
            activeIcon:
                Icon(Icons.trending_up_rounded, color: AppColors.aiAccent),
            label: 'Mercado',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline_rounded),
            activeIcon:
                Icon(Icons.pie_chart_rounded, color: AppColors.bullish),
            label: 'Mi Cartera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_outlined),
            activeIcon:
                Icon(Icons.account_balance_rounded, color: AppColors.gold),
            label: 'Cuentas',
          ),
        ],
      ),
    );
  }

  Widget _buildMarketTab(EtfProvider provider, {required bool isDesktop}) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header estilo Apple Finance
          _buildHeader(provider),

          // Selector horizontal de Categorías (Pills / Chips)
          CategorySelector(
            categories: EtfProvider.categories.keys.toList(),
            selectedCategory: provider.selectedCategory,
            onCategorySelected: (category) {
              if (provider.selectedCategory != category) {
                context.read<AudioService>().stop();
                provider.selectCategory(category);
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(0);
                }
              }
            },
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2.0),
          ),

          const SizedBox(height: 6.0),

          // Selector horizontal de Tickers (Pills / Segmented Control) - solo en móvil
          if (!isDesktop) _buildTickerSelector(provider),

          const SizedBox(height: 8.0),

          // Contenido dinámico conectado reactivamente al Provider
          Expanded(
            child: isDesktop
                ? _buildDesktopMarketBody(provider)
                : _buildBody(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(EtfProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MARKET SENTIMENT',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  '${provider.selectedCategory} Dashboard',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge dinámico de estado en vivo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: AppColors.cardBorder.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (provider.isLoading) ...[
                      const SizedBox(
                        width: 8.0,
                        height: 8.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.aiAccent),
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      const Text(
                        'SINCRONIZANDO',
                        style: TextStyle(
                          color: AppColors.aiAccent,
                          fontSize: 10.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.circle,
                        color: provider.hasData ? AppColors.bullish : AppColors.bearish,
                        size: 7.0,
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        provider.hasData ? 'LIVE • FASTAPI' : 'OFFLINE',
                        style: TextStyle(
                          color: provider.hasData
                              ? AppColors.textSecondary
                              : AppColors.bearish,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4.0),
              const NotificationBellButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTickerSelector(EtfProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        children: List.generate(provider.tickers.length, (index) {
          final ticker = provider.tickers[index];
          final isSelected = index == provider.selectedIndex;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 5.0,
                right: index == provider.tickers.length - 1 ? 0 : 5.0,
              ),
              child: GestureDetector(
                onTap: () => _onSelectTab(index, provider),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.surfaceSecondary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.cardBorder
                          : Colors.transparent,
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      ticker.replaceAll('.DE', '').replaceAll('.L', ''),
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 13.0,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 38.0,
            height: 38.0,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.bullish),
            ),
          ),
          const SizedBox(height: 24.0),
          const Text(
            'Consultando cotizaciones de ETFs...',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            'Analizando titulares con Gemini LLM',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 13.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(EtfProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.bearishSoft,
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.bearish,
                size: 40.0,
              ),
            ),
            const SizedBox(height: 20.0),
            const Text(
              'No se pudo conectar con el Backend',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10.0),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24.0),
            ElevatedButton.icon(
              onPressed: () => provider.loadData(force: true),
              icon: const Icon(Icons.refresh_rounded, size: 18.0),
              label: const Text('Reintentar conexión'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceSecondary,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22.0, vertical: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopMarketBody(EtfProvider provider) {
    if (provider.isLoading && !provider.hasData) {
      return _buildLoadingState();
    }

    if (provider.errorMessage != null && !provider.hasData) {
      return _buildErrorState(provider);
    }

    final activeTicker = (provider.selectedIndex < provider.tickers.length)
        ? provider.tickers[provider.selectedIndex]
        : (provider.tickers.isNotEmpty ? provider.tickers.first : 'SWDA.L');

    final activeEtf = provider.allEtfs.firstWhere(
      (item) => item.ticker == activeTicker,
      orElse: () => EtfData(
        ticker: activeTicker,
        currentPrice: 0.0,
        changePercent: 0.0,
        currency: activeTicker.endsWith('.DE') ? 'EUR' : 'USD',
        sentimentScore: 50,
        aiSummary: provider.isTickerLoading(activeTicker)
            ? 'Cargando datos para $activeTicker...'
            : 'Sin datos disponibles para $activeTicker.',
      ),
    );

    return RefreshIndicator(
      color: AppColors.bullish,
      backgroundColor: AppColors.cardSurface,
      onRefresh: () => provider.loadData(force: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. GridView responsivo de tarjetas de ETFs (aprovecha ancho en varias columnas)
            LayoutBuilder(
              builder: (context, gridConstraints) {
                final crossAxisCount = gridConstraints.maxWidth > 1100
                    ? 3
                    : (gridConstraints.maxWidth > 650 ? 2 : 1);

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                    mainAxisExtent: 215.0,
                  ),
                  itemCount: provider.tickers.length,
                  itemBuilder: (context, index) {
                    final ticker = provider.tickers[index];
                    final isCardLoading = provider.isTickerLoading(ticker);
                    final etf = provider.allEtfs.firstWhere(
                      (item) => item.ticker == ticker,
                      orElse: () => EtfData(
                        ticker: ticker,
                        currentPrice: 0.0,
                        changePercent: 0.0,
                        currency: ticker.endsWith('.DE') ? 'EUR' : 'USD',
                        sentimentScore: 50,
                        aiSummary: 'Cargando datos para $ticker...',
                      ),
                    );
                    final isSelected = index == provider.selectedIndex;

                    return GlassCard(
                      onTap: () {
                        context.read<AudioService>().stop();
                        provider.selectTickerIndex(index);
                      },
                      borderColor: isSelected
                          ? AppColors.aiAccent
                          : AppColors.cardBorder.withValues(alpha: 0.6),
                      borderWidth: isSelected ? 2.0 : 1.0,
                      padding: EdgeInsets.zero,
                      child: Stack(
                        children: [
                          EtfCardWidget(
                            data: etf,
                            isLoading: isCardLoading,
                          ),
                          if (isSelected)
                            Positioned(
                              top: 12,
                              right: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 3.0,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.aiAccent
                                      .withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(
                                    color: AppColors.aiAccent,
                                    width: 1.0,
                                  ),
                                ),
                                child: const Text(
                                  'ACTIVO',
                                  style: TextStyle(
                                    color: AppColors.aiAccent,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 20.0),

            // Fase 26: Proyección Fan Chart de Monte Carlo en Desktop
            Builder(
              builder: (ctx) {
                final voice = ctx.watch<VoiceProvider>();
                if (!voice.hasMonteCarloResult) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: PredictiveChartWidget(
                    result: voice.monteCarloResult!,
                    history: provider.getHistoryFor(activeTicker),
                  ),
                );
              },
            ),

            // 2. Sección de Análisis Detallado del ETF Activo en layout responsivo
            LayoutBuilder(
              builder: (context, detailConstraints) {
                final voice = context.watch<VoiceProvider>();
                final isWide = detailConstraints.maxWidth >= 850;

                final leftAnalytics = Column(
                  children: [
                    SentimentGaugeWidget(score: activeEtf.sentimentScore),
                    const SizedBox(height: 16.0),
                    HistoryChartWidget(
                      history: provider.getHistoryFor(activeTicker),
                      ticker: activeTicker,
                    ),
                  ],
                );

                final rightAnalytics = Column(
                  children: [
                    AiSummaryWidget(
                      summary: activeEtf.aiSummary,
                      audioBase64: activeEtf.audioBase64,
                      ticker: activeEtf.ticker,
                    ),
                    const SizedBox(height: 16.0),
                    NewsListWidget(news: activeEtf.news),
                  ],
                );

                // Si hay un debate del comité de IA activo, acoplarlo en la columna derecha
                if (voice.hasCommitteeDebate) {
                  final committeeWidget = CommitteePanel(
                    debate: voice.committeeDebate!,
                    isDesktopSidebar: true,
                  );

                  if (detailConstraints.maxWidth >= 1200) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: leftAnalytics),
                        const SizedBox(width: 16.0),
                        Expanded(flex: 3, child: rightAnalytics),
                        const SizedBox(width: 16.0),
                        Expanded(flex: 4, child: committeeWidget),
                      ],
                    );
                  } else if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              leftAnalytics,
                              const SizedBox(height: 16.0),
                              rightAnalytics,
                            ],
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(flex: 1, child: committeeWidget),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        committeeWidget,
                        const SizedBox(height: 16.0),
                        leftAnalytics,
                        const SizedBox(height: 16.0),
                        rightAnalytics,
                      ],
                    );
                  }
                }

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 1, child: leftAnalytics),
                      const SizedBox(width: 16.0),
                      Expanded(flex: 1, child: rightAnalytics),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      leftAnalytics,
                      const SizedBox(height: 16.0),
                      rightAnalytics,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(EtfProvider provider) {
    // 1. Estado inicial de carga completa (sin datos en memoria)
    if (provider.isLoading && !provider.hasData) {
      return _buildLoadingState();
    }

    // 2. Estado de error global de conexión
    if (provider.errorMessage != null && !provider.hasData) {
      return _buildErrorState(provider);
    }

    // 3. Vista reactiva con PageView conectado a los datos en vivo (Layout Móvil)
    return RefreshIndicator(
      color: AppColors.bullish,
      backgroundColor: AppColors.cardSurface,
      onRefresh: () => provider.loadData(force: true),
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          context.read<AudioService>().stop();
          provider.selectTickerIndex(index);
        },
        itemCount: provider.tickers.length,
        itemBuilder: (context, index) {
          final ticker = provider.tickers[index];
          final isCardLoading = provider.isTickerLoading(ticker);
          final etf = provider.allEtfs.firstWhere(
            (item) => item.ticker == ticker,
            orElse: () => EtfData(
              ticker: ticker,
              currentPrice: 0.0,
              changePercent: 0.0,
              currency: ticker.endsWith('.DE') ? 'EUR' : 'USD',
              sentimentScore: 50,
              aiSummary: 'Cargando datos para $ticker...',
            ),
          );

          final voice = context.watch<VoiceProvider>();

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 32.0),
            child: Column(
              children: [
                // 1. Tarjeta principal de Cotización y Variación en tiempo real
                EtfCardWidget(
                  data: etf,
                  isLoading: isCardLoading,
                ),

                // Fase 26: Panel del Comité de IA si hay debate activo
                if (voice.hasCommitteeDebate) ...[
                  const SizedBox(height: 16.0),
                  CommitteePanel(debate: voice.committeeDebate!),
                ],

                // Fase 26: Gráfico Fan Chart de Monte Carlo
                if (voice.hasMonteCarloResult) ...[
                  const SizedBox(height: 16.0),
                  PredictiveChartWidget(
                    result: voice.monteCarloResult!,
                    history: provider.getHistoryFor(ticker),
                  ),
                ],

                const SizedBox(height: 16.0),

                // 2. Medidor radial de Sentimiento de Mercado generado por Gemini
                SentimentGaugeWidget(score: etf.sentimentScore),

                const SizedBox(height: 16.0),

                // 3. Gráfico Histórico de Sentimiento (PostgreSQL / Celery)
                HistoryChartWidget(
                  history: provider.getHistoryFor(ticker),
                  ticker: ticker,
                ),

                const SizedBox(height: 16.0),

                // 4. Resumen narrativo y Flash Briefing con ElevenLabs TTS
                AiSummaryWidget(
                  summary: etf.aiSummary,
                  audioBase64: etf.audioBase64,
                  ticker: etf.ticker,
                ),

                const SizedBox(height: 16.0),

                // 4. Titulares financieros analizados
                NewsListWidget(news: etf.news),
              ],
            ),
          );
        },
      ),
    );
  }
}
