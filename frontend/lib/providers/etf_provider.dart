import 'package:flutter/foundation.dart';
import '../models/etf_data.dart';
import '../models/etf_history_entry.dart';
import '../services/api_service.dart';

class EtfProvider extends ChangeNotifier {
  final ApiService _apiService;

  EtfProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  static const List<String> defaultTickers = [
    'VWCE.DE',
    'EUNL.DE',
    '8PSG.DE',
  ];

  final Map<String, EtfData> _etfMap = {};
  final Map<String, List<EtfHistoryEntry>> _historyMap = {};
  int _selectedIndex = 0;
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  DateTime? _lastUpdated;

  // Getters de estado
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;
  int get selectedIndex => _selectedIndex;
  List<String> get tickers => defaultTickers;
  bool get hasData => _etfMap.isNotEmpty;

  String get selectedTicker => defaultTickers[_selectedIndex];

  /// Obtiene los datos del ETF actualmente seleccionado, o null si aún no se han cargado
  EtfData? get currentEtf => _etfMap[selectedTicker];

  /// Obtiene el historial del ETF actualmente seleccionado
  List<EtfHistoryEntry> get currentHistory => getHistoryFor(selectedTicker);

  /// Obtiene la lista histórica de un ticker dado
  List<EtfHistoryEntry> getHistoryFor(String ticker) {
    return _historyMap[ticker.trim().toUpperCase()] ?? const [];
  }

  /// Lista ordenada de todos los ETFs cargados según defaultTickers
  List<EtfData> get allEtfs => defaultTickers
      .map((t) => _etfMap[t])
      .whereType<EtfData>()
      .toList();

  /// Cambia el ticker activo
  void selectTickerIndex(int index) {
    if (index >= 0 && index < defaultTickers.length && index != _selectedIndex) {
      _selectedIndex = index;
      notifyListeners();
      // Si por alguna razón no tenemos historial cargado para este ticker, intentar obtenerlo
      final ticker = defaultTickers[_selectedIndex];
      if (!_historyMap.containsKey(ticker) || _historyMap[ticker]!.isEmpty) {
        loadHistoryForTicker(ticker);
      }
    }
  }

  /// Limpia cualquier mensaje de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Carga inicial protegida contra bucles: solo consulta si la lista está vacía
  /// y no hay ninguna petición en curso o ya completada.
  Future<void> fetchInitialData() async {
    if (_hasLoaded || _isLoading || _etfMap.isNotEmpty) {
      debugPrint('[EtfProvider] fetchInitialData omitido: datos ya presentes o carga en curso.');
      return;
    }
    await loadData(force: false);
  }

  /// Realiza la consulta a la API de los 3 tickers y su historial en paralelo
  Future<void> loadData({bool force = false}) async {
    // Protección contra peticiones duplicadas o concurrentes
    if (_isLoading) {
      debugPrint('[EtfProvider] loadData omitido: petición ya en curso.');
      return;
    }
    if (!force && _hasLoaded && _etfMap.isNotEmpty) {
      debugPrint('[EtfProvider] loadData omitido: datos ya cargados previamente.');
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Peticiones en paralelo con tolerancia individual para cotizaciones e historiales
      final results = await Future.wait(
        defaultTickers.map((ticker) async {
          try {
            final dataFuture = _apiService.fetchEtfData(ticker);
            final historyFuture = _apiService.fetchEtfHistory(ticker).catchError((_) => <EtfHistoryEntry>[]);

            final data = await dataFuture;
            final history = await historyFuture;

            return _TickerFetchResult(ticker: ticker, data: data, history: history);
          } catch (e) {
            debugPrint('[EtfProvider] Error cargando $ticker: $e');
            // Intentar cargar al menos el historial si el endpoint principal falla
            try {
              final history = await _apiService.fetchEtfHistory(ticker);
              return _TickerFetchResult(ticker: ticker, data: null, history: history);
            } catch (_) {
              return _TickerFetchResult(ticker: ticker, data: null, history: const []);
            }
          }
        }),
      );

      int successfulLoads = 0;
      for (final res in results) {
        if (res.data != null) {
          _etfMap[res.ticker] = res.data!;
          successfulLoads++;
        }
        if (res.history.isNotEmpty) {
          _historyMap[res.ticker] = res.history;
        }
      }

      if (successfulLoads == 0) {
        _errorMessage =
            'No se pudo obtener información del backend. Verifica que el servidor FastAPI esté corriendo en http://localhost:8000';
      } else {
        _lastUpdated = DateTime.now();
        _hasLoaded = true;
      }
    } catch (e) {
      _errorMessage = 'Error inesperado al cargar los datos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recarga el historial de un ticker específico
  Future<void> loadHistoryForTicker(String ticker) async {
    final cleanTicker = ticker.trim().toUpperCase();
    try {
      final history = await _apiService.fetchEtfHistory(cleanTicker);
      _historyMap[cleanTicker] = history;
      notifyListeners();
    } catch (e) {
      debugPrint('[EtfProvider] Error al obtener historial para $cleanTicker: $e');
    }
  }

  /// Recarga un único ticker
  Future<void> refreshTicker(String ticker) async {
    final cleanTicker = ticker.trim().toUpperCase();
    try {
      final data = await _apiService.fetchEtfData(cleanTicker);
      _etfMap[cleanTicker] = data;
      final history = await _apiService.fetchEtfHistory(cleanTicker).catchError((_) => <EtfHistoryEntry>[]);
      if (history.isNotEmpty) {
        _historyMap[cleanTicker] = history;
      }
      _lastUpdated = DateTime.now();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'No se pudo actualizar $cleanTicker: $e';
      notifyListeners();
    }
  }

  @visibleForTesting
  void setEtfDataForTesting(String ticker, EtfData data, [List<EtfHistoryEntry>? history]) {
    _etfMap[ticker] = data;
    if (history != null) {
      _historyMap[ticker] = history;
    }
    _hasLoaded = true;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}

class _TickerFetchResult {
  final String ticker;
  final EtfData? data;
  final List<EtfHistoryEntry> history;

  _TickerFetchResult({
    required this.ticker,
    required this.data,
    required this.history,
  });
}
