class EtfHistoryEntry {
  final int? id;
  final String ticker;
  final double price;
  final double changePercent;
  final int sentimentScore;
  final String aiSummary;
  final DateTime timestamp;

  const EtfHistoryEntry({
    this.id,
    required this.ticker,
    required this.price,
    required this.changePercent,
    required this.sentimentScore,
    required this.aiSummary,
    required this.timestamp,
  });

  factory EtfHistoryEntry.fromJson(Map<String, dynamic> json) {
    DateTime parsedTime;
    final rawTs = json['timestamp'];
    if (rawTs is String && rawTs.isNotEmpty) {
      parsedTime = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    return EtfHistoryEntry(
      id: json['id'] is int ? json['id'] as int : null,
      ticker: (json['ticker'] ?? '').toString(),
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0.0,
      changePercent: (json['change_percent'] is num)
          ? (json['change_percent'] as num).toDouble()
          : 0.0,
      sentimentScore: (json['sentiment_score'] is num)
          ? (json['sentiment_score'] as num).toInt()
          : 50,
      aiSummary: (json['ai_summary'] ?? '').toString(),
      timestamp: parsedTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticker': ticker,
      'price': price,
      'change_percent': changePercent,
      'sentiment_score': sentimentScore,
      'ai_summary': aiSummary,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get formattedShortDate {
    final day = timestamp.day.toString().padLeft(2, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  @override
  String toString() {
    return 'EtfHistoryEntry(ticker: $ticker, price: $price, score: $sentimentScore, time: $timestamp)';
  }
}
