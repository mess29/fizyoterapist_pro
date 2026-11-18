import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/service_type.dart';
import '../services/database_service.dart';

final dbServiceProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError();
});

class ServiceTypesNotifier extends StateNotifier<List<ServiceType>> {
  final DatabaseService _dbService;

  ServiceTypesNotifier(this._dbService) : super([]) {
    load();
  }

  void load() {
    state = _dbService.getServiceTypes();
  }

  Future<void> addServiceType(String name, int durationInMinutes) async {
    final service = ServiceType(
      id: const Uuid().v4(),
      name: name,
      durationInMinutes: durationInMinutes,
    );
    await _dbService.saveServiceType(service);
    load();
  }

  Future<void> updateServiceType(String id, String name, int durationInMinutes) async {
    final service = ServiceType(
      id: id,
      name: name,
      durationInMinutes: durationInMinutes,
    );
    await _dbService.saveServiceType(service);
    load();
  }

  Future<void> deleteServiceType(String id) async {
    await _dbService.deleteServiceType(id);
    load();
  }
}

final serviceTypesProvider = StateNotifierProvider<ServiceTypesNotifier, List<ServiceType>>((ref) {
  final dbService = ref.watch(dbServiceProvider);
  return ServiceTypesNotifier(dbService);
});
