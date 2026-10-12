import 'package:flutter/foundation.dart';
import '../models/notification_item.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _apiService;

  NotificationProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  // Getters
  List<NotificationItem> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;

  /// Carga las notificaciones del usuario
  Future<void> loadNotifications({
    int userId = 1,
    bool force = false,
  }) async {
    if (_isLoading) return;
    if (!force && _hasLoaded) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await _apiService.fetchNotifications(userId: userId);
      _notifications = list;
      _hasLoaded = true;
    } catch (e) {
      _errorMessage = 'Error al cargar alertas: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marca una notificación individual como leída
  Future<void> markAsRead(int notificationId) async {
    try {
      // Optimistic update
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true);
        notifyListeners();
      }

      final updated = await _apiService.markNotificationAsRead(notificationId);
      if (idx != -1) {
        _notifications[idx] = updated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[NotificationProvider] Error marcando leída: $e');
    }
  }

  /// Marca todas las notificaciones como leídas
  Future<void> markAllAsRead() async {
    final unread = _notifications.where((n) => !n.isRead).toList();
    for (final item in unread) {
      await markAsRead(item.id);
    }
  }

  @visibleForTesting
  void setNotificationsForTesting(List<NotificationItem> list) {
    _notifications = list;
    _hasLoaded = true;
    notifyListeners();
  }
}
