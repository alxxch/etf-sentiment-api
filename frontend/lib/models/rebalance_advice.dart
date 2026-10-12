class AssetRebalanceItem {
  final String ticker;
  final String assetClass; // EQUITY o GOLD
  final double currentValue;
  final double currentAllocationPct;
  final double targetAllocationPct;
  final double driftPct;
  final double driftAmount;
  final double suggestedDeposit;
  final double suggestedDepositPct;
  final double projectedValue;
  final double projectedAllocationPct;

  const AssetRebalanceItem({
    required this.ticker,
    required this.assetClass,
    required this.currentValue,
    required this.currentAllocationPct,
    required this.targetAllocationPct,
    required this.driftPct,
    required this.driftAmount,
    required this.suggestedDeposit,
    required this.suggestedDepositPct,
    required this.projectedValue,
    required this.projectedAllocationPct,
  });

  factory AssetRebalanceItem.fromJson(Map<String, dynamic> json) {
    return AssetRebalanceItem(
      ticker: json['ticker'] as String? ?? '',
      assetClass: (json['asset_class'] as String? ?? 'EQUITY').toUpperCase(),
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0.0,
      currentAllocationPct:
          (json['current_allocation_pct'] as num?)?.toDouble() ?? 0.0,
      targetAllocationPct:
          (json['target_allocation_pct'] as num?)?.toDouble() ?? 0.0,
      driftPct: (json['drift_pct'] as num?)?.toDouble() ?? 0.0,
      driftAmount: (json['drift_amount'] as num?)?.toDouble() ?? 0.0,
      suggestedDeposit:
          (json['suggested_deposit'] as num?)?.toDouble() ?? 0.0,
      suggestedDepositPct:
          (json['suggested_deposit_pct'] as num?)?.toDouble() ?? 0.0,
      projectedValue: (json['projected_value'] as num?)?.toDouble() ?? 0.0,
      projectedAllocationPct:
          (json['projected_allocation_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }

  bool get isOverweight => driftPct > 0;
  bool get isUnderweight => driftPct < 0;
  bool get isGold => assetClass == 'GOLD' || ticker.contains('8PSG');
}

class RebalanceAdvice {
  final int portfolioId;
  final int userId;
  final double currentPortfolioValue;
  final double monthlyDeposit;
  final double postRebalancePortfolioValue;
  final String rebalanceStatus; // BALANCED, FULLY_REBALANCED, PARTIALLY_REBALANCED
  final String summaryMessage;
  final List<AssetRebalanceItem> assets;

  const RebalanceAdvice({
    required this.portfolioId,
    required this.userId,
    required this.currentPortfolioValue,
    required this.monthlyDeposit,
    required this.postRebalancePortfolioValue,
    required this.rebalanceStatus,
    required this.summaryMessage,
    this.assets = const [],
  });

  factory RebalanceAdvice.fromJson(Map<String, dynamic> json) {
    return RebalanceAdvice(
      portfolioId: (json['portfolio_id'] as num?)?.toInt() ?? 1,
      userId: (json['user_id'] as num?)?.toInt() ?? 1,
      currentPortfolioValue:
          (json['current_portfolio_value'] as num?)?.toDouble() ?? 0.0,
      monthlyDeposit: (json['monthly_deposit'] as num?)?.toDouble() ?? 200.0,
      postRebalancePortfolioValue:
          (json['post_rebalance_portfolio_value'] as num?)?.toDouble() ?? 0.0,
      rebalanceStatus:
          (json['rebalance_status'] as String? ?? 'BALANCED').toUpperCase(),
      summaryMessage: json['summary_message'] as String? ?? '',
      assets: (json['assets'] as List<dynamic>?)
              ?.map((item) =>
                  AssetRebalanceItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  bool get isBalanced => rebalanceStatus == 'BALANCED';
  bool get isFullyRebalanced => rebalanceStatus == 'FULLY_REBALANCED';
  bool get isPartiallyRebalanced => rebalanceStatus == 'PARTIALLY_REBALANCED';
  bool get hasSignificantDrift => !isBalanced;

  /// Obtiene el activo con mayor necesidad de aportación
  AssetRebalanceItem? get highestSuggestedAsset {
    if (assets.isEmpty) return null;
    return assets.reduce(
        (a, b) => a.suggestedDeposit >= b.suggestedDeposit ? a : b);
  }
}
