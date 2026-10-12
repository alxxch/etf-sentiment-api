import 'package:flutter/foundation.dart';
import '../models/broker_account.dart';
import '../services/api_service.dart';
import 'portfolio_provider.dart';

class BankingProvider extends ChangeNotifier {
  final ApiService _apiService;

  BankingProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  List<BrokerAccount> _accounts = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  int? _syncingAccountId;
  String? _errorMessage;
  String? _syncSuccessMessage;

  // Getters
  List<BrokerAccount> get accounts => _accounts;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  int? get syncingAccountId => _syncingAccountId;
  String? get errorMessage => _errorMessage;
  String? get syncSuccessMessage => _syncSuccessMessage;

  bool isSyncing(int accountId) => _syncingAccountId == accountId;

  /// Carga la lista de brokers conectados
  Future<void> loadAccounts({int userId = 1, bool force = false}) async {
    if (_isLoading) return;
    if (!force && _hasLoaded && _accounts.isNotEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await _apiService.fetchBrokerAccounts(userId: userId);
      _accounts = list;
      _hasLoaded = true;
    } catch (e) {
      _errorMessage = 'Error al cargar brokers: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Vincula un nuevo broker externo
  Future<BrokerAccount?> linkAccount({
    required String brokerName,
    required String accountReference,
    int userId = 1,
  }) async {
    _errorMessage = null;
    try {
      final newAcc = await _apiService.linkBrokerAccount(
        brokerName: brokerName,
        accountReference: accountReference,
        userId: userId,
      );
      _accounts.add(newAcc);
      notifyListeners();
      return newAcc;
    } catch (e) {
      _errorMessage = 'Error vinculando broker: $e';
      notifyListeners();
      return null;
    }
  }

  /// Dispara la sincronización bajo demanda para una cuenta
  Future<Map<String, dynamic>?> syncAccount(
    int accountId, {
    PortfolioProvider? portfolioProvider,
  }) async {
    if (_syncingAccountId != null) return null;

    _syncingAccountId = accountId;
    _errorMessage = null;
    _syncSuccessMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.syncBrokerAccount(accountId);
      _syncSuccessMessage = res['message'] as String? ?? 'Sincronizado con éxito';

      // Actualizar cuenta en lista local
      await loadAccounts(force: true);

      // Si se proporcionó portfolioProvider, refrescar la cartera y rebalanceo
      if (portfolioProvider != null) {
        await portfolioProvider.loadPortfolio(force: true);
      }

      return res;
    } catch (e) {
      _errorMessage = 'Error al sincronizar cuenta $accountId: $e';
      return null;
    } finally {
      _syncingAccountId = null;
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _syncSuccessMessage = null;
    notifyListeners();
  }
}
