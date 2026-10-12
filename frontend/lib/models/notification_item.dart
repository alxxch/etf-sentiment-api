class NotificationItem {
  final int id;
  final int userId;
  final String title;
  final String message;
  final String type; // OPPORTUNITY, DRIFT, SYSTEM
  final bool isRead;
  final DateTime? timestamp;

  const NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.timestamp,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['timestamp'] != null) {
      try {
        parsedDate = DateTime.parse(json['timestamp'] as String);
      } catch (_) {}
    }

    return NotificationItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 1,
      title: json['title'] as String? ?? 'Notificación',
      message: json['message'] as String? ?? '',
      type: (json['type'] as String? ?? 'SYSTEM').toUpperCase(),
      isRead: json['is_read'] as bool? ?? false,
      timestamp: parsedDate,
    );
  }

  bool get isOpportunity => type == 'OPPORTUNITY';
  bool get isDrift => type == 'DRIFT';
  bool get isSystem => type == 'SYSTEM';

  NotificationItem copyWith({
    bool? isRead,
  }) {
    return NotificationItem(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp,
    );
  }
}
