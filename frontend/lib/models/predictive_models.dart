// Modelo de datos para la respuesta de simulación Monte Carlo — Fase 26.
//
// Encapsula los tres arrays de proyección (P10/P50/P90), las estadísticas
// del modelo GBM calibrado y los valores finales resumidos.

/// Resultado completo de una simulación Monte Carlo devuelta por el backend.
class MonteCarloResult {
  final String ticker;
  final int horizonDays;
  final int nSimulations;
  final double initialInvestment;
  final double monthlyContribution;

  /// Arrays de proyección — longitud: horizonDays + 1 (incluye día 0 = hoy)
  final List<double> p10; // Escenario pesimista
  final List<double> p50; // Escenario base (mediana)
  final List<double> p90; // Escenario optimista
  final List<int> days; // Índices de día [0, 1, …, horizonDays]

  // Estadísticas del modelo GBM calibrado
  final double meanDailyReturn;
  final double stdDailyReturn;
  final double annualizedReturn;
  final double annualizedVol;

  // Valores finales resumidos (último día)
  final double finalP10;
  final double finalP50;
  final double finalP90;

  const MonteCarloResult({
    required this.ticker,
    required this.horizonDays,
    required this.nSimulations,
    required this.initialInvestment,
    required this.monthlyContribution,
    required this.p10,
    required this.p50,
    required this.p90,
    required this.days,
    required this.meanDailyReturn,
    required this.stdDailyReturn,
    required this.annualizedReturn,
    required this.annualizedVol,
    required this.finalP10,
    required this.finalP50,
    required this.finalP90,
  });

  factory MonteCarloResult.fromJson(Map<String, dynamic> json) {
    List<double> parseDoubleList(dynamic raw) {
      if (raw == null) return [];
      return (raw as List<dynamic>)
          .map((v) => (v as num).toDouble())
          .toList();
    }

    List<int> parseIntList(dynamic raw) {
      if (raw == null) return [];
      return (raw as List<dynamic>).map((v) => (v as num).toInt()).toList();
    }

    return MonteCarloResult(
      ticker: json['ticker'] as String? ?? 'VWCE.DE',
      horizonDays: (json['horizon_days'] as num?)?.toInt() ?? 1260,
      nSimulations: (json['n_simulations'] as num?)?.toInt() ?? 5000,
      initialInvestment:
          (json['initial_investment'] as num?)?.toDouble() ?? 10000.0,
      monthlyContribution:
          (json['monthly_contribution'] as num?)?.toDouble() ?? 200.0,
      p10: parseDoubleList(json['p10']),
      p50: parseDoubleList(json['p50']),
      p90: parseDoubleList(json['p90']),
      days: parseIntList(json['days']),
      meanDailyReturn:
          (json['mean_daily_return'] as num?)?.toDouble() ?? 0.0,
      stdDailyReturn:
          (json['std_daily_return'] as num?)?.toDouble() ?? 0.0,
      annualizedReturn:
          (json['annualized_return'] as num?)?.toDouble() ?? 0.0,
      annualizedVol: (json['annualized_vol'] as num?)?.toDouble() ?? 0.0,
      finalP10: (json['final_p10'] as num?)?.toDouble() ?? 0.0,
      finalP50: (json['final_p50'] as num?)?.toDouble() ?? 0.0,
      finalP90: (json['final_p90'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Retorno anualizado en porcentaje (para mostrar en UI)
  double get annualizedReturnPct => annualizedReturn * 100;

  /// Volatilidad anualizada en porcentaje
  double get annualizedVolPct => annualizedVol * 100;

  /// Horizonte en años (redondeado a 1 decimal)
  double get horizonYears => (horizonDays / 252).roundToDouble();

  /// Devuelve true si la proyección tiene suficientes puntos para graficar
  bool get hasData => p10.isNotEmpty && p50.isNotEmpty && p90.isNotEmpty;
}

/// Debate completo generado por el Comité de Inversión IA — Fase 25/26.
class CommitteeDebate {
  final String technicalAnalyst;
  final String macroEconomist;
  final String riskManager;
  final String leadAdvisor; // Veredicto final sintetizado

  const CommitteeDebate({
    required this.technicalAnalyst,
    required this.macroEconomist,
    required this.riskManager,
    required this.leadAdvisor,
  });

  factory CommitteeDebate.fromJson(Map<String, dynamic> json) {
    return CommitteeDebate(
      technicalAnalyst: json['technical_analyst'] as String? ?? '',
      macroEconomist: json['macro_economist'] as String? ?? '',
      riskManager: json['risk_manager'] as String? ?? '',
      leadAdvisor: json['lead_advisor'] as String? ?? '',
    );
  }

  /// Devuelve true si el debate tiene contenido real de al menos un agente
  bool get hasContent =>
      technicalAnalyst.isNotEmpty ||
      macroEconomist.isNotEmpty ||
      riskManager.isNotEmpty;
}
