class EtfData {
  final String ticker;
  final double currentPrice;
  final double changePercent;
  final String currency;
  final int sentimentScore;
  final String aiSummary;
  final List<String> news;
  final String? audioBase64;

  const EtfData({
    required this.ticker,
    required this.currentPrice,
    required this.changePercent,
    this.currency = 'EUR',
    required this.sentimentScore,
    required this.aiSummary,
    this.news = const [],
    this.audioBase64,
  });

  factory EtfData.fromJson(Map<String, dynamic> json) {
    return EtfData(
      ticker: json['ticker'] as String? ?? '',
      currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0.0,
      changePercent: (json['change_percent'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'EUR',
      sentimentScore: (json['sentiment_score'] as num?)?.toInt() ?? 50,
      aiSummary: json['ai_summary'] as String? ?? '',
      news: (json['news'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      audioBase64: json['audio_base64'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ticker': ticker,
      'current_price': currentPrice,
      'change_percent': changePercent,
      'currency': currency,
      'sentiment_score': sentimentScore,
      'ai_summary': aiSummary,
      'news': news,
      'audio_base64': audioBase64,
    };
  }

  bool get isPositive => changePercent >= 0;

  bool get hasAudio => audioBase64 != null && audioBase64!.trim().isNotEmpty;

  String get formattedPrice => '${currentPrice.toStringAsFixed(2)} $currency';

  String get formattedChange =>
      '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(2)}%';

  String get sentimentLabel {
    if (sentimentScore >= 65) return 'Bullish';
    if (sentimentScore <= 40) return 'Bearish';
    return 'Neutral';
  }

  /// Datos simulados (mocks) para previsualización
  static List<EtfData> get mocks => [
        const EtfData(
          ticker: 'VWCE.DE',
          currentPrice: 172.86,
          changePercent: 0.56,
          currency: 'EUR',
          sentimentScore: 68,
          aiSummary:
              'El mercado global muestra una tendencia moderadamente alcista impulsada por la diversificación internacional y flujos hacia índices globales tras la consolidación de las megacaps tecnológicas.',
          news: [
            'Barclays says AI trade is maturing, favors greater diversification',
            'Is Vanguard FTSE All-World ex-US Index Admiral a Strong Pick Right Now?',
            'Global ETF flows reach record quarterly volumes across European exchanges',
          ],
        ),
        const EtfData(
          ticker: 'EUNL.DE',
          currentPrice: 131.64,
          changePercent: 0.51,
          currency: 'EUR',
          sentimentScore: 62,
          aiSummary:
              'Sentimiento equilibrado con sesgo positivo en economías desarrolladas. Los inversores institucionales mantienen posiciones estratégicas en el índice MSCI World.',
          news: [
            'Two International ETFs With Contrasting Styles: iShares MSCI World ETF',
            'Better International ETF: Vanguard VEA vs. iShares URTH',
            'European investors continue accumulating core equity exposures',
          ],
        ),
        const EtfData(
          ticker: '8PSG.DE',
          currentPrice: 360.06,
          changePercent: 1.84,
          currency: 'EUR',
          sentimentScore: 84,
          aiSummary:
              'Fuerte optimismo en activos refugio. El oro físico registra máximos históricos debido a la flexibilización de tasas globales y alta demanda de bancos centrales.',
          news: [
            'A Record \$31 Billion Gold Rush Is Sending Investors Warning Signals',
            'UBS Sees Gold Support Near \$4,000, Forecasts Continued Upward Momentum',
            'Central bank reserves expansion drives physical gold ETC inflows',
          ],
        ),
      ];
}
