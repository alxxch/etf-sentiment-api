import 'package:flutter/material.dart';
import '../models/etf_data.dart';
import '../theme/app_colors.dart';
import '../widgets/ai_summary_widget.dart';
import '../widgets/etf_card_widget.dart';
import '../widgets/news_list_widget.dart';
import '../widgets/sentiment_gauge_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<EtfData> _etfList = EtfData.mocks;
  int _selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onSelectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header estilo Apple Finance
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MARKET SENTIMENT',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 2.0),
                      Text(
                        'ETF Dashboard',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: AppColors.cardBorder.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          color: AppColors.bullish,
                          size: 7.0,
                        ),
                        SizedBox(width: 6.0),
                        Text(
                          'LIVE MOCK',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Selector horizontal de Tickers (Pills / Segmented Control)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Row(
                children: List.generate(_etfList.length, (index) {
                  final item = _etfList[index];
                  final isSelected = index == _selectedIndex;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : 5.0,
                        right: index == _etfList.length - 1 ? 0 : 5.0,
                      ),
                      child: GestureDetector(
                        onTap: () => _onSelectTab(index),
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
                              item.ticker.replaceAll('.DE', ''),
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontSize: 13.0,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 8.0),

            // Contenido deslizable entre Tickers (PageView)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                itemCount: _etfList.length,
                itemBuilder: (context, index) {
                  final etf = _etfList[index];

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 32.0),
                    child: Column(
                      children: [
                        // 1. Tarjeta principal de Cotización y Variación
                        EtfCardWidget(data: etf),

                        const SizedBox(height: 16.0),

                        // 2. Medidor radial de Sentimiento de Mercado
                        SentimentGaugeWidget(score: etf.sentimentScore),

                        const SizedBox(height: 16.0),

                        // 3. Resumen inteligente generado por IA
                        AiSummaryWidget(summary: etf.aiSummary),

                        const SizedBox(height: 16.0),

                        // 4. Titulares recientes analizados
                        NewsListWidget(news: etf.news),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
