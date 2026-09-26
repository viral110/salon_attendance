class FaceRecognitionConfig {
  /// Similarity score threshold (0.0 to 1.0) for face recognition matching.
  static const double recognitionThreshold = 0.45;

  /// Similarity score threshold for detecting duplicate face enrollment across different staff members.
  static const double duplicateThreshold = 0.65;

  /// Required confidence margin between top matching staff and second-best candidate.
  static const double confidenceMargin = 0.04;

  /// Number of high-quality camera frames to average during staff face enrollment.
  static const int enrollmentSampleCount = 5;

  /// Maximum recognition attempts before declaring an unrecognized face.
  static const int maxRecognitionAttempts = 3;

  /// Cooldown window in seconds to prevent accidental duplicate check-in/out scans.
  static const int duplicateProtectionSeconds = 30;

  /// Standard office start time in HH:mm (24h) format.
  static const String officeStartTime = "09:00";

  /// Standard office end time in HH:mm (24h) format.
  static const String officeEndTime = "18:00";

  /// Grace period in minutes after office start time before marking late check-in.
  static const int gracePeriodMinutes = 15;

  /// Minimum ratio of face bounding box size relative to total camera frame width.
  static const double minFaceSizeRatio = 0.18;

  /// Maximum ratio of face bounding box size relative to total camera frame width.
  static const double maxFaceSizeRatio = 0.85;

  /// Maximum allowed horizontal head angle (Euler Y) for frontal face validation.
  static const double maxHeadYawAngle = 20.0;

  /// Maximum allowed head tilt angle (Euler Z) for frontal face validation.
  static const double maxHeadRollAngle = 20.0;
}
