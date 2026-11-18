import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fizyoterapist_pro/models/session.dart';
import 'package:fizyoterapist_pro/models/service_type.dart';
import 'package:fizyoterapist_pro/models/schedule_slot.dart';
import 'package:fizyoterapist_pro/models/sync_conflict_log.dart';
import 'package:fizyoterapist_pro/providers/session_provider.dart';
import 'package:fizyoterapist_pro/providers/service_provider.dart';
import 'package:fizyoterapist_pro/services/database_service.dart';
import 'package:fizyoterapist_pro/services/data_sync_service.dart';

// Mock DB wrapper for unit tests (in-memory lists)
class MockDatabaseService extends DatabaseService {
  final List<ServiceType> serviceTypes = [];
  final List<Session> sessions = [];
  final List<SyncConflictLog> conflicts = [];

  @override
  Future<void> init() async {}

  @override
  List<ServiceType> getServiceTypes() => List.from(serviceTypes);

  @override
  Future<void> saveServiceType(ServiceType serviceType) async {
    final idx = serviceTypes.indexWhere((t) => t.id == serviceType.id);
    if (idx != -1) {
      serviceTypes[idx] = serviceType;
    } else {
      serviceTypes.add(serviceType);
    }
  }

  @override
  Future<void> deleteServiceType(String id) async {
    serviceTypes.removeWhere((t) => t.id == id);
  }

  @override
  List<Session> getSessions() => List.from(sessions);

  @override
  Future<void> saveSession(Session session) async {
    final idx = sessions.indexWhere((s) => s.id == session.id);
    if (idx != -1) {
      sessions[idx] = session;
    } else {
      sessions.add(session);
    }
  }

  @override
  Future<void> saveSessions(List<Session> list) async {
    for (var s in list) {
      await saveSession(s);
    }
  }

  @override
  Future<void> deleteSession(String id) async {
    sessions.removeWhere((s) => s.id == id);
  }

  @override
  List<SyncConflictLog> getSyncConflicts() => List.from(conflicts);

  @override
  Future<void> saveSyncConflict(SyncConflictLog log) async {
    conflicts.add(log);
  }

  @override
  Future<void> clearSyncConflicts() async {
    conflicts.clear();
  }

  @override
  Future<void> clearAll() async {
    serviceTypes.clear();
    sessions.clear();
    conflicts.clear();
  }
}

// A simple riverpod-like stub container to satisfy notifier dependency in tests
class TestRef implements Ref {
  final ServiceTypesNotifier serviceNotifier;
  final SyncConflictLogsNotifier conflictNotifier;

  TestRef(this.serviceNotifier, this.conflictNotifier);

  @override
  T read<T>(ProviderListenable<T> provider) {
    if (provider.toString().contains('serviceTypesProvider')) {
      return serviceNotifier.state as T;
    }
    if (provider.toString().contains('syncConflictLogsProvider')) {
      return conflictNotifier as T;
    }
    throw UnimplementedError('Provider read not mocked for $provider');
  }

  @override
  void invalidate(ProviderOrFamily provider) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Session Generation Logic Tests', () {
    late SessionsNotifier notifier;
    late MockDatabaseService mockDb;

    setUp(() {
      mockDb = MockDatabaseService();
      // Setup simple manual DI for Riverpod ref in tests
      final serviceNotifier = ServiceTypesNotifier(mockDb);
      final conflictNotifier = SyncConflictLogsNotifier(mockDb);
      final ref = TestRef(serviceNotifier, conflictNotifier);
      notifier = SessionsNotifier(mockDb, ref);
    });

    test('generateSessionDates outputs correct chronological list', () {
      final startFrom = DateTime(2026, 6, 25, 14, 1); // Thursday
      final slots = [
        ScheduleSlot(weekday: 2, hour: 10, minute: 0), // Tuesday
        ScheduleSlot(weekday: 4, hour: 10, minute: 0), // Thursday
      ];

      final dates = notifier.generateSessionDates(
        startFrom: startFrom,
        slots: slots,
        totalSessions: 4,
      );

      expect(dates.length, 4);
      expect(dates[0], DateTime(2026, 6, 30, 10, 0));
      expect(dates[1], DateTime(2026, 7, 2, 10, 0));
      expect(dates[2], DateTime(2026, 7, 7, 10, 0));
      expect(dates[3], DateTime(2026, 7, 9, 10, 0));
    });

    test('Session labels match formatting specification', () {
      final sessionWithSeries = Session(
        id: '1',
        clientName: 'Ahmet Bey',
        serviceTypeId: 'pilates',
        serviceTypeName: 'Pilates',
        serviceTypeDurationMinutes: 50,
        dateTime: DateTime(2026, 6, 25, 10, 0),
        seriesId: 'series-xyz',
        indexInSeries: 4,
        totalInSeries: 10,
      );

      expect(sessionWithSeries.label, 'Ahmet Bey - Pilates (4/10)');
    });

    test('Conflict checking detects overlapping slots correctly', () {
      notifier.state = [
        Session(
          id: 'existing-1',
          clientName: 'Client A',
          serviceTypeId: 'therapy',
          serviceTypeName: 'Manual Therapy',
          serviceTypeDurationMinutes: 60, // 10:00 to 11:00
          dateTime: DateTime(2026, 6, 25, 10, 0),
        ),
      ];

      final conflict = notifier.checkConflict(
        DateTime(2026, 6, 25, 10, 15),
        60,
      );
      expect(conflict, true);

      final noConflict = notifier.checkConflict(
        DateTime(2026, 6, 25, 11, 0),
        60,
      );
      expect(noConflict, false);
    });
  });

  group('Phase 2 Upgrades Tests', () {
    late MockDatabaseService mockDb;
    late SessionsNotifier sessionsNotifier;
    late ServiceTypesNotifier serviceTypesNotifier;
    late SyncConflictLogsNotifier conflictLogsNotifier;

    setUp(() {
      mockDb = MockDatabaseService();
      serviceTypesNotifier = ServiceTypesNotifier(mockDb);
      conflictLogsNotifier = SyncConflictLogsNotifier(mockDb);
      final ref = TestRef(serviceTypesNotifier, conflictLogsNotifier);
      sessionsNotifier = SessionsNotifier(mockDb, ref);
    });

    test('Isolated Service Type Durations - Modifying ServiceType does not change old sessions', () async {
      // 1. Create a service type
      final initialService = ServiceType(id: 'pilates-id', name: 'Pilates', durationInMinutes: 60);
      await mockDb.saveServiceType(initialService);
      serviceTypesNotifier.state = [initialService];

      // 2. Generate a session using this service type (creates snapshotted duration)
      await sessionsNotifier.addSession(
        clientName: 'Client A',
        serviceType: initialService,
        dateTime: DateTime(2026, 7, 18, 10, 0),
      );

      // Verify created session has 60 minutes
      expect(sessionsNotifier.state.first.serviceTypeDurationMinutes, 60);

      // 3. Update the service type duration to 45 minutes
      final updatedService = ServiceType(id: 'pilates-id', name: 'Pilates', durationInMinutes: 45);
      await mockDb.saveServiceType(updatedService);
      serviceTypesNotifier.state = [updatedService];

      // 4. Force reload sessions and verify original generated session duration is still 60 minutes
      sessionsNotifier.state = mockDb.getSessions();
      expect(sessionsNotifier.state.first.serviceTypeDurationMinutes, 60); // Unaltered
    });

    test('Financial Fields Serialization - Price, PaymentStatus, AmountPaid mapping works', () {
      final session = Session(
        id: 'financial-1',
        clientName: 'Client A',
        serviceTypeId: 'pilates',
        serviceTypeName: 'Pilates',
        serviceTypeDurationMinutes: 60,
        dateTime: DateTime(2026, 7, 18, 10, 0),
        price: 500.0,
        paymentStatus: PaymentStatus.partiallyPaid,
        amountPaid: 200.0,
      );

      final json = session.toJson();
      expect(json['price'], 500.0);
      expect(json['paymentStatus'], 'partiallyPaid');
      expect(json['amountPaid'], 200.0);

      final deserialized = Session.fromJson(json);
      expect(deserialized.price, 500.0);
      expect(deserialized.paymentStatus, PaymentStatus.partiallyPaid);
      expect(deserialized.amountPaid, 200.0);
    });

    test('JSON Data Sync - Export limits output to requested date ranges', () {
      final syncService = DataSyncService();
      
      final services = [ServiceType(id: 'pilates', name: 'Pilates', durationInMinutes: 50)];
      final sessions = [
        Session(
          id: 's1',
          clientName: 'Client A',
          serviceTypeId: 'pilates',
          serviceTypeName: 'Pilates',
          serviceTypeDurationMinutes: 50,
          dateTime: DateTime(2026, 7, 5, 10, 0), // Inside July range
        ),
        Session(
          id: 's2',
          clientName: 'Client B',
          serviceTypeId: 'pilates',
          serviceTypeName: 'Pilates',
          serviceTypeDurationMinutes: 50,
          dateTime: DateTime(2026, 8, 1, 10, 0), // Outside range
        ),
      ];

      // Export July range
      final exported = syncService.exportData(
        allSessions: sessions,
        allServiceTypes: services,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 31),
      );

      final exportedSessions = exported['sessions'] as List;
      expect(exportedSessions.length, 1);
      expect(exportedSessions.first['id'], 's1');
    });

    test('JSON Data Sync - Importing merges updates and records overlaps in conflicts log', () {
      final syncService = DataSyncService();

      final currentServices = [ServiceType(id: 'pilates', name: 'Pilates', durationInMinutes: 50)];
      
      // Existing session (Client A at 10:00)
      final existingSession = Session(
        id: 'session-a',
        clientName: 'Client A',
        serviceTypeId: 'pilates',
        serviceTypeName: 'Pilates',
        serviceTypeDurationMinutes: 50, // 10:00 to 10:50
        dateTime: DateTime(2026, 7, 18, 10, 0),
        price: 400.0,
        paymentStatus: PaymentStatus.unpaid,
        amountPaid: 0.0,
      );

      final currentSessions = [existingSession];

      // Import payload:
      // 1. Updates Client A to 'paid' status
      // 2. Inserts Client B at 10:30 (overlaps with Client A)
      final payload = {
        'serviceTypes': currentServices.map((s) => s.toJson()).toList(),
        'sessions': [
          // Update:
          existingSession.copyWith(
            paymentStatus: PaymentStatus.paid,
            amountPaid: 400.0,
          ).toJson(),
          // Conflict Insert:
          {
            'id': 'session-b',
            'clientName': 'Client B',
            'serviceTypeId': 'pilates',
            'serviceTypeName': 'Pilates',
            'serviceTypeDurationMinutes': 50,
            'dateTime': DateTime(2026, 7, 18, 10, 30).toIso8601String(), // Overlaps
            'price': 500.0,
            'paymentStatus': 'unpaid',
            'amountPaid': 0.0,
          }
        ]
      };

      final jsonPayload = jsonEncode(payload);

      final result = syncService.importData(
        jsonPayload: jsonPayload,
        currentSessions: currentSessions,
        currentServiceTypes: currentServices,
      );

      expect(result.errorMessage, isNull);
      expect(result.importedSessionsCount, 2);
      expect(result.importedServiceTypesCount, 1);
      
      // Verification of overlap conflict logging
      expect(result.conflictLogs.length, 1);
      final log = result.conflictLogs.first;
      expect(log.sessionId, 'session-b');
      expect(log.clientName, 'Client B');
      expect(log.message, contains('Overlapped with Client A'));
    });
  });
}
