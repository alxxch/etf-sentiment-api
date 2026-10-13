import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/etf_data.dart';
import '../models/etf_history_entry.dart';
import '../models/portfolio_models.dart';
import '../models/broker_account.dart';
import '../models/notification_item.dart';
import '../models/rebalance_advice.dart';
import '../models/predictive_models.dart';

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

  /// Consulta el estado consolidado de la cartera y sus métricas en tiempo real.
  Future<PortfolioStatus> fetchPortfolio() async {
    final uri = Uri.parse('$baseUrl/api/v1/fintech/portfolio');

    try {
      final response = await _client
          .get(
            uri,
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return PortfolioStatus.fromJson(data);
      } else {
        throw ApiException(
          'Error obteniendo estado de la cartera (${response.statusCode}).',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al consultar la cartera.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de red al consultar la cartera: $e');
    }
  }

  /// Ejecuta una simulación DCA matemática retrospectiva cruzada con sentimiento.
  Future<DcaSimulationResult> simulateDca({
    double initialCapital = 0.0,
    double monthlyDeposit = 200.0,
    int months = 6,
    double allocationEquityPct = 80.0,
    double allocationGoldPct = 20.0,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/fintech/simulate-dca');
    final payload = {
      'initial_capital': initialCapital,
      'monthly_deposit': monthlyDeposit,
      'months': months,
      'allocation_equity_pct': allocationEquityPct,
      'allocation_gold_pct': allocationGoldPct,
    };

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(payload),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return DcaSimulationResult.fromJson(data);
      } else {
        throw ApiException(
          'Error ejecutando simulación DCA (${response.statusCode}).',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al ejecutar simulación DCA.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de red al simular DCA: $e');
    }
  }

  /// Actualiza la configuración del plan de ahorro activo del usuario.
  Future<SavingsPlanConfig> updateSavingsPlan(SavingsPlanConfig plan) async {
    final uri = Uri.parse('$baseUrl/api/v1/fintech/savings-plan');

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(plan.toJson()),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return SavingsPlanConfig.fromJson(data);
      } else {
        throw ApiException(
          'Error al actualizar el plan de ahorro (${response.statusCode}).',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al actualizar el plan de ahorro.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error al actualizar el plan de ahorro: $e');
    }
  }

  /// Envía la transcripción de voz o texto al asistente financiero (Gemini Function Calling + ElevenLabs).
  Future<Map<String, dynamic>> sendAssistantChat(
    String prompt, {
    int userId = 1,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/assistant/chat');
    final payload = {
      'user_prompt': prompt,
      'user_id': userId,
    };

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(payload),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data;
      } else {
        throw ApiException(
          'Error en el asistente (${response.statusCode}): ${utf8.decode(response.bodyBytes)}',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al consultar al asistente financiero.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de red al consultar al asistente: $e');
    }
  }

  // ==========================================================================
  // Open Banking & Broker Connectivity (Fase 13 & 16)
  // ==========================================================================

  /// Consulta las cuentas de brokers vinculadas por el usuario.
  Future<List<BrokerAccount>> fetchBrokerAccounts({int userId = 1}) async {
    final uri = Uri.parse('$baseUrl/api/v1/banking/accounts?user_id=$userId');

    try {
      final response = await _client
          .get(
            uri,
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> data =
            json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return data
            .map((item) => BrokerAccount.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          'Error obteniendo cuentas de broker (${response.statusCode}).',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al consultar cuentas de broker.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de red al consultar cuentas de broker: $e');
    }
  }

  /// Vincula una nueva cuenta de broker externo para el usuario.
  Future<BrokerAccount> linkBrokerAccount({
    required String brokerName,
    required String accountReference,
    int userId = 1,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/banking/link-account');
    final payload = {
      'broker_name': brokerName,
      'account_reference': accountReference,
      'user_id': userId,
    };

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(payload),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return BrokerAccount.fromJson(data);
      } else {
        throw ApiException(
          'Error vinculando broker (${response.statusCode}): ${utf8.decode(response.bodyBytes)}',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw const ApiException('Tiempo de espera agotado al vincular broker.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de red al vincular broker: $e');
    }
  }

  /// Dispara la sincronización bajo demanda e idempotente para una cuenta de broker.
  Future<Map<String, dynamic>> syncBrokerAccount(int accountId) async {
    final uri = Uri.parse('$baseUrl/api/v1/banking/sync/$accountId');

    try {
      final response = await _client
          .post(
            uri,
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data;
      } else {
        throw ApiException(
          'Error al sincronizar broker (${response.statusCode}): ${utf8.decode(response.bodyBytes)}',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al sincronizar broker.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de red al sincronizar broker: $e');
    }
  }

  // ==========================================================================
  // Motor de Rebalanceo Inteligente (Fase 14 & 16)
  // ==========================================================================

  /// Consulta el análisis cuantitativo de rebalanceo y desviación de cartera.
  Future<RebalanceAdvice> fetchRebalanceAdvice({
    int? portfolioId,
    double? customDeposit,
  }) async {
    final queryParams = <String, String>{};
    if (portfolioId != null) {
      queryParams['portfolio_id'] = portfolioId.toString();
    }
    if (customDeposit != null) {
      queryParams['custom_deposit'] = customDeposit.toString();
    }

    final uri = Uri.parse('$baseUrl/api/v1/fintech/rebalance-advice')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    try {
      final response = await _client
          .get(
            uri,
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return RebalanceAdvice.fromJson(data);
      } else {
        throw ApiException(
          'Error obteniendo consejo de rebalanceo (${response.statusCode}).',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al consultar consejo de rebalanceo.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de red al consultar rebalanceo: $e');
    }
  }

  // ==========================================================================
  // Alertas y Notificaciones Proactivas (Fase 15 & 16)
  // ==========================================================================

  /// Obtiene la lista de notificaciones del usuario ordenadas por fecha reciente.
  Future<List<NotificationItem>> fetchNotifications({
    int userId = 1,
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/notifications?user_id=$userId&unread_only=$unreadOnly&limit=$limit',
    );

    try {
      final response = await _client
          .get(
            uri,
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> data =
            json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return data
            .map((item) =>
                NotificationItem.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          'Error obteniendo notificaciones (${response.statusCode}).',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al consultar notificaciones.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de red al consultar notificaciones: $e');
    }
  }

  /// Marca una notificación como leída.
  Future<NotificationItem> markNotificationAsRead(int notificationId) async {
    final uri = Uri.parse('$baseUrl/api/v1/notifications/$notificationId/read');

    try {
      final response = await _client
          .patch(
            uri,
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return NotificationItem.fromJson(data);
      } else {
        throw ApiException(
          'Error al marcar notificación como leída (${response.statusCode}).',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al marcar notificación.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error al marcar notificación: $e');
    }
  }

  // ==========================================================================
  // Analítica Predictiva & Monte Carlo (Fase 24 & 26)
  // ==========================================================================

  /// Ejecuta una simulación estocástica Monte Carlo mediante GBM (Fase 24 / 26).
  Future<MonteCarloResult> fetchMonteCarloSimulation({
    String ticker = 'VWCE.DE',
    int horizonDays = 1260,
    int nSimulations = 5000,
    double initialInvestment = 10000.0,
    double monthlyContribution = 200.0,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/analytics/montecarlo');
    final payload = {
      'ticker': ticker,
      'horizon_days': horizonDays,
      'n_simulations': nSimulations,
      'initial_investment': initialInvestment,
      'monthly_contribution': monthlyContribution,
    };

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(payload),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return MonteCarloResult.fromJson(data);
      } else {
        throw ApiException(
          'Error en simulación Monte Carlo (${response.statusCode}): ${utf8.decode(response.bodyBytes)}',
          response.statusCode,
        );
      }
    } on TimeoutException {
      throw const ApiException(
        'Tiempo de espera agotado al consultar simulación Monte Carlo.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de red al consultar Monte Carlo: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
