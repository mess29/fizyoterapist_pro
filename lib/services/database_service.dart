import 'package:hive_flutter/hive_flutter.dart';
import '../models/service_type.dart';
import '../models/session.dart';
import '../models/sync_conflict_log.dart';

class DatabaseService {
  late Box _serviceTypesBox;
  late Box _sessionsBox;
  late Box _syncConflictsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _serviceTypesBox = await Hive.openBox('service_types');
    _sessionsBox = await Hive.openBox('sessions');
    _syncConflictsBox = await Hive.openBox('sync_conflicts');
  }

  // Service Type CRUD
  List<ServiceType> getServiceTypes() {
    return _serviceTypesBox.values
        .map((e) => ServiceType.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveServiceType(ServiceType serviceType) async {
    await _serviceTypesBox.put(serviceType.id, serviceType.toJson());
  }

  Future<void> deleteServiceType(String id) async {
    await _serviceTypesBox.delete(id);
  }

  // Session CRUD
  List<Session> getSessions() {
    return _sessionsBox.values
        .map((e) => Session.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveSession(Session session) async {
    await _sessionsBox.put(session.id, session.toJson());
  }

  Future<void> saveSessions(List<Session> sessions) async {
    final Map<String, Map<String, dynamic>> data = {};
    for (var s in sessions) {
      data[s.id] = s.toJson();
    }
    await _sessionsBox.putAll(data);
  }

  Future<void> deleteSession(String id) async {
    await _sessionsBox.delete(id);
  }

  // Sync Conflict Logs
  List<SyncConflictLog> getSyncConflicts() {
    return _syncConflictsBox.values
        .map((e) => SyncConflictLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Sort newest first
  }

  Future<void> saveSyncConflict(SyncConflictLog log) async {
    await _syncConflictsBox.put(log.id, log.toJson());
  }

  Future<void> clearSyncConflicts() async {
    await _syncConflictsBox.clear();
  }

  Future<void> clearAll() async {
    await _serviceTypesBox.clear();
    await _sessionsBox.clear();
    await _syncConflictsBox.clear();
  }
}
