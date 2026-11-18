class SyncConflictLog {
  final String id;
  final String sessionId;
  final String clientName;
  final DateTime dateTime;
  final String message;
  final DateTime timestamp;

  SyncConflictLog({
    required this.id,
    required this.sessionId,
    required this.clientName,
    required this.dateTime,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'clientName': clientName,
        'dateTime': dateTime.toIso8601String(),
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SyncConflictLog.fromJson(Map<String, dynamic> json) => SyncConflictLog(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String,
        clientName: json['clientName'] as String,
        dateTime: DateTime.parse(json['dateTime'] as String),
        message: json['message'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
