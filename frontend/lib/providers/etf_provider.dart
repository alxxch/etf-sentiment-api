import 'package:flutter/foundation.dart';
import '../models/etf_data.dart';
import '../services/api_service.dart';

class EtfProvider extends ChangeNotifier {
  final ApiService _apiService;

  EtfProvider({ApiService? apiService})
      : _apiService = apiService ?? const ApiService();

  static const List<String> availableTickers = [
    'VWCE.DE',
    'EUNL.DE',
    '8PSG.DE',
  ];

  int _selectedIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;
  List<EtfData> _items = EtfData.mocks;

  int get selectedIndex => _selectedIndex;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<EtfData> get items => _items;

  EtfData get currentItem =>
      _items.isNotEmpty && _selectedIndex < _items.length
          ? _items[_selectedIndex]
          : EtfData.mocks[0];

  void selectTicker(int index) {
    if (index >= 0 && index < availableTickers.length) {
      _selectedIndex = index;
      notifyListeners();
    }
  }

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<EtfData> loaded = [];
      for (final ticker in availableTickers) {
        final data = await _apiService.fetchEtfData(ticker);
        loaded.add(data);
      }
      _items = loaded;
    } catch (e) {
      _errorMessage = e.toString();
      // Mantiene datos mock si falla la conexión
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
