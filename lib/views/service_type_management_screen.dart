import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_type.dart';
import '../providers/service_provider.dart';

class ServiceTypeManagementScreen extends ConsumerStatefulWidget {
  const ServiceTypeManagementScreen({super.key});

  @override
  ConsumerState<ServiceTypeManagementScreen> createState() => _ServiceTypeManagementScreenState();
}

class _ServiceTypeManagementScreenState extends ConsumerState<ServiceTypeManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _showServiceTypeDialog({ServiceType? service}) {
    if (service != null) {
      _nameController.text = service.name;
      _durationController.text = service.durationInMinutes.toString();
    } else {
      _nameController.clear();
      _durationController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          backgroundColor: const Color(0xFF1E293B), // Slate 800
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service == null ? 'Add Service Type' : 'Edit Service Type',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  
                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Service Name',
                      labelStyle: const TextStyle(color: Color(0xFF64748B)),
                      hintText: 'e.g., Pilates, Manual Therapy',
                      hintStyle: const TextStyle(color: Color(0xFF475569)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF475569)),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF6366F1)),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),

                  // Duration Field
                  TextFormField(
                    controller: _durationController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Duration (Minutes)',
                      labelStyle: const TextStyle(color: Color(0xFF64748B)),
                      hintText: 'e.g., 60',
                      hintStyle: const TextStyle(color: Color(0xFF475569)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF475569)),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF6366F1)),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a duration';
                      }
                      final dur = int.tryParse(value);
                      if (dur == null || dur <= 0) {
                        return 'Please enter a valid duration greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24.0),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            final name = _nameController.text.trim();
                            final duration = int.parse(_durationController.text);
                            final notifier = ref.read(serviceTypesProvider.notifier);

                            if (service == null) {
                              notifier.addServiceType(name, duration);
                            } else {
                              notifier.updateServiceType(service.id, name, duration);
                            }
                            
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  service == null ? 'Service created' : 'Service updated',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1), // Indigo 500
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                        ),
                        child: Text(
                          service == null ? 'Create' : 'Save Changes',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(ServiceType service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Service Type', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${service.name}"? This will not delete previously generated sessions of this type, but they will be frozen.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(serviceTypesProvider.notifier).deleteServiceType(service.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Service type deleted'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(serviceTypesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        title: const Text(
          'Service Types',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20.0),
        ),
        backgroundColor: const Color(0xFF1E293B), // Slate 800
        elevation: 0,
      ),
      body: services.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                return Card(
                  color: const Color(0xFF1E293B), // Slate 800
                  margin: const EdgeInsets.only(bottom: 12.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side: const BorderSide(color: Color(0xFF334155), width: 1.0),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    leading: Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medical_services_rounded,
                        color: Color(0xFF6366F1), // Indigo 500
                        size: 24.0,
                      ),
                    ),
                    title: Text(
                      service.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${service.durationInMinutes} minutes duration',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8), // Slate 400
                        fontSize: 14.0,
                        height: 1.6,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF38BDF8)),
                          onPressed: () => _showServiceTypeDialog(service: service),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Color(0xFFEF4444)),
                          onPressed: () => _confirmDelete(service),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6366F1), // Indigo 500
        foregroundColor: Colors.white,
        onPressed: () => _showServiceTypeDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              color: Color(0xFF475569),
              size: 48.0,
            ),
          ),
          const SizedBox(height: 16.0),
          const Text(
            'No Service Types Found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),
          const Text(
            'Create service types to define appointment durations.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14.0,
            ),
          ),
        ],
      ),
    );
  }
}
