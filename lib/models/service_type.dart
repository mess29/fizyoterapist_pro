class ServiceType {
  final String id;
  final String name;
  final int durationInMinutes;

  ServiceType({
    required this.id,
    required this.name,
    required this.durationInMinutes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'durationInMinutes': durationInMinutes,
      };

  factory ServiceType.fromJson(Map<String, dynamic> json) => ServiceType(
        id: json['id'] as String,
        name: json['name'] as String,
        durationInMinutes: json['durationInMinutes'] as int,
      );
}
