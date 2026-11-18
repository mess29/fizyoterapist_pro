import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../providers/session_provider.dart';
import 'widgets/session_details_dialog.dart';
import 'widgets/conflict_dialog.dart';

class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late DateTime _selectedDay;
  late DateTime _currentWeekStart;
  final double _hourHeight = 80.0;
  final int _startHour = 7;
  final int _endHour = 22;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _currentWeekStart = _getMonday(_selectedDay);
  }

  DateTime _getMonday(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  List<DateTime> _getWeekDays(DateTime startOfWeek) {
    return List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
  }

  void _navigateToPreviousWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
      _selectedDay = _currentWeekStart;
    });
  }

  void _navigateToNextWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
      _selectedDay = _currentWeekStart;
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = DateTime(day.year, day.month, day.day);
      _currentWeekStart = _getMonday(_selectedDay);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDay = DateTime(now.year, now.month, now.day);
      _currentWeekStart = _getMonday(_selectedDay);
    });
  }

  Color _getEventColor(String serviceTypeName) {
    // Generate distinct beautiful colors for service types
    final name = serviceTypeName.toLowerCase();
    if (name.contains('pilates')) {
      return const Color(0xFF14B8A6); // Teal 500
    } else if (name.contains('therapy') || name.contains('terapi')) {
      return const Color(0xFF6366F1); // Indigo 500
    } else if (name.contains('massage') || name.contains('masaj')) {
      return const Color(0xFFF59E0B); // Amber 500
    } else {
      return const Color(0xFFEC4899); // Pink 500
    }
  }

  Widget _buildPaymentIndicatorDot(PaymentStatus status) {
    Color color;
    switch (status) {
      case PaymentStatus.paid:
        color = const Color(0xFF22C55E); // Green 500
        break;
      case PaymentStatus.unpaid:
        color = const Color(0xFFEF4444); // Red 500
        break;
      case PaymentStatus.partiallyPaid:
        color = const Color(0xFFF59E0B); // Amber 500
        break;
    }
    return Container(
      width: 8.0,
      height: 8.0,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 0.5),
      ),
    );
  }

  Future<void> _handleSessionDetails(Session session) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => SessionDetailsDialog(session: session),
    );

    if (result == null) return;

    if (result == 'delete') {
      _handleDelete(session);
      return;
    }

    if (result is Session) {
      final notifier = ref.read(sessionsProvider.notifier);
      
      // Only run conflict checks if date/time changed
      final timeChanged = !result.dateTime.isAtSameMomentAs(session.dateTime);
      
      bool proceed = true;
      if (timeChanged) {
        final hasConflict = notifier.checkConflict(
          result.dateTime,
          result.serviceTypeDurationMinutes,
          excludeId: session.id,
        );

        if (hasConflict) {
          proceed = await showDialog<bool>(
                context: context,
                builder: (context) => const ConflictDialog(),
              ) ??
              false;
        }
      }

      if (proceed) {
        await notifier.updateSession(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  void _handleDelete(Session session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Session', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${session.label}"?',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(sessionsProvider.notifier).deleteSession(session.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Session deleted'),
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
    final allSessions = ref.watch(sessionsProvider);
    
    // Filter sessions for the selected day
    final dailySessions = allSessions.where((session) {
      final sDate = session.dateTime;
      return sDate.year == _selectedDay.year &&
          sDate.month == _selectedDay.month &&
          sDate.day == _selectedDay.day;
    }).toList();

    final weekDays = _getWeekDays(_currentWeekStart);
    final monthYearFormatter = DateFormat('MMMM yyyy');
    final formattedMonthYear = monthYearFormatter.format(_selectedDay);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        title: Text(
          formattedMonthYear,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20.0),
        ),
        backgroundColor: const Color(0xFF1E293B), // Slate 800
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: Color(0xFF38BDF8)),
            tooltip: 'Go to Today',
            onPressed: _goToToday,
          ),
        ],
      ),
      body: Column(
        children: [
          // Weekly calendar strip
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            color: const Color(0xFF1E293B), // Slate 800
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: _navigateToPreviousWeek,
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: weekDays.map((day) {
                      final isSelected = day.year == _selectedDay.year &&
                          day.month == _selectedDay.month &&
                          day.day == _selectedDay.day;
                      final isToday = day.year == DateTime.now().year &&
                          day.month == DateTime.now().month &&
                          day.day == DateTime.now().day;
                      final weekdayLetter = DateFormat('E').format(day).substring(0, 3);
                      final dayNum = day.day.toString();

                      return GestureDetector(
                        onTap: () => _selectDay(day),
                        child: Container(
                          width: 44.0,
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6366F1) // Indigo 500
                                : isToday
                                    ? const Color(0xFF334155) // Slate 700
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(10.0),
                            border: isToday && !isSelected
                                ? Border.all(color: const Color(0xFF6366F1), width: 1.5)
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                weekdayLetter,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF94A3B8), // Slate 400
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6.0),
                              Text(
                                dayNum,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white,
                                  fontSize: 16.0,
                                  fontWeight: isSelected || isToday
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: _navigateToNextWeek,
                ),
              ],
            ),
          ),

          // Daily Agenda Timeline View
          Expanded(
            child: dailySessions.isEmpty
                ? _buildEmptyState()
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12.0, 16.0, 16.0, 16.0),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Hour labels column
                            _buildHourLabelsColumn(),
                            const SizedBox(width: 12.0),
                            // Hourly grid and events stack
                            Expanded(
                              child: Stack(
                                children: [
                                  _buildTimelineGridBackground(),
                                  ..._buildPositionedSessionCards(dailySessions),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
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
              Icons.calendar_today_outlined,
              color: Color(0xFF475569),
              size: 48.0,
            ),
          ),
          const SizedBox(height: 16.0),
          const Text(
            'No Sessions Scheduled',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),
          const Text(
            'Use the "Generate Series" tab to add appointments.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourLabelsColumn() {
    return SizedBox(
      width: 44.0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_endHour - _startHour + 1, (index) {
          final hourNum = _startHour + index;
          final time = DateTime(2026, 1, 1, hourNum);
          final formattedHour = DateFormat.j().format(time);

          return SizedBox(
            height: _hourHeight,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  formattedHour,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTimelineGridBackground() {
    return Column(
      children: List.generate(_endHour - _startHour + 1, (index) {
        return SizedBox(
          height: _hourHeight,
          child: Column(
            children: [
              const Divider(color: Color(0xFF334155), height: 1.0), // Slate 700
              Expanded(child: Container()),
            ],
          ),
        );
      }),
    );
  }

  List<Widget> _buildPositionedSessionCards(List<Session> sessions) {
    final positionedSessions = _layoutSessions(sessions);

    return positionedSessions.map((pos) {
      final s = pos.session;
      final color = _getEventColor(s.serviceTypeName);
      final formattedStart = DateFormat.jm().format(s.dateTime);
      final formattedEnd = DateFormat.jm().format(s.endTime);

      return Positioned(
        top: pos.top,
        height: pos.height,
        left: pos.left * (MediaQuery.of(context).size.width - 84.0),
        width: pos.widthFactor * (MediaQuery.of(context).size.width - 84.0) - 2.0,
        child: GestureDetector(
          onTap: () => _handleSessionDetails(s),
          onLongPress: () => _handleDelete(s),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 1.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.95), color.withOpacity(0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10.0),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4.0,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client & Service Label
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          s.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            overflow: TextOverflow.fade,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4.0),
                      _buildPaymentIndicatorDot(s.paymentStatus),
                    ],
                  ),
                ),
                // Time Range
                const SizedBox(height: 2.0),
                Text(
                  '$formattedStart - $formattedEnd (${s.serviceTypeDurationMinutes}m)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 10.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<PositionedSession> _layoutSessions(List<Session> sessions) {
    // Sort sessions by start time
    List<Session> sorted = List.from(sessions)..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    List<PositionedSession> positioned = [];
    List<List<PositionedSession>> groups = [];

    for (var session in sorted) {
      double top = ((session.dateTime.hour + session.dateTime.minute / 60.0) - _startHour) * _hourHeight;
      double height = (session.serviceTypeDurationMinutes / 60.0) * _hourHeight;
      var posSession = PositionedSession(session, top, height);

      bool addedToGroup = false;
      for (var group in groups) {
        double groupMinTop = group.map((s) => s.top).reduce((a, b) => a < b ? a : b);
        double groupMaxBottom = group.map((s) => s.top + s.height).reduce((a, b) => a > b ? a : b);

        // Check if overlaps
        if (posSession.top < groupMaxBottom && (posSession.top + posSession.height) > groupMinTop) {
          group.add(posSession);
          addedToGroup = true;
          break;
        }
      }

      if (!addedToGroup) {
        groups.add([posSession]);
      }
      positioned.add(posSession);
    }

    for (var group in groups) {
      group.sort((a, b) => a.top.compareTo(b.top));
      List<List<PositionedSession>> columns = [];

      for (var posSession in group) {
        int colIndex = 0;
        bool placed = false;
        while (!placed) {
          if (colIndex >= columns.length) {
            columns.add([posSession]);
            placed = true;
          } else {
            var col = columns[colIndex];
            // Check overlap with the last item in this column
            if (posSession.top >= (col.last.top + col.last.height)) {
              col.add(posSession);
              placed = true;
            } else {
              colIndex++;
            }
          }
        }
      }

      int totalCols = columns.length;
      for (int colIndex = 0; colIndex < totalCols; colIndex++) {
        for (var posSession in columns[colIndex]) {
          posSession.left = colIndex.toDouble() / totalCols;
          posSession.widthFactor = 1.0 / totalCols;
        }
      }
    }

    return positioned;
  }
}

class PositionedSession {
  final Session session;
  final double top;
  final double height;
  double left = 0.0;
  double widthFactor = 1.0;

  PositionedSession(this.session, this.top, this.height);
}
