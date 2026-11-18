import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/session.dart';
import '../models/service_type.dart';
import '../models/sync_conflict_log.dart';

class SyncResult {
  final int importedSessionsCount;
  final int importedServiceTypesCount;
  final List<SyncConflictLog> conflictLogs;
  final String? errorMessage;

  SyncResult({
    required this.importedSessionsCount,
    required this.importedServiceTypesCount,
    required this.conflictLogs,
    this.errorMessage,
  });
}

class DataSyncService {
  final _uuid = const Uuid();

  /// Exports all client sessions and service types within a selected date range to a structured map.
  Map<String, dynamic> exportData({
    required List<Session> allSessions,
    required List<ServiceType> allServiceTypes,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    // Ensure date range includes the entire start and end days
    final rangeStart = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
    final rangeEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final filteredSessions = allSessions.where((s) {
      return s.dateTime.isAfter(rangeStart) && s.dateTime.isBefore(rangeEnd);
    }).toList();

    return {
      'exportTime': DateTime.now().toIso8601String(),
      'startDate': rangeStart.toIso8601String(),
      'endDate': rangeEnd.toIso8601String(),
      'serviceTypes': allServiceTypes.map((t) => t.toJson()).toList(),
      'sessions': filteredSessions.map((s) => s.toJson()).toList(),
    };
  }

  /// Imports and merges a JSON payload, checking for schedule overlaps and logging conflicts.
  SyncResult importData({
    required String jsonPayload,
    required List<Session> currentSessions,
    required List<ServiceType> currentServiceTypes,
  }) {
    try {
      final decoded = json.decode(jsonPayload) as Map<String, dynamic>;
      
      final List<Session> importedSessions = [];
      final List<ServiceType> importedServiceTypes = [];
      final List<SyncConflictLog> newConflicts = [];

      // Parse service types if present
      if (decoded.containsKey('serviceTypes') && decoded['serviceTypes'] != null) {
        final rawTypes = decoded['serviceTypes'] as List;
        for (var raw in rawTypes) {
          importedServiceTypes.add(ServiceType.fromJson(Map<String, dynamic>.from(raw as Map)));
        }
      }

      // Parse sessions if present
      if (decoded.containsKey('sessions') && decoded['sessions'] != null) {
        final rawSessions = decoded['sessions'] as List;
        for (var raw in rawSessions) {
          importedSessions.add(Session.fromJson(Map<String, dynamic>.from(raw as Map)));
        }
      }

      // Create a working list of sessions that will be merged into the DB
      // We start with a copy of all current DB sessions
      final List<Session> mergedSessions = List.from(currentSessions);

      for (var importedSession in importedSessions) {
        // Find if this session is an update or a new insert
        final existingIndex = mergedSessions.indexWhere((s) => s.id == importedSession.id);
        
        // Remove old instance from working list to perform conflict checks accurately (excludes self)
        if (existingIndex != -1) {
          mergedSessions.removeAt(existingIndex);
        }

        // Check for conflicts against the rest of the sessions in our working list
        final importedStart = importedSession.dateTime;
        final importedEnd = importedSession.endTime;
        Session? conflictingSession;

        for (var s in mergedSessions) {
          final existingStart = s.dateTime;
          final existingEnd = s.endTime;

          // Overlap condition
          if (importedStart.isBefore(existingEnd) && importedEnd.isAfter(existingStart)) {
            conflictingSession = s;
            break; // Stop at first conflict
          }
        }

        if (conflictingSession != null) {
          final logMessage = 'Overlapped with ${conflictingSession.clientName}\'s '
              'session (${conflictingSession.serviceTypeName}) scheduled at '
              '${_formatDateTime(conflictingSession.dateTime)}';
          
          newConflicts.add(SyncConflictLog(
            id: _uuid.v4(),
            sessionId: importedSession.id,
            clientName: importedSession.clientName,
            dateTime: importedSession.dateTime,
            message: logMessage,
            timestamp: DateTime.now(),
          ));
        }

        // Add back (or update) the imported session into our working list
        mergedSessions.add(importedSession);
      }

      return SyncResult(
        importedSessionsCount: importedSessions.length,
        importedServiceTypesCount: importedServiceTypes.length,
        conflictLogs: newConflicts,
      );
    } catch (e) {
      return SyncResult(
        importedSessionsCount: 0,
        importedServiceTypesCount: 0,
        conflictLogs: [],
        errorMessage: 'Failed to parse JSON sync payload: $e',
      );
    }
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} at $h:$m';
  }
}
