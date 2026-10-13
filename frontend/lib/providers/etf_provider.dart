import 'package:flutter/foundation.dart';
import '../models/etf_data.dart';
import '../models/etf_history_entry.dart';
import '../services/api_service.dart';

class EtfProvider extends ChangeNotifier {
  final ApiService _apiService;

  EtfProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  static const Map<String, List<String>> categories = {
    'Trending': ['NVDA', 'TSLA', 'PLTR'],
    'ETFs': ['SWDA.L', 'CSPX.L', 'VWRA.L'],
    'Stocks': ['AAPL', 'MSFT', 'AMZN'],
    'Crypto': ['BTC-USD', 'ETH-USD', 'SOL-USD'],
  };

  static const String defaultCategory = 'ETFs';

  static const List<String> defaultTickers = [
    'SWDA.L',
    'CSPX.L',
    'VWRA.L',
  ];

  final Map<String, EtfData> _etfMap = {};
  final Map<String, List<EtfHistoryEntry>> _historyMap = {};
  final Set<String> _loadingTickers = {};
  String _selectedCategory = defaultCategory;
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
  String get selectedCategory => _selectedCategory;
  List<String> get availableCategories => categories.keys.toList();
  List<String> get tickers => categories[_selectedCategory] ?? defaultTickers;
  bool get hasData => _etfMap.isNotEmpty;

  String get selectedTicker =>
      tickers.isNotEmpty ? tickers[_selectedIndex.clamp(0, tickers.length - 1)] : '';

  /// Obtiene los datos del ETF actualmente seleccionado, o null si aún no se han cargado
  EtfData? get currentEtf => _etfMap[selectedTicker.trim().toUpperCase()];

  /// Obtiene el historial del ETF actualmente seleccionado
  List<EtfHistoryEntry> get currentHistory => getHistoryFor(selectedTicker);

  /// Obtiene la lista histórica de un ticker dado
  List<EtfHistoryEntry> getHistoryFor(String ticker) {
    return _historyMap[ticker.trim().toUpperCase()] ?? const [];
  }

  /// Lista ordenada de todos los ETFs cargados según la categoría activa
  List<EtfData> get allEtfs => tickers
      .map((t) => _etfMap[t.trim().toUpperCase()])
      .whereType<EtfData>()
      .toList();

  /// Comprueba si un ticker específico está cargando datos actualmente
  bool isTickerLoading(String ticker) {
    final clean = ticker.trim().toUpperCase();
    if (_loadingTickers.contains(clean)) return true;
    if (_isLoading) return true;
    return !_etfMap.containsKey(clean);
  }

  /// Comprueba si ya existen datos en memoria para un ticker específico
  bool hasLoadedTicker(String ticker) {
    return _etfMap.containsKey(ticker.trim().toUpperCase());
  }

  /// Cambia el ticker activo dentro de la categoría
  void selectTickerIndex(int index) {
    if (index >= 0 && index < tickers.length && index != _selectedIndex) {
      _selectedIndex = index;
      notifyListeners();
      // Si por alguna razón no tenemos historial cargado para este ticker, intentar obtenerlo
      final ticker = tickers[_selectedIndex];
      if (!_historyMap.containsKey(ticker) || _historyMap[ticker]!.isEmpty) {
        loadHistoryForTicker(ticker);
      }
    }
  }

  /// Cambia la categoría activa y recarga los datos de sus tickers desde el backend
  Future<void> selectCategory(String category) async {
    if (!categories.containsKey(category)) return;
    if (_selectedCategory == category && !_isLoading && _hasLoaded) {
      // Si ya está seleccionada y tiene datos, forzamos recarga al hacer click de nuevo
      await loadData(force: true);
      return;
    }

    _selectedCategory = category;
    _selectedIndex = 0;
    _errorMessage = null;
    notifyListeners();

    await loadData(force: true);
  }

  /// Alias para selectCategory
  Future<void> changeCategory(String category) => selectCategory(category);

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

  /// Realiza la consulta a la API de los 3 tickers de la categoría activa y su historial en paralelo
  Future<void> loadData({bool force = false}) async {
    // Protección contra peticiones duplicadas o concurrentes
    if (_isLoading) {
      debugPrint('[EtfProvider] loadData omitido: petición ya en curso.');
      return;
    }

    final currentTickers = List<String>.from(tickers);
    final currentCategory = _selectedCategory;

    final allCategoryTickersCached =
        currentTickers.every((t) => _etfMap.containsKey(t.trim().toUpperCase()));
    if (!force && _hasLoaded && allCategoryTickersCached) {
      debugPrint('[EtfProvider] loadData omitido: tickers de $currentCategory ya cargados previamente.');
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _loadingTickers.addAll(currentTickers.map((t) => t.trim().toUpperCase()));
    notifyListeners();

    try {
      // Peticiones en paralelo con tolerancia individual para cotizaciones e historiales
      final results = await Future.wait(
        currentTickers.map((ticker) async {
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

      // Si la categoría cambió mientras resolvía la red, no sobreescribir con resultados viejos
      if (_selectedCategory != currentCategory) {
        return;
      }

      int successfulLoads = 0;
      for (final res in results) {
        final cleanTicker = res.ticker.trim().toUpperCase();
        if (res.data != null) {
          _etfMap[cleanTicker] = res.data!;
          successfulLoads++;
        }
        if (res.history.isNotEmpty) {
          _historyMap[cleanTicker] = res.history;
        }
      }

      if (successfulLoads == 0) {
        _errorMessage =
            'No se pudo obtener información del backend para "$currentCategory". Verifica que el servidor FastAPI esté corriendo en http://localhost:8000';
      } else {
        _lastUpdated = DateTime.now();
        _hasLoaded = true;
      }
    } catch (e) {
      _errorMessage = 'Error inesperado al cargar los datos: $e';
    } finally {
      _loadingTickers.removeAll(currentTickers.map((t) => t.trim().toUpperCase()));
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
    final cleanTicker = ticker.trim().toUpperCase();
    _etfMap[cleanTicker] = data;
    if (history != null) {
      _historyMap[cleanTicker] = history;
    }
    _hasLoaded = true;
    _isLoading = false;
    _loadingTickers.remove(cleanTicker);
    notifyListeners();
  }

  @visibleForTesting
  void setCategoryForTesting(String category) {
    if (categories.containsKey(category)) {
      _selectedCategory = category;
      _selectedIndex = 0;
      notifyListeners();
    }
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
