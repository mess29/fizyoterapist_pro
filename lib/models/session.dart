enum PaymentStatus {
  paid,
  unpaid,
  partiallyPaid;

  String get label {
    switch (this) {
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.partiallyPaid:
        return 'Partially Paid';
    }
  }

  static PaymentStatus fromJson(String value) {
    switch (value.toLowerCase()) {
      case 'paid':
        return PaymentStatus.paid;
      case 'partiallypaid':
      case 'partially_paid':
        return PaymentStatus.partiallyPaid;
      case 'unpaid':
      default:
        return PaymentStatus.unpaid;
    }
  }

  String toJson() {
    switch (this) {
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.partiallyPaid:
        return 'partiallyPaid';
      case PaymentStatus.unpaid:
        return 'unpaid';
    }
  }
}

class Session {
  final String id;
  final String clientName;
  final String serviceTypeId;
  final String serviceTypeName;
  final int serviceTypeDurationMinutes;
  final DateTime dateTime;
  final String? seriesId;
  final int? indexInSeries;
  final int? totalInSeries;
  
  // Phase 2 Financial Fields
  final double? price;
  final PaymentStatus paymentStatus;
  final double amountPaid;

  Session({
    required this.id,
    required this.clientName,
    required this.serviceTypeId,
    required this.serviceTypeName,
    required this.serviceTypeDurationMinutes,
    required this.dateTime,
    this.seriesId,
    this.indexInSeries,
    this.totalInSeries,
    this.price,
    this.paymentStatus = PaymentStatus.unpaid,
    this.amountPaid = 0.0,
  });

  DateTime get endTime => dateTime.add(Duration(minutes: serviceTypeDurationMinutes));

  String get label => (indexInSeries != null && totalInSeries != null)
      ? '$clientName - $serviceTypeName ($indexInSeries/$totalInSeries)'
      : '$clientName - $serviceTypeName';

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'serviceTypeId': serviceTypeId,
        'serviceTypeName': serviceTypeName,
        'serviceTypeDurationMinutes': serviceTypeDurationMinutes,
        'dateTime': dateTime.toIso8601String(),
        'seriesId': seriesId,
        'indexInSeries': indexInSeries,
        'totalInSeries': totalInSeries,
        'price': price,
        'paymentStatus': paymentStatus.toJson(),
        'amountPaid': amountPaid,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] as String,
        clientName: json['clientName'] as String,
        serviceTypeId: json['serviceTypeId'] as String,
        serviceTypeName: json['serviceTypeName'] as String,
        serviceTypeDurationMinutes: json['serviceTypeDurationMinutes'] as int,
        dateTime: DateTime.parse(json['dateTime'] as String),
        seriesId: json['seriesId'] as String?,
        indexInSeries: json['indexInSeries'] as int?,
        totalInSeries: json['totalInSeries'] as int?,
        price: json['price'] != null ? (json['price'] as num).toDouble() : null,
        paymentStatus: json['paymentStatus'] != null
            ? PaymentStatus.fromJson(json['paymentStatus'] as String)
            : PaymentStatus.unpaid,
        amountPaid: json['amountPaid'] != null
            ? (json['amountPaid'] as num).toDouble()
            : 0.0,
      );

  Session copyWith({
    String? id,
    String? clientName,
    String? serviceTypeId,
    String? serviceTypeName,
    int? serviceTypeDurationMinutes,
    DateTime? dateTime,
    String? seriesId,
    int? indexInSeries,
    int? totalInSeries,
    double? price,
    PaymentStatus? paymentStatus,
    double? amountPaid,
  }) {
    return Session(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      serviceTypeId: serviceTypeId ?? this.serviceTypeId,
      serviceTypeName: serviceTypeName ?? this.serviceTypeName,
      serviceTypeDurationMinutes: serviceTypeDurationMinutes ?? this.serviceTypeDurationMinutes,
      dateTime: dateTime ?? this.dateTime,
      seriesId: seriesId ?? this.seriesId,
      indexInSeries: indexInSeries ?? this.indexInSeries,
      totalInSeries: totalInSeries ?? this.totalInSeries,
      price: price ?? this.price,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amountPaid: amountPaid ?? this.amountPaid,
    );
  }
}
