import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/service_type.dart';
import '../models/schedule_slot.dart';
import '../providers/service_provider.dart';
import '../providers/session_provider.dart';
import 'widgets/conflict_dialog.dart';

class SessionGenerationScreen extends ConsumerStatefulWidget {
  final VoidCallback onGenerationSuccess;

  const SessionGenerationScreen({super.key, required this.onGenerationSuccess});

  @override
  ConsumerState<SessionGenerationScreen> createState() => _SessionGenerationScreenState();
}

class _SessionGenerationScreenState extends ConsumerState<SessionGenerationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _totalSessionsController = TextEditingController(text: '10');
  
  ServiceType? _selectedServiceType;
  
  // Maps weekday (1=Mon, 7=Sun) to selected TimeOfDay
  final Map<int, TimeOfDay> _selectedDays = {};

  @override
  void dispose() {
    _clientNameController.dispose();
    _totalSessionsController.dispose();
    super.dispose();
  }

  String _getWeekdayName(int day) {
    switch (day) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  Future<void> _selectTime(int day) async {
    final currentTime = _selectedDays[day] ?? const TimeOfDay(hour: 9, minute: 0);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        _selectedDays[day] = pickedTime;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServiceType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a service type'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one schedule day'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final clientName = _clientNameController.text.trim();
    final totalSessions = int.parse(_totalSessionsController.text);
    
    // Map selected days to ScheduleSlot models
    final slots = _selectedDays.entries.map((e) => ScheduleSlot(
      weekday: e.key,
      hour: e.value.hour,
      minute: e.value.minute,
    )).toList();

    final sessionsNotifier = ref.read(sessionsProvider.notifier);
    final now = DateTime.now();

    // Pre-calculate session dates to check for conflicts
    final generatedDates = sessionsNotifier.generateSessionDates(
      startFrom: now,
      slots: slots,
      totalSessions: totalSessions,
    );

    final conflictCount = sessionsNotifier.countConflicts(
      generatedDates,
      _selectedServiceType!.durationInMinutes,
    );

    bool proceed = true;
    if (conflictCount > 0) {
      proceed = await showDialog<bool>(
        context: context,
        builder: (context) => ConflictDialog(
          title: 'Schedule Conflict Detected',
          content: 'There are $conflictCount conflict(s) with existing sessions in this series. Do you want to generate and overlap them anyway?',
        ),
      ) ?? false;
    }

    if (proceed) {
      await sessionsNotifier.generateSeries(
        clientName: clientName,
        serviceType: _selectedServiceType!,
        totalSessions: totalSessions,
        slots: slots,
        startFrom: now,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully generated $totalSessions sessions for $clientName!'),
            backgroundColor: Colors.green,
          ),
        );
        // Clear form
        _clientNameController.clear();
        _totalSessionsController.text = '10';
        setState(() {
          _selectedServiceType = null;
          _selectedDays.clear();
        });
        widget.onGenerationSuccess();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceTypes = ref.watch(serviceTypesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Generate Session Series',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20.0),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Client Name
              TextFormField(
                controller: _clientNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Client / Group Name',
                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                  hintText: 'e.g., Ahmet Bey or Ebru - Ayşe',
                  hintStyle: const TextStyle(color: Color(0xFF475569)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a client or group name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),

              // Service Type Dropdown
              DropdownButtonFormField<ServiceType>(
                value: _selectedServiceType,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Service Type',
                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                ),
                items: serviceTypes.map((type) {
                  return DropdownMenuItem<ServiceType>(
                    value: type,
                    child: Text('${type.name} (${type.durationInMinutes} min)'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedServiceType = val;
                  });
                },
                validator: (value) => value == null ? 'Please select a service type' : null,
              ),
              const SizedBox(height: 16.0),

              // Total Sessions
              TextFormField(
                controller: _totalSessionsController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Total Sessions',
                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                  hintText: 'e.g., 10',
                  hintStyle: const TextStyle(color: Color(0xFF475569)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter total sessions count';
                  }
                  final count = int.tryParse(value);
                  if (count == null || count <= 0) {
                    return 'Please enter a valid count greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24.0),

              // Weekly Schedule Section Header
              const Text(
                'Weekly Schedule Days & Times',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12.0),

              // Days selector list
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 7,
                itemBuilder: (context, index) {
                  final weekdayNum = index + 1;
                  final isChecked = _selectedDays.containsKey(weekdayNum);
                  final timeOfDay = _selectedDays[weekdayNum] ?? const TimeOfDay(hour: 10, minute: 0);
                  
                  // Format TimeOfDay
                  final tempDate = DateTime(2026, 1, 1, timeOfDay.hour, timeOfDay.minute);
                  final formattedTime = DateFormat.jm().format(tempDate);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: isChecked ? const Color(0xFF1E293B) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(
                        color: isChecked ? const Color(0xFF475569) : const Color(0xFF334155),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: isChecked,
                              activeColor: const Color(0xFF6366F1),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedDays[weekdayNum] = const TimeOfDay(hour: 10, minute: 0);
                                  } else {
                                    _selectedDays.remove(weekdayNum);
                                  }
                                });
                              },
                            ),
                            Text(
                              _getWeekdayName(weekdayNum),
                              style: TextStyle(
                                color: isChecked ? Colors.white : const Color(0xFF94A3B8),
                                fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        if (isChecked)
                          OutlinedButton.icon(
                            onPressed: () => _selectTime(weekdayNum),
                            icon: const Icon(Icons.access_time, size: 16.0, color: Color(0xFF38BDF8)),
                            label: Text(
                              formattedTime,
                              style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF38BDF8)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 32.0),

              // Submit Button
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  elevation: 2,
                ),
                child: const Text(
                  'Generate and Save Series',
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 40.0),
            ],
          ),
        ),
      ),
    );
  }
}
