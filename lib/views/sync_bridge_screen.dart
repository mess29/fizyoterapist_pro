import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/session_provider.dart';
import '../providers/service_provider.dart';
import '../models/session.dart';

class SyncBridgeScreen extends ConsumerStatefulWidget {
  const SyncBridgeScreen({super.key});

  @override
  ConsumerState<SyncBridgeScreen> createState() => _SyncBridgeScreenState();
}

class _SyncBridgeScreenState extends ConsumerState<SyncBridgeScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  String _exportedJson = '';
  final _importController = TextEditingController();
  String _syncMessage = '';
  bool _isSuccess = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0); // Last day of month
  }

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picker = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picker != null) {
      setState(() {
        _startDate = picker;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picker = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picker != null) {
      setState(() {
        _endDate = picker;
      });
    }
  }

  void _handleExport() {
    final exported = ref.read(sessionsProvider.notifier).exportSyncData(_startDate, _endDate);
    final encoder = const JsonEncoder.withIndent('  ');
    setState(() {
      _exportedJson = encoder.convert(exported);
    });
  }

  void _copyToClipboard() {
    if (_exportedJson.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _exportedJson));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('JSON copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _handleImport() async {
    final jsonText = _importController.text.trim();
    if (jsonText.isEmpty) {
      setState(() {
        _syncMessage = 'Please enter a JSON payload to import.';
        _isSuccess = false;
      });
      return;
    }

    final notifier = ref.read(sessionsProvider.notifier);
    final result = await notifier.importSyncData(jsonText);

    setState(() {
      if (result.errorMessage != null) {
        _syncMessage = result.errorMessage!;
        _isSuccess = false;
      } else {
        _syncMessage = 'Import successful!\n'
            '- Service Types loaded: ${result.importedServiceTypesCount}\n'
            '- Sessions updated/loaded: ${result.importedSessionsCount}\n'
            '- Overlap conflicts recorded: ${result.conflictLogs.length}';
        _isSuccess = true;
        _importController.clear();
      }
    });
  }

  // Generates a mock sync payload for the user to try the feature easily
  void _loadSamplePayload() {
    final sessions = ref.read(sessionsProvider);
    final services = ref.read(serviceTypesProvider);

    // If we have an existing session, let's reschedule it and mark it paid as a sample update
    if (sessions.isNotEmpty) {
      final sampleSession = sessions.first;
      // Reschedule to tomorrow at 11:00 AM
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final newTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 11, 0);
      
      final payloadMap = {
        'serviceTypes': services.map((s) => s.toJson()).toList(),
        'sessions': [
          sampleSession.copyWith(
            dateTime: newTime,
            price: 700.0,
            paymentStatus: PaymentStatus.paid,
            amountPaid: 700.0,
          ).toJson()
        ]
      };
      
      final encoder = const JsonEncoder.withIndent('  ');
      _importController.text = encoder.convert(payloadMap);
    } else {
      // If db is empty, create a dummy session and a dummy service type
      final serviceId = const Uuid().v4();
      final sessionId = const Uuid().v4();
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final newTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0);

      final payloadMap = {
        'serviceTypes': [
          {
            'id': serviceId,
            'name': 'Clinical Pilates',
            'durationInMinutes': 50,
          }
        ],
        'sessions': [
          {
            'id': sessionId,
            'clientName': 'Sample Client (Imported)',
            'serviceTypeId': serviceId,
            'serviceTypeName': 'Clinical Pilates',
            'serviceTypeDurationMinutes': 50,
            'dateTime': newTime.toIso8601String(),
            'price': 600.0,
            'paymentStatus': 'partiallyPaid',
            'amountPaid': 200.0,
          }
        ]
      };
      
      final encoder = const JsonEncoder.withIndent('  ');
      _importController.text = encoder.convert(payloadMap);
    }

    setState(() {
      _syncMessage = 'Sample update payload loaded. Click "Run Import Sync" to process.';
      _isSuccess = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final conflictLogs = ref.watch(syncConflictLogsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'AI Sync & Data Bridge',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20.0),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Export Panel
            _buildSectionHeader(Icons.download_rounded, 'Export Local Data'),
            const SizedBox(height: 12.0),
            _buildExportCard(),
            const SizedBox(height: 24.0),

            // Import Panel
            _buildSectionHeader(Icons.upload_rounded, 'Import Sync Updates'),
            const SizedBox(height: 12.0),
            _buildImportCard(),
            const SizedBox(height: 24.0),

            // Conflict Logs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(Icons.history_toggle_off_rounded, 'Import Conflict Logs'),
                if (conflictLogs.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(syncConflictLogsProvider.notifier).clearLogs();
                    },
                    icon: const Icon(Icons.clear_all, color: Color(0xFFEF4444), size: 16.0),
                    label: const Text('Clear History', style: TextStyle(color: Color(0xFFEF4444))),
                  ),
              ],
            ),
            const SizedBox(height: 12.0),
            _buildConflictLogsList(conflictLogs),
            const SizedBox(height: 40.0),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6366F1), size: 20.0),
        const SizedBox(width: 8.0),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildExportCard() {
    final startStr = DateFormat('yMMMd').format(_startDate);
    final endStr = DateFormat('yMMMd').format(_endDate);

    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectStartDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF475569)),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Start Date', style: TextStyle(color: Color(0xFF64748B), fontSize: 10.0)),
                          const SizedBox(height: 4.0),
                          Text(startStr, style: const TextStyle(color: Colors.white, fontSize: 13.0)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: InkWell(
                    onTap: _selectEndDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF475569)),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('End Date', style: TextStyle(color: Color(0xFF64748B), fontSize: 10.0)),
                          const SizedBox(height: 4.0),
                          Text(endStr, style: const TextStyle(color: Colors.white, fontSize: 13.0)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _handleExport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                padding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
              child: const Text('Export JSON', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (_exportedJson.isNotEmpty) ...[
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Exported Payload', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Color(0xFF38BDF8), size: 18.0),
                    onPressed: _copyToClipboard,
                    tooltip: 'Copy to Clipboard',
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Container(
                constraints: const BoxConstraints(maxHeight: 180.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _exportedJson,
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      color: Color(0xFF38BDF8),
                      fontSize: 11.0,
                    ),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildImportCard() {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _importController,
              maxLines: 5,
              style: const TextStyle(fontFamily: 'Courier', color: Color(0xFF38BDF8), fontSize: 11.0),
              decoration: InputDecoration(
                hintText: 'Paste update JSON payload here...',
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF475569)),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                filled: true,
                fillColor: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loadSamplePayload,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF64748B)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    child: const Text('Load Sample Update', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleImport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    child: const Text('Run Import Sync', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            if (_syncMessage.isNotEmpty) ...[
              const SizedBox(height: 16.0),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: _isSuccess ? const Color(0xFF14B8A6).withOpacity(0.1) : const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: _isSuccess ? const Color(0xFF14B8A6) : const Color(0xFFEF4444),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  _syncMessage,
                  style: TextStyle(
                    color: _isSuccess ? const Color(0xFF2DD4BF) : const Color(0xFFFCA5A5),
                    fontSize: 12.0,
                    height: 1.5,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildConflictLogsList(List<dynamic> logs) {
    if (logs.isEmpty) {
      return Card(
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Center(
            child: Text(
              'No import conflicts recorded.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13.0),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final conflictTime = DateFormat('MMM d, h:mm a').format(log.timestamp);
        final sessionTime = DateFormat('MMM d, h:mm a').format(log.dateTime);

        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 8.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: const BorderSide(color: Color(0xFFEF4444), width: 0.5),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12.0),
            leading: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20.0),
            ),
            title: Text(
              'Conflict: ${log.clientName}',
              style: const TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4.0),
                Text(
                  'Proposed: $sessionTime\nDetails: ${log.message}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0, height: 1.4),
                ),
                const SizedBox(height: 6.0),
                Text(
                  'Logged: $conflictTime',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.0),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
