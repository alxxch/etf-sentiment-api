class BrokerAccount {
  final int id;
  final int userId;
  final String brokerName;
  final String accountReference;
  final String syncStatus;
  final DateTime? lastSyncedAt;

  const BrokerAccount({
    required this.id,
    required this.userId,
    required this.brokerName,
    required this.accountReference,
    required this.syncStatus,
    this.lastSyncedAt,
  });

  factory BrokerAccount.fromJson(Map<String, dynamic> json) {
    DateTime? parsedSync;
    if (json['last_synced_at'] != null) {
      try {
        parsedSync = DateTime.parse(json['last_synced_at'] as String);
      } catch (_) {}
    }

    return BrokerAccount(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 1,
      brokerName: json['broker_name'] as String? ?? 'Broker',
      accountReference: json['account_reference'] as String? ?? '',
      syncStatus: (json['sync_status'] as String? ?? 'PENDING').toUpperCase(),
      lastSyncedAt: parsedSync,
    );
  }

  bool get isSynced => syncStatus == 'SYNCED';
  bool get isPending => syncStatus == 'PENDING';
  bool get isError => syncStatus == 'ERROR';
}
