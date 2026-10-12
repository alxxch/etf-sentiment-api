import 'package:flutter/foundation.dart';
import '../models/portfolio_models.dart';
import '../models/rebalance_advice.dart';
import '../services/api_service.dart';

class PortfolioProvider extends ChangeNotifier {
  final ApiService _apiService;

  PortfolioProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  PortfolioStatus? _portfolio;
  DcaSimulationResult? _simulation;
  RebalanceAdvice? _rebalanceAdvice;
  bool _isLoading = false;
  bool _isSimulating = false;
  bool _isLoadingRebalance = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  // Parámetros interactivos del simulador DCA
  double _monthlyDeposit = 200.0;
  double _allocationEquityPct = 80.0;
  double _allocationGoldPct = 20.0;
  int _simulationMonths = 6;
  double _initialCapital = 0.0;
  int _rebalanceEventCounter = 0;

  // Getters
  PortfolioStatus? get portfolio => _portfolio;
  DcaSimulationResult? get simulation => _simulation;
  RebalanceAdvice? get rebalanceAdvice => _rebalanceAdvice;
  bool get isLoading => _isLoading;
  bool get isSimulating => _isSimulating;
  bool get isLoadingRebalance => _isLoadingRebalance;
  bool get hasLoaded => _hasLoaded;
  bool get hasData => _portfolio != null;
  bool get hasRebalanceAdvice => _rebalanceAdvice != null;
  String? get errorMessage => _errorMessage;

  double get monthlyDeposit => _monthlyDeposit;
  double get allocationEquityPct => _allocationEquityPct;
  double get allocationGoldPct => _allocationGoldPct;
  int get simulationMonths => _simulationMonths;
  double get initialCapital => _initialCapital;
  int get rebalanceEventCounter => _rebalanceEventCounter;

  /// Carga inicial del portfolio solo si no está en memoria
  Future<void> fetchInitialData() async {
    if (_hasLoaded || _isLoading || _portfolio != null) return;
    await loadPortfolio();
  }

  /// Carga la información de la cartera desde el backend
  Future<void> loadPortfolio({bool force = false}) async {
    if (_isLoading) return;
    if (!force && _hasLoaded && _portfolio != null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final status = await _apiService.fetchPortfolio();
      _portfolio = status;
      _hasLoaded = true;

      // Sincronizar parámetros interactivos con el plan de ahorro del usuario
      if (status.savingsPlan != null) {
        _monthlyDeposit = status.savingsPlan!.monthlyDeposit;
        _allocationEquityPct = status.savingsPlan!.allocationEquityPct;
        _allocationGoldPct = status.savingsPlan!.allocationGoldPct;
      }

      // Ejecutar simulación inicial en segundo plano
      await runSimulation(silent: true);

      // Cargar consejo de rebalanceo cuantitativo
      await loadRebalanceAdvice(customDeposit: _monthlyDeposit);
    } catch (e) {
      _errorMessage = 'Error al cargar cartera: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Consulta el consejo y métricas de rebalanceo inteligente
  Future<void> loadRebalanceAdvice({double? customDeposit}) async {
    _isLoadingRebalance = true;
    notifyListeners();

    try {
      final advice = await _apiService.fetchRebalanceAdvice(
        customDeposit: customDeposit ?? _monthlyDeposit,
      );
      _rebalanceAdvice = advice;
    } catch (e) {
      debugPrint('[PortfolioProvider] Error al cargar rebalanceo: $e');
    } finally {
      _isLoadingRebalance = false;
      notifyListeners();
    }
  }

  /// Ejecuta la simulación DCA con los parámetros interactivos actuales
  Future<void> runSimulation({bool silent = false}) async {
    if (_isSimulating) return;

    if (!silent) {
      _isSimulating = true;
      notifyListeners();
    }

    try {
      final sim = await _apiService.simulateDca(
        initialCapital: _initialCapital,
        monthlyDeposit: _monthlyDeposit,
        months: _simulationMonths,
        allocationEquityPct: _allocationEquityPct,
        allocationGoldPct: _allocationGoldPct,
      );
      _simulation = sim;
      _rebalanceEventCounter++;
    } catch (e) {
      debugPrint('[PortfolioProvider] Error al simular DCA: $e');
    } finally {
      if (!silent) {
        _isSimulating = false;
      }
      notifyListeners();
    }
  }

  /// Ajusta la aportación mensual
  void setMonthlyDeposit(double value) {
    if ((_monthlyDeposit - value).abs() > 0.01) {
      _monthlyDeposit = value;
      notifyListeners();
    }
  }

  /// Ajusta el % de Renta Variable y calcula automáticamente el % restante en Oro
  void setEquityAllocation(double equityPct) {
    final clampedEquity = equityPct.clamp(0.0, 100.0);
    _allocationEquityPct = clampedEquity;
    _allocationGoldPct = (100.0 - clampedEquity);
    notifyListeners();
  }

  /// Ajusta el horizonte temporal de simulación
  void setSimulationMonths(int months) {
    if (_simulationMonths != months) {
      _simulationMonths = months;
      notifyListeners();
    }
  }

  /// Ajusta el capital inicial disponible
  void setInitialCapital(double capital) {
    if ((_initialCapital - capital).abs() > 0.01) {
      _initialCapital = capital;
      notifyListeners();
    }
  }

  /// Guarda y persiste el plan de ahorro modificado en la base de datos
  Future<bool> saveSavingsPlan() async {
    if (_portfolio == null) return false;

    try {
      final config = SavingsPlanConfig(
        portfolioId: _portfolio!.id,
        monthlyDeposit: _monthlyDeposit,
        allocationEquityPct: _allocationEquityPct,
        allocationGoldPct: _allocationGoldPct,
        frequency: 'monthly',
        isActive: true,
      );
      final updated = await _apiService.updateSavingsPlan(config);

      // Actualizar estado local
      _portfolio = PortfolioStatus(
        id: _portfolio!.id,
        userId: _portfolio!.userId,
        userEmail: _portfolio!.userEmail,
        userName: _portfolio!.userName,
        name: _portfolio!.name,
        currency: _portfolio!.currency,
        initialBalance: _portfolio!.initialBalance,
        totalInvested: _portfolio!.totalInvested,
        currentValue: _portfolio!.currentValue,
        pnl: _portfolio!.pnl,
        roiPct: _portfolio!.roiPct,
        marketSentimentScore: _portfolio!.marketSentimentScore,
        assetAllocation: _portfolio!.assetAllocation,
        savingsPlan: updated,
        transactions: _portfolio!.transactions,
      );
      _rebalanceEventCounter++;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'No se pudo guardar el plan de ahorro: $e';
      notifyListeners();
      return false;
    }
  }

  /// Sincroniza de forma reactiva el estado financiero ante mutaciones ordenadas por voz (Fase 12).
  /// Si el action_type es DCA_SIMULATED o SAVINGS_PLAN_UPDATED, actualiza los sliders y
  /// la distribución de activos en tiempo real sin requerir interacción manual del usuario.
  Future<void> applyAssistantPayload(
    String actionType,
    Map<String, dynamic> dataPayload,
  ) async {
    try {
      final normAction = actionType.toUpperCase();

      if (normAction == 'DCA_SIMULATED' || normAction == 'SIMULATE_DCA_PLAN') {
        final params = dataPayload['simulation_parameters'] as Map<String, dynamic>?;
        if (params != null) {
          if (params['monthly_deposit'] != null) {
            _monthlyDeposit = (params['monthly_deposit'] as num).toDouble();
          }
          if (params['allocation_equity_pct'] != null) {
            _allocationEquityPct = (params['allocation_equity_pct'] as num).toDouble();
          }
          if (params['allocation_gold_pct'] != null) {
            _allocationGoldPct = (params['allocation_gold_pct'] as num).toDouble();
          }
          if (params['months'] != null) {
            _simulationMonths = (params['months'] as num).toInt();
          }
        }

        // Si el payload contiene el objeto de simulación completo, actualizarlo directamente
        if (dataPayload['simulation'] != null &&
            dataPayload['simulation'] is Map<String, dynamic>) {
          _simulation = DcaSimulationResult.fromJson(
            dataPayload['simulation'] as Map<String, dynamic>,
          );
        } else {
          // Si no vino completo, recalcular simulación matemáticamente en segundo plano
          await runSimulation(silent: true);
        }

        // Sincronizar reactivamente el PieChart de la cartera principal si existe
        if (_portfolio != null && _portfolio!.assetAllocation.isNotEmpty) {
          final updatedAllocation = _portfolio!.assetAllocation.map((item) {
            final newPct = item.isGold ? _allocationGoldPct : _allocationEquityPct;
            return AssetAllocationItem(
              ticker: item.ticker,
              assetClass: item.assetClass,
              shares: item.shares,
              currentPrice: item.currentPrice,
              currentValue: item.currentValue,
              allocationPct: newPct,
              breakEvenPrice: item.breakEvenPrice,
              pnl: item.pnl,
              roiPct: item.roiPct,
            );
          }).toList();

          _portfolio = PortfolioStatus(
            id: _portfolio!.id,
            userId: _portfolio!.userId,
            userEmail: _portfolio!.userEmail,
            userName: _portfolio!.userName,
            name: _portfolio!.name,
            currency: _portfolio!.currency,
            initialBalance: _portfolio!.initialBalance,
            totalInvested: _portfolio!.totalInvested,
            currentValue: _portfolio!.currentValue,
            pnl: _portfolio!.pnl,
            roiPct: _portfolio!.roiPct,
            marketSentimentScore: _portfolio!.marketSentimentScore,
            assetAllocation: updatedAllocation,
            savingsPlan: _portfolio!.savingsPlan,
            transactions: _portfolio!.transactions,
          );
        }
        _rebalanceEventCounter++;
        notifyListeners();
      } else if (normAction == 'SAVINGS_PLAN_UPDATED' ||
          normAction == 'UPDATE_SAVINGS_PLAN') {
        final planData = dataPayload['savings_plan'] as Map<String, dynamic>?;
        if (planData != null) {
          final updatedPlan = SavingsPlanConfig.fromJson(planData);
          _monthlyDeposit = updatedPlan.monthlyDeposit;
          _allocationEquityPct = updatedPlan.allocationEquityPct;
          _allocationGoldPct = updatedPlan.allocationGoldPct;

          if (_portfolio != null) {
            final updatedAllocation = _portfolio!.assetAllocation.map((item) {
              final newPct = item.isGold ? _allocationGoldPct : _allocationEquityPct;
              return AssetAllocationItem(
                ticker: item.ticker,
                assetClass: item.assetClass,
                shares: item.shares,
                currentPrice: item.currentPrice,
                currentValue: item.currentValue,
                allocationPct: newPct,
                breakEvenPrice: item.breakEvenPrice,
                pnl: item.pnl,
                roiPct: item.roiPct,
              );
            }).toList();

            _portfolio = PortfolioStatus(
              id: _portfolio!.id,
              userId: _portfolio!.userId,
              userEmail: _portfolio!.userEmail,
              userName: _portfolio!.userName,
              name: _portfolio!.name,
              currency: _portfolio!.currency,
              initialBalance: _portfolio!.initialBalance,
              totalInvested: _portfolio!.totalInvested,
              currentValue: _portfolio!.currentValue,
              pnl: _portfolio!.pnl,
              roiPct: _portfolio!.roiPct,
              marketSentimentScore: _portfolio!.marketSentimentScore,
              assetAllocation: updatedAllocation,
              savingsPlan: updatedPlan,
              transactions: _portfolio!.transactions,
            );
          }
        }
        await runSimulation(silent: true);
      } else if (normAction == 'PORTFOLIO_QUERY' ||
          normAction == 'GET_PORTFOLIO_SUMMARY') {
        await loadPortfolio(force: true);
      } else if (normAction == 'REBALANCE_ADVICE_QUERIED' ||
          normAction == 'CALCULATE_PORTFOLIO_REBALANCE' ||
          normAction == 'PORTFOLIO_REBALANCE') {
        if (dataPayload['rebalance_advice'] != null &&
            dataPayload['rebalance_advice'] is Map<String, dynamic>) {
          _rebalanceAdvice = RebalanceAdvice.fromJson(
            dataPayload['rebalance_advice'] as Map<String, dynamic>,
          );
        } else {
          await loadRebalanceAdvice();
        }
        _rebalanceEventCounter++;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[PortfolioProvider] Error aplicando payload del asistente: $e');
    }
  }

  /// Dispara manualmente una animación de rebalanceo/recalculo en el espacio 3D
  void triggerRebalanceAnimation() {
    _rebalanceEventCounter++;
    notifyListeners();
  }

  @visibleForTesting
  void setRebalanceAdviceForTesting(RebalanceAdvice? advice) {
    _rebalanceAdvice = advice;
    notifyListeners();
  }
}

