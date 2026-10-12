// Modelos de datos para el ecosistema Fintech y Cartera de Inversión (v3.0).

class AssetAllocationItem {
  final String ticker;
  final String assetClass; // EQUITY o GOLD
  final double shares;
  final double currentPrice;
  final double currentValue;
  final double allocationPct;
  final double breakEvenPrice;
  final double pnl;
  final double roiPct;

  const AssetAllocationItem({
    required this.ticker,
    required this.assetClass,
    required this.shares,
    required this.currentPrice,
    required this.currentValue,
    required this.allocationPct,
    required this.breakEvenPrice,
    required this.pnl,
    required this.roiPct,
  });

  factory AssetAllocationItem.fromJson(Map<String, dynamic> json) {
    return AssetAllocationItem(
      ticker: json['ticker'] as String? ?? '',
      assetClass: json['asset_class'] as String? ?? 'EQUITY',
      shares: (json['shares'] as num?)?.toDouble() ?? 0.0,
      currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0.0,
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0.0,
      allocationPct: (json['allocation_pct'] as num?)?.toDouble() ?? 0.0,
      breakEvenPrice: (json['break_even_price'] as num?)?.toDouble() ?? 0.0,
      pnl: (json['pnl'] as num?)?.toDouble() ?? 0.0,
      roiPct: (json['roi_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }

  bool get isPnlPositive => pnl >= 0;
  bool get isGold => assetClass.toUpperCase() == 'GOLD' || ticker.contains('8PSG');
}

class SavingsPlanConfig {
  final int? id;
  final int? portfolioId;
  final double monthlyDeposit;
  final String frequency;
  final double allocationEquityPct;
  final double allocationGoldPct;
  final bool isActive;

  const SavingsPlanConfig({
    this.id,
    this.portfolioId,
    required this.monthlyDeposit,
    this.frequency = 'monthly',
    required this.allocationEquityPct,
    required this.allocationGoldPct,
    this.isActive = true,
  });

  factory SavingsPlanConfig.fromJson(Map<String, dynamic> json) {
    return SavingsPlanConfig(
      id: (json['id'] as num?)?.toInt(),
      portfolioId: (json['portfolio_id'] as num?)?.toInt(),
      monthlyDeposit: (json['monthly_deposit'] as num?)?.toDouble() ?? 200.0,
      frequency: json['frequency'] as String? ?? 'monthly',
      allocationEquityPct:
          (json['allocation_equity_pct'] as num?)?.toDouble() ?? 80.0,
      allocationGoldPct:
          (json['allocation_gold_pct'] as num?)?.toDouble() ?? 20.0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (portfolioId != null) 'portfolio_id': portfolioId,
      'monthly_deposit': monthlyDeposit,
      'frequency': frequency,
      'allocation_equity_pct': allocationEquityPct,
      'allocation_gold_pct': allocationGoldPct,
      'is_active': isActive,
    };
  }
}

class PortfolioTransaction {
  final int? id;
  final int? portfolioId;
  final String ticker;
  final String assetClass;
  final double shares;
  final double pricePerShare;
  final double amountInvested;
  final double fee;
  final bool isAutomated;
  final DateTime? timestamp;

  const PortfolioTransaction({
    this.id,
    this.portfolioId,
    required this.ticker,
    required this.assetClass,
    required this.shares,
    required this.pricePerShare,
    required this.amountInvested,
    this.fee = 0.0,
    this.isAutomated = true,
    this.timestamp,
  });

  factory PortfolioTransaction.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['timestamp'] != null) {
      try {
        parsedDate = DateTime.parse(json['timestamp'] as String);
      } catch (_) {}
    }

    return PortfolioTransaction(
      id: (json['id'] as num?)?.toInt(),
      portfolioId: (json['portfolio_id'] as num?)?.toInt(),
      ticker: json['ticker'] as String? ?? '',
      assetClass: json['asset_class'] as String? ?? 'EQUITY',
      shares: (json['shares'] as num?)?.toDouble() ?? 0.0,
      pricePerShare: (json['price_per_share'] as num?)?.toDouble() ?? 0.0,
      amountInvested: (json['amount_invested'] as num?)?.toDouble() ?? 0.0,
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      isAutomated: json['is_automated'] as bool? ?? true,
      timestamp: parsedDate,
    );
  }
}

class PortfolioStatus {
  final int id;
  final int userId;
  final String userEmail;
  final String userName;
  final String name;
  final String currency;
  final double initialBalance;
  final double totalInvested;
  final double currentValue;
  final double pnl;
  final double roiPct;
  final int marketSentimentScore;
  final List<AssetAllocationItem> assetAllocation;
  final SavingsPlanConfig? savingsPlan;
  final List<PortfolioTransaction> transactions;

  const PortfolioStatus({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.name,
    required this.currency,
    required this.initialBalance,
    required this.totalInvested,
    required this.currentValue,
    required this.pnl,
    required this.roiPct,
    required this.marketSentimentScore,
    this.assetAllocation = const [],
    this.savingsPlan,
    this.transactions = const [],
  });

  factory PortfolioStatus.fromJson(Map<String, dynamic> json) {
    return PortfolioStatus(
      id: (json['id'] as num?)?.toInt() ?? 1,
      userId: (json['user_id'] as num?)?.toInt() ?? 1,
      userEmail: json['user_email'] as String? ?? '',
      userName: json['user_name'] as String? ?? 'Demo',
      name: json['name'] as String? ?? 'Mi Cartera Principal',
      currency: json['currency'] as String? ?? 'EUR',
      initialBalance: (json['initial_balance'] as num?)?.toDouble() ?? 0.0,
      totalInvested: (json['total_invested'] as num?)?.toDouble() ?? 0.0,
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0.0,
      pnl: (json['pnl'] as num?)?.toDouble() ?? 0.0,
      roiPct: (json['roi_pct'] as num?)?.toDouble() ?? 0.0,
      marketSentimentScore:
          (json['market_sentiment_score'] as num?)?.toInt() ?? 58,
      assetAllocation: (json['asset_allocation'] as List<dynamic>?)
              ?.map((item) =>
                  AssetAllocationItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      savingsPlan: json['savings_plan'] != null
          ? SavingsPlanConfig.fromJson(
              json['savings_plan'] as Map<String, dynamic>)
          : null,
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((item) =>
                  PortfolioTransaction.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  bool get isPnlPositive => pnl >= 0;
  String get formattedTotalInvested => '${totalInvested.toStringAsFixed(2)} $currency';
  String get formattedCurrentValue => '${currentValue.toStringAsFixed(2)} $currency';
  String get formattedPnl => '${isPnlPositive ? '+' : ''}${pnl.toStringAsFixed(2)} $currency';
  String get formattedRoi => '${isPnlPositive ? '+' : ''}${roiPct.toStringAsFixed(2)}%';
}

class DcaStepPoint {
  final int monthIndex;
  final String date;
  final double cumulativeInvested;
  final double portfolioValue;
  final double pnl;
  final double roiPct;
  final int marketSentimentScore;
  final double equityPrice;
  final double goldPrice;
  final double equitySharesBought;
  final double goldSharesBought;

  const DcaStepPoint({
    required this.monthIndex,
    required this.date,
    required this.cumulativeInvested,
    required this.portfolioValue,
    required this.pnl,
    required this.roiPct,
    required this.marketSentimentScore,
    required this.equityPrice,
    required this.goldPrice,
    required this.equitySharesBought,
    required this.goldSharesBought,
  });

  factory DcaStepPoint.fromJson(Map<String, dynamic> json) {
    return DcaStepPoint(
      monthIndex: (json['month_index'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
      cumulativeInvested:
          (json['cumulative_invested'] as num?)?.toDouble() ?? 0.0,
      portfolioValue: (json['portfolio_value'] as num?)?.toDouble() ?? 0.0,
      pnl: (json['pnl'] as num?)?.toDouble() ?? 0.0,
      roiPct: (json['roi_pct'] as num?)?.toDouble() ?? 0.0,
      marketSentimentScore:
          (json['market_sentiment_score'] as num?)?.toInt() ?? 50,
      equityPrice: (json['equity_price'] as num?)?.toDouble() ?? 0.0,
      goldPrice: (json['gold_price'] as num?)?.toDouble() ?? 0.0,
      equitySharesBought:
          (json['equity_shares_bought'] as num?)?.toDouble() ?? 0.0,
      goldSharesBought:
          (json['gold_shares_bought'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DcaSimulationResult {
  final double totalInvested;
  final double currentValue;
  final double pnl;
  final double roiPct;
  final double equityShares;
  final double goldShares;
  final double breakEvenEquity;
  final double breakEvenGold;
  final double currentEquityPrice;
  final double currentGoldPrice;
  final int transactionsCount;
  final double allocationEquityPct;
  final double allocationGoldPct;
  final List<DcaStepPoint> steps;

  const DcaSimulationResult({
    required this.totalInvested,
    required this.currentValue,
    required this.pnl,
    required this.roiPct,
    required this.equityShares,
    required this.goldShares,
    required this.breakEvenEquity,
    required this.breakEvenGold,
    required this.currentEquityPrice,
    required this.currentGoldPrice,
    required this.transactionsCount,
    required this.allocationEquityPct,
    required this.allocationGoldPct,
    this.steps = const [],
  });

  factory DcaSimulationResult.fromJson(Map<String, dynamic> json) {
    return DcaSimulationResult(
      totalInvested: (json['total_invested'] as num?)?.toDouble() ?? 0.0,
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0.0,
      pnl: (json['pnl'] as num?)?.toDouble() ?? 0.0,
      roiPct: (json['roi_pct'] as num?)?.toDouble() ?? 0.0,
      equityShares: (json['equity_shares'] as num?)?.toDouble() ?? 0.0,
      goldShares: (json['gold_shares'] as num?)?.toDouble() ?? 0.0,
      breakEvenEquity: (json['break_even_equity'] as num?)?.toDouble() ?? 0.0,
      breakEvenGold: (json['break_even_gold'] as num?)?.toDouble() ?? 0.0,
      currentEquityPrice:
          (json['current_equity_price'] as num?)?.toDouble() ?? 0.0,
      currentGoldPrice: (json['current_gold_price'] as num?)?.toDouble() ?? 0.0,
      transactionsCount: (json['transactions_count'] as num?)?.toInt() ?? 0,
      allocationEquityPct:
          (json['allocation_equity_pct'] as num?)?.toDouble() ?? 80.0,
      allocationGoldPct:
          (json['allocation_gold_pct'] as num?)?.toDouble() ?? 20.0,
      steps: (json['steps'] as List<dynamic>?)
              ?.map((item) => DcaStepPoint.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  bool get isPnlPositive => pnl >= 0;
}
