import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/session.dart';
import '../models/service_type.dart';
import '../models/schedule_slot.dart';
import '../models/sync_conflict_log.dart';
import '../services/database_service.dart';
import '../services/data_sync_service.dart';
import 'service_provider.dart';

class SessionsNotifier extends StateNotifier<List<Session>> {
  final DatabaseService _dbService;
  final Ref _ref;
  final _syncService = DataSyncService();

  SessionsNotifier(this._dbService, this._ref) : super([]) {
    _load();
  }

  void _load() {
    state = _dbService.getSessions();
  }

  // Check if a given slot overlaps with any existing sessions (except excludeId)
  bool checkConflict(DateTime start, int durationInMinutes, {String? excludeId}) {
    final end = start.add(Duration(minutes: durationInMinutes));
    for (var session in state) {
      if (session.id == excludeId) continue;
      final existingStart = session.dateTime;
      final existingEnd = session.endTime;
      
      // Overlap condition: start < existingEnd && end > existingStart
      if (start.isBefore(existingEnd) && end.isAfter(existingStart)) {
        return true;
      }
    }
    return false;
  }

  // Count conflicts in a proposed list of dates/durations
  int countConflicts(List<DateTime> dates, int durationInMinutes) {
    int count = 0;
    for (var date in dates) {
      if (checkConflict(date, durationInMinutes)) {
        count++;
      }
    }
    return count;
  }

  // Create a single session
  Future<void> addSession({
    required String clientName,
    required ServiceType serviceType,
    required DateTime dateTime,
    double? price,
    PaymentStatus paymentStatus = PaymentStatus.unpaid,
    double amountPaid = 0.0,
  }) async {
    final session = Session(
      id: const Uuid().v4(),
      clientName: clientName,
      serviceTypeId: serviceType.id,
      serviceTypeName: serviceType.name,
      serviceTypeDurationMinutes: serviceType.durationInMinutes,
      dateTime: dateTime,
      price: price,
      paymentStatus: paymentStatus,
      amountPaid: amountPaid,
    );
    await _dbService.saveSession(session);
    _load();
  }

  // Generate and insert a session series
  Future<void> generateSeries({
    required String clientName,
    required ServiceType serviceType,
    required int totalSessions,
    required List<ScheduleSlot> slots,
    required DateTime startFrom,
    double? price,
  }) async {
    // Generate dates
    final dates = generateSessionDates(
      startFrom: startFrom,
      slots: slots,
      totalSessions: totalSessions,
    );

    final seriesId = const Uuid().v4();
    final List<Session> newSessions = [];

    for (int i = 0; i < dates.length; i++) {
      newSessions.add(Session(
        id: const Uuid().v4(),
        clientName: clientName,
        serviceTypeId: serviceType.id,
        serviceTypeName: serviceType.name,
        serviceTypeDurationMinutes: serviceType.durationInMinutes,
        dateTime: dates[i],
        seriesId: seriesId,
        indexInSeries: i + 1,
        totalInSeries: totalSessions,
        price: price,
        paymentStatus: PaymentStatus.unpaid,
        amountPaid: 0.0,
      ));
    }

    await _dbService.saveSessions(newSessions);
    _load();
  }

  // Helper date generation logic
  List<DateTime> generateSessionDates({
    required DateTime startFrom,
    required List<ScheduleSlot> slots,
    required int totalSessions,
  }) {
    List<DateTime> dates = [];
    DateTime current = startFrom;

    while (dates.length < totalSessions) {
      int dayOfWeek = current.weekday;
      
      // Find slots matching current day of week
      List<ScheduleSlot> dailySlots = slots.where((s) => s.weekday == dayOfWeek).toList();
      dailySlots.sort((a, b) {
        if (a.hour != b.hour) return a.hour.compareTo(b.hour);
        return a.minute.compareTo(b.minute);
      });

      for (var slot in dailySlots) {
        DateTime candidate = DateTime(
          current.year,
          current.month,
          current.day,
          slot.hour,
          slot.minute,
        );
        
        if (candidate.isAfter(startFrom)) {
          dates.add(candidate);
          if (dates.length == totalSessions) {
            break;
          }
        }
      }
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  // Update an existing session's values entirely (Phase 2 general update)
  Future<void> updateSession(Session session) async {
    await _dbService.saveSession(session);
    _load();
  }

  // Reschedule a specific session (affects ONLY this instance)
  Future<void> rescheduleSession(String id, DateTime newDateTime) async {
    final existingIndex = state.indexWhere((s) => s.id == id);
    if (existingIndex == -1) return;

    final updatedSession = state[existingIndex].copyWith(
      dateTime: newDateTime,
    );

    await _dbService.saveSession(updatedSession);
    _load();
  }

  // Quick toggle between Paid and Unpaid status
  Future<void> togglePaymentStatus(String id) async {
    final existingIndex = state.indexWhere((s) => s.id == id);
    if (existingIndex == -1) return;

    final session = state[existingIndex];
    final isCurrentlyPaid = session.paymentStatus == PaymentStatus.paid;
    final newStatus = isCurrentlyPaid ? PaymentStatus.unpaid : PaymentStatus.paid;
    
    // Automatically set amountPaid to match price if paid, or reset to 0 if unpaid
    final newAmountPaid = newStatus == PaymentStatus.paid 
        ? (session.price ?? 0.0) 
        : 0.0;

    final updatedSession = session.copyWith(
      paymentStatus: newStatus,
      amountPaid: newAmountPaid,
    );

    await _dbService.saveSession(updatedSession);
    _load();
  }

  // Delete a session
  Future<void> deleteSession(String id) async {
    await _dbService.deleteSession(id);
    _load();
  }

  // JSON Export wrapper
  Map<String, dynamic> exportSyncData(DateTime start, DateTime end) {
    final serviceTypes = _ref.read(serviceTypesProvider);
    return _syncService.exportData(
      allSessions: state,
      allServiceTypes: serviceTypes,
      startDate: start,
      endDate: end,
    );
  }

  // JSON Import wrapper
  Future<SyncResult> importSyncData(String jsonPayload) async {
    final serviceTypes = _ref.read(serviceTypesProvider);
    final result = _syncService.importData(
      jsonPayload: jsonPayload,
      currentSessions: state,
      currentServiceTypes: serviceTypes,
    );

    if (result.errorMessage != null) {
      return result;
    }



    // Let's perform db writes for what was imported
    final decoded = jsonDecode(jsonPayload) as Map<String, dynamic>;
    
    // Write service types
    if (decoded.containsKey('serviceTypes') && decoded['serviceTypes'] != null) {
      final list = decoded['serviceTypes'] as List;
      for (var raw in list) {
        final type = ServiceType.fromJson(Map<String, dynamic>.from(raw as Map));
        await _dbService.saveServiceType(type);
      }
      // Force service types provider to reload
      _ref.read(serviceTypesProvider.notifier).load();
    }

    // Write sessions
    if (decoded.containsKey('sessions') && decoded['sessions'] != null) {
      final list = decoded['sessions'] as List;
      for (var raw in list) {
        final sess = Session.fromJson(Map<String, dynamic>.from(raw as Map));
        await _dbService.saveSession(sess);
      }
    }

    // Write conflicts
    for (var log in result.conflictLogs) {
      await _dbService.saveSyncConflict(log);
    }
    
    // Reload conflicts state
    _ref.read(syncConflictLogsProvider.notifier).loadLogs();

    // Reload sessions state
    _load();

    return result;
  }
}

final sessionsProvider = StateNotifierProvider<SessionsNotifier, List<Session>>((ref) {
  final dbService = ref.watch(dbServiceProvider);
  return SessionsNotifier(dbService, ref);
});

// Conflict logs state provider
class SyncConflictLogsNotifier extends StateNotifier<List<SyncConflictLog>> {
  final DatabaseService _dbService;

  SyncConflictLogsNotifier(this._dbService) : super([]) {
    loadLogs();
  }

  void loadLogs() {
    state = _dbService.getSyncConflicts();
  }

  Future<void> saveLog(SyncConflictLog log) async {
    await _dbService.saveSyncConflict(log);
    loadLogs();
  }

  Future<void> clearLogs() async {
    await _dbService.clearSyncConflicts();
    loadLogs();
  }
}

final syncConflictLogsProvider = StateNotifierProvider<SyncConflictLogsNotifier, List<SyncConflictLog>>((ref) {
  final dbService = ref.watch(dbServiceProvider);
  return SyncConflictLogsNotifier(dbService);
});
