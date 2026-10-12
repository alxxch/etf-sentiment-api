import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/etf_data.dart';
import '../models/etf_history_entry.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiService {
  final String baseUrl;
  final http.Client _client;
  final Duration timeoutDuration;

  ApiService({
    this.baseUrl = 'http://localhost:8000',
    http.Client? client,
    this.timeoutDuration = const Duration(seconds: 25),
  }) : _client = client ?? http.Client();

  /// Realiza la petición GET al endpoint del backend para un ticker específico.
  /// Maneja timeouts, errores de conexión, y códigos de respuesta HTTP (404, 500).
  Future<EtfData> fetchEtfData(String ticker) async {
    final cleanTicker = ticker.trim().toUpperCase();
    final uri = Uri.parse('$baseUrl/api/v1/sentiment/$cleanTicker');

    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return EtfData.fromJson(data);
      } else if (response.statusCode == 404) {
        throw ApiException(
          'Ticker "$cleanTicker" no encontrado en el servidor.',
          404,
        );
      } else if (response.statusCode >= 500) {
        throw ApiException(
          'Error interno en el backend (${response.statusCode}) procesando "$cleanTicker".',
          response.statusCode,
        );
      } else {
        throw ApiException(
          'Respuesta inesperada (${response.statusCode}) del servidor.',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw ApiException(
        'Tiempo de espera agotado al consultar "$cleanTicker". Verifica que el backend esté respondiendo.',
      );
    } on SocketException catch (e) {
      throw ApiException(
        'No se pudo conectar con el servidor en $baseUrl: ${e.message}. Asegúrate de que Uvicorn esté iniciado.',
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Error de conexión HTTP: ${e.message}. Verifica que el backend esté activo en $baseUrl.',
      );
    } on FormatException {
      throw const ApiException(
        'El servidor devolvió un formato JSON inválido o corrupto.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'Error inesperado al consultar "$cleanTicker": $e',
      );
    }
  }

  /// Obtiene la serie temporal de registros históricos almacenados en PostgreSQL.
  Future<List<EtfHistoryEntry>> fetchEtfHistory(
    String ticker, {
    int limit = 50,
  }) async {
    final cleanTicker = ticker.trim().toUpperCase();
    final uri = Uri.parse('$baseUrl/api/v1/history/$cleanTicker?limit=$limit');

    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> data =
            json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return data
            .map((item) => EtfHistoryEntry.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          'Error obteniendo historial (${response.statusCode}) para "$cleanTicker".',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw ApiException(
        'Tiempo de espera agotado al consultar historial de "$cleanTicker".',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'Error de red al consultar historial de "$cleanTicker": $e',
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
