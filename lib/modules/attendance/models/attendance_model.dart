enum AttendanceStatus {
  checkedIn,
  checkedOut,
  incomplete,
}

extension AttendanceStatusExtension on AttendanceStatus {
  String get value {
    switch (this) {
      case AttendanceStatus.checkedIn:
        return 'checked_in';
      case AttendanceStatus.checkedOut:
        return 'checked_out';
      case AttendanceStatus.incomplete:
        return 'incomplete';
    }
  }

  static AttendanceStatus fromString(String status) {
    switch (status) {
      case 'checked_in':
        return AttendanceStatus.checkedIn;
      case 'checked_out':
        return AttendanceStatus.checkedOut;
      default:
        return AttendanceStatus.incomplete;
    }
  }
}

class AttendanceModel {
  final String id;
  final String staffId;
  final String dateKey; // Deterministic "YYYY-MM-DD"
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final AttendanceStatus status;
  final String? checkInVerificationId;
  final String? checkOutVerificationId;
  final double? checkInConfidence;
  final double? checkOutConfidence;
  final DateTime createdAt;
  final DateTime updatedAt;

  AttendanceModel({
    required this.id,
    required this.staffId,
    required this.dateKey,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.status,
    this.checkInVerificationId,
    this.checkOutVerificationId,
    this.checkInConfidence,
    this.checkOutConfidence,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Calculates working duration if both checkIn and checkOut are recorded.
  Duration? get workingDuration {
    if (checkIn != null && checkOut != null) {
      return checkOut!.difference(checkIn!);
    }
    return null;
  }

  /// Returns working duration formatted cleanly as e.g. "08h 49m".
  String get formattedWorkingDuration {
    final duration = workingDuration;
    if (duration == null) return '--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m';
  }

  AttendanceModel copyWith({
    String? id,
    String? staffId,
    String? dateKey,
    DateTime? date,
    DateTime? checkIn,
    DateTime? checkOut,
    AttendanceStatus? status,
    String? checkInVerificationId,
    String? checkOutVerificationId,
    double? checkInConfidence,
    double? checkOutConfidence,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      dateKey: dateKey ?? this.dateKey,
      date: date ?? this.date,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      status: status ?? this.status,
      checkInVerificationId: checkInVerificationId ?? this.checkInVerificationId,
      checkOutVerificationId: checkOutVerificationId ?? this.checkOutVerificationId,
      checkInConfidence: checkInConfidence ?? this.checkInConfidence,
      checkOutConfidence: checkOutConfidence ?? this.checkOutConfidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staffId': staffId,
      'dateKey': dateKey,
      'date': date.toIso8601String(),
      'checkIn': checkIn?.toIso8601String(),
      'checkOut': checkOut?.toIso8601String(),
      'status': status.value,
      'checkInVerificationId': checkInVerificationId,
      'checkOutVerificationId': checkOutVerificationId,
      'checkInConfidence': checkInConfidence,
      'checkOutConfidence': checkOutConfidence,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id'] as String,
      staffId: map['staffId'] as String,
      dateKey: map['dateKey'] as String,
      date: DateTime.parse(map['date'] as String),
      checkIn: map['checkIn'] != null ? DateTime.parse(map['checkIn'] as String) : null,
      checkOut: map['checkOut'] != null ? DateTime.parse(map['checkOut'] as String) : null,
      status: AttendanceStatusExtension.fromString(map['status'] as String),
      checkInVerificationId: map['checkInVerificationId'] as String?,
      checkOutVerificationId: map['checkOutVerificationId'] as String?,
      checkInConfidence: map['checkInConfidence'] != null
          ? (map['checkInConfidence'] as num).toDouble()
          : null,
      checkOutConfidence: map['checkOutConfidence'] != null
          ? (map['checkOutConfidence'] as num).toDouble()
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
