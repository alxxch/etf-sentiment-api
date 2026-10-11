import 'package:flutter/foundation.dart';
import '../models/etf_data.dart';
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

  /// Realiza la consulta a la API de los 3 tickers en paralelo
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
      // Peticiones en paralelo con tolerancia individual
      final results = await Future.wait(
        defaultTickers.map((ticker) async {
          try {
            final data = await _apiService.fetchEtfData(ticker);
            return MapEntry<String, EtfData?>(ticker, data);
          } catch (e) {
            debugPrint('[EtfProvider] Error cargando $ticker: $e');
            return MapEntry<String, EtfData?>(ticker, null);
          }
        }),
      );

      int successfulLoads = 0;
      for (final entry in results) {
        if (entry.value != null) {
          _etfMap[entry.key] = entry.value!;
          successfulLoads++;
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

  /// Recarga un único ticker
  Future<void> refreshTicker(String ticker) async {
    try {
      final data = await _apiService.fetchEtfData(ticker);
      _etfMap[ticker] = data;
      _lastUpdated = DateTime.now();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'No se pudo actualizar $ticker: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}
