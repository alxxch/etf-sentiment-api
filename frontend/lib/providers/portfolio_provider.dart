import 'package:flutter/foundation.dart';
import '../models/portfolio_models.dart';
import '../services/api_service.dart';

class PortfolioProvider extends ChangeNotifier {
  final ApiService _apiService;

  PortfolioProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  PortfolioStatus? _portfolio;
  DcaSimulationResult? _simulation;
  bool _isLoading = false;
  bool _isSimulating = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  // Parámetros interactivos del simulador DCA
  double _monthlyDeposit = 200.0;
  double _allocationEquityPct = 80.0;
  double _allocationGoldPct = 20.0;
  int _simulationMonths = 6;
  double _initialCapital = 0.0;

  // Getters
  PortfolioStatus? get portfolio => _portfolio;
  DcaSimulationResult? get simulation => _simulation;
  bool get isLoading => _isLoading;
  bool get isSimulating => _isSimulating;
  bool get hasLoaded => _hasLoaded;
  bool get hasData => _portfolio != null;
  String? get errorMessage => _errorMessage;

  double get monthlyDeposit => _monthlyDeposit;
  double get allocationEquityPct => _allocationEquityPct;
  double get allocationGoldPct => _allocationGoldPct;
  int get simulationMonths => _simulationMonths;
  double get initialCapital => _initialCapital;

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
    } catch (e) {
      _errorMessage = 'Error al cargar cartera: $e';
    } finally {
      _isLoading = false;
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
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'No se pudo guardar el plan de ahorro: $e';
      notifyListeners();
      return false;
    }
  }
}
