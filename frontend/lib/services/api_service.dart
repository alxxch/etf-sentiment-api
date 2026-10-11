import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/etf_data.dart';

class ApiService {
  final String baseUrl;

  const ApiService({
    this.baseUrl = 'http://127.0.0.1:8000',
  });

  /// Realiza la petición GET al endpoint de backend para un ticker específico
  Future<EtfData> fetchEtfData(String ticker) async {
    final uri = Uri.parse('$baseUrl/api/v1/sentiment/$ticker');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return EtfData.fromJson(data);
    } else {
      throw Exception('Error al consultar el ticker $ticker: Status ${response.statusCode}');
    }
  }
}
