class AttendanceVerificationModel {
  final String verificationId;
  final String? staffId;
  final String action; // 'check_in', 'check_out', 'failed'
  final DateTime timestamp;
  final bool success;
  final double? confidence;
  final String? deviceId;
  final String? failureReason;

  AttendanceVerificationModel({
    required this.verificationId,
    this.staffId,
    required this.action,
    required this.timestamp,
    required this.success,
    this.confidence,
    this.deviceId,
    this.failureReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'verificationId': verificationId,
      'staffId': staffId,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
      'success': success ? 1 : 0,
      'confidence': confidence,
      'deviceId': deviceId,
      'failureReason': failureReason,
    };
  }

  factory AttendanceVerificationModel.fromMap(Map<String, dynamic> map) {
    return AttendanceVerificationModel(
      verificationId: map['verificationId'] as String,
      staffId: map['staffId'] as String?,
      action: map['action'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      success: map['success'] == 1 || map['success'] == true,
      confidence: map['confidence'] != null ? (map['confidence'] as num).toDouble() : null,
      deviceId: map['deviceId'] as String?,
      failureReason: map['failureReason'] as String?,
    );
  }
}
