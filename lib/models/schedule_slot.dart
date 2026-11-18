class ScheduleSlot {
  final int weekday; // 1 = Monday, 7 = Sunday
  final int hour;
  final int minute;

  ScheduleSlot({
    required this.weekday,
    required this.hour,
    required this.minute,
  });

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'hour': hour,
        'minute': minute,
      };

  factory ScheduleSlot.fromJson(Map<String, dynamic> json) => ScheduleSlot(
        weekday: json['weekday'] as int,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      );

  String get dayName {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  String get timeString {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
